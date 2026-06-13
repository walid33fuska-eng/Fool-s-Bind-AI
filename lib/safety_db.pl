#!/usr/bin/perl
# ============================================
# Fool's Bind AI - قاعدة بيانات الأمان (Safety DB)
# ============================================
# الوظيفة: تصنيف الأدوات (آمنة / خطيرة / إجرامية) مع العقوبات
# ============================================

package SafetyDB;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);

use lib dirname(abs_path($0)) . '/..';
use Utils qw(log_message);

our @EXPORT = qw(
    check_tool_safety
    get_tool_risk_level
    get_tool_penalty
    is_tool_allowed
    add_custom_tool
    get_blacklist_report
    verify_user_eligibility
    record_violation
);

# ============================================
# 📊 قاعدة البيانات الرئيسية
# ============================================

# هيكل البيانات: اسم الأداة -> { risk, details, penalty, source }
my %TOOL_DB = ();

# ============================================
# 🟢 الأدوات الآمنة (Safe Tools)
# ============================================

sub init_safe_tools {
    my %safe = (
        "nmap" => { risk => "آمنة", details => "أداة فحص شبكات قانونية", penalty => "لا عقوبة", source => "official" },
        "wireshark" => { risk => "آمنة", details => "تحليل حزم الشبكة", penalty => "لا عقوبة", source => "official" },
        "python" => { risk => "آمنة", details => "لغة برمجة", penalty => "لا عقوبة", source => "official" },
        "python3" => { risk => "آمنة", details => "لغة برمجة", penalty => "لا عقوبة", source => "official" },
        "perl" => { risk => "آمنة", details => "لغة برمجة", penalty => "لا عقوبة", source => "official" },
        "bash" => { risk => "آمنة", details => "قشرة أوامر", penalty => "لا عقوبة", source => "official" },
        "git" => { risk => "آمنة", details => "نظام تحكم بالإصدارات", penalty => "لا عقوبة", source => "official" },
        "curl" => { risk => "آمنة", details => "نقل بيانات عبر URL", penalty => "لا عقوبة", source => "official" },
        "wget" => { risk => "آمنة", details => "تحميل الملفات", penalty => "لا عقوبة", source => "official" },
        "openssl" => { risk => "آمنة", details => "مكتبة تشفير", penalty => "لا عقوبة", source => "official" },
        "ssh" => { risk => "آمنة", details => "اتصال آمن", penalty => "لا عقوبة", source => "official" },
        "ping" => { risk => "آمنة", details => "اختبار اتصال الشبكة", penalty => "لا عقوبة", source => "official" },
        "traceroute" => { risk => "آمنة", details => "تتبع مسار الشبكة", penalty => "لا عقوبة", source => "official" },
        "netstat" => { risk => "آمنة", details => "إحصائيات الشبكة", penalty => "لا عقوبة", source => "official" },
        "ifconfig" => { risk => "آمنة", details => "تكوين واجهات الشبكة", penalty => "لا عقوبة", source => "official" },
        "tcpdump" => { risk => "آمنة", details => "التقاط حزم الشبكة", penalty => "لا عقوبة", source => "official" },
        "make" => { risk => "آمنة", details => "أداة بناء", penalty => "لا عقوبة", source => "official" },
        "gcc" => { risk => "آمنة", details => "مترجم C", penalty => "لا عقوبة", source => "official" },
        "go" => { risk => "آمنة", details => "لغة برمجة Go", penalty => "لا عقوبة", source => "official" },
        "rustc" => { risk => "آمنة", details => "مترجم Rust", penalty => "لا عقوبة", source => "official" },
    );
    
    foreach my $tool (keys %safe) {
        $TOOL_DB{$tool} = $safe{$tool};
    }
}

# ============================================
# 🟠 الأدوات الخطيرة (Dangerous Tools)
# ============================================

sub init_dangerous_tools {
    my %dangerous = (
        "aircrack-ng" => { risk => "خطيرة", details => "اختراق شبكات WiFi", penalty => "غرامة مالية أو سجن حسب الاستخدام", source => "official" },
        "wifite" => { risk => "خطيرة", details => "اختراق شبكات WiFi تلقائي", penalty => "غرامة مالية", source => "official" },
        "john" => { risk => "خطيرة", details => "تكسير كلمات المرور", penalty => "يعتمد على نية الاستخدام", source => "official" },
        "hashcat" => { risk => "خطيرة", details => "تكسير الهاشات", penalty => "يعتمد على نية الاستخدام", source => "official" },
        "metasploit" => { risk => "خطيرة", details => "إطار اختبار الاختراق", penalty => "يعتمد على نية الاستخدام", source => "official" },
        "msfconsole" => { risk => "خطيرة", details => "واجهة Metasploit", penalty => "يعتمد على نية الاستخدام", source => "official" },
        "searchsploit" => { risk => "خطيرة", details => "البحث عن الثغرات", penalty => "للاستخدام التعليمي فقط", source => "official" },
        "exploit-db" => { risk => "خطيرة", details => "قاعدة بيانات الثغرات", penalty => "للاستخدام التعليمي فقط", source => "official" },
    );
    
    foreach my $tool (keys %dangerous) {
        $TOOL_DB{$tool} = $dangerous{$tool};
    }
}

# ============================================
# 🔴 الأدوات الإجرامية (Criminal Tools)
# ============================================

sub init_criminal_tools {
    my %criminal = (
        # أدوات التصيد الاحتيالي
        "zphisher" => { risk => "إجرامية", details => "تصيد احتيالي (Phishing)", penalty => "السجن 1-3 سنوات وغرامة مالية كبيرة", source => "blacklist" },
        "blackeye" => { risk => "إجرامية", details => "تصيد احتيالي", penalty => "السجن والغرامة", source => "blacklist" },
        "shellphish" => { risk => "إجرامية", details => "تصيد احتيالي", penalty => "السجن والغرامة", source => "blacklist" },
        "hiddeneye" => { risk => "إجرامية", details => "تصيد احتيالي", penalty => "السجن والغرامة", source => "blacklist" },
        "nexphisher" => { risk => "إجرامية", details => "تصيد احتيالي", penalty => "السجن والغرامة", source => "blacklist" },
        "socialphish" => { risk => "إجرامية", details => "تصيد احتيالي", penalty => "السجن والغرامة", source => "blacklist" },
        "advphishing" => { risk => "إجرامية", details => "تصيد متقدم", penalty => "السجن المشدد", source => "blacklist" },
        
        # أدوات تخمين كلمات المرور
        "hydra" => { risk => "إجرامية", details => "تخمين كلمات المرور", penalty => "السجن 6 شهور - 3 سنوات", source => "blacklist" },
        "ncrack" => { risk => "إجرامية", details => "تخمين كلمات المرور", penalty => "السجن والغرامة", source => "blacklist" },
        "medusa" => { risk => "إجرامية", details => "تخمين كلمات المرور", penalty => "السجن والغرامة", source => "blacklist" },
        
        # أدوات حقن SQL
        "sqlmap" => { risk => "إجرامية", details => "حقن قواعد البيانات", penalty => "السجن 6 شهور - 3 سنوات", source => "blacklist" },
        "sqlninja" => { risk => "إجرامية", details => "حقن SQL متقدم", penalty => "السجن والغرامة", source => "blacklist" },
        "bbqsql" => { risk => "إجرامية", details => "حقن SQL", penalty => "السجن والغرامة", source => "blacklist" },
        
        # أدوات اختراق الشبكات
        "reaver" => { risk => "إجرامية", details => "اختراق WPS", penalty => "السجن والغرامة", source => "blacklist" },
        "pixiewps" => { risk => "إجرامية", details => "اختراق WPS", penalty => "السجن والغرامة", source => "blacklist" },
        
        # أدوات الهندسة الاجتماعية
        "setoolkit" => { risk => "إجرامية", details => "هندسة اجتماعية", penalty => "السجن والغرامة", source => "blacklist" },
        "beef" => { risk => "إجرامية", details => "اختراق المتصفحات", penalty => "السجن", source => "blacklist" },
        "king-phisher" => { risk => "إجرامية", details => "تصيد احتيالي متقدم", penalty => "عقوبات مشددة", source => "blacklist" },
        "weeman" => { risk => "إجرامية", details => "هندسة اجتماعية", penalty => "السجن والغرامة", source => "blacklist" },
        
        # أدوات DDoS
        "slowloris" => { risk => "إجرامية", details => "هجمات حجب الخدمة", penalty => "السجن 2-5 سنوات", source => "blacklist" },
        "hulk" => { risk => "إجرامية", details => "هجمات حجب الخدمة", penalty => "السجن والغرامة", source => "blacklist" },
        "goldeneye" => { risk => "إجرامية", details => "هجمات حجب الخدمة", penalty => "السجن والغرامة", source => "blacklist" },
        "torhammer" => { risk => "إجرامية", details => "هجمات حجب الخدمة عبر Tor", penalty => "السجن المشدد", source => "blacklist" },
        "xdos" => { risk => "إجرامية", details => "هجمات حجب الخدمة", penalty => "السجن والغرامة", source => "blacklist" },
        
        # أدوات استغلال الثغرات
        "routersploit" => { risk => "إجرامية", details => "استغلال الراوترات", penalty => "السجن والغرامة", source => "blacklist" },
        
        # أدوات التجسس
        "evil-evil" => { risk => "إجرامية", details => "أدوات تجسس", penalty => "السجن المشدد", source => "blacklist" },
        "keylogger" => { risk => "إجرامية", details => "تسجيل ضغطات المفاتيح", penalty => "السجن 2-5 سنوات", source => "blacklist" },
        "rat" => { risk => "إجرامية", details => "تحكم عن بعد خبيث", penalty => "السجن المشدد", source => "blacklist" ),
    );
    
    foreach my $tool (keys %criminal) {
        $TOOL_DB{$tool} = $criminal{$tool};
    }
}

# ============================================
# 🧠 تهيئة قاعدة البيانات
# ============================================

sub init_database {
    init_safe_tools();
    init_dangerous_tools();
    init_criminal_tools();
    log_message("INFO", "SafetyDB", "تم تهيئة قاعدة بيانات الأمان (" . scalar(keys %TOOL_DB) . " أداة)");
}

# ============================================
# 🔍 الدوال الرئيسية للفحص
# ============================================

sub check_tool_safety {
    my ($tool_name) = @_;
    $tool_name = lc($tool_name);
    
    init_database() unless %TOOL_DB;
    
    if (exists $TOOL_DB{$tool_name}) {
        return ($TOOL_DB{$tool_name}{risk}, $TOOL_DB{$tool_name}{details}, $TOOL_DB{$tool_name}{penalty});
    }
    
    return ("غير معروف", "الأداة غير مصنفة في قاعدة البيانات", "غير محدد");
}

sub get_tool_risk_level {
    my ($tool_name) = @_;
    my ($risk) = check_tool_safety($tool_name);
    return $risk;
}

sub get_tool_penalty {
    my ($tool_name) = @_;
    my ($risk, $details, $penalty) = check_tool_safety($tool_name);
    return $penalty;
}

sub is_tool_allowed {
    my ($tool_name) = @_;
    my ($risk) = check_tool_safety($tool_name);
    
    # الأداة مسموحة إذا كانت آمنة فقط
    return 1 if $risk eq "آمنة";
    return 0 if $risk eq "إجرامية";
    return 0 if $risk eq "خطيرة";
    
    # إذا كانت غير معروفة، نطلب من المستخدم التصنيف
    return 2;  # 2 يعني يحتاج إلى تصنيف يدوي
}

# ============================================
# ➕ إضافة أداة مخصصة
# ============================================

sub add_custom_tool {
    my ($tool_name, $risk, $details, $penalty) = @_;
    $tool_name = lc($tool_name);
    
    $TOOL_DB{$tool_name} = {
        risk => $risk,
        details => $details,
        penalty => $penalty,
        source => "custom"
    };
    
    log_message("INFO", "SafetyDB", "تمت إضافة أداة مخصصة: $tool_name ($risk)");
    return 1;
}

# ============================================
# 📋 تقرير القائمة السوداء
# ============================================

sub get_blacklist_report {
    my $report = "";
    my @criminal_tools = ();
    
    foreach my $tool (keys %TOOL_DB) {
        if ($TOOL_DB{$tool}{risk} eq "إجرامية") {
            push(@criminal_tools, $tool);
        }
    }
    
    $report .= "\n" . "=" x 60 . "\n";
    $report .= "  🚫 تقرير الأدوات الإجرامية\n";
    $report .= "=" x 60 . "\n\n";
    
    $report .= "عدد الأدوات الإجرامية في قاعدة البيانات: " . scalar(@criminal_tools) . "\n\n";
    
    foreach my $tool (sort @criminal_tools) {
        $report .= "🔴 $tool\n";
        $report .= "   📝 " . $TOOL_DB{$tool}{details} . "\n";
        $report .= "   ⚖️ العقوبة: " . $TOOL_DB{$tool}{penalty} . "\n\n";
    }
    
    $report .= "=" x 60 . "\n";
    $report .= "⚠️ تنبيه: استخدام هذه الأدوات لأغراض غير قانونية يعرضك للمساءلة.\n";
    $report .= "=" x 60 . "\n";
    
    return $report;
}

# ============================================
# 👤 التحقق من أهلية المستخدم
# ============================================

my %VIOLATION_LOG = ();

sub verify_user_eligibility {
    my ($user_id, $proof, $script_summary) = @_;
    
    log_message("INFO", "SafetyDB", "التحقق من أهلية المستخدم: $user_id");
    
    # فحص إذا كان المستخدم في قائمة المخالفين
    if (exists $VIOLATION_LOG{$user_id}) {
        my $violation_count = $VIOLATION_LOG{$user_id}{count};
        if ($violation_count >= 3) {
            log_message("WARNING", "SafetyDB", "مستخدم ممنوع: $user_id (عدد المخالفات: $violation_count)");
            return (0, "أنت ممنوع من استخدام الأداة بسبب 3 مخالفات سابقة");
        }
    }
    
    # التحقق من صحة الدليل المقدم
    if ($proof !~ /^[A-Fa-f0-9]{64}$/) {
        return (0, "الدليل المقدم غير صالح. يجب أن يكون هاش SHA256 صحيح");
    }
    
    # التحقق من صحة السكربت المقدم (لا يحتوي على أوامر إجرامية)
    if ($script_summary =~ /(hydra|sqlmap|zphisher|slowloris)/i) {
        log_message("WARNING", "SafetyDB", "سكربت مقدم يحتوي على أدوات إجرامية من قبل $user_id");
        record_violation($user_id, "سكربت يحتوي على أدوات إجرامية");
        return (0, "السكربت المقدم يحتوي على أدوات إجرامية. ممنوع.");
    }
    
    log_message("SUCCESS", "SafetyDB", "تم التحقق من أهلية المستخدم: $user_id");
    return (1, "✅ تم التحقق. أهلاً بك في Fool's Bind AI");
}

sub record_violation {
    my ($user_id, $reason) = @_;
    
    $VIOLATION_LOG{$user_id}{count}++;
    $VIOLATION_LOG{$user_id}{last_reason} = $reason;
    $VIOLATION_LOG{$user_id}{last_time} = time();
    
    log_message("VIOLATION", "SafetyDB", "مخالفة من $user_id: $reason (العدد: $VIOLATION_LOG{$user_id}{count})");
    
    # إذا وصل إلى 3 مخالفات، نمنعه نهائياً
    if ($VIOLATION_LOG{$user_id}{count} >= 3) {
        log_message("BANNED", "SafetyDB", "تم منع المستخدم $user_id نهائياً");
    }
}

# ============================================
# تهيئة قاعدة البيانات عند التحميل
# ============================================

init_database();

# ============================================
# انتهى الملف
# ============================================
1;
