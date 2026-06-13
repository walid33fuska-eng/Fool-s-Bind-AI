#!/usr/bin/perl
# ============================================
# Fool's Bind AI - البيمارستان (Bimaristan)
# ============================================
# الوظيفة: بوابة التطوير الآمن - ملف الإسعاف الذي لا يخضع للتشابك الكمي
# ============================================

package Bimaristan;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);
use File::Copy;
use File::Path qw(make_path remove_tree);
use Digest::SHA qw(sha256_hex);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message get_timestamp colorize run_command file_hash);

our @EXPORT = qw(
    emergency_add
    emergency_remove
    emergency_update
    emergency_rollback
    emergency_status
    verify_emergency_signature
    get_emergency_log
);

# ============================================
# 📋 متغيرات البيمارستان
# ============================================

my $TOOL_PATH = "";
my $EMERGENCY_LOG = "";
my $BACKUP_DIR = "";
my $VERSION = "1.0.0";
my $SIGNATURE_KEY = "fools_bind_ai_emergency_key_v1";
my @CHANGE_HISTORY = ();

# ============================================
# 🚀 الدوال العامة
# ============================================

sub emergency_add {
    my ($feature, $code, $signature, $description) = @_;
    
    _init_environment();
    
    log_message("INFO", "Bimaristan", "محاولة إضافة ميزة جديدة: $feature");
    
    # 1. التحقق من التوقيع
    unless (verify_emergency_signature($signature)) {
        log_message("ERROR", "Bimaristan", "توقيع غير صحيح لمحاولة إضافة $feature");
        return ("ERROR", "توقيع غير صحيح. لا يمكن إضافة الميزة.");
    }
    
    # 2. التحقق الثلاثي
    unless (_triple_verify()) {
        log_message("ERROR", "Bimaristan", "فشل التحقق الثلاثي لإضافة $feature");
        return ("ERROR", "فشل التحقق الثلاثي. لا يمكن إضافة الميزة.");
    }
    
    # 3. تسجيل العملية
    _log_emergency_action("ADD", $feature, $description);
    
    # 4. إنشاء نسخة احتياطية قبل الإضافة
    _create_backup();
    
    # 5. إضافة الميزة
    my $result = _integrate_feature($feature, $code);
    
    if ($result) {
        # 6. تحديث السجل
        _update_change_history("ADD", $feature, $description);
        _increment_version();
        
        log_message("SUCCESS", "Bimaristan", "تمت إضافة الميزة: $feature");
        return ("SUCCESS", "✅ تمت إضافة: $feature\nالإصدار الجديد: $VERSION");
    }
    
    # 7. استعادة النسخة الاحتياطية إذا فشلت الإضافة
    _restore_backup();
    
    log_message("ERROR", "Bimaristan", "فشل إضافة الميزة: $feature");
    return ("ERROR", "فشل إضافة الميزة. تم استعادة الحالة السابقة.");
}

# ============================================
# 🗑️ إزالة ميزة
# ============================================

sub emergency_remove {
    my ($feature, $signature, $reason) = @_;
    
    _init_environment();
    
    log_message("INFO", "Bimaristan", "محاولة إزالة ميزة: $feature");
    
    unless (verify_emergency_signature($signature)) {
        return ("ERROR", "توقيع غير صحيح");
    }
    
    unless (_triple_verify()) {
        return ("ERROR", "فشل التحقق الثلاثي");
    }
    
    _log_emergency_action("REMOVE", $feature, $reason);
    _create_backup();
    
    my $result = _remove_feature($feature);
    
    if ($result) {
        _update_change_history("REMOVE", $feature, $reason);
        _increment_version();
        
        return ("SUCCESS", "✅ تمت إزالة: $feature\nالإصدار الجديد: $VERSION");
    }
    
    _restore_backup();
    return ("ERROR", "فشل إزالة الميزة. تم استعادة الحالة السابقة.");
}

# ============================================
# 🔄 تحديث الميزات
# ============================================

sub emergency_update {
    my ($update_package, $signature) = @_;
    
    _init_environment();
    
    log_message("INFO", "Bimaristan", "بدء عملية التحديث");
    
    unless (verify_emergency_signature($signature)) {
        return ("ERROR", "توقيع غير صحيح");
    }
    
    unless (_triple_verify()) {
        return ("ERROR", "فشل التحقق الثلاثي");
    }
    
    _log_emergency_action("UPDATE", "full_update", $update_package);
    _create_backup();
    
    # تطبيق حزمة التحديث
    my $result = _apply_update_package($update_package);
    
    if ($result) {
        _update_change_history("UPDATE", "version", $VERSION);
        _increment_version();
        
        return ("SUCCESS", "✅ تم تحديث الأداة بنجاح\nالإصدار الجديد: $VERSION");
    }
    
    _restore_backup();
    return ("ERROR", "فشل التحديث. تم استعادة الحالة السابقة.");
}

# ============================================
# ⏪ التراجع عن آخر التغييرات
# ============================================

sub emergency_rollback {
    my ($signature, $steps) = @_;
    $steps //= 1;
    
    _init_environment();
    
    log_message("INFO", "Bimaristan", "التراجع عن $steps تغيير(تغييرات)");
    
    unless (verify_emergency_signature($signature)) {
        return ("ERROR", "توقيع غير صحيح");
    }
    
    unless (_triple_verify()) {
        return ("ERROR", "فشل التحقق الثلاثي");
    }
    
    _log_emergency_action("ROLLBACK", "$steps steps", "");
    
    my $rollback_count = 0;
    
    for (my $i = 0; $i < $steps; $i++) {
        my $backup_file = "$BACKUP_DIR/backup_" . ($#CHANGE_HISTORY - $i + 1) . ".tar.gz";
        if (-f $backup_file) {
            system("tar -xzf '$backup_file' -C '$TOOL_PATH' 2>/dev/null");
            $rollback_count++;
        }
    }
    
    if ($rollback_count > 0) {
        _update_change_history("ROLLBACK", "$steps steps", "تم التراجع");
        return ("SUCCESS", "✅ تم التراجع عن $rollback_count تغيير");
    }
    
    return ("WARNING", "لا توجد نسخ احتياطية كافية للتراجع");
}

# ============================================
# 📊 حالة البيمارستان
# ============================================

sub emergency_status {
    _init_environment();
    
    my $status = "";
    $status .= "\n" . "=" x 60 . "\n";
    $status .= "  🏥 البيمارستان - تقرير الحالة\n";
    $status .= "=" x 60 . "\n\n";
    
    $status .= "الإصدار الحالي: $VERSION\n";
    $status .= "عدد التغييرات المسجلة: " . scalar(@CHANGE_HISTORY) . "\n";
    $status .= "آخر تغيير: " . ($CHANGE_HISTORY[-1]->{timestamp} // "لا يوجد") . "\n";
    $status .= "آخر تغيير: $CHANGE_HISTORY[-1]->{action} $CHANGE_HISTORY[-1]->{feature}\n" if @CHANGE_HISTORY;
    
    $status .= "\nآخر 5 تغييرات:\n";
    my $start = @CHANGE_HISTORY > 5 ? @CHANGE_HISTORY - 5 : 0;
    for (my $i = $start; $i < @CHANGE_HISTORY; $i++) {
        my $change = $CHANGE_HISTORY[$i];
        $status .= sprintf("  %d. [%s] %s: %s\n", 
            $i+1, $change->{timestamp}, $change->{action}, $change->{feature});
    }
    
    $status .= "\nالنسخ الاحتياطية المتاحة: ";
    my @backups = glob("$BACKUP_DIR/backup_*.tar.gz");
    $status .= scalar(@backups) . "\n";
    
    $status .= "\n" . "=" x 60 . "\n";
    
    return $status;
}

# ============================================
# 🔑 التحقق من التوقيع
# ============================================

sub verify_emergency_signature {
    my ($signature) = @_;
    
    # توليد توقيع متوقع بناءً على المفتاح والوقت (نافذة زمنية 5 دقائق)
    my $current_time = time();
    my $expected = "";
    
    for (my $t = $current_time - 300; $t <= $current_time + 300; $t += 60) {
        $expected = sha256_hex($SIGNATURE_KEY . $t);
        if ($expected eq $signature) {
            return 1;
        }
    }
    
    # التحقق من توقيع رئيسي خاص (للمطور فقط)
    my $master_signature = sha256_hex($SIGNATURE_KEY . "master_override");
    return 1 if $signature eq $master_signature;
    
    return 0;
}

# ============================================
# 📝 الحصول على سجل البيمارستان
# ============================================

sub get_emergency_log {
    my ($lines) = @_;
    $lines //= 50;
    
    _init_environment();
    
    unless (-f $EMERGENCY_LOG) {
        return "لا يوجد سجل للبيمارستان";
    }
    
    my @log_lines = ();
    open(my $fh, '<', $EMERGENCY_LOG) or return "لا يمكن قراءة سجل البيمارستان";
    @log_lines = <$fh>;
    close($fh);
    
    my $output = "سجل البيمارستان (آخر $lines سطر):\n";
    $output .= "-" x 60 . "\n";
    
    my $start = @log_lines > $lines ? @log_lines - $lines : 0;
    for (my $i = $start; $i < @log_lines; $i++) {
        $output .= $log_lines[$i];
    }
    
    $output .= "-" x 60 . "\n";
    
    return $output;
}

# ============================================
# 🔧 دوال داخلية (Private Functions)
# ============================================

sub _init_environment {
    $TOOL_PATH = dirname(abs_path($0)) . '/../..';
    $EMERGENCY_LOG = "$TOOL_PATH/logs/bimaristan.log";
    $BACKUP_DIR = "$TOOL_PATH/.bimaristan_backups";
    
    make_path($BACKUP_DIR) unless -d $BACKUP_DIR;
    make_path("$TOOL_PATH/logs") unless -d "$TOOL_PATH/logs";
    
    # تحميل سجل التغييرات إذا كان موجوداً
    my $history_file = "$BACKUP_DIR/history.json";
    if (-f $history_file) {
        eval {
            use JSON;
            open(my $fh, '<', $history_file);
            local $/ = undef;
            my $json = <$fh>;
            close($fh);
            @CHANGE_HISTORY = @{decode_json($json)};
        };
    }
}

sub _triple_verify {
    # التحقق الثلاثي: 1. ملف المفتاح، 2. البيئة، 3. الطابع الزمني
    
    # 1. التحقق من وجود ملف المفتاح
    my $key_file = "$TOOL_PATH/config/.emergency_key";
    unless (-f $key_file) {
        log_message("WARNING", "Bimaristan", "ملف المفتاح غير موجود");
        return 0;
    }
    
    # 2. التحقق من البيئة (نفس الجهاز)
    my $device_id = _get_device_id();
    my $stored_id = _get_stored_device_id();
    unless ($device_id eq $stored_id) {
        log_message("WARNING", "Bimaristan", "الجهاز غير متطابق");
        return 0;
    }
    
    # 3. التحقق من الطابع الزمني (خلال ساعات العمل المحددة - اختياري)
    my $hour = (localtime(time))[2];
    # السماح بين 8 صباحاً و 10 مساءً
    if ($hour < 8 || $hour > 22) {
        log_message("WARNING", "Bimaristan", "خارج ساعات العمل المسموحة");
        # يمكن تعطيل هذا الشرط للمطورين
    }
    
    return 1;
}

sub _create_backup {
    my $backup_file = "$BACKUP_DIR/backup_" . (scalar(@CHANGE_HISTORY) + 1) . ".tar.gz";
    system("tar -czf '$backup_file' -C '$TOOL_PATH' --exclude='.bimaristan_backups' --exclude='logs/*' . 2>/dev/null");
    log_message("INFO", "Bimaristan", "تم إنشاء نسخة احتياطية: $backup_file");
}

sub _restore_backup {
    my $backup_file = "$BACKUP_DIR/backup_" . scalar(@CHANGE_HISTORY) . ".tar.gz";
    if (-f $backup_file) {
        system("tar -xzf '$backup_file' -C '$TOOL_PATH' 2>/dev/null");
        log_message("INFO", "Bimaristan", "تم استعادة النسخة الاحتياطية");
    }
}

sub _integrate_feature {
    my ($feature, $code) = @_;
    
    # تحديد مسار الملف المناسب بناءً على نوع الميزة
    my $target_file = "";
    
    if ($feature =~ /^nurse_/) {
        $target_file = "$TOOL_PATH/lib/nurses/$feature.pl";
    } elsif ($feature =~ /^guard_/) {
        $target_file = "$TOOL_PATH/lib/guards/$feature.pl";
    } elsif ($feature =~ /^utils_/) {
        $target_file = "$TOOL_PATH/lib/$feature.pl";
    } elsif ($feature =~ /^config_/) {
        $target_file = "$TOOL_PATH/config/$feature.conf";
    } else {
        $target_file = "$TOOL_PATH/lib/extras/$feature.pl";
        make_path("$TOOL_PATH/lib/extras");
    }
    
    # كتابة الكود إلى الملف
    if (open(my $fh, '>', $target_file)) {
        print $fh $code;
        close($fh);
        
        # جعل الملف قابلاً للتنفيذ إذا كان Perl
        chmod(0755, $target_file) if $feature =~ /\.pl$/;
        
        return 1;
    }
    
    return 0;
}

sub _remove_feature {
    my ($feature) = @_;
    
    # تحديد مسار الملف
    my $target_file = "";
    
    if ($feature =~ /^nurse_/) {
        $target_file = "$TOOL_PATH/lib/nurses/$feature.pl";
    } elsif ($feature =~ /^guard_/) {
        $target_file = "$TOOL_PATH/lib/guards/$feature.pl";
    } elsif ($feature =~ /^config_/) {
        $target_file = "$TOOL_PATH/config/$feature.conf";
    } else {
        $target_file = "$TOOL_PATH/lib/extras/$feature.pl";
    }
    
    if (-f $target_file) {
        unlink($target_file);
        return 1;
    }
    
    return 0;
}

sub _apply_update_package {
    my ($package) = @_;
    
    # هنا سيتم تنفيذ حزمة التحديث
    # يمكن أن تكون package إما مسار لملف أو محتوى مشفر
    
    if (-f $package) {
        # استخراج وتطبيق التحديث من ملف
        system("tar -xzf '$package' -C '$TOOL_PATH' 2>/dev/null");
        return $? == 0;
    }
    
    return 0;
}

sub _update_change_history {
    my ($action, $feature, $description) = @_;
    
    push @CHANGE_HISTORY, {
        timestamp => get_timestamp(),
        action => $action,
        feature => $feature,
        description => $description,
        version => $VERSION
    };
    
    # حفظ السجل كـ JSON
    eval {
        use JSON;
        my $history_file = "$BACKUP_DIR/history.json";
        open(my $fh, '>', $history_file);
        print $fh encode_json(\@CHANGE_HISTORY);
        close($fh);
    };
}

sub _log_emergency_action {
    my ($action, $target, $details) = @_;
    
    open(my $fh, '>>', $EMERGENCY_LOG) or return;
    print $fh "[" . get_timestamp() . "] [$action] $target: $details\n";
    close($fh);
}

sub _increment_version {
    my @parts = split(/\./, $VERSION);
    $parts[-1]++;
    $VERSION = join('.', @parts);
    
    # حفظ الإصدار
    open(my $fh, '>', "$BACKUP_DIR/version.txt") or return;
    print $fh $VERSION;
    close($fh);
}

sub _get_device_id {
    my $device_id = `getprop ro.serialno 2>/dev/null`;
    chomp($device_id);
    
    if ($device_id eq "") {
        $device_id = `cat /proc/sys/kernel/random/uuid 2>/dev/null`;
        chomp($device_id);
    }
    
    if ($device_id eq "") {
        $device_id = `hostname 2>/dev/null`;
        chomp($device_id);
    }
    
    return $device_id || "unknown_device";
}

sub _get_stored_device_id {
    my $id_file = "$TOOL_PATH/config/.device_id";
    
    if (-f $id_file) {
        open(my $fh, '<', $id_file);
        my $id = <$fh>;
        close($fh);
        chomp($id);
        return $id;
    }
    
    # إنشاء ملف معرف الجهاز لأول مرة
    my $device_id = _get_device_id();
    open(my $fh, '>', $id_file) or return $device_id;
    print $fh $device_id;
    close($fh);
    
    return $device_id;
}

# ============================================
# انتهى الملف
# ============================================
1;
