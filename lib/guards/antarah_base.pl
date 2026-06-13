#!/usr/bin/perl
# ============================================
# Fool's Bind AI - قائد رجال الأمن (Antarah Base)
# ============================================
# الوظيفة: قائد فريق الأمن المسؤول عن حماية الأداة والمستشفى
# ============================================

package AntarahBase;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);
use Time::HiRes qw(sleep);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message get_timestamp colorize run_command file_hash);

our @EXPORT = qw(
    initialize_guards
    call_guard
    call_all_guards
    get_guard_report
    report_incident
    emergency_lockdown
    get_security_status
);

# ============================================
# 📋 تسجيل رجال الأمن المتخصصين
# ============================================

my %GUARDS = ();
my %GUARD_LOGS = ();
my $GUARDS_PATH = "";
my $SECURITY_STATUS = "NORMAL";  # NORMAL, WATCHING, LOCKDOWN
my @INCIDENT_LOG = ();

# ============================================
# 🛡️ تهيئة رجال الأمن
# ============================================

sub initialize_guards {
    my $script_dir = dirname(abs_path($0));
    $GUARDS_PATH = $script_dir;
    
    # قائمة رجال الأمن المتخصصين
    my @guard_list = qw(
        antarah_patrol
        antarah_comm
        antarah_investigator
        antarah_logwarden
        antarah_shadow
    );
    
    foreach my $guard (@guard_list) {
        my $guard_file = "$GUARDS_PATH/$guard.pl";
        if (-f $guard_file) {
            eval {
                require $guard_file;
                $GUARDS{$guard} = 1;
                log_message("INFO", "AntarahBase", "تم تحميل رجل الأمن: $guard");
            };
            if ($@) {
                log_message("ERROR", "AntarahBase", "فشل تحميل رجل الأمن $guard: $@");
            }
        } else {
            log_message("WARNING", "AntarahBase", "الملف غير موجود: $guard_file");
        }
    }
    
    log_message("INFO", "AntarahBase", "تم تهيئة " . scalar(keys %GUARDS) . " من رجال الأمن");
    return scalar(keys %GUARDS);
}

# ============================================
# 📞 استدعاء رجل أمن واحد
# ============================================

sub call_guard {
    my ($guard_name, $task, $params) = @_;
    
    unless ($GUARDS{$guard_name}) {
        my $error = "رجل الأمن غير موجود: $guard_name";
        log_message("ERROR", "AntarahBase", $error);
        return ("ERROR", $error);
    }
    
    log_message("INFO", "AntarahBase", "استدعاء رجل الأمن: $guard_name للمهمة: $task");
    
    _log_to_guard($guard_name, "START", "مهمة: $task");
    
    my $result = "";
    my $status = "";
    
    eval {
        my $function = "${guard_name}::execute";
        no strict 'refs';
        ($status, $result) = $function->($task, $params);
    };
    
    if ($@) {
        log_message("ERROR", "AntarahBase", "خطأ في استدعاء رجل الأمن $guard_name: $@");
        _log_to_guard($guard_name, "ERROR", $@);
        return ("ERROR", "فشل استدعاء رجل الأمن: $@");
    }
    
    _log_to_guard($guard_name, "END", "الحالة: $status - $result");
    log_message("INFO", "AntarahBase", "انتهى رجل الأمن $guard_name بـ $status");
    
    # إذا تم اكتشاف تهديد، سجل الحادثة
    if ($status eq "THREAT_DETECTED") {
        _report_incident($guard_name, $result);
    }
    
    return ($status, $result);
}

# ============================================
# 🚨 استدعاء جميع رجال الأمن (تفتيش كامل)
# ============================================

sub call_all_guards {
    my ($task, $params) = @_;
    $task //= "security_check";
    $params //= {};
    
    log_message("INFO", "AntarahBase", "استدعاء جميع رجال الأمن للتفتيش: $task");
    
    my %results = ();
    my $threat_count = 0;
    
    foreach my $guard_name (keys %GUARDS) {
        my ($status, $result) = call_guard($guard_name, $task, $params);
        $results{$guard_name} = {
            status => $status,
            result => $result,
            timestamp => get_timestamp()
        };
        $threat_count++ if $status eq "THREAT_DETECTED";
    }
    
    # إذا تم اكتشاف تهديدات، نرفع حالة التأهب
    if ($threat_count > 0) {
        $SECURITY_STATUS = "WATCHING";
        log_message("WARNING", "AntarahBase", "تم اكتشاف $threat_count تهديداً");
        
        # إذا كان التهديد خطيراً، نغلق المستشفى
        if ($threat_count >= 2) {
            emergency_lockdown();
        }
    }
    
    return (\%results, $threat_count);
}

# ============================================
# 📊 تقرير حالة الأمن
# ============================================

sub get_guard_report {
    my $report = "";
    
    $report .= "\n" . "=" x 60 . "\n";
    $report .= "  🛡️ تقرير رجال الأمن (Antarah)\n";
    $report .= "=" x 60 . "\n\n";
    
    my $active = scalar(keys %GUARDS);
    $report .= "عدد رجال الأمن النشطين: $active\n";
    $report .= "حالة الأمن: " . _get_security_status_text() . "\n\n";
    
    foreach my $guard (sort keys %GUARDS) {
        $report .= "  🛡️ $guard\n";
        $report .= "     الحالة: نشط\n";
        
        if (exists $GUARD_LOGS{$guard} && @{$GUARD_LOGS{$guard}}) {
            my $last_log = $GUARD_LOGS{$guard}[-1];
            $report .= "     آخر نشاط: $last_log->{action} - $last_log->{message}\n";
        }
        $report .= "\n";
    }
    
    # عرض آخر 3 حوادث
    if (@INCIDENT_LOG) {
        $report .= "📋 آخر الحوادث:\n";
        my @recent = @INCIDENT_LOG;
        if (@recent > 3) {
            @recent = @recent[-3 .. -1];
        }
        foreach my $incident (@recent) {
            $report .= "  • $incident->{timestamp} [$incident->{guard}] $incident->{description}\n";
        }
        $report .= "\n";
    }
    
    $report .= "=" x 60 . "\n";
    
    return $report;
}

# ============================================
# 📝 تسجيل حادثة
# ============================================

sub _report_incident {
    my ($guard_name, $description) = @_;
    
    push @INCIDENT_LOG, {
        timestamp => get_timestamp(),
        guard => $guard_name,
        description => $description
    };
    
    # الاحتفاظ بآخر 50 حادثة فقط
    if (@INCIDENT_LOG > 50) {
        shift @INCIDENT_LOG;
    }
    
    log_message("ALERT", "AntarahBase", "حادثة أمنية من $guard_name: $description");
}

sub report_incident {
    my ($description) = @_;
    _report_incident("UNKNOWN", $description);
}

# ============================================
# 🔒 إغلاق طارئ للمستشفى
# ============================================

sub emergency_lockdown {
    log_message("CRITICAL", "AntarahBase", "⚠️ إغلاق طارئ للمستشفى ⚠️");
    
    $SECURITY_STATUS = "LOCKDOWN";
    
    # إعلام جميع رجال الأمن بالإغلاق
    foreach my $guard_name (keys %GUARDS) {
        call_guard($guard_name, "lockdown", {});
    }
    
    # إنشاء تقرير الإغلاق
    my $lockdown_report = "";
    $lockdown_report .= "\n" . "=" x 60 . "\n";
    $lockdown_report .= colorize("  🔒 الإغلاق الطارئ للمستشفى", "red") . "\n";
    $lockdown_report .= "=" x 60 . "\n\n";
    $lockdown_report .= "تم اكتشاف تهديد أمني خطير.\n";
    $lockdown_report .= "تم إغلاق المستشفى لحين التحقق من السلامة.\n\n";
    $lockdown_report .= "التاريخ والوقت: " . get_timestamp() . "\n";
    $lockdown_report .= "حالة الأمن: LOCKDOWN\n";
    $lockdown_report .= "=" x 60 . "\n";
    
    print $lockdown_report;
    
    return $lockdown_report;
}

# ============================================
# 🔓 فتح المستشفى (بعد التأكد من السلامة)
# ============================================

sub emergency_open {
    log_message("INFO", "AntarahBase", "🔓 فتح المستشفى بعد التأكد من السلامة");
    
    $SECURITY_STATUS = "NORMAL";
    
    foreach my $guard_name (keys %GUARDS) {
        call_guard($guard_name, "open", {});
    }
    
    return "تم فتح المستشفى وعودة العمل إلى طبيعته";
}

# ============================================
# 📊 الحصول على حالة الأمن
# ============================================

sub get_security_status {
    return $SECURITY_STATUS;
}

sub _get_security_status_text {
    if ($SECURITY_STATUS eq "NORMAL") {
        return colorize("✅ طبيعي", "green");
    } elsif ($SECURITY_STATUS eq "WATCHING") {
        return colorize("⚠️ مراقبة مشددة", "yellow");
    } elsif ($SECURITY_STATUS eq "LOCKDOWN") {
        return colorize("🔒 إغلاق تام", "red");
    }
    return colorize("غير معروف", "white");
}

# ============================================
# 📝 تسجيل داخلي في سجل رجل الأمن
# ============================================

sub _log_to_guard {
    my ($guard_name, $action, $message) = @_;
    
    $GUARD_LOGS{$guard_name} = [] unless exists $GUARD_LOGS{$guard_name};
    
    push @{$GUARD_LOGS{$guard_name}}, {
        timestamp => get_timestamp(),
        action => $action,
        message => $message
    };
    
    # الاحتفاظ بآخر 100 سجل فقط
    if (@{$GUARD_LOGS{$guard_name}} > 100) {
        shift @{$GUARD_LOGS{$guard_name}};
    }
}

# ============================================
# 🔍 فحص أمني سريع (يُستدعى عند بدء التشغيل)
# ============================================

sub quick_security_scan {
    log_message("INFO", "AntarahBase", "بدء الفحص الأمني السريع");
    
    my ($results, $threat_count) = call_all_guards("quick_scan", {});
    
    if ($threat_count > 0) {
        log_message("WARNING", "AntarahBase", "تم اكتشاف $threat_count تهديداً أثناء الفحص السريع");
        return (0, $threat_count);
    }
    
    log_message("SUCCESS", "AntarahBase", "الفحص الأمني السريع: لا توجد تهديدات");
    return (1, 0);
}

# ============================================
# 🧬 تهيئة رجال الأمن عند تحميل الملف
# ============================================

initialize_guards();

# ============================================
# انتهى الملف
# ============================================
1;
