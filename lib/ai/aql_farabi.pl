#!/usr/bin/perl
# ============================================
# Fool's Bind AI - العقل الفارابي (Aql Farabi)
# ============================================
# الوظيفة: الذكاء الاصطناعي الكمي النووي الذري (QNAI) - عقل الطبيب
# ============================================

package AqlFarabi;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);
use JSON;
use LWP::UserAgent;
use HTTP::Request;

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message get_timestamp colorize check_internet);

our @EXPORT = qw(
    initialize_ai
    ai_think
    ai_analyze
    ai_suggest_solution
    ai_quantum_decision
    get_ai_status
);

# ============================================
# 🧠 متغيرات العقل الفارابي
# ============================================

my $AI_ACTIVE = 0;
my $GROQ_API_KEY = "";
my $GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";
my $MODEL = "llama3-70b-8192";
my $TEMPERATURE = 0.3;
my $MAX_TOKENS = 2048;

# إحصائيات الذكاء الاصطناعي
my $AI_STATS = {
    decisions_made => 0,
    solutions_suggested => 0,
    quantum_calculations => 0,
    last_decision => undef,
    accuracy_rate => 0
};

# ============================================
# 🚀 تهيئة العقل الفارابي
# ============================================

sub initialize_ai {
    log_message("INFO", "AqlFarabi", "بدء تهيئة العقل الفارابي");
    
    # قراءة مفتاح API من متغير البيئة
    $GROQ_API_KEY = $ENV{GROQ_API_KEY} // "";
    
    if ($GROQ_API_KEY eq "") {
        # محاولة القراءة من ملف مخفي
        my $key_file = dirname(abs_path($0)) . '/../../config/.groq_key';
        if (-f $key_file) {
            open(my $fh, '<', $key_file);
            $GROQ_API_KEY = <$fh>;
            close($fh);
            chomp($GROQ_API_KEY);
        }
    }
    
    if ($GROQ_API_KEY eq "") {
        log_message("WARNING", "AqlFarabi", "مفتاح Groq API غير موجود. سيتم العمل في وضع بدون إنترنت");
        $AI_ACTIVE = 0;
        return 0;
    }
    
    # التحقق من الإنترنت
    unless (check_internet()) {
        log_message("WARNING", "AqlFarabi", "لا يوجد اتصال بالإنترنت. سيتم العمل في وضع بدون إنترنت");
        $AI_ACTIVE = 0;
        return 0;
    }
    
    $AI_ACTIVE = 1;
    log_message("SUCCESS", "AqlFarabi", "تم تهيئة العقل الفارابي بنجاح (النموذج: $MODEL)");
    
    return 1;
}

# ============================================
# 🧠 التفكير (التحليل واتخاذ القرار)
# ============================================

sub ai_think {
    my ($query, $context) = @_;
    
    log_message("INFO", "AqlFarabi", "بدء عملية التفكير: $query");
    
    unless ($AI_ACTIVE) {
        return _fallback_decision($query);
    }
    
    # بناء prompt متقدم مع رياضيات الكم
    my $prompt = _build_quantum_prompt($query, $context);
    
    # استدعاء Groq API
    my $response = _call_groq_api($prompt);
    
    if ($response) {
        $AI_STATS->{decisions_made}++;
        $AI_STATS->{last_decision} = get_timestamp();
        
        # تطبيق رياضيات الكم على القرار
        my $quantum_decision = _apply_quantum_math($response);
        
        log_message("SUCCESS", "AqlFarabi", "تم اتخاذ القرار");
        return $quantum_decision;
    }
    
    # إذا فشل API، نستخدم الخوارزميات المحلية
    log_message("WARNING", "AqlFarabi", "فشل API، استخدام الخوارزميات المحلية");
    return _fallback_decision($query);
}

# ============================================
# 🔬 التحليل العميق
# ============================================

sub ai_analyze {
    my ($data, $analysis_type) = @_;
    
    log_message("INFO", "AqlFarabi", "تحليل $analysis_type");
    
    my $analysis_result = {};
    
    if ($analysis_type eq "security_risk") {
        $analysis_result = _analyze_security_risk($data);
    }
    elsif ($analysis_type eq "tool_health") {
        $analysis_result = _analyze_tool_health($data);
    }
    elsif ($analysis_type eq "quantum_state") {
        $analysis_result = _analyze_quantum_state($data);
    }
    else {
        $analysis_result = _general_analysis($data);
    }
    
    return $analysis_result;
}

# ============================================
# 💡 اقتراح الحلول
# ============================================

sub ai_suggest_solution {
    my ($problem, $environment) = @_;
    
    log_message("INFO", "AqlFarabi", "اقتراح حلول للمشكلة: $problem");
    
    my @solutions = ();
    
    # 1. البحث في قاعدة البيانات المحلية
    my $local_solutions = _search_local_solutions($problem, $environment);
    push @solutions, @$local_solutions if $local_solutions;
    
    # 2. استخدام Groq API إن أمكن
    if ($AI_ACTIVE) {
        my $prompt = "المشكلة: $problem\n";
        $prompt .= "البيئة: " . encode_json($environment) . "\n";
        $prompt .= "اقترح 3 حلول عملية لإصلاح هذه المشكلة في Termux.";
        
        my $ai_solutions = _call_groq_api($prompt);
        if ($ai_solutions) {
            push @solutions, {
                source => "Groq AI",
                solution => $ai_solutions,
                confidence => 0.85
            };
            $AI_STATS->{solutions_suggested}++;
        }
    }
    
    # 3. استخدام خوارزميات الكم
    my $quantum_solutions = _quantum_solution_search($problem);
    push @solutions, @$quantum_solutions if $quantum_solutions;
    
    return \@solutions;
}

# ============================================
# ⚛️ القرار الكمي
# ============================================

sub ai_quantum_decision {
    my ($options, $weights) = @_;
    
    log_message("INFO", "AqlFarabi", "اتخاذ قرار كمي");
    $AI_STATS->{quantum_calculations}++;
    
    # تطبيق التراكب الكمي (محاكاة لعدة احتمالات في وقت واحد)
    my @superposition = ();
    
    foreach my $option (@$options) {
        my $weight = $weights->{$option} // 1;
        my $quantum_state = {
            option => $option,
            probability => _quantum_probability($weight),
            entangled_factors => _quantum_entanglement($option)
        };
        push @superposition, $quantum_state;
    }
    
    # انهيار الدالة الموجية (اختيار الخيار الأكثر احتمالاً)
    @superposition = sort { $b->{probability} <=> $a->{probability} } @superposition;
    
    my $final_decision = $superposition[0]->{option};
    
    log_message("INFO", "AqlFarabi", "القرار الكمي: $final_decision");
    
    return {
        decision => $final_decision,
        probability => $superposition[0]->{probability},
        alternatives => \@superposition
    };
}

# ============================================
# 📊 حالة العقل الفارابي
# ============================================

sub get_ai_status {
    my $status = "";
    
    $status .= "\n" . "=" x 60 . "\n";
    $status .= colorize("  🧠 العقل الفارابي - تقرير الحالة\n", "cyan");
    $status .= "=" x 60 . "\n\n";
    
    $status .= "الحالة: " . ($AI_ACTIVE ? colorize("🟢 نشط", "green") : colorize("🔴 غير نشط", "red")) . "\n";
    $status .= "النموذج: $MODEL\n";
    $status .= "درجة الحرارة: $TEMPERATURE\n";
    $status .= "الحد الأقصى للرموز: $MAX_TOKENS\n\n";
    
    $status .= "الإحصائيات:\n";
    $status .= "  • القرارات المتخذة: $AI_STATS->{decisions_made}\n";
    $status .= "  • الحلول المقترحة: $AI_STATS->{solutions_suggested}\n";
    $status .= "  • الحسابات الكمية: $AI_STATS->{quantum_calculations}\n";
    $status .= "  • آخر قرار: $AI_STATS->{last_decision}\n";
    
    $status .= "\n" . "=" x 60 . "\n";
    
    return $status;
}

# ============================================
# 🔧 دوال Groq API
# ============================================

sub _call_groq_api {
    my ($prompt) = @_;
    
    return undef unless $AI_ACTIVE;
    
    my $ua = LWP::UserAgent->new;
    $ua->timeout(30);
    
    my $request_data = {
        model => $MODEL,
        messages => [
            { role => "system", content => _get_system_prompt() },
            { role => "user", content => $prompt }
        ],
        temperature => $TEMPERATURE,
        max_tokens => $MAX_TOKENS
    };
    
    my $json_data = encode_json($request_data);
    
    my $request = HTTP::Request->new('POST', $GROQ_API_URL);
    $request->header('Content-Type' => 'application/json');
    $request->header('Authorization' => "Bearer $GROQ_API_KEY");
    $request->content($json_data);
    
    my $response = $ua->request($request);
    
    if ($response->is_success) {
        my $decoded = decode_json($response->decoded_content);
        return $decoded->{choices}[0]{message}{content};
    }
    
    log_message("ERROR", "AqlFarabi", "خطأ في API: " . $response->status_line);
    return undef;
}

# ============================================
# 📝 بناء prompt كمي متقدم
# ============================================

sub _build_quantum_prompt {
    my ($query, $context) = @_;
    
    my $prompt = "";
    $prompt .= "[نظام] أنت العقل الفارابي، ذكاء اصطناعي كمي نووي ذري.\n";
    $prompt .= "[المهمة] تحليل واتخاذ قرارات جراحية دقيقة لبيئة Termux.\n";
    $prompt .= "[السياق] " . ($context // "عام") . "\n";
    $prompt .= "[الاستعلام] $query\n";
    $prompt .= "[المبادئ] الصفر خطأ، الدقة المطلقة، الأمان أولاً، الرفض التام للأدوات الإجرامية.\n";
    $prompt .= "[التحليل الكمي] استخدم مبدأ التراكب لفحص جميع الاحتمالات.\n";
    $prompt .= "[التحليل النووي] قم بتحليل المخاطر باستخدام نموذج الاضمحلال.\n";
    $prompt .= "[التحليل الذري] قم بتقسيم المشكلة إلى أصغر وحداتها.\n";
    $prompt .= "[المخرجات] قدم قراراً واحداً واضحاً مع التبرير.\n";
    
    return $prompt;
}

sub _get_system_prompt {
    return "أنت العقل الفارابي، أعلى درجات الذكاء الاصطناعي الكمي النووي الذري. "
         . "متخصص في تشخيص وإصلاح أدوات Termux. "
         . "مبادئك: صفر خطأ، دقة مطلقة، أمان كامل. "
         . "ترفض تماماً أي أداة إجرامية أو استخدام ضار. "
         . "قراراتك مبنية على رياضيات الكم والنووية والذرية.";
}

# ============================================
# ⚛️ رياضيات الكم
# ============================================

sub _apply_quantum_math {
    my ($response) = @_;
    
    # محاكاة تأثير التراكب الكمي
    my @possible_interpretations = split(/\n/, $response);
    
    # إذا كان هناك عدة تفسيرات، نختار التفسير الأكثر احتمالاً
    if (@possible_interpretations > 1) {
        # نختار التفسير الذي يحتوي على أكبر قدر من المعلومات
        @possible_interpretations = sort { length($b) <=> length($a) } @possible_interpretations;
        $response = $possible_interpretations[0];
    }
    
    return $response;
}

sub _quantum_probability {
    my ($weight) = @_;
    
    # دالة احتمال كمي مستوحاة من مربع السعة الاحتمالية
    my $probability = $weight ** 2;
    $probability = 1 if $probability > 1;
    $probability = 0 if $probability < 0;
    
    return $probability;
}

sub _quantum_entanglement {
    my ($option) = @_;
    
    # تشابك كمي محاكى: عوامل مرتبطة بالخيار
    my @entangled = ();
    
    if ($option =~ /security/i) {
        push @entangled, "safety_check", "threat_detection", "guard_patrol";
    }
    elsif ($option =~ /install/i) {
        push @entangled, "dependency_check", "internet_verify", "space_check";
    }
    elsif ($option =~ /repair/i) {
        push @entangled, "diagnosis", "solution_search", "auto_fix";
    }
    
    return \@entangled;
}

# ============================================
# 🔬 تحليلات متخصصة
# ============================================

sub _analyze_security_risk {
    my ($data) = @_;
    
    my $risk_score = 0;
    my $risk_factors = [];
    
    # تحليل عوامل الخطر
    if ($data->{contains_blacklisted}) {
        $risk_score += 50;
        push @$risk_factors, "يحتوي على أدوات محظورة";
    }
    
    if ($data->{network_access}) {
        $risk_score += 20;
        push @$risk_factors, "يتطلب وصولاً إلى الشبكة";
    }
    
    if ($data->{file_modification}) {
        $risk_score += 30;
        push @$risk_factors, "يعدل ملفات النظام";
    }
    
    return {
        risk_score => $risk_score,
        risk_level => $risk_score > 70 ? "high" : ($risk_score > 40 ? "medium" : "low"),
        risk_factors => $risk_factors,
        recommendation => $risk_score > 70 ? "block" : "monitor"
    };
}

sub _analyze_tool_health {
    my ($data) = @_;
    
    my $health_score = 100;
    my $issues = [];
    
    if (!$data->{installed}) {
        $health_score -= 50;
        push @$issues, "غير مثبت";
    }
    
    if ($data->{broken}) {
        $health_score -= 30;
        push @$issues, "معطوب";
    }
    
    if ($data->{outdated}) {
        $health_score -= 20;
        push @$issues, "قديم";
    }
    
    return {
        health_score => $health_score,
        status => $health_score >= 80 ? "جيد" : ($health_score >= 50 ? "متوسط" : "سيء"),
        issues => $issues,
        needs_repair => $health_score < 80
    };
}

sub _analyze_quantum_state {
    my ($data) = @_;
    
    # تحليل كمي محاكى
    return {
        superposition_states => ["working", "broken", "repairing"],
        collapse_probability => 0.85,
        entanglement_level => "high",
        quantum_phase => "stable"
    };
}

sub _general_analysis {
    my ($data) = @_;
    
    return {
        analyzed_at => get_timestamp(),
        data_size => length(encode_json($data)),
        complexity => "normal",
        recommendation => "proceed_with_caution"
    };
}

# ============================================
# 💡 البحث عن حلول محلية
# ============================================

sub _search_local_solutions {
    my ($problem, $environment) = @_;
    
    my @solutions = ();
    
    # فحص المشكلات الشائعة
    if ($problem =~ /command not found/i) {
        my $tool = $problem =~ /command not found: (\S+)/i ? $1 : "";
        if ($tool) {
            push @solutions, {
                source => "local_db",
                solution => "pkg install $tool",
                confidence => 0.9,
                steps => ["pkg update", "pkg install $tool -y"]
            };
        }
    }
    
    if ($problem =~ /permission denied/i) {
        push @solutions, {
            source => "local_db",
            solution => "termux-setup-storage",
            confidence => 0.85,
            steps => ["تشغيل termux-setup-storage", "منح الصلاحيات من الهاتف"]
        };
    }
    
    return \@solutions;
}

# ============================================
# 🔄 البحث الكمي عن الحلول
# ============================================

sub _quantum_solution_search {
    my ($problem) = @_;
    
    my @solutions = ();
    
    # محاكاة للبحث الكمي (توليد حلول متعددة ثم اختيار الأفضل)
    my @quantum_solutions = (
        {
            source => "quantum_algorithm",
            solution => "تحليل شامل للمشكلة وإصلاح تلقائي",
            confidence => 0.75,
            quantum_probability => 0.82
        },
        {
            source => "quantum_algorithm",
            solution => "إعادة تثبيت الأداة بعد تنظيف البيئة",
            confidence => 0.70,
            quantum_probability => 0.78
        }
    );
    
    push @solutions, @quantum_solutions;
    
    return \@solutions;
}

# ============================================
# 🔄 القرار البديل (بدون AI)
# ============================================

sub _fallback_decision {
    my ($query) = @_;
    
    log_message("INFO", "AqlFarabi", "استخدام خوارزميات بديلة");
    
    if ($query =~ /(install|تثبيت)/i) {
        return "محاولة التثبيت عبر الممرضات المتخصصة";
    }
    elsif ($query =~ /(fix|إصلاح)/i) {
        return "بدء عملية الإصلاح التلقائي";
    }
    elsif ($query =~ /(security|أمن)/i) {
        return "تفعيل رجال الأمن والفحص الشامل";
    }
    else {
        return "تشخيص المشكلة وجمع المعلومات";
    }
}

# ============================================
# انتهى الملف
# ============================================
1;
