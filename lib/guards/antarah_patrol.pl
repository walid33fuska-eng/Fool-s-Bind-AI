#!/usr/bin/perl
# ============================================
# Fool's Bind AI - دورية التطواف (Antarah Patrol)
# ============================================
# الوظيفة: فحص عشوائي للملفات والمجلدات حماية من التعديل غير المصرح به
# ============================================

package antarah_patrol;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);
use File::Find;
use List::Util qw(shuffle);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message get_timestamp colorize file_hash random_range);

our @EXPORT = qw(execute);

# ============================================
# 📁 مسار الأداة الرئيسي
# ============================================

my $TOOL_PATH = "";
my $LAST_SCAN_TIME = 0;
my $SCAN_INTERVAL = 60;  # ثانية
my @SUSPICIOUS_FILES = ();
my %FILE_HISTORY = ();

# ============================================
# 🚀 الدالة الرئيسية للتنفيذ
# ============================================

sub execute {
    my ($task, $params) = @_;
    
    log_message("INFO", "antarah_patrol", "بدء مهمة: $task");
    
    # تحديد مسار الأداة
    $TOOL_PATH = dirname(abs_path($0)) . '/../..';
    
    if ($task eq "quick_scan") {
        return _quick_scan();
    }
    elsif ($task eq "full_scan") {
        return _full_scan();
    }
    elsif ($task eq "random_patrol") {
        return _random_patrol();
    }
    elsif ($task eq "security_check") {
        return _security_check();
    }
    elsif ($task eq "lockdown") {
        return _lockdown();
    }
    elsif ($task eq "open") {
        return _open();
    }
    elsif ($task eq "watch_file") {
        my $file = $params->{file} // return ("ERROR", "لم يتم تحديد الملف");
        return _watch_file($file);
    }
    else {
        return ("ERROR", "مهمة غير معروفة: $task");
    }
}

# ============================================
# 🔍 فحص سريع (للملفات الرئيسية فقط)
# ============================================

sub _quick_scan {
    log_message("INFO", "antarah_patrol", "بدء الفحص السريع");
    
    my @critical_files = (
        "$TOOL_PATH/fools_bind_ai.pl",
        "$TOOL_PATH/lib/utils.pl",
        "$TOOL_PATH/lib/detector.pl",
        "$TOOL_PATH/lib/safety_db.pl",
        "$TOOL_PATH/config/settings.conf"
    );
    
    my $violations = 0;
    my $report = "";
    
    foreach my $file (@critical_files) {
        next unless -f $file;
        
        my $current_hash = file_hash($file);
        my $stored_hash = _get_stored_hash($file);
        
        if ($stored_hash && $current_hash ne $stored_hash) {
            $violations++;
            $report .= "  ⚠️ ملف معدل: $file\n";
            log_message("WARNING", "antarah_patrol", "ملف معدل: $file");
            _report_violation("file_modified", $file);
        }
    }
    
    $LAST_SCAN_TIME = time();
    
    if ($violations > 0) {
        return ("THREAT_DETECTED", "تم اكتشاف $violations ملفاً معدلاً:\n$report");
    }
    
    return ("SUCCESS", "الفحص السريع: لا توجد مخالفات");
}

# ============================================
# 🔍 فحص كامل (جميع الملفات)
# ============================================

sub _full_scan {
    log_message("INFO", "antarah_patrol", "بدء الفحص الكامل");
    
    my $violations = 0;
    my $report = "";
    
    # فحص جميع ملفات Perl
    find({
        wanted => sub {
            return unless -f $_;
            return unless /\.(pl|sh|conf)$/;
            
            my $file = $File::Find::name;
            my $current_hash = file_hash($file);
            my $stored_hash = _get_stored_hash($file);
            
            if ($stored_hash && $current_hash ne $stored_hash) {
                $violations++;
                $report .= "  ⚠️ ملف معدل: $file\n";
                log_message("WARNING", "antarah_patrol", "ملف معدل: $file");
            }
        },
        no_chdir => 1
    }, $TOOL_PATH);
    
    $LAST_SCAN_TIME = time();
    
    if ($violations > 0) {
        _report_violation("mass_modification", "$violations ملفاً معدلاً");
        return ("THREAT_DETECTED", "تم اكتشاف $violations ملفاً معدلاً:\n$report");
    }
    
    return ("SUCCESS", "الفحص الكامل: لا توجد مخالفات");
}

# ============================================
# 🎲 دورية عشوائية (تطواف غير متوقع)
# ============================================

sub _random_patrol {
    log_message("INFO", "antarah_patrol", "بدء الدورية العشوائية");
    
    # وقت عشوائي بين 30 و 120 ثانية
    my $random_wait = random_range(30, 120);
    log_message("INFO", "antarah_patrol", "الدورية العشوائية بعد $random_wait ثانية");
    
    sleep($random_wait);
    
    # اختيار عشوائي لنوع الفحص
    my @scan_types = ("quick_scan", "full_scan", "targeted_scan");
    my $scan_type = $scan_types[random_range(0, $#scan_types)];
    
    log_message("INFO", "antarah_patrol", "تنفيذ فحص عشوائي من النوع: $scan_type");
    
    if ($scan_type eq "quick_scan") {
        return _quick_scan();
    }
    elsif ($scan_type eq "full_scan") {
        return _full_scan();
    }
    else {
        return _targeted_scan();
    }
}

# ============================================
# 🎯 فحص مستهدف (مجلدات محددة عشوائياً)
# ============================================

sub _targeted_scan {
    my @target_dirs = (
        "$TOOL_PATH/lib",
        "$TOOL_PATH/config",
        "$TOOL_PATH/lib/nurses",
        "$TOOL_PATH/lib/guards"
    );
    
    # اختيار مجلد عشوائي
    my $target = $target_dirs[random_range(0, $#target_dirs)];
    
    log_message("INFO", "antarah_patrol", "الفحص المستهدف للمجلد: $target");
    
    return unless -d $target;
    
    my $violations = 0;
    my $report = "";
    
    opendir(my $dh, $target) or return ("ERROR", "لا يمكن فتح المجلد: $target");
    my @files = readdir($dh);
    closedir($dh);
    
    # اختيار عشوائي لـ 3-5 ملفات
    @files = shuffle(@files);
    my $num_files = random_range(3, 5);
    $num_files = $#files if $num_files > $#files;
    
    for (my $i = 0; $i < $num_files; $i++) {
        my $file = "$target/$files[$i]";
        next unless -f $file;
        
        my $current_hash = file_hash($file);
        my $stored_hash = _get_stored_hash($file);
        
        if ($stored_hash && $current_hash ne $stored_hash) {
            $violations++;
            $report .= "  ⚠️ ملف معدل: $file\n";
        }
    }
    
    if ($violations > 0) {
        return ("THREAT_DETECTED", "تم اكتشاف $violations ملفاً معدلاً في $target:\n$report");
    }
    
    return ("SUCCESS", "الفحص المستهدف للمجلد $target: لا توجد مخالفات");
}

# ============================================
# 🔒 وضع الإغلاق (زيادة وتيرة الفحص)
# ============================================

sub _lockdown {
    log_message("INFO", "antarah_patrol", "تفعيل وضع الإغلاق - زيادة وتيرة الفحص");
    
    $SCAN_INTERVAL = 10;  # فحص كل 10 ثوانٍ في وضع الإغلاق
    
    # فحص كامل فوري
    _full_scan();
    
    return ("SUCCESS", "تم تفعيل وضع الإغلاق. وتيرة الفحص: كل 10 ثوانٍ");
}

# ============================================
# 🔓 العودة إلى الوضع العادي
# ============================================

sub _open {
    log_message("INFO", "antarah_patrol", "العودة إلى الوضع العادي");
    
    $SCAN_INTERVAL = 60;
    
    return ("SUCCESS", "تم العودة إلى الوضع العادي. وتيرة الفحص: كل 60 ثانية");
}

# ============================================
# 👁️ مراقبة ملف معين بشكل مستمر
# ============================================

sub _watch_file {
    my ($file) = @_;
    
    unless (-f $file) {
        return ("ERROR", "الملف غير موجود: $file");
    }
    
    log_message("INFO", "antarah_patrol", "بدء مراقبة الملف: $file");
    
    # تخزين الهاش الحالي
    $FILE_HISTORY{$file} = file_hash($file);
    
    # بدء المراقبة في الخلفية
    my $pid = fork();
    if ($pid == 0) {
        # العملية الابن
        while (1) {
            sleep(5);
            my $current_hash = file_hash($file);
            if ($current_hash ne $FILE_HISTORY{$file}) {
                log_message("WARNING", "antarah_patrol", "تغيير في الملف المراقب: $file");
                _report_violation("watched_file_changed", $file);
                $FILE_HISTORY{$file} = $current_hash;
            }
        }
        exit(0);
    }
    
    return ("SUCCESS", "بدأت مراقبة الملف $file (PID: $pid)");
}

# ============================================
# 🔐 الفحص الأمني الشامل (يُستدعى عند بدء التشغيل)
# ============================================

sub _security_check {
    log_message("INFO", "antarah_patrol", "الفحص الأمني الشامل");
    
    my $report = "";
    my $threats = 0;
    
    # 1. فحص الملفات الرئيسية
    my ($status, $result) = _quick_scan();
    if ($status eq "THREAT_DETECTED") {
        $threats++;
        $report .= $result;
    }
    
    # 2. فحص الصلاحيات
    my $permissions_check = _check_permissions();
    if ($permissions_check) {
        $threats++;
        $report .= $permissions_check;
    }
    
    # 3. فحص الملفات المشبوهة
    my $suspicious_check = _check_suspicious_files();
    if ($suspicious_check) {
        $threats++;
        $report .= $suspicious_check;
    }
    
    if ($threats > 0) {
        return ("THREAT_DETECTED", "تم اكتشاف $threats تهديداً:\n$report");
    }
    
    return ("SUCCESS", "الفحص الأمني الشامل: لا توجد تهديدات");
}

# ============================================
# 🔍 فحص الصلاحيات غير العادية
# ============================================

sub _check_permissions {
    my $report = "";
    my $found = 0;
    
    # فحص صلاحيات الملفات الرئيسية
    my @files = ("$TOOL_PATH/fools_bind_ai.pl", "$TOOL_PATH/lib/utils.pl");
    
    foreach my $file (@files) {
        next unless -f $file;
        
        my @stat = stat($file);
        my $mode = $stat[2] & 0777;
        
        # إذا كان الملف قابل للكتابة من الجميع
        if (($mode & 002) || ($mode & 020)) {
            $found++;
            $report .= "  ⚠️ صلاحية خطيرة: $file ($mode)\n";
        }
    }
    
    return $found ? $report : "";
}

# ============================================
# 🔍 فحص الملفات المشبوهة
# ============================================

sub _check_suspicious_files {
    my $report = "";
    my $found = 0;
    
    # قائمة بأسماء الملفات المشبوهة
    my @suspicious_names = qw(
        backup copy temp test debug
        malicious hack exploit crack
    );
    
    find({
        wanted => sub {
            return unless -f $_;
            my $filename = lc($_);
            
            foreach my $susp (@suspicious_names) {
                if ($filename =~ /$susp/) {
                    $found++;
                    $report .= "  ⚠️ ملف مشبوه: $File::Find::name\n";
                    last;
                }
            }
        },
        no_chdir => 1
    }, $TOOL_PATH);
    
    return $found ? $report : "";
}

# ============================================
# 📝 الإبلاغ عن انتهاك
# ============================================

sub _report_violation {
    my ($type, $details) = @_;
    
    log_message("VIOLATION", "antarah_patrol", "$type: $details");
    
    # تسجيل في ملف الانتهاكات
    my $violation_log = "$TOOL_PATH/logs/violations.log";
    open(my $fh, '>>', $violation_log) or return;
    print $fh "[" . get_timestamp() . "] [$type] $details\n";
    close($fh);
}

# ============================================
# 📦 الحصول على الهاش المخزن لملف
# ============================================

sub _get_stored_hash {
    my ($file) = @_;
    
    my $integrity_file = "$TOOL_PATH/config/integrity.sha256";
    return undef unless -f $integrity_file;
    
    open(my $fh, '<', $integrity_file) or return undef;
    while (my $line = <$fh>) {
        chomp($line);
        if ($line =~ /^([a-f0-9]{64})\s+(.+)$/) {
            my ($hash, $path) = ($1, $2);
            if ($file =~ /$path$/ || $file eq "$TOOL_PATH/$path") {
                close($fh);
                return $hash;
            }
        }
    }
    close($fh);
    
    return undef;
}

# ============================================
# انتهى الملف
# ============================================
1;
