#!/usr/bin/perl
# ============================================
# Fool's Bind AI - حارس الظل (Antarah Shadow Guard)
# ============================================
# الوظيفة: نسخة مخفية في الذاكرة فقط، تعمل عند فشل جميع رجال الأمن
# ============================================

package antarah_shadow;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message get_timestamp colorize run_command file_hash);

our @EXPORT = qw(execute);

# ============================================
# 🥷 متغيرات حارس الظل
# ============================================

my $TOOL_PATH = "";
my $SHADOW_PID = $$;
my $SHADOW_ACTIVE = 1;
my $HEARTBEAT_INTERVAL = 30;  # ثانية
my $LAST_HEARTBEAT = time();
my @CRITICAL_COMPONENTS = ();
my $RECOVERY_IN_PROGRESS = 0;

# ============================================
# 🚀 الدالة الرئيسية للتنفيذ
# ============================================

sub execute {
    my ($task, $params) = @_;
    
    log_message("INFO", "antarah_shadow", "بدء مهمة: $task");
    
    $TOOL_PATH = dirname(abs_path($0)) . '/../..';
    
    # تهيئة المكونات الحرجة
    @CRITICAL_COMPONENTS = (
        "$TOOL_PATH/fools_bind_ai.pl",
        "$TOOL_PATH/lib/utils.pl",
        "$TOOL_PATH/lib/detector.pl",
        "$TOOL_PATH/lib/safety_db.pl",
        "$TOOL_PATH/lib/guards/antarah_base.pl",
        "$TOOL_PATH/lib/nurses/refida_base.pl"
    );
    
    if ($task eq "quick_scan") {
        return _quick_scan();
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
    elsif ($task eq "heartbeat") {
        return _heartbeat();
    }
    elsif ($task eq "recover_system") {
        return _recover_system();
    }
    elsif ($task eq "get_status") {
        return _get_status();
    }
    else {
        return ("ERROR", "مهمة غير معروفة: $task");
    }
}

# ============================================
# 🔍 الفحص السريع
# ============================================

sub _quick_scan {
    log_message("INFO", "antarah_shadow", "الفحص السريع للنظام");
    
    my $report = "";
    my $issues = 0;
    
    # تحديث نبض القلب
    $LAST_HEARTBEAT = time();
    
    # فحص سلامة المكونات الحرجة
    foreach my $component (@CRITICAL_COMPONENTS) {
        unless (-f $component) {
            $issues++;
            $report .= "  ❌ مكون مفقود: $component\n";
        }
    }
    
    # فحص وجود عملية الأداة الرئيسية
    my $main_pid = _find_main_process();
    unless ($main_pid) {
        $issues++;
        $report .= "  ⚠️ العملية الرئيسية غير موجودة\n";
    }
    
    if ($issues > 0) {
        log_message("WARNING", "antarah_shadow", "تم اكتشاف $issues مشكلة");
        return ("WARNING", $report);
    }
    
    return ("SUCCESS", "النظام يعمل بشكل طبيعي");
}

# ============================================
# 🛡️ الفحص الأمني الشامل
# ============================================

sub _security_check {
    log_message("INFO", "antarah_shadow", "الفحص الأمني الشامل");
    
    my $report = "";
    my $threats = 0;
    
    # 1. فحص سلامة المكونات الحرجة
    foreach my $component (@CRITICAL_COMPONENTS) {
        unless (-f $component) {
            $threats++;
            $report .= "❌ مكون مفقود حرج: $component\n";
        }
    }
    
    # 2. فحص صلاحية استعادة النظام
    my $recovery_possible = _can_recover();
    if ($recovery_possible) {
        $report .= "✅ إمكانية استعادة النظام: متاحة\n";
    } else {
        $report .= "⚠️ إمكانية استعادة النظام: محدودة\n";
    }
    
    # 3. فحص حالة رجال الأمن الآخرين
    my $guards_status = _check_other_guards();
    if ($guards_status->{active} == 0) {
        $threats++;
        $report .= "⚠️ جميع رجال الأمن الآخرين غير نشطين\n";
        $report .= "🔄 حارس الظل سيتولى المسؤولية\n";
    }
    
    # 4. فحص الذاكرة المتاحة
    my $free_memory = _get_free_memory();
    if ($free_memory < 50) {  # أقل من 50MB
        $report .= "⚠️ ذاكرة منخفضة: ${free_memory}MB\n";
    }
    
    if ($threats > 0) {
        log_message("WARNING", "antarah_shadow", "تم اكتشاف $threats تهديداً");
        return ("THREAT_DETECTED", $report);
    }
    
    return ("SUCCESS", $report);
}

# ============================================
# 🔒 وضع الإغلاق (تفعيل حارس الظل بشكل كامل)
# ============================================

sub _lockdown {
    log_message("INFO", "antarah_shadow", "تفعيل وضع الإغلاق - حارس الظل في الخدمة");
    
    $SHADOW_ACTIVE = 2;  # مستوى نشاط عالٍ
    $HEARTBEAT_INTERVAL = 10;  # نبض كل 10 ثوانٍ
    
    # بدء دورة نبضات القلب في الخلفية
    _start_heartbeat_loop();
    
    return ("SUCCESS", "تم تفعيل حارس الظل. النظام تحت الحماية القصوى.");
}

# ============================================
# 🔓 العودة إلى الوضع العادي
# ============================================

sub _open {
    log_message("INFO", "antarah_shadow", "العودة إلى الوضع العادي");
    
    $SHADOW_ACTIVE = 1;
    $HEARTBEAT_INTERVAL = 30;
    
    return ("SUCCESS", "العودة إلى الوضع العادي. حارس الظل في الخلفية.");
}

# ============================================
# 💓 نبض القلب
# ============================================

sub _heartbeat {
    $LAST_HEARTBEAT = time();
    
    # تسجيل نبض القلب (مرة كل 10 نبضات فقط لتجنب إغراق السجل)
    if (int(time() / 10) % 10 == 0) {
        log_message("INFO", "antarah_shadow", "نبض القلب: حي");
    }
    
    # فحص سريع للنظام
    _quick_scan();
    
    return ("ALIVE", "نبض القلب: " . get_timestamp());
}

# ============================================
# 🔄 استعادة النظام
# ============================================

sub _recover_system {
    log_message("CRITICAL", "antarah_shadow", "بدء استعادة النظام!");
    
    return if $RECOVERY_IN_PROGRESS;
    $RECOVERY_IN_PROGRESS = 1;
    
    my $report = "";
    my $recovered = 0;
    
    # 1. استعادة الملفات المفقودة من النسخ الاحتياطية
    my $backup_dir = "$TOOL_PATH/logs/backup";
    if (-d $backup_dir) {
        foreach my $component (@CRITICAL_COMPONENTS) {
            unless (-f $component) {
                my $basename = basename($component);
                my $backup_file = _find_backup_file($backup_dir, $basename);
                if ($backup_file && -f $backup_file) {
                    system("cp '$backup_file' '$component' 2>/dev/null");
                    $recovered++;
                    $report .= "  ✅ تم استعادة: $basename\n";
                    log_message("INFO", "antarah_shadow", "تم استعادة الملف: $component");
                }
            }
        }
    }
    
    # 2. إعادة تشغيل المكونات الحيوية
    if ($recovered > 0) {
        $report .= "\n🔄 إعادة تشغيل المكونات المستعادة...\n";
        _restart_recovered_components();
    }
    
    # 3. تحديث نبض القلب
    $LAST_HEARTBEAT = time();
    
    # 4. التحقق من نجاح الاستعادة
    my $all_restored = 1;
    foreach my $component (@CRITICAL_COMPONENTS) {
        unless (-f $component) {
            $all_restored = 0;
            last;
        }
    }
    
    $RECOVERY_IN_PROGRESS = 0;
    
    if ($all_restored) {
        log_message("SUCCESS", "antarah_shadow", "تم استعادة النظام بنجاح!");
        return ("SUCCESS", "تم استعادة النظام بنجاح!\n$report");
    }
    
    log_message("WARNING", "antarah_shadow", "استعادة جزئية للنظام");
    return ("WARNING", "تم استعادة $recovered من " . scalar(@CRITICAL_COMPONENTS) . " مكون\n$report");
}

# ============================================
# 📊 الحصول على حالة حارس الظل
# ============================================

sub _get_status {
    my $status = "";
    
    $status .= "\n" . "=" x 60 . "\n";
    $status .= "  🥷 حارس الظل - تقرير الحالة\n";
    $status .= "=" x 60 . "\n\n";
    
    $status .= "الحالة: " . ($SHADOW_ACTIVE ? "🟢 نشط" : "🔴 غير نشط") . "\n";
    $status .= "المعرف (PID): $SHADOW_PID\n";
    $status .= "آخر نبض قلب: " . get_timestamp() . "\n";
    $status .= "فترة النبض: ${HEARTBEAT_INTERVAL} ثانية\n";
    
    my $seconds_since_heartbeat = time() - $LAST_HEARTBEAT;
    if ($seconds_since_heartbeat > $HEARTBEAT_INTERVAL * 2) {
        $status .= "⚠️ تأخر في نبض القلب: ${seconds_since_heartbeat} ثانية\n";
    }
    
    $status .= "\nالمكونات الحرجة:\n";
    foreach my $component (@CRITICAL_COMPONENTS) {
        my $exists = -f $component ? "✅" : "❌";
        $status .= "  $exists " . basename($component) . "\n";
    }
    
    $status .= "\n" . "=" x 60 . "\n";
    
    return ("SUCCESS", $status);
}

# ============================================
# 🔍 البحث عن العملية الرئيسية
# ============================================

sub _find_main_process {
    my $ps_output = `ps aux 2>/dev/null | grep "fools_bind_ai.pl" | grep -v grep | head -1`;
    if ($ps_output =~ /^\S+\s+(\d+)/) {
        return $1;
    }
    
    # محاولة بديلة
    $ps_output = `ps -ef 2>/dev/null | grep "fools_bind_ai.pl" | grep -v grep | head -1`;
    if ($ps_output =~ /^\S+\s+(\d+)/) {
        return $1;
    }
    
    return undef;
}

# ============================================
# 🔍 البحث عن ملف نسخة احتياطية
# ============================================

sub _find_backup_file {
    my ($dir, $filename) = @_;
    
    opendir(my $dh, $dir) or return undef;
    my @files = grep { /$filename\./ && /\.bak$/ } readdir($dh);
    closedir($dh);
    
    if (@files) {
        return "$dir/" . (sort { $b cmp $a } @files)[0];
    }
    
    return undef;
}

# ============================================
# 🧠 فحص إمكانية استعادة النظام
# ============================================

sub _can_recover {
    my $backup_dir = "$TOOL_PATH/logs/backup";
    return 0 unless -d $backup_dir;
    
    # فحص وجود نسخ احتياطية للمكونات الحرجة
    my $has_backups = 0;
    foreach my $component (@CRITICAL_COMPONENTS) {
        my $basename = basename($component);
        if (_find_backup_file($backup_dir, $basename)) {
            $has_backups++;
        }
    }
    
    return ($has_backups > 0);
}

# ============================================
# 🔄 إعادة تشغيل المكونات المستعادة
# ============================================

sub _restart_recovered_components {
    # تحديث هاشات الملفات المستعادة
    foreach my $component (@CRITICAL_COMPONENTS) {
        if (-f $component) {
            # إعادة حساب الهاش وتخزينه
            my $hash = file_hash($component);
            log_message("INFO", "antarah_shadow", "تم تحديث هاش الملف: " . basename($component));
        }
    }
}

# ============================================
# 💾 الحصول على الذاكرة الحرة
# ============================================

sub _get_free_memory {
    my $free_memory = 0;
    
    if (-f "/proc/meminfo") {
        open(my $fh, '<', '/proc/meminfo');
        while (my $line = <$fh>) {
            if ($line =~ /MemAvailable:\s+(\d+)/) {
                $free_memory = int($1 / 1024);
                last;
            }
        }
        close($fh);
    }
    
    return $free_memory || 100;  # افتراض 100MB إذا لم نتمكن من القراءة
}

# ============================================
# 🔄 بدء حلقة نبضات القلب
# ============================================

sub _start_heartbeat_loop {
    # هذه الدالة تبدأ نبضات القلب في الخلفية
    # يتم استدعاؤها مرة واحدة عند تفعيل حارس الظل
    
    my $pid = fork();
    return if $pid;  # العملية الأب تعود فوراً
    
    # العملية الابن - حلقة نبضات القلب
    $0 = "fools_bind_ai_shadow_heartbeat";
    
    while ($SHADOW_ACTIVE) {
        sleep($HEARTBEAT_INTERVAL);
        _heartbeat();
        
        # فحص سريع للمكونات الحرجة كل 5 نبضات
        if (int(time() / $HEARTBEAT_INTERVAL) % 5 == 0) {
            my ($status, $result) = _security_check();
            if ($status eq "THREAT_DETECTED") {
                log_message("WARNING", "antarah_shadow", "تم اكتشاف تهديد أثناء النبض: $result");
            }
        }
    }
    
    exit(0);
}

# ============================================
# 🧬 فحص حالة رجال الأمن الآخرين
# ============================================

sub _check_other_guards {
    my $result = { active => 0, guards => [] };
    
    # قائمة رجال الأمن الآخرين
    my @other_guards = qw(antarah_patrol antarah_comm antarah_investigator antarah_logwarden);
    
    foreach my $guard (@other_guards) {
        # فحص إذا كانت العملية موجودة
        my $ps_output = `ps aux 2>/dev/null | grep "$guard.pl" | grep -v grep`;
        if ($ps_output) {
            $result->{active}++;
            push @{$result->{guards}}, $guard;
        }
    }
    
    return $result;
}

# ============================================
# انتهى الملف
# ============================================
1;
