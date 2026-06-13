#!/usr/bin/perl
# ============================================
# Fool's Bind AI - حارس السجلات (Antarah Log Warden)
# ============================================
# الوظيفة: حماية سجلات الأداة من التعديل أو الحذف
# ============================================

package antarah_logwarden;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);
use File::Copy;
use File::stat;
use Fcntl qw(:flock);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message get_timestamp colorize file_hash);

our @EXPORT = qw(execute);

# ============================================
# 📋 مسارات السجلات
# ============================================

my $TOOL_PATH = "";
my $LOG_DIR = "";
my @PROTECTED_LOGS = ();
my %LOG_HASHES = ();
my $LAST_INTEGRITY_CHECK = 0;

# ============================================
# 🚀 الدالة الرئيسية للتنفيذ
# ============================================

sub execute {
    my ($task, $params) = @_;
    
    log_message("INFO", "antarah_logwarden", "بدء مهمة: $task");
    
    $TOOL_PATH = dirname(abs_path($0)) . '/../..';
    $LOG_DIR = "$TOOL_PATH/logs";
    
    mkdir($LOG_DIR) unless -d $LOG_DIR;
    
    # تهيئة قائمة السجلات المحمية
    @PROTECTED_LOGS = (
        "$LOG_DIR/doctor.log",
        "$LOG_DIR/incidents.log",
        "$LOG_DIR/connections.log",
        "$LOG_DIR/threats.log",
        "$LOG_DIR/violations.log",
        "$LOG_DIR/cases/"
    );
    
    if ($task eq "quick_scan") {
        return _quick_scan();
    }
    elsif ($task eq "security_check") {
        return _security_check();
    }
    elsif ($task eq "protect_log") {
        my $log_file = $params->{log_file} // return ("ERROR", "لم يتم تحديد ملف السجل");
        return _protect_log($log_file);
    }
    elsif ($task eq "verify_integrity") {
        return _verify_integrity();
    }
    elsif ($task eq "backup_logs") {
        my $backup_path = $params->{backup_path} // "$LOG_DIR/backup";
        return _backup_logs($backup_path);
    }
    elsif ($task eq "rotate_logs") {
        return _rotate_logs();
    }
    elsif ($task eq "lockdown") {
        return _lockdown();
    }
    elsif ($task eq "open") {
        return _open();
    }
    else {
        return ("ERROR", "مهمة غير معروفة: $task");
    }
}

# ============================================
# 🔍 الفحص السريع
# ============================================

sub _quick_scan {
    log_message("INFO", "antarah_logwarden", "الفحص السريع للسجلات");
    
    my $report = "";
    my $issues = 0;
    
    # فحص سلامة السجلات الأساسية
    my ($status, $result) = _verify_integrity();
    if ($status eq "INTEGRITY_FAILED") {
        $issues++;
        $report .= $result;
    }
    
    # فحص حجم السجلات
    foreach my $log (grep { -f $_ } @PROTECTED_LOGS) {
        my $size = -s $log;
        if ($size > 10 * 1024 * 1024) {  # 10MB
            $issues++;
            $report .= "  ⚠️ ملف السجل كبير جداً: " . basename($log) . " (" . int($size/1024/1024) . "MB)\n";
        }
    }
    
    if ($issues > 0) {
        return ("WARNING", "مشاكل في السجلات:\n$report");
    }
    
    return ("SUCCESS", "السجلات سليمة");
}

# ============================================
# 🛡️ الفحص الأمني الشامل
# ============================================

sub _security_check {
    log_message("INFO", "antarah_logwarden", "الفحص الأمني الشامل للسجلات");
    
    my $report = "";
    my $threats = 0;
    
    # 1. فحص سلامة السجلات
    my ($status, $result) = _verify_integrity();
    if ($status eq "INTEGRITY_FAILED") {
        $threats++;
        $report .= "❌ اختراق سلامة السجلات:\n$result";
    } else {
        $report .= "✅ سلامة السجلات: سليمة\n";
    }
    
    # 2. فحص الصلاحيات
    my $perm_check = _check_permissions();
    if ($perm_check) {
        $threats++;
        $report .= $perm_check;
    }
    
    # 3. فحص وجود نسخ احتياطية حديثة
    my $backup_check = _check_backups();
    if ($backup_check) {
        $report .= $backup_check;
    }
    
    # 4. فحص محتوى السجلات بحثاً عن أنماط مشبوهة
    my $content_check = _check_log_content();
    if ($content_check) {
        $threats++;
        $report .= $content_check;
    }
    
    if ($threats > 0) {
        return ("THREAT_DETECTED", "تم اكتشاف $threats مشكلة:\n$report");
    }
    
    return ("SUCCESS", $report);
}

# ============================================
# 🔒 حماية سجل معين
# ============================================

sub _protect_log {
    my ($log_file) = @_;
    
    log_message("INFO", "antarah_logwarden", "حماية السجل: $log_file");
    
    unless (-f $log_file) {
        # إنشاء الملف إذا لم يكن موجوداً
        open(my $fh, '>', $log_file) or return ("ERROR", "لا يمكن إنشاء ملف السجل");
        print $fh "# سجل محمي بواسطة Fool's Bind AI\n";
        print $fh "# تم الإنشاء: " . get_timestamp() . "\n";
        close($fh);
    }
    
    # تخزين الهاش الأولي
    $LOG_HASHES{$log_file} = file_hash($log_file);
    
    # تغيير الصلاحيات لجعل الملف محمياً
    chmod(0644, $log_file);
    
    log_message("SUCCESS", "antarah_logwarden", "تم حماية السجل: $log_file");
    return ("SUCCESS", "تم حماية السجل: " . basename($log_file));
}

# ============================================
# ✅ التحقق من سلامة السجلات
# ============================================

sub _verify_integrity {
    my $report = "";
    my $failed = 0;
    
    foreach my $log (grep { -f $_ } @PROTECTED_LOGS) {
        my $current_hash = file_hash($log);
        
        if (exists $LOG_HASHES{$log}) {
            if ($current_hash ne $LOG_HASHES{$log}) {
                $failed++;
                $report .= "  ❌ سجل معدل: " . basename($log) . "\n";
                log_message("WARNING", "antarah_logwarden", "سجل معدل: $log");
                
                # استعادة من النسخة الاحتياطية إذا كانت موجودة
                _restore_from_backup($log);
            }
        } else {
            # سجل جديد، نخزن هاشه
            $LOG_HASHES{$log} = $current_hash;
        }
    }
    
    $LAST_INTEGRITY_CHECK = time();
    
    if ($failed > 0) {
        return ("INTEGRITY_FAILED", $report);
    }
    
    return ("INTEGRITY_OK", "");
}

# ============================================
# 🔍 فحص الصلاحيات
# ============================================

sub _check_permissions {
    my $report = "";
    my $issues = 0;
    
    foreach my $log (grep { -f $_ } @PROTECTED_LOGS) {
        my @stat = stat($log);
        my $mode = $stat[2] & 0777;
        
        # فحص إذا كان الملف قابلاً للكتابة من الجميع
        if (($mode & 002) || ($mode & 020)) {
            $issues++;
            $report .= "  ⚠️ صلاحية خطيرة على $log ($mode)\n";
            # إصلاح الصلاحية
            chmod(0644, $log);
        }
    }
    
    return $issues ? "مشاكل في الصلاحيات:\n$report" : "";
}

# ============================================
# 💾 فحص النسخ الاحتياطية
# ============================================

sub _check_backups {
    my $backup_dir = "$LOG_DIR/backup";
    
    unless (-d $backup_dir) {
        return "  ⚠️ لا توجد نسخ احتياطية للسجلات\n";
    }
    
    # فحص تاريخ أحدث نسخة احتياطية
    my $latest_backup = 0;
    opendir(my $dh, $backup_dir);
    while (my $file = readdir($dh)) {
        next unless $file =~ /\.bak$/;
        my $mtime = (stat("$backup_dir/$file"))->mtime;
        $latest_backup = $mtime if $mtime > $latest_backup;
    }
    closedir($dh);
    
    if ($latest_backup == 0) {
        return "  ⚠️ لا توجد نسخ احتياطية للسجلات\n";
    }
    
    my $days_old = (time() - $latest_backup) / 86400;
    if ($days_old > 7) {
        return "  ⚠️ آخر نسخة احتياطية منذ " . int($days_old) . " يوماً\n";
    }
    
    return "";
}

# ============================================
# 🔍 فحص محتوى السجلات
# ============================================

sub _check_log_content {
    my $report = "";
    my $suspicious = 0;
    
    my $log_file = "$LOG_DIR/doctor.log";
    return "" unless -f $log_file;
    
    open(my $fh, '<', $log_file) or return "";
    
    while (my $line = <$fh>) {
        # فحص محاولات التعديل
        if ($line =~ /(modified|changed|altered|tampered)/i && $line =~ /WARNING|ERROR/) {
            $suspicious++;
            $report .= "  ⚠️ " . $line;
            last if $suspicious >= 3;  # نكتفي بآخر 3
        }
        
        # فحص محاولات الحذف
        if ($line =~ /(deleted|removed|unlink|rm)/i && $line =~ /WARNING|ERROR/) {
            $suspicious++;
            $report .= "  ⚠️ " . $line;
            last if $suspicious >= 3;
        }
    }
    close($fh);
    
    return $suspicious ? "أنماط مشبوهة في السجلات:\n$report" : "";
}

# ============================================
# 💾 إنشاء نسخة احتياطية
# ============================================

sub _backup_logs {
    my ($backup_path) = @_;
    
    log_message("INFO", "antarah_logwarden", "إنشاء نسخة احتياطية للسجلات إلى: $backup_path");
    
    mkdir($backup_path) unless -d $backup_path;
    
    my $backup_count = 0;
    my $timestamp = get_timestamp();
    $timestamp =~ s/[-:\s]/_/g;
    
    foreach my $log (grep { -f $_ } @PROTECTED_LOGS) {
        my $backup_file = "$backup_path/" . basename($log) . ".$timestamp.bak";
        copy($log, $backup_file);
        $backup_count++;
    }
    
    # نسخ مجلد القضايا إذا كان موجوداً
    my $cases_dir = "$LOG_DIR/cases";
    if (-d $cases_dir) {
        my $cases_backup = "$backup_path/cases_$timestamp";
        system("cp -r '$cases_dir' '$cases_backup' 2>/dev/null");
        $backup_count++;
    }
    
    log_message("SUCCESS", "antarah_logwarden", "تم إنشاء نسخة احتياطية لـ $backup_count عنصر");
    return ("SUCCESS", "تم إنشاء نسخة احتياطية لـ $backup_count عنصر في $backup_path");
}

# ============================================
# 🔄 تدوير السجلات
# ============================================

sub _rotate_logs {
    log_message("INFO", "antarah_logwarden", "تدوير السجلات");
    
    my $rotated = 0;
    
    foreach my $log (grep { -f $_ } @PROTECTED_LOGS) {
        my $size = -s $log;
        
        # تدوير إذا تجاوز الحجم 5MB
        if ($size > 5 * 1024 * 1024) {
            my $rotated_file = "$log." . time() . ".old";
            rename($log, $rotated_file);
            
            # إنشاء ملف سجل جديد
            open(my $fh, '>', $log) or next;
            print $fh "# سجل جديد - تم تدويره من " . basename($rotated_file) . "\n";
            print $fh "# وقت التدوير: " . get_timestamp() . "\n";
            close($fh);
            
            $rotated++;
            log_message("INFO", "antarah_logwarden", "تم تدوير السجل: " . basename($log));
        }
    }
    
    return ("SUCCESS", "تم تدوير $rotated سجل");
}

# ============================================
# 🔒 وضع الإغلاق (تسجيل مكثف)
# ============================================

sub _lockdown {
    log_message("INFO", "antarah_logwarden", "تفعيل وضع الإغلاق - حماية مشددة للسجلات");
    
    # إنشاء نسخة احتياطية فورية
    _backup_logs("$LOG_DIR/backup/pre_lockdown");
    
    # تغيير صلاحيات السجلات إلى للقراءة فقط
    foreach my $log (grep { -f $_ } @PROTECTED_LOGS) {
        chmod(0444, $log);
    }
    
    return ("SUCCESS", "تم تفعيل وضع الإغلاق. السجلات محمية بشكل مشدد.");
}

# ============================================
# 🔓 العودة إلى الوضع العادي
# ============================================

sub _open {
    log_message("INFO", "antarah_logwarden", "العودة إلى الوضع العادي");
    
    # استعادة الصلاحيات الطبيعية
    foreach my $log (grep { -f $_ } @PROTECTED_LOGS) {
        chmod(0644, $log);
    }
    
    return ("SUCCESS", "تم العودة إلى الوضع العادي.");
}

# ============================================
# 🔄 استعادة من النسخة الاحتياطية
# ============================================

sub _restore_from_backup {
    my ($log_file) = @_;
    
    my $backup_dir = "$LOG_DIR/backup";
    return unless -d $backup_dir;
    
    my $basename = basename($log_file);
    opendir(my $dh, $backup_dir);
    my @backups = grep { /^$basename\./ && /\.bak$/ } readdir($dh);
    closedir($dh);
    
    if (@backups) {
        # استعادة أحدث نسخة احتياطية
        my $latest = (sort { $b cmp $a } @backups)[0];
        my $backup_file = "$backup_dir/$latest";
        
        copy($backup_file, $log_file);
        log_message("INFO", "antarah_logwarden", "تم استعادة السجل من النسخة الاحتياطية: $latest");
    }
}

# ============================================
# انتهى الملف
# ============================================
1;
