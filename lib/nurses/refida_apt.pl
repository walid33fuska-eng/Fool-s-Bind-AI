#!/usr/bin/perl
# ============================================
# Fool's Bind AI - الممرضة المتخصصة في APT/PKG (Refida Apt)
# ============================================
# الوظيفة: تثبيت وإصلاح حزم Termux (pkg/apt)
# ============================================

package refida_apt;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message run_command retry_command check_internet get_os_type detect_termux_path);

our @EXPORT = qw(heal);

# ============================================
# 📦 الدالة الرئيسية للإصلاح
# ============================================

sub heal {
    my ($task, $params) = @_;
    
    log_message("INFO", "refida_apt", "بدء مهمة APT/PKG: $task");
    
    # تنفيذ المهمة المطلوبة
    if ($task eq "self_check") {
        return _self_check();
    }
    elsif ($task eq "install_package") {
        my $package = $params->{package} // return ("ERROR", "لم يتم تحديد الحزمة");
        return _install_package($package);
    }
    elsif ($task eq "remove_package") {
        my $package = $params->{package} // return ("ERROR", "لم يتم تحديد الحزمة");
        return _remove_package($package);
    }
    elsif ($task eq "update_repos") {
        return _update_repos();
    }
    elsif ($task eq "upgrade_all") {
        return _upgrade_all();
    }
    elsif ($task eq "check_package") {
        my $package = $params->{package} // return ("ERROR", "لم يتم تحديد الحزمة");
        return _check_package($package);
    }
    elsif ($task eq "fix_broken") {
        return _fix_broken();
    }
    elsif ($task eq "clean_cache") {
        return _clean_cache();
    }
    elsif ($task eq "search_package") {
        my $package = $params->{package} // return ("ERROR", "لم يتم تحديد الحزمة");
        return _search_package($package);
    }
    else {
        return ("ERROR", "مهمة غير معروفة: $task");
    }
}

# ============================================
# 🔍 الفحص الذاتي
# ============================================

sub _self_check {
    my $status = "SUCCESS";
    my $details = "";
    
    my $os = get_os_type();
    $details .= "نظام التشغيل: $os\n";
    
    # فحص وجود pkg أو apt
    my $has_pkg = `which pkg 2>/dev/null` ? 1 : 0;
    my $has_apt = `which apt 2>/dev/null` ? 1 : 0;
    
    if ($has_pkg) {
        $details .= "pkg: ✅ موجود\n";
        
        # فحص إذا كان pkg يعمل
        my $pkg_test = `pkg list-installed 2>&1 | head -1`;
        if ($? == 0) {
            $details .= "pkg: ✅ يعمل\n";
        } else {
            $status = "WARNING";
            $details .= "pkg: ⚠️ قد لا يعمل بشكل صحيح\n";
        }
    }
    elsif ($has_apt) {
        $details .= "apt: ✅ موجود\n";
        
        my $apt_test = `apt list --installed 2>&1 | head -1`;
        if ($? == 0) {
            $details .= "apt: ✅ يعمل\n";
        } else {
            $status = "WARNING";
            $details .= "apt: ⚠️ قد لا يعمل بشكل صحيح\n";
        }
    }
    else {
        $status = "ERROR";
        $details .= "pkg/apt: ❌ غير موجود\n";
    }
    
    # فحص المستودعات
    my $sources_file = detect_termux_path() . "/etc/apt/sources.list";
    if (-f $sources_file) {
        $details .= "المستودعات: ✅ موجودة\n";
    } else {
        $status = "WARNING";
        $details .= "المستودعات: ❌ غير موجودة\n";
    }
    
    log_message("INFO", "refida_apt", "الفحص الذاتي: $status");
    return ($status, $details);
}

# ============================================
# 📦 تثبيت حزمة
# ============================================

sub _install_package {
    my ($package) = @_;
    
    log_message("INFO", "refida_apt", "محاولة تثبيت حزمة: $package");
    
    # التحقق من الإنترنت
    unless (check_internet()) {
        return ("ERROR", "لا يوجد إنترنت لتثبيت الحزمة $package");
    }
    
    # تحديث المستودعات أولاً
    _update_repos();
    
    # تحديد مدير الحزم المناسب
    my $pkg_manager = _get_pkg_manager();
    
    if ($pkg_manager eq "pkg") {
        my ($output, $success) = retry_command("pkg install $package -y", 3, 30);
        
        if ($success) {
            log_message("SUCCESS", "refida_apt", "تم تثبيت الحزمة $package بنجاح عبر pkg");
            
            # التحقق من التثبيت
            if (_check_package($package)) {
                return ("SUCCESS", "تم تثبيت الحزمة $package وتأكيدها");
            }
            return ("SUCCESS", "تم تثبيت الحزمة $package");
        }
        
        log_message("ERROR", "refida_apt", "فشل تثبيت الحزمة $package عبر pkg");
        return ("ERROR", "فشل تثبيت الحزمة $package: $output");
    }
    elsif ($pkg_manager eq "apt") {
        my ($output, $success) = retry_command("apt install $package -y", 3, 30);
        
        if ($success) {
            log_message("SUCCESS", "refida_apt", "تم تثبيت الحزمة $package بنجاح عبر apt");
            
            if (_check_package($package)) {
                return ("SUCCESS", "تم تثبيت الحزمة $package وتأكيدها");
            }
            return ("SUCCESS", "تم تثبيت الحزمة $package");
        }
        
        log_message("ERROR", "refida_apt", "فشل تثبيت الحزمة $package عبر apt");
        return ("ERROR", "فشل تثبيت الحزمة $package: $output");
    }
    
    return ("ERROR", "لا يوجد مدير حزم متاح");
}

# ============================================
# 🗑️ إزالة حزمة
# ============================================

sub _remove_package {
    my ($package) = @_;
    
    log_message("INFO", "refida_apt", "محاولة إزالة حزمة: $package");
    
    my $pkg_manager = _get_pkg_manager();
    
    if ($pkg_manager eq "pkg") {
        my ($output, $success) = run_command("pkg uninstall $package -y", 20);
        
        if ($success) {
            log_message("SUCCESS", "refida_apt", "تم إزالة الحزمة $package");
            return ("SUCCESS", "تم إزالة الحزمة $package");
        }
        
        return ("ERROR", "فشل إزالة الحزمة $package: $output");
    }
    elsif ($pkg_manager eq "apt") {
        my ($output, $success) = run_command("apt remove $package -y", 20);
        
        if ($success) {
            log_message("SUCCESS", "refida_apt", "تم إزالة الحزمة $package");
            return ("SUCCESS", "تم إزالة الحزمة $package");
        }
        
        return ("ERROR", "فشل إزالة الحزمة $package: $output");
    }
    
    return ("ERROR", "لا يوجد مدير حزم متاح");
}

# ============================================
# 🔄 تحديث المستودعات
# ============================================

sub _update_repos {
    log_message("INFO", "refida_apt", "تحديث المستودعات...");
    
    unless (check_internet()) {
        return ("ERROR", "لا يوجد إنترنت لتحديث المستودعات");
    }
    
    my $pkg_manager = _get_pkg_manager();
    
    if ($pkg_manager eq "pkg") {
        my ($output, $success) = retry_command("pkg update -y", 3, 60);
        
        if ($success) {
            log_message("SUCCESS", "refida_apt", "تم تحديث المستودعات عبر pkg");
            return ("SUCCESS", "تم تحديث المستودعات");
        }
        
        return ("ERROR", "فشل تحديث المستودعات: $output");
    }
    elsif ($pkg_manager eq "apt") {
        my ($output, $success) = retry_command("apt update -y", 3, 60);
        
        if ($success) {
            log_message("SUCCESS", "refida_apt", "تم تحديث المستودعات عبر apt");
            return ("SUCCESS", "تم تحديث المستودعات");
        }
        
        return ("ERROR", "فشل تحديث المستودعات: $output");
    }
    
    return ("ERROR", "لا يوجد مدير حزم متاح");
}

# ============================================
# ⬆️ ترقية جميع الحزم
# ============================================

sub _upgrade_all {
    log_message("INFO", "refida_apt", "ترقية جميع الحزم...");
    
    unless (check_internet()) {
        return ("ERROR", "لا يوجد إنترنت لترقية الحزم");
    }
    
    # تحديث المستودعات أولاً
    _update_repos();
    
    my $pkg_manager = _get_pkg_manager();
    
    if ($pkg_manager eq "pkg") {
        my ($output, $success) = retry_command("pkg upgrade -y", 3, 120);
        
        if ($success) {
            log_message("SUCCESS", "refida_apt", "تمت ترقية جميع الحزم");
            return ("SUCCESS", "تمت ترقية جميع الحزم");
        }
        
        return ("ERROR", "فشل ترقية الحزم: $output");
    }
    elsif ($pkg_manager eq "apt") {
        my ($output, $success) = retry_command("apt upgrade -y", 3, 120);
        
        if ($success) {
            log_message("SUCCESS", "refida_apt", "تمت ترقية جميع الحزم");
            return ("SUCCESS", "تمت ترقية جميع الحزم");
        }
        
        return ("ERROR", "فشل ترقية الحزم: $output");
    }
    
    return ("ERROR", "لا يوجد مدير حزم متاح");
}

# ============================================
# 🔧 إصلاح الحزم المكسورة
# ============================================

sub _fix_broken {
    log_message("INFO", "refida_apt", "إصلاح الحزم المكسورة...");
    
    my $pkg_manager = _get_pkg_manager();
    
    if ($pkg_manager eq "pkg") {
        my ($output, $success) = run_command("pkg install -f", 30);
        
        if ($success) {
            log_message("SUCCESS", "refida_apt", "تم إصلاح الحزم المكسورة");
            return ("SUCCESS", "تم إصلاح الحزم المكسورة");
        }
        
        # محاولة بديلة
        ($output, $success) = run_command("pkg check", 30);
        if ($success) {
            return ("SUCCESS", "تم فحص الحزم المكسورة ولم يتم العثور على مشاكل");
        }
        
        return ("WARNING", "قد توجد حزم مكسورة: $output");
    }
    elsif ($pkg_manager eq "apt") {
        my ($output, $success) = run_command("apt --fix-broken install -y", 30);
        
        if ($success) {
            log_message("SUCCESS", "refida_apt", "تم إصلاح الحزم المكسورة");
            return ("SUCCESS", "تم إصلاح الحزم المكسورة");
        }
        
        return ("WARNING", "قد توجد حزم مكسورة: $output");
    }
    
    return ("ERROR", "لا يوجد مدير حزم متاح");
}

# ============================================
# 🧹 تنظيف ذاكرة التخزين المؤقت
# ============================================

sub _clean_cache {
    log_message("INFO", "refida_apt", "تنظيف ذاكرة التخزين المؤقت...");
    
    my $pkg_manager = _get_pkg_manager();
    
    if ($pkg_manager eq "pkg") {
        my $cache_dir = "/data/data/com.termux/files/usr/var/cache/apt/archives";
        if (-d $cache_dir) {
            system("rm -rf $cache_dir/*.deb 2>/dev/null");
            log_message("SUCCESS", "refida_apt", "تم تنظيف ذاكرة التخزين المؤقت");
            return ("SUCCESS", "تم تنظيف ذاكرة التخزين المؤقت");
        }
    }
    elsif ($pkg_manager eq "apt") {
        my ($output, $success) = run_command("apt clean", 20);
        
        if ($success) {
            log_message("SUCCESS", "refida_apt", "تم تنظيف ذاكرة التخزين المؤقت");
            return ("SUCCESS", "تم تنظيف ذاكرة التخزين المؤقت");
        }
    }
    
    return ("WARNING", "لا توجد ذاكرة تخزين مؤقت لتنظيفها");
}

# ============================================
# 🔍 فحص وجود حزمة
# ============================================

sub _check_package {
    my ($package) = @_;
    
    my $pkg_manager = _get_pkg_manager();
    
    if ($pkg_manager eq "pkg") {
        my $check = `pkg list-installed 2>/dev/null | grep -E "^$package/"`;
        return 1 if $check;
        
        $check = `dpkg -l $package 2>/dev/null | grep "^ii"`;
        return 1 if $check;
    }
    elsif ($pkg_manager eq "apt") {
        my $check = `apt list --installed 2>/dev/null | grep "^$package/"`;
        return 1 if $check;
        
        $check = `dpkg -l $package 2>/dev/null | grep "^ii"`;
        return 1 if $check;
    }
    
    # فحص وجود الأمر في PATH
    my $which = `which $package 2>/dev/null`;
    return 1 if $which;
    
    return 0;
}

# ============================================
# 🔎 البحث عن حزمة
# ============================================

sub _search_package {
    my ($package) = @_;
    
    log_message("INFO", "refida_apt", "البحث عن حزمة: $package");
    
    unless (check_internet()) {
        return ("ERROR", "لا يوجد إنترنت للبحث عن الحزمة");
    }
    
    my $pkg_manager = _get_pkg_manager();
    
    if ($pkg_manager eq "pkg") {
        my ($output, $success) = run_command("pkg search $package", 30);
        
        if ($success && $output) {
            return ("SUCCESS", $output);
        }
        
        return ("WARNING", "لم يتم العثور على حزمة: $package");
    }
    elsif ($pkg_manager eq "apt") {
        my ($output, $success) = run_command("apt search $package", 30);
        
        if ($success && $output) {
            return ("SUCCESS", $output);
        }
        
        return ("WARNING", "لم يتم العثور على حزمة: $package");
    }
    
    return ("ERROR", "لا يوجد مدير حزم متاح");
}

# ============================================
# 🛠️ تحديد مدير الحزم المناسب
# ============================================

sub _get_pkg_manager {
    # التحقق من وجود pkg (Termux)
    my $which_pkg = `which pkg 2>/dev/null`;
    return "pkg" if $which_pkg;
    
    # التحقق من وجود apt
    my $which_apt = `which apt 2>/dev/null`;
    return "apt" if $which_apt;
    
    return undef;
}

# ============================================
# انتهى الملف
# ============================================
1;
