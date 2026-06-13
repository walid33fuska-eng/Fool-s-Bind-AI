#!/usr/bin/perl
# ============================================
# Fool's Bind AI - كاشف البيئة (Detector)
# ============================================
# الوظيفة: التعرف على البيئة وجمع المعلومات تلقائياً
# ============================================

package Detector;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);

# استيراد الدوال المساعدة
use lib dirname(abs_path($0)) . '/..';
use Utils qw(log_message get_timestamp colorize run_command get_os_type detect_termux_path);

our @EXPORT = qw(
    detect_all
    get_android_version
    get_termux_version
    get_architecture
    check_permissions
    get_free_space
    get_installed_packages
    detect_broken_tools
    get_environment_report
);

# ============================================
# 📊 المتغيرات العامة للبيئة
# ============================================

my %ENV_INFO = ();
my $OS_TYPE = "";
my $TERMUX_PATH = "";

# ============================================
# 🔍 الدالة الرئيسية: اكتشاف كل شيء
# ============================================

sub detect_all {
    log_message("INFO", "Detector", "بدء اكتشاف البيئة...");
    
    $OS_TYPE = get_os_type();
    $TERMUX_PATH = detect_termux_path();
    
    $ENV_INFO{os_type} = $OS_TYPE;
    $ENV_INFO{termux_path} = $TERMUX_PATH;
    $ENV_INFO{android_version} = get_android_version();
    $ENV_INFO{termux_version} = get_termux_version();
    $ENV_INFO{architecture} = get_architecture();
    $ENV_INFO{permissions} = check_permissions();
    $ENV_INFO{free_space} = get_free_space();
    $ENV_INFO{installed_packages} = get_installed_packages();
    $ENV_INFO{broken_tools} = detect_broken_tools();
    $ENV_INFO{internet} = Utils::check_internet();
    
    log_message("INFO", "Detector", "تم اكتشاف البيئة بنجاح");
    return \%ENV_INFO;
}

# ============================================
# 📱 اكتشاف إصدار Android
# ============================================

sub get_android_version {
    my $version = "Unknown";
    
    if ($OS_TYPE eq "Android") {
        $version = `getprop ro.build.version.release 2>/dev/null`;
        chomp($version);
        
        if ($version eq "") {
            $version = `cat /system/build.prop 2>/dev/null | grep "ro.build.version.release" | cut -d'=' -f2`;
            chomp($version);
        }
        
        # الحصول على API level
        my $api = `getprop ro.build.version.sdk 2>/dev/null`;
        chomp($api);
        $ENV_INFO{api_level} = $api if $api;
    }
    
    return $version || "Unknown";
}

# ============================================
# 📦 اكتشاف إصدار Termux
# ============================================

sub get_termux_version {
    my $version = "Unknown";
    my $source = "Unknown";
    
    if ($OS_TYPE eq "Android") {
        # محاولة من pkg
        my $pkg_list = `pkg list-installed 2>/dev/null | grep termux | head -1`;
        chomp($pkg_list);
        
        if ($pkg_list =~ /termux\/([\d\.]+)/) {
            $version = $1;
            $source = "pkg";
        }
        
        # محاولة من dpkg
        if ($version eq "Unknown") {
            $version = `dpkg -l termux 2>/dev/null | grep termux | awk '{print \$3}'`;
            chomp($version);
            $source = "dpkg" if $version;
        }
        
        # محاولة من ملف الإصدار
        if ($version eq "Unknown" && -f "$TERMUX_PATH/version") {
            $version = Utils::safe_read_file("$TERMUX_PATH/version");
            chomp($version);
            $source = "file" if $version;
        }
        
        # تحديد المصدر (F-Droid أو Google Play)
        if (-f "/data/data/com.termux/files/home/.installed_from_fdroid") {
            $source = "F-Droid";
        } elsif (-f "/data/data/com.termux/files/home/.installed_from_google_play") {
            $source = "Google Play";
        }
    } elsif ($OS_TYPE eq "iOS") {
        # على iOS، نحاول تحديد الإصدار من ملفات النظام
        if (-f "$TERMUX_PATH/var/lib/dpkg/status") {
            my $status = Utils::safe_read_file("$TERMUX_PATH/var/lib/dpkg/status");
            if ($status =~ /Package: termux\nVersion: ([\d\.]+)/) {
                $version = $1;
                $source = "dpkg";
            }
        }
    }
    
    $ENV_INFO{termux_source} = $source;
    return $version;
}

# ============================================
# 🖥️ اكتشاف نوع المعالج
# ============================================

sub get_architecture {
    my $arch = "Unknown";
    
    if ($OS_TYPE eq "Android") {
        $arch = `getprop ro.product.cpu.abi 2>/dev/null`;
        chomp($arch);
        
        if ($arch eq "") {
            $arch = `uname -m 2>/dev/null`;
            chomp($arch);
        }
    } else {
        $arch = `uname -m 2>/dev/null`;
        chomp($arch);
    }
    
    # توحيد الأسماء
    $arch = "ARM64" if $arch =~ /aarch64/;
    $arch = "ARM32" if $arch =~ /armv7l|armv8l/;
    $arch = "x86_64" if $arch =~ /x86_64/;
    $arch = "x86" if $arch =~ /i[3456]86/;
    
    return $arch;
}

# ============================================
# 🔐 فحص الصلاحيات
# ============================================

sub check_permissions {
    my %perms = ();
    
    # فحص صلاحية التخزين
    if ($OS_TYPE eq "Android") {
        $perms{storage} = (-d "/sdcard" && -r "/sdcard" && -w "/sdcard") ? "yes" : "no";
        $perms{termux_setup} = (-f "$TERMUX_PATH/bin/termux-setup-storage") ? "yes" : "no";
    } elsif ($OS_TYPE eq "iOS") {
        $perms{storage} = (-d "$ENV{HOME}/Documents") ? "yes" : "no";
    }
    
    # فحص صلاحية الكتابة في المسار الرئيسي
    $perms{termux_write} = (-w $TERMUX_PATH) ? "yes" : "no";
    
    # فحص صلاحية التنفيذ
    $perms{execute} = (-x $TERMUX_PATH) ? "yes" : "no";
    
    return \%perms;
}

# ============================================
# 💾 فحص المساحة المتوفرة
# ============================================

sub get_free_space {
    my $free_space = 0;
    my $unit = "MB";
    
    my $df_output = `df -h $TERMUX_PATH 2>/dev/null | tail -1`;
    chomp($df_output);
    
    if ($df_output =~ /(\d+(?:\.\d+)?)([MG]?)/) {
        $free_space = $1;
        $unit = $2 . "B" if $2;
        $unit = "MB" if $unit eq "M";
        $unit = "GB" if $unit eq "G";
    } else {
        # بديل: حساب المساحة بـ MB
        my $df_kb = `df -k $TERMUX_PATH 2>/dev/null | tail -1 | awk '{print \$4}'`;
        chomp($df_kb);
        $free_space = int($df_kb / 1024);
        $unit = "MB";
    }
    
    return "$free_space $unit";
}

# ============================================
# 📋 قائمة الحزم المثبتة
# ============================================

sub get_installed_packages {
    my @packages = ();
    
    # محاولة من pkg
    my $pkg_list = `pkg list-installed 2>/dev/null | grep -v "Listing" | awk '{print \$1}'`;
    if ($pkg_list) {
        @packages = split(/\n/, $pkg_list);
    }
    
    # بديل: من dpkg
    if (@packages == 0) {
        my $dpkg_list = `dpkg -l 2>/dev/null | grep ^ii | awk '{print \$2}'`;
        if ($dpkg_list) {
            @packages = split(/\n/, $dpkg_list);
        }
    }
    
    return \@packages;
}

# ============================================
# 🔧 اكتشاف الأدوات المعطوبة
# ============================================

sub detect_broken_tools {
    my @broken = ();
    
    # قائمة الأوامر الشائعة للفحص
    my @common_commands = qw(
        nmap wireshark python python3 node nodejs git curl wget
        perl bash ruby go rustc gcc clang make cmake openssl
        ssh ping traceroute netstat ifconfig iptables tcpdump
    );
    
    foreach my $cmd (@common_commands) {
        my $which = `which $cmd 2>/dev/null`;
        chomp($which);
        
        if ($which eq "") {
            push(@broken, "$cmd (غير مثبت)");
            next;
        }
        
        # فحص إذا كان قابل للتنفيذ
        if (! -x $which) {
            push(@broken, "$cmd (غير قابل للتنفيذ)");
            next;
        }
        
        # فحص بسيط للأمر (يعمل أم لا)
        my $test = `$cmd --version 2>/dev/null | head -1`;
        if ($test eq "") {
            push(@broken, "$cmd (لا يستجيب)");
        }
    }
    
    return \@broken;
}

# ============================================
# 📊 تقرير البيئة الكامل
# ============================================

sub get_environment_report {
    my $report = "";
    
    $report .= "\n" . "=" x 60 . "\n";
    $report .= "  🌍 تقرير البيئة - " . Utils::get_timestamp() . "\n";
    $report .= "=" x 60 . "\n\n";
    
    $report .= "┌────────────────────────────────────────┐\n";
    $report .= sprintf("│ %-20s : %-20s │\n", "نظام التشغيل", $ENV_INFO{os_type});
    $report .= sprintf("│ %-20s : %-20s │\n", "إصدار Android", $ENV_INFO{android_version});
    $report .= sprintf("│ %-20s : %-20s │\n", "إصدار Termux", $ENV_INFO{termux_version});
    $report .= sprintf("│ %-20s : %-20s │\n", "المصدر", $ENV_INFO{termux_source});
    $report .= sprintf("│ %-20s : %-20s │\n", "المعالج", $ENV_INFO{architecture});
    $report .= sprintf("│ %-20s : %-20s │\n", "المساحة المتوفرة", $ENV_INFO{free_space});
    $report .= sprintf("│ %-20s : %-20s │\n", "الإنترنت", $ENV_INFO{internet} ? "✅ متصل" : "❌ غير متصل");
    $report .= "└────────────────────────────────────────┘\n";
    
    # الصلاحيات
    $report .= "\n📋 الصلاحيات:\n";
    my $perms = $ENV_INFO{permissions};
    foreach my $key (keys %$perms) {
        my $status = ($perms->{$key} eq "yes") ? "✅" : "❌";
        $report .= sprintf("  %s %-15s : %s\n", $status, $key, $perms->{$key});
    }
    
    # الأدوات المعطوبة
    my $broken = $ENV_INFO{broken_tools};
    if (@$broken > 0) {
        $report .= "\n⚠️ الأدوات المعطوبة:\n";
        foreach my $tool (@$broken) {
            $report .= "  • $tool\n";
        }
    } else {
        $report .= "\n✅ جميع الأدوات تعمل بشكل طبيعي\n";
    }
    
    $report .= "\n" . "=" x 60 . "\n";
    
    log_message("INFO", "Detector", "تم إنشاء تقرير البيئة");
    return $report;
}

# ============================================
# انتهى الملف
# ============================================
1;
