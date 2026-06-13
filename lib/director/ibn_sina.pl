#!/usr/bin/perl
# ============================================
# Fool's Bind AI - ابن سينا (Ibn Sina)
# ============================================
# الوظيفة: القائد الأعلى للمستشفى، يدير الطبيب والممرضين ورجال الأمن والإسعاف
# ============================================

package IbnSina;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message get_timestamp colorize run_command check_internet);
use Detector;
use SafetyDB;
use RefidaBase;
use AntarahBase;
use Bimaristan;

our @EXPORT = qw(
    initialize_hospital
    get_hospital_status
    director_decision
    approve_surgery
    handle_emergency
    get_directive
    shutdown_hospital
);

# ============================================
# 📋 متغيرات المستشفى
# ============================================

my $HOSPITAL_NAME = "Fool's Bind AI Hospital";
my $HOSPITAL_STATUS = "STANDBY";  # STANDBY, OPERATING, EMERGENCY, LOCKDOWN
my $CURRENT_SURGERY = undef;
my @DECISION_LOG = ();
my $DIRECTOR_ACTIVE = 1;

# ============================================
# 🏥 تهيئة المستشفى
# ============================================

sub initialize_hospital {
    log_message("INFO", "IbnSina", "بدء تهيئة مستشفى $HOSPITAL_NAME");
    
    print colorize("\n" . "=" x 60 . "\n", "cyan");
    print colorize("  🏥 Fool's Bind AI - مستشفى الجراح الكمي\n", "cyan");
    print colorize("  👨‍⚕️ القائد الأعلى: ابن سينا\n", "green");
    print colorize("=" x 60 . "\n\n", "cyan");
    
    # 1. فحص البيئة
    print colorize("📋 فحص البيئة...\n", "yellow");
    my $env_info = Detector::detect_all();
    print Detector::get_environment_report();
    
    # 2. فحص الأمان
    print colorize("\n🛡️ فحص الأمان...\n", "yellow");
    my ($security_status, $security_report) = AntarahBase::quick_security_scan();
    print $security_report if $security_report;
    
    # 3. فحص البيمارستان
    print colorize("\n🏥 فحص البيمارستان...\n", "yellow");
    my $bimaristan_status = Bimaristan::emergency_status();
    print $bimaristan_status;
    
    # 4. فحص الإنترنت
    print colorize("\n🌐 فحص الاتصال بالإنترنت...\n", "yellow");
    if (check_internet()) {
        print colorize("✅ الإنترنت: متصل\n", "green");
    } else {
        print colorize("❌ الإنترنت: غير متصل\n", "red");
        print colorize("⚠️ الأداة تحتاج إلى إنترنت لجلب الأوامر الصحيحة\n", "yellow");
    }
    
    $HOSPITAL_STATUS = "STANDBY";
    
    print colorize("\n✅ مستشفى $HOSPITAL_NAME جاهز للعمل\n", "green");
    print colorize("=" x 60 . "\n\n", "cyan");
    
    log_message("SUCCESS", "IbnSina", "تم تهيئة المستشفى بنجاح");
    return 1;
}

# ============================================
# 📊 حالة المستشفى
# ============================================

sub get_hospital_status {
    my $status = "";
    $status .= "\n" . "=" x 60 . "\n";
    $status .= colorize("  🏥 $HOSPITAL_NAME\n", "cyan");
    $status .= "=" x 60 . "\n\n";
    
    my $status_text = "";
    if ($HOSPITAL_STATUS eq "STANDBY") {
        $status_text = colorize("🟢 جاهز للعمل", "green");
    } elsif ($HOSPITAL_STATUS eq "OPERATING") {
        $status_text = colorize("🟡 قيد التشغيل", "yellow");
    } elsif ($HOSPITAL_STATUS eq "EMERGENCY") {
        $status_text = colorize("🔴 حالة طارئة", "red");
    } elsif ($HOSPITAL_STATUS eq "LOCKDOWN") {
        $status_text = colorize("🔒 إغلاق تام", "red");
    }
    
    $status .= "حالة المستشفى: $status_text\n";
    $status .= "القائد: ابن سينا\n";
    $status .= "العملية الحالية: " . ($CURRENT_SURGERY // "لا توجد") . "\n";
    $status .= "عدد القرارات المسجلة: " . scalar(@DECISION_LOG) . "\n\n";
    
    # عرض آخر 3 قرارات
    if (@DECISION_LOG) {
        $status .= "آخر القرارات:\n";
        my $start = @DECISION_LOG > 3 ? @DECISION_LOG - 3 : 0;
        for (my $i = $start; $i < @DECISION_LOG; $i++) {
            my $decision = $DECISION_LOG[$i];
            $status .= sprintf("  • %s: %s\n", $decision->{timestamp}, $decision->{decision});
        }
    }
    
    $status .= "\n" . "=" x 60 . "\n";
    
    return $status;
}

# ============================================
# 🧠 اتخاذ القرار
# ============================================

sub director_decision {
    my ($context, $options, $priority) = @_;
    
    log_message("INFO", "IbnSina", "اتخاذ قرار في السياق: $context");
    
    my $decision = "";
    my $reason = "";
    
    # التحليل بناءً على السياق والأولويات
    if ($context eq "security_threat") {
        ($decision, $reason) = _handle_security_threat($options, $priority);
    } 
    elsif ($context eq "surgery_request") {
        ($decision, $reason) = _handle_surgery_request($options);
    }
    elsif ($context eq "resource_allocation") {
        ($decision, $reason) = _handle_resource_allocation($options);
    }
    elsif ($context eq "conflict_resolution") {
        ($decision, $reason) = _handle_conflict_resolution($options);
    }
    else {
        $decision = "defer";
        $reason = "سياق غير معروف، تم تأجيل القرار";
    }
    
    # تسجيل القرار
    push @DECISION_LOG, {
        timestamp => get_timestamp(),
        context => $context,
        decision => $decision,
        reason => $reason,
        priority => $priority // "normal"
    };
    
    log_message("INFO", "IbnSina", "القرار: $decision - $reason");
    
    return ($decision, $reason);
}

# ============================================
# ✅ الموافقة على عملية جراحية
# ============================================

sub approve_surgery {
    my ($surgery_type, $tool_name, $patient_id) = @_;
    
    log_message("INFO", "IbnSina", "مراجعة طلب عملية: $surgery_type لـ $tool_name");
    
    # 1. فحص الأداة
    my ($risk, $details, $penalty) = SafetyDB::check_tool_safety($tool_name);
    
    if ($risk eq "إجرامية") {
        my $report = "";
        $report .= "\n" . "=" x 60 . "\n";
        $report .= colorize("  ⛔ عملية مرفوضة - أداة إجرامية\n", "red");
        $report .= "=" x 60 . "\n\n";
        $report .= "الأداة: $tool_name\n";
        $report .= "التصنيف: $risk\n";
        $report .= "العقوبة المقترحة: $penalty\n\n";
        $report .= "القرار: منع العملية\n";
        $report .= "=" x 60 . "\n";
        
        log_message("WARNING", "IbnSina", "رفض عملية $tool_name (إجرامي)");
        return ("REJECTED", $report);
    }
    
    if ($risk eq "خطيرة") {
        # عملية خطيرة تحتاج موافقة خاصة
        my $report = "";
        $report .= "\n" . "=" x 60 . "\n";
        $report .= colorize("  ⚠️ عملية عالية الخطورة\n", "yellow");
        $report .= "=" x 60 . "\n\n";
        $report .= "الأداة: $tool_name\n";
        $report .= "التصنيف: $risk\n";
        $report .= "التفاصيل: $details\n\n";
        $report .= "القرار: موافقة مشروطة\n";
        $report .= "الشروط: المراقبة المباشرة من رجال الأمن\n";
        $report .= "=" x 60 . "\n";
        
        $CURRENT_SURGERY = "$surgery_type:$tool_name";
        $HOSPITAL_STATUS = "OPERATING";
        
        log_message("INFO", "IbnSina", "الموافقة المشروطة على عملية $tool_name");
        return ("APPROVED_CONDITIONAL", $report);
    }
    
    # عملية آمنة
    $CURRENT_SURGERY = "$surgery_type:$tool_name";
    $HOSPITAL_STATUS = "OPERATING";
    
    my $report = "";
    $report .= "\n" . "=" x 60 . "\n";
    $report .= colorize("  ✅ عملية موافق عليها\n", "green");
    $report .= "=" x 60 . "\n\n";
    $report .= "الأداة: $tool_name\n";
    $report .= "التصنيف: $risk\n";
    $report .= "القرار: بدء العملية\n";
    $report .= "=" x 60 . "\n";
    
    log_message("SUCCESS", "IbnSina", "الموافقة على عملية $tool_name");
    return ("APPROVED", $report);
}

# ============================================
# 🚨 التعامل مع الحالات الطارئة
# ============================================

sub handle_emergency {
    my ($emergency_type, $details) = @_;
    
    log_message("CRITICAL", "IbnSina", "حالة طارئة: $emergency_type - $details");
    
    $HOSPITAL_STATUS = "EMERGENCY";
    
    my $response = "";
    $response .= "\n" . "=" x 60 . "\n";
    $response .= colorize("  🚨 حالة طارئة في المستشفى\n", "red");
    $response .= "=" x 60 . "\n\n";
    $response .= "النوع: $emergency_type\n";
    $response .= "التفاصيل: $details\n\n";
    
    if ($emergency_type eq "security_breach") {
        # استدعاء رجال الأمن
        $response .= "🛡️ استدعاء رجال الأمن...\n";
        AntarahBase::emergency_lockdown();
        $response .= "✅ تم تفعيل الإغلاق الطارئ\n";
        
        # التحقيق
        $response .= "🔍 بدء التحقيق...\n";
        my ($status, $report) = AntarahBase::call_guard("antarah_investigator", "investigate_incident", {
            incident_type => $emergency_type,
            details => $details
        });
        $response .= $report if $report;
        
    } 
    elsif ($emergency_type eq "system_failure") {
        # محاولة استعادة النظام
        $response .= "🔄 محاولة استعادة النظام...\n";
        my ($status, $report) = Bimaristan::emergency_rollback("master_signature", 1);
        $response .= $report;
        
        if ($status eq "SUCCESS") {
            $response .= "✅ تم استعادة النظام\n";
            $HOSPITAL_STATUS = "STANDBY";
        } else {
            $response .= "⚠️ فشل استعادة النظام تلقائياً\n";
        }
    }
    
    $response .= "\n" . "=" x 60 . "\n";
    
    log_message("INFO", "IbnSina", "تم التعامل مع الحالة الطارئة");
    return $response;
}

# ============================================
# 📜 الحصول على توجيهات
# ============================================

sub get_directive {
    my ($section, $sub_section) = @_;
    
    my %DIRECTIVES = (
        "security" => {
            "policy" => "سياسة الأمن: المراقبة المستمرة، الإغلاق الفوري عند اكتشاف أي اختراق",
            "protocol" => "بروتوكول الأمن: استدعاء رجال الأمن فوراً، التحقيق في الحادثة، اتخاذ الإجراء المناسب"
        },
        "surgery" => {
            "approval" => "الموافقة على العمليات: آمنة ← تلقائي، خطيرة ← موافقة مشروطة، إجرامية ← رفض تام",
            "protocol" => "بروتوكول الجراحة: تشخيص، جمع الحلول، تجربة، تأكيد النجاح"
        },
        "emergency" => {
            "lockdown" => "الإغلاق الطارئ: يتم تفعيله تلقائياً عند اكتشاف تهديد خطير",
            "recovery" => "استعادة النظام: عبر البيمارستان، التراجع إلى آخر نسخة مستقرة"
        }
    );
    
    if (exists $DIRECTIVES{$section}) {
        if ($sub_section && exists $DIRECTIVES{$section}{$sub_section}) {
            return $DIRECTIVES{$section}{$sub_section};
        }
        return $DIRECTIVES{$section};
    }
    
    return "توجيه غير موجود";
}

# ============================================
# 🔒 إغلاق المستشفى
# ============================================

sub shutdown_hospital {
    log_message("INFO", "IbnSina", "بدء إغلاق المستشفى");
    
    # تنبيه جميع المكونات
    print colorize("\n🛑 إغلاق مستشفى $HOSPITAL_NAME...\n", "yellow");
    
    # إنشاء تقرير نهائي
    my $final_report = "";
    $final_report .= "\n" . "=" x 60 . "\n";
    $final_report .= colorize("  📊 التقرير النهائي للمستشفى\n", "cyan");
    $final_report .= "=" x 60 . "\n\n";
    $final_report .= "عدد العمليات التي تمت: " . scalar(grep { $_->{context} eq "surgery_request" } @DECISION_LOG) . "\n";
    $final_report .= "عدد القرارات المتخذة: " . scalar(@DECISION_LOG) . "\n";
    $final_report .= "آخر حالة للمستشفى: $HOSPITAL_STATUS\n";
    $final_report .= "وقت الإغلاق: " . get_timestamp() . "\n";
    $final_report .= "\n" . "=" x 60 . "\n";
    
    print $final_report;
    
    $DIRECTOR_ACTIVE = 0;
    $HOSPITAL_STATUS = "SHUTDOWN";
    
    log_message("SUCCESS", "IbnSina", "تم إغلاق المستشفى");
    
    return $final_report;
}

# ============================================
# 🔧 دوال مساعدة داخلية
# ============================================

sub _handle_security_threat {
    my ($options, $priority) = @_;
    
    my $severity = $options->{severity} // "medium";
    
    if ($severity eq "critical" || $priority eq "high") {
        return ("emergency_lockdown", "تهديد حرج يتطلب إغلاق المستشفى فوراً");
    } 
    elsif ($severity eq "high") {
        return ("intensify_monitoring", "زيادة المراقبة واستدعاء رجال الأمن");
    }
    else {
        return ("log_and_continue", "تسجيل التهديد ومراقبته");
    }
}

sub _handle_surgery_request {
    my ($options) = @_;
    
    my $tool_name = $options->{tool} // "unknown";
    my ($risk) = SafetyDB::check_tool_safety($tool_name);
    
    if ($risk eq "إجرامية") {
        return ("reject", "أداة إجرامية، لا يمكن الموافقة");
    }
    elsif ($risk eq "خطيرة") {
        return ("conditional_approve", "موافقة مشروطة مع مراقبة");
    }
    else {
        return ("approve", "موافقة تلقائية");
    }
}

sub _handle_resource_allocation {
    my ($options) = @_;
    
    my $resource_type = $options->{resource} // "cpu";
    my $requested = $options->{amount} // 0;
    
    if ($requested > 80) {
        return ("limit", "الموارد المطلوبة عالية جداً، سيتم تقليلها إلى 80%");
    }
    else {
        return ("allocate", "تخصيص الموارد المطلوبة");
    }
}

sub _handle_conflict_resolution {
    my ($options) = @_;
    
    my $component1 = $options->{component1} // "";
    my $component2 = $options->{component2} // "";
    
    if ($component1 eq "antarah" && $component2 eq "refida") {
        return ("priority_to_security", "في حالة النزاع، الأولوية للأمن");
    }
    else {
        return ("defer_to_director", "سيتم اتخاذ القرار من قبل المدير");
    }
}

# ============================================
# انتهى الملف
# ============================================
1;
