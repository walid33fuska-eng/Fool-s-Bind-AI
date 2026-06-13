#!/usr/bin/perl
# ============================================
# Fool's Bind AI - الممرضة المتخصصة في الصلاحيات (Refida Permission)
# ============================================
# الوظيفة: إصلاح ومنح الصلاحيات المفقودة في Termux
# ============================================

package refida_permission;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message run_command get_os_type detect_termux_path);

our @EXPORT = qw(heal);

# ============================================
# 🔐 الدالة الرئيسية للإصلاح
# ============================================

sub heal {
    my ($task, $params) = @_;
    
    log_message("INFO", "refida_permission", "بدء مهمة Permissions: $task");
    
    if ($task eq "self_check") {
        return _self_check();
    }
    elsif ($task eq "fix_storage") {
        return _fix_storage_permission();
    }
    elsif ($task eq "fix_execute") {
        my $file = $params->{file} // return ("ERROR", "لم يتم تحديد الملف");
        return _fix_execute_permission($file);
    }
    elsif ($task eq "fix_directory") {
        my $dir = $params->{dir} // return ("ERROR", "لم يتم تحديد المجلد");
        return _fix_directory_permission($dir);
    }
    elsif ($task eq "fix_all") {
        return _fix_all_permissions();
    }
    elsif ($task eq "check_termux_api") {
        return _check_termux_api();
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
    
    # فحص صلاحية التخزين
    my $storage_ok = _check_storage_permission();
    $details .= "صلاحية التخزين: " . ($storage_ok ? "✅ مفعلة" : "❌ غير مفعلة") . "\n";
    $status = "WARNING" unless $storage_ok;
    
    # فحص صلاحية التنفيذ للمجلدات الرئيسية
    my $termux_path = detect_termux_path();
    my $bin_ok = (-x "$termux_path/bin") ? "✅" : "❌";
    $details .= "تنفيذ $termux_path/bin: $bin_ok\n";
    
    # فحص Termux-API
    my $api_installed = _check_termux_api();
    $details .= "Termux-API: " . ($api_installed ? "✅ مثبت" : "❌ غير مثبت") . "\n";
    
    log_message("INFO", "refida_permission", "الفحص الذاتي: $status");
    return ($status, $details);
}

# ============================================
# 📁 فحص صلاحية التخزين
# ============================================

sub _check_storage_permission {
    my $os = get_os_type();
    
    if ($os eq "Android") {
        # فحص إذا كان مجلد /sdcard قابل للقراءة
        return 1 if -r "/sdcard" && -w "/sdcard";
        
        # فحص Termux API إذا كان قد قام بإعداد التخزين
        my $storage_dir = "/data/data/com.termux/files/home/storage";
        return 1 if -d "$storage_dir/shared";
    }
    elsif ($os eq "iOS") {
        # على iOS، صلاحية التخزين مختلفة
        return 1 if -d "$ENV{HOME}/Documents";
    }
    
    return 0;
}

# ============================================
# 🔧 إصلاح صلاحية التخزين
# ============================================

sub _fix_storage_permission {
    log_message("INFO", "refida_permission", "محاولة إصلاح صلاحية التخزين");
    
    my $os = get_os_type();
    
    if ($os eq "Android") {
        # محاولة تشغيل termux-setup-storage
        my $setup_cmd = "termux-setup-storage";
        my $which = `which $setup_cmd 2>/dev/null`;
        
        if ($which) {
            my ($output, $success) = run_command($setup_cmd, 10);
            if ($success) {
                log_message("SUCCESS", "refida_permission", "تم تشغيل termux-setup-storage");
                sleep(2); # انتظار حتى يتم إنشاء المجلدات
                
                # التحقق من النجاح
                if (_check_storage_permission()) {
                    return ("SUCCESS", "تم منح صلاحية التخزين بنجاح");
                }
            }
        }
        
        # إذا فشل، نطلب من المستخدم التدخل اليدوي
        my $message = _get_storage_instruction($os);
        return ("NEED_USER", $message);
    }
    elsif ($os eq "iOS") {
        my $message = _get_storage_instruction($os);
        return ("NEED_USER", $message);
    }
    
    return ("ERROR", "نظام غير مدعوم لإصلاح صلاحية التخزين تلقائياً");
}

# ============================================
# 📝 توجيهات المستخدم للصلاحيات
# ============================================

sub _get_storage_instruction {
    my ($os) = @_;
    
    my $instruction = "";
    
    if ($os eq "Android") {
        $instruction = <<'EOF';
═══════════════════════════════════════════════════
  📱 Fool's Bind AI - مطلوب صلاحية التخزين
═══════════════════════════════════════════════════

لم أتمكن من منح صلاحية التخزين تلقائياً.

الرجاء تنفيذ الخطوات التالية يدوياً:

1. افتح Termux
2. اكتب الأمر التالي:
   termux-setup-storage

3. ستظهر نافذة من Android تطلب الإذن
4. اضغط "السماح" (Allow)

5. بعد الانتهاء، أعد تشغيل Fool's Bind AI

═══════════════════════════════════════════════════
EOF
    }
    elsif ($os eq "iOS") {
        $instruction = <<'EOF';
═══════════════════════════════════════════════════
  📱 Fool's Bind AI - مطلوب صلاحية التخزين (iOS)
═══════════════════════════════════════════════════

على نظام iOS، صلاحية التخزين تمنح يدوياً:

الرجاء تنفيذ الخطوات التالية:

1. افتح إعدادات الجهاز (Settings)
2. ابحث عن Termux
3. فعّل صلاحية "الملفات" (Files)

4. بعد الانتهاء، أعد تشغيل Fool's Bind AI

═══════════════════════════════════════════════════
EOF
    }
    
    return $instruction;
}

# ============================================
# 🔧 إصلاح صلاحية التنفيذ لملف
# ============================================

sub _fix_execute_permission {
    my ($file) = @_;
    
    log_message("INFO", "refida_permission", "إصلاح صلاحية التنفيذ للملف: $file");
    
    unless (-f $file) {
        return ("ERROR", "الملف غير موجود: $file");
    }
    
    # إضافة صلاحية التنفيذ
    my ($output, $success) = run_command("chmod +x '$file'", 5);
    
    if ($success && -x $file) {
        log_message("SUCCESS", "refida_permission", "تم إصلاح صلاحية التنفيذ لـ $file");
        return ("SUCCESS", "تم منح صلاحية التنفيذ للملف $file");
    }
    
    return ("ERROR", "فشل في منح صلاحية التنفيذ للملف $file");
}

# ============================================
# 🔧 إصلاح صلاحيات مجلد
# ============================================

sub _fix_directory_permission {
    my ($dir) = @_;
    
    log_message("INFO", "refida_permission", "إصلاح صلاحيات المجلد: $dir");
    
    unless (-d $dir) {
        return ("ERROR", "المجلد غير موجود: $dir");
    }
    
    # إصلاح صلاحيات المجلد (755 للمجلدات، 644 للملفات)
    my $fix_cmd = "find '$dir' -type d -exec chmod 755 {} \\; 2>/dev/null";
    run_command($fix_cmd, 30);
    
    $fix_cmd = "find '$dir' -type f -exec chmod 644 {} \\; 2>/dev/null";
    run_command($fix_cmd, 30);
    
    # جعل الملفات القابلة للتنفيذ (مثل .pl, .sh) قابلة للتنفيذ
    $fix_cmd = "find '$dir' -type f \\( -name '*.pl' -o -name '*.sh' -o -name '*.py' \\) -exec chmod +x {} \\; 2>/dev/null";
    run_command($fix_cmd, 30);
    
    log_message("SUCCESS", "refida_permission", "تم إصلاح صلاحيات المجلد $dir");
    return ("SUCCESS", "تم إصلاح صلاحيات المجلد $dir");
}

# ============================================
# 🔧 إصلاح جميع الصلاحيات
# ============================================

sub _fix_all_permissions {
    log_message("INFO", "refida_permission", "إصلاح جميع الصلاحيات");
    
    my $result = "";
    my $success_count = 0;
    
    # 1. إصلاح صلاحية التخزين
    my ($status, $msg) = _fix_storage_permission();
    if ($status eq "SUCCESS") {
        $success_count++;
        $result .= "✅ $msg\n";
    } elsif ($status eq "NEED_USER") {
        $result .= "⚠️ $msg\n";
    } else {
        $result .= "❌ $msg\n";
    }
    
    # 2. إصلاح صلاحيات مجلد Termux الرئيسي
    my $termux_path = detect_termux_path();
    if (-d $termux_path) {
        ($status, $msg) = _fix_directory_permission($termux_path);
        if ($status eq "SUCCESS") {
            $success_count++;
            $result .= "✅ $msg\n";
        }
    }
    
    # 3. إصلاح صلاحيات مجلد .termux
    my $home = $ENV{HOME} // "/data/data/com.termux/files/home";
    if (-d "$home/.termux") {
        ($status, $msg) = _fix_directory_permission("$home/.termux");
        if ($status eq "SUCCESS") {
            $success_count++;
            $result .= "✅ $msg\n";
        }
    }
    
    log_message("INFO", "refida_permission", "تم إصلاح $success_count عنصر");
    return ("SUCCESS", $result);
}

# ============================================
# 📦 فحص Termux-API
# ============================================

sub _check_termux_api {
    my $os = get_os_type();
    
    # Termux-API متاح فقط على Android
    return 0 if $os ne "Android";
    
    # فحص وجود الأمر
    my $which = `which termux-wifi-scaninfo 2>/dev/null`;
    return 1 if $which;
    
    $which = `which termux-battery-status 2>/dev/null`;
    return 1 if $which;
    
    return 0;
}

# ============================================
# 📦 تثبيت Termux-API (اختياري)
# ============================================

sub _install_termux_api {
    log_message("INFO", "refida_permission", "محاولة تثبيت Termux-API");
    
    my $os = get_os_type();
    return ("ERROR", "Termux-API متاح فقط على Android") if $os ne "Android";
    
    # التحقق من الإنترنت
    unless (Utils::check_internet()) {
        return ("ERROR", "لا يوجد إنترنت لتثبيت Termux-API");
    }
    
    # تثبيت الحزمة
    my ($output, $success) = run_command("pkg install termux-api -y", 30);
    
    if ($success) {
        log_message("SUCCESS", "refida_permission", "تم تثبيت Termux-API");
        return ("SUCCESS", "تم تثبيت Termux-API. قد تحتاج إلى منح صلاحيات إضافية من إعدادات الهاتف");
    }
    
    return ("WARNING", "فشل تثبيت Termux-API. يمكنك تثبيته يدوياً عبر: pkg install termux-api");
}

# ============================================
# انتهى الملف
# ============================================
1;
