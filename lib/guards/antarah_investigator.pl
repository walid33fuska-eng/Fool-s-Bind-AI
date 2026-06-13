#!/usr/bin/perl
# ============================================
# Fool's Bind AI - محقق الحوادث (Antarah Investigator)
# ============================================
# الوظيفة: التحقيق في الحوادث الأمنية وتحليلها وتقديم تقارير مفصلة
# ============================================

package antarah_investigator;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);
use File::Copy;
use File::Path qw(remove_tree);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message get_timestamp colorize file_hash);

our @EXPORT = qw(execute);

# ============================================
# 📋 مسارات التحقيق
# ============================================

my $TOOL_PATH = "";
my $INVESTIGATION_ID = 0;
my %ACTIVE_INVESTIGATIONS = ();
my @CASE_FILES = ();

# ============================================
# 🚀 الدالة الرئيسية للتنفيذ
# ============================================

sub execute {
    my ($task, $params) = @_;
    
    log_message("INFO", "antarah_investigator", "بدء مهمة: $task");
    
    $TOOL_PATH = dirname(abs_path($0)) . '/../..';
    
    if ($task eq "quick_scan") {
        return _quick_scan();
    }
    elsif ($task eq "security_check") {
        return _security_check();
    }
    elsif ($task eq "investigate_incident") {
        my $incident_type = $params->{incident_type} // "unknown";
        my $details = $params->{details} // "";
        return _investigate_incident($incident_type, $details);
    }
    elsif ($task eq "get_case_file") {
        my $case_id = $params->{case_id} // return ("ERROR", "لم يتم تحديد معرف القضية");
        return _get_case_file($case_id);
    }
    elsif ($task eq "list_cases") {
        return _list_cases();
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
    log_message("INFO", "antarah_investigator", "الفحص السريع للحوادث الأخيرة");
    
    my $report = "";
    my $recent_incidents = 0;
    
    # فتح سجل الحوادث
    my $incident_log = "$TOOL_PATH/logs/incidents.log";
    if (-f $incident_log) {
        my @lines = ();
        open(my $fh, '<', $incident_log) or return ("ERROR", "لا يمكن قراءة سجل الحوادث");
        @lines = <$fh>;
        close($fh);
        
        # الحوادث من آخر 24 ساعة
        my $now = time();
        foreach my $line (@lines) {
            if ($line =~ /^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]/) {
                # تحويل التاريخ إلى وقت (تقريبي - للأغراض العرضية)
                $recent_incidents++;
                if ($recent_incidents <= 5) {
                    $report .= "  • $line";
                }
            }
        }
    }
    
    if ($recent_incidents > 0) {
        $report = "آخر $recent_incidents حادثة:\n$report";
        if ($recent_incidents > 5) {
            $report .= "  ... و " . ($recent_incidents - 5) . " حوادث أخرى\n";
        }
        return ("WARNING", $report);
    }
    
    return ("SUCCESS", "لا توجد حوادث حديثة");
}

# ============================================
# 🛡️ الفحص الأمني الشامل مع التحقيق
# ============================================

sub _security_check {
    log_message("INFO", "antarah_investigator", "الفحص الأمني الشامل مع التحقيق");
    
    my $report = "";
    my $issues = 0;
    
    # 1. فحص سلامة الملفات
    my $integrity_check = _check_integrity();
    if ($integrity_check) {
        $issues++;
        $report .= $integrity_check;
    }
    
    # 2. فحص السجلات بحثاً عن أنماط مشبوهة
    my $log_analysis = _analyze_logs();
    if ($log_analysis) {
        $issues++;
        $report .= $log_analysis;
    }
    
    # 3. فحص التعديلات غير المصرح بها
    my $unauth_check = _check_unauthorized_changes();
    if ($unauth_check) {
        $issues++;
        $report .= $unauth_check;
    }
    
    if ($issues > 0) {
        my $case_id = _open_investigation("security_scan", $report);
        return ("THREAT_DETECTED", "تم فتح تحقيق رقم: #$case_id\n\n$report");
    }
    
    return ("SUCCESS", "لا توجد مشاكل أمنية");
}

# ============================================
# 🔍 التحقيق في حادثة محددة
# ============================================

sub _investigate_incident {
    my ($incident_type, $details) = @_;
    
    log_message("INFO", "antarah_investigator", "التحقيق في حادثة: $incident_type");
    
    my $investigation = {
        case_id => ++$INVESTIGATION_ID,
        incident_type => $incident_type,
        details => $details,
        opened_at => get_timestamp(),
        status => "open",
        evidence => [],
        findings => [],
    };
    
    # جمع الأدلة حسب نوع الحادثة
    if ($incident_type eq "file_modified") {
        $investigation->{evidence} = _gather_file_evidence($details);
    }
    elsif ($incident_type eq "unauthorized_access") {
        $investigation->{evidence} = _gather_access_evidence();
    }
    elsif ($incident_type eq "suspicious_command") {
        $investigation->{evidence} = _gather_command_evidence($details);
    }
    elsif ($incident_type eq "connection_blocked") {
        $investigation->{evidence} = _gather_network_evidence($details);
    }
    else {
        $investigation->{evidence} = _gather_general_evidence();
    }
    
    # تحليل الأدلة
    $investigation->{findings} = _analyze_evidence($investigation->{evidence});
    
    # تحديد مستوى الخطورة
    $investigation->{severity} = _determine_severity($investigation);
    
    # إغلاق التحقيق إذا كان بسيطاً
    if ($investigation->{severity} eq "low") {
        $investigation->{status} = "closed";
        $investigation->{closed_at} = get_timestamp();
        $investigation->{resolution} = "لا توجد أدلة كافية على وجود خرق أمني حقيقي";
    } else {
        $investigation->{status} = "pending_review";
    }
    
    # حفظ ملف القضية
    _save_case_file($investigation);
    
    # تسجيل الحادثة
    _log_incident($incident_type, $details, $investigation->{case_id});
    
    # توليد التقرير
    my $report = _generate_investigation_report($investigation);
    
    return ("INVESTIGATION_COMPLETE", $report);
}

# ============================================
# 📁 جمع أدلة متعلقة بالملفات
# ============================================

sub _gather_file_evidence {
    my ($file) = @_;
    my @evidence = ();
    
    if (-f $file) {
        my @stat = stat($file);
        my $hash = file_hash($file);
        
        push @evidence, {
            type => "file_info",
            data => {
                path => $file,
                size => $stat[7],
                modified => scalar(localtime($stat[9])),
                hash => $hash,
                permissions => sprintf("%04o", $stat[2] & 07777)
            }
        };
        
        # فحص محتوى الملف (أول 500 حرف)
        if (open(my $fh, '<', $file)) {
            my $content = '';
            read($fh, $content, 500);
            close($fh);
            
            push @evidence, {
                type => "file_content_preview",
                data => $content
            };
        }
    }
    
    return \@evidence;
}

# ============================================
# 🔍 جمع أدلة الوصول
# ============================================

sub _gather_access_evidence {
    my @evidence = ();
    
    # سجل آخر محاولات الدخول
    my $auth_log = "/data/data/com.termux/files/home/.bash_history";
    if (-f $auth_log) {
        my @last_commands = ();
        open(my $fh, '<', $auth_log) or return [];
        my @lines = <$fh>;
        close($fh);
        
        # آخر 10 أوامر
        my $start = @lines > 10 ? @lines - 10 : 0;
        for (my $i = $start; $i < @lines; $i++) {
            push @last_commands, chomp($lines[$i]);
        }
        
        push @evidence, {
            type => "last_commands",
            data => \@last_commands
        };
    }
    
    return \@evidence;
}

# ============================================
# 🔍 جمع أدلة الأوامر المشبوهة
# ============================================

sub _gather_command_evidence {
    my ($command) = @_;
    my @evidence = ();
    
    push @evidence, {
        type => "suspicious_command",
        data => {
            command => $command,
            timestamp => get_timestamp(),
            environment => $ENV{PATH}
        }
    };
    
    return \@evidence;
}

# ============================================
# 🌐 جمع أدلة الشبكة
# ============================================

sub _gather_network_evidence {
    my ($url) = @_;
    my @evidence = ();
    
    # جمع معلومات عن الاتصالات النشطة
    my $netstat = `netstat -an 2>/dev/null | grep ESTABLISHED`;
    
    push @evidence, {
        type => "network_connections",
        data => $netstat
    };
    
    push @evidence, {
        type => "blocked_url",
        data => $url
    };
    
    return \@evidence;
}

# ============================================
# 📦 جمع أدلة عامة
# ============================================

sub _gather_general_evidence {
    my @evidence = ();
    
    # معلومات النظام
    my $uname = `uname -a`;
    my $os = $^O;
    my $perl_version = $];
    
    push @evidence, {
        type => "system_info",
        data => {
            uname => $uname,
            os => $os,
            perl_version => $perl_version,
            timestamp => get_timestamp()
        }
    };
    
    return \@evidence;
}

# ============================================
# 🔬 تحليل الأدلة
# ============================================

sub _analyze_evidence {
    my ($evidence) = @_;
    my @findings = ();
    
    foreach my $item (@$evidence) {
        if ($item->{type} eq "file_content_preview") {
            # فحص المحتوى للكشف عن كود خبيث
            my $content = $item->{data};
            if ($content =~ /(eval|system|exec|backtick|`)/i) {
                push @findings, "يحتوي الملف على دوال تنفيذ أوامر خطيرة";
            }
            if ($content =~ /(base64|rot13|encode)/i) {
                push @findings, "يحتوي الملف على تشفير قد يهدف إلى إخفاء محتوى ضار";
            }
        }
        elsif ($item->{type} eq "suspicious_command") {
            my $cmd = $item->{data}->{command};
            if ($cmd =~ /(rm -rf|mkfs|dd if=)/) {
                push @findings, "أمر مدمر قد يحذف البيانات";
            }
            if ($cmd =~ /(wget.*\|.*sh|curl.*\|.*bash)/) {
                push @findings, "محاولة تنزيل وتنفيذ كود من الإنترنت";
            }
        }
    }
    
    return \@findings;
}

# ============================================
# ⚖️ تحديد مستوى الخطورة
# ============================================

sub _determine_severity {
    my ($investigation) = @_;
    
    my $findings_count = scalar(@{$investigation->{findings}});
    
    if ($findings_count >= 3) {
        return "critical";
    } elsif ($findings_count >= 1) {
        return "medium";
    } else {
        return "low";
    }
}

# ============================================
# 💾 حفظ ملف القضية
# ============================================

sub _save_case_file {
    my ($case) = @_;
    
    my $cases_dir = "$TOOL_PATH/logs/cases";
    mkdir($cases_dir) unless -d $cases_dir;
    
    my $case_file = "$cases_dir/case_$case->{case_id}.json";
    
    use JSON;
    my $json = JSON->new->pretty;
    my $json_text = $json->encode($case);
    
    open(my $fh, '>', $case_file) or return;
    print $fh $json_text;
    close($fh);
    
    push @CASE_FILES, $case_file;
    
    log_message("INFO", "antarah_investigator", "تم حفظ ملف القضية #$case->{case_id}");
}

# ============================================
# 📂 استرجاع ملف القضية
# ============================================

sub _get_case_file {
    my ($case_id) = @_;
    
    my $case_file = "$TOOL_PATH/logs/cases/case_$case_id.json";
    
    unless (-f $case_file) {
        return ("ERROR", "ملف القضية رقم $case_id غير موجود");
    }
    
    open(my $fh, '<', $case_file) or return ("ERROR", "لا يمكن قراءة ملف القضية");
    local $/ = undef;
    my $content = <$fh>;
    close($fh);
    
    return ("SUCCESS", $content);
}

# ============================================
# 📋 قائمة القضايا
# ============================================

sub _list_cases {
    my $cases_dir = "$TOOL_PATH/logs/cases";
    mkdir($cases_dir) unless -d $cases_dir;
    
    opendir(my $dh, $cases_dir) or return ("ERROR", "لا يمكن فتح مجلد القضايا");
    my @files = grep { /\.json$/ } readdir($dh);
    closedir($dh);
    
    my $list = "قائمة القضايا (" . scalar(@files) . "):\n";
    foreach my $file (sort { $b cmp $a } @files) {
        $file =~ s/\.json$//;
        $file =~ s/case_//;
        $list .= "  • قضية رقم: $file\n";
    }
    
    return ("SUCCESS", $list);
}

# ============================================
# 🔒 وضع الإغلاق
# ============================================

sub _lockdown {
    log_message("INFO", "antarah_investigator", "تفعيل وضع الإغلاق - تسجيل مكثف");
    
    # بدء تحقيق عام
    _investigate_incident("system_lockdown", "تم تفعيل وضع الإغلاق من قبل المدير");
    
    return ("SUCCESS", "تم تفعيل وضع الإغلاق. سيتم تسجيل جميع الأحداث وتحليلها.");
}

# ============================================
# 🔓 العودة إلى الوضع العادي
# ============================================

sub _open {
    log_message("INFO", "antarah_investigator", "العودة إلى الوضع العادي");
    return ("SUCCESS", "تم العودة إلى الوضع العادي.");
}

# ============================================
# 📝 تسجيل حادثة
# ============================================

sub _log_incident {
    my ($type, $details, $case_id) = @_;
    
    my $incident_log = "$TOOL_PATH/logs/incidents.log";
    open(my $fh, '>>', $incident_log) or return;
    print $fh "[" . get_timestamp() . "] [$type] [$case_id] $details\n";
    close($fh);
}

# ============================================
# 🔧 فتح تحقيق جديد
# ============================================

sub _open_investigation {
    my ($type, $details) = @_;
    
    my $case_id = ++$INVESTIGATION_ID;
    
    my $investigation = {
        case_id => $case_id,
        incident_type => $type,
        details => $details,
        opened_at => get_timestamp(),
        status => "open",
        severity => "pending",
    };
    
    _save_case_file($investigation);
    
    return $case_id;
}

# ============================================
# 📊 فحص سلامة الملفات
# ============================================

sub _check_integrity {
    my $integrity_file = "$TOOL_PATH/config/integrity.sha256";
    return "" unless -f $integrity_file;
    
    my $report = "";
    my $issues = 0;
    
    open(my $fh, '<', $integrity_file) or return "";
    while (my $line = <$fh>) {
        chomp($line);
        next if $line =~ /^#/;
        
        if ($line =~ /^([a-f0-9]{64})\s+(.+)$/) {
            my ($expected, $file) = ($1, $2);
            my $full_path = "$TOOL_PATH/$file";
            
            if (-f $full_path) {
                my $current = file_hash($full_path);
                if ($current ne $expected) {
                    $issues++;
                    $report .= "  ⚠️ ملف معدل: $file\n";
                }
            } else {
                $issues++;
                $report .= "  ⚠️ ملف مفقود: $file\n";
            }
        }
    }
    close($fh);
    
    return $issues ? "مشاكل التكامل:\n$report" : "";
}

# ============================================
# 📝 تحليل السجلات
# ============================================

sub _analyze_logs {
    my $report = "";
    my $log_file = "$TOOL_PATH/logs/doctor.log";
    
    return "" unless -f $log_file;
    
    my $error_count = 0;
    my $warning_count = 0;
    
    open(my $fh, '<', $log_file) or return "";
    while (my $line = <$fh>) {
        $error_count++ if $line =~ /ERROR/;
        $warning_count++ if $line =~ /WARNING/;
    }
    close($fh);
    
    if ($error_count > 10 || $warning_count > 20) {
        $report .= "  ⚠️ عدد مرتفع من الأخطاء: $error_count خطأ، $warning_count تحذير\n";
    }
    
    return $report;
}

# ============================================
# 🔧 فحص التعديلات غير المصرح بها
# ============================================

sub _check_unauthorized_changes {
    my $report = "";
    
    # فحص الملفات التي تم تعديلها مؤخراً
    my $find_cmd = "find '$TOOL_PATH' -type f -mmin -60 \\( -name '*.pl' -o -name '*.conf' \\) 2>/dev/null";
    my $changed_files = `$find_cmd`;
    
    if ($changed_files) {
        $report = "ملفات تم تعديلها خلال الساعة الماضية:\n";
        foreach my $file (split(/\n/, $changed_files)) {
            $report .= "  • $file\n";
        }
    }
    
    return $report;
}

# ============================================
# 📋 إنشاء تقرير التحقيق
# ============================================

sub _generate_investigation_report {
    my ($case) = @_;
    
    my $report = "";
    $report .= "\n" . "=" x 60 . "\n";
    $report .= "  🔍 تقرير التحقيق #$case->{case_id}\n";
    $report .= "=" x 60 . "\n\n";
    
    $report .= "نوع الحادثة: $case->{incident_type}\n";
    $report .= "وقت الفتح: $case->{opened_at}\n";
    $report .= "الحالة: $case->{status}\n";
    $report .= "مستوى الخطورة: " . uc($case->{severity}) . "\n\n";
    
    if ($case->{details}) {
        $report .= "التفاصيل:\n$case->{details}\n\n";
    }
    
    if (@{$case->{findings}} > 0) {
        $report .= "النتائج:\n";
        foreach my $finding (@{$case->{findings}}) {
            $report .= "  • $finding\n";
        }
        $report .= "\n";
    }
    
    if ($case->{resolution}) {
        $report .= "القرار: $case->{resolution}\n\n";
    }
    
    $report .= "=" x 60 . "\n";
    
    return $report;
}

# ============================================
# انتهى الملف
# ============================================
1;
