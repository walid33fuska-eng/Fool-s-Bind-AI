#!/usr/bin/perl
# ============================================
# Fool's Bind AI - التنفس الاصطناعي (Artificial Breathing)
# ============================================
# الوظيفة: محاكاة التنفس عندما لا يعمل المستخدم، تفاعل ككائن حي
# ============================================

package ArtificialBreathing;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);
use Time::HiRes qw(sleep time);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message get_timestamp colorize);

our @EXPORT = qw(
    init_breathing
    start_breathing
    stop_breathing
    breathe_once
    set_idle_threshold
    breathing_status
);

# ============================================
# 🌬️ متغيرات التنفس الاصطناعي
# ============================================

my $BREATHING_ACTIVE = 0;
my $BREATHING_PID = 0;
my $IDLE_THRESHOLD = 60;  # ثانية (دقيقة واحدة)
my $LAST_ACTIVITY = 0;
my $BREATHING_STYLE = "calm";  # calm, deep, rapid
my $BREATHING_MESSAGE = "";

# أنماط التنفس
my %BREATHING_PATTERNS = (
    "calm" => {
        inhale_time => 2.0,
        exhale_time => 3.0,
        pause_time => 1.0,
        symbol_inhale => "🫁 [شهيق]",
        symbol_exhale => "🌬️ [زفير]",
        symbol_pause => "💨 ...",
        message => "أنا هنا. فقط أتنفس. عندما تحتاجني، أنا جاهز."
    },
    "deep" => {
        inhale_time => 4.0,
        exhale_time => 4.0,
        pause_time => 2.0,
        symbol_inhale => "🌊 [شهيق عميق]",
        symbol_exhale => "🌀 [زفير عميق]",
        symbol_pause => "💫 ...",
        message => "أتنفس بعمق. أنا في انتظارك."
    },
    "rapid" => {
        inhale_time => 1.0,
        exhale_time => 1.5,
        pause_time => 0.5,
        symbol_inhale => "⚡ [شهيق سريع]",
        symbol_exhale => "💨 [زفير سريع]",
        symbol_pause => "· · ·",
        message => "مستعد للعمل في أي لحظة!"
    }
);

# رسائل تطمينية متنوعة
my @REASSURING_MESSAGES = (
    "أنا هنا. فقط أتنفس.",
    "عندما تحتاجني، أنا جاهز.",
    "استرح. سأنتظرك.",
    "لا تعجل، أنا هنا.",
    "كل شيء تحت السيطرة.",
    "أتنفس بهدوء من أجلك.",
    "فقط أخبرني متى تبدأ.",
    "أنا في الخدمة دائمًا."
);

# رسائل حسب الوقت
my @TIME_MESSAGES = (
    "صباح الخير. أتمنى لك يوماً جيداً.",
    "نهارك سعيد. أنا هنا للمساعدة.",
    "مساء الخير. استرخِ وأنا هنا.",
    "ليل هادئ. لا تقلق، أنا معك."
);

# ============================================
# 🚀 تهيئة التنفس الاصطناعي
# ============================================

sub init_breathing {
    log_message("INFO", "ArtificialBreathing", "بدء تهيئة التنفس الاصطناعي");
    
    $LAST_ACTIVITY = time();
    $BREATHING_STYLE = "calm";
    $BREATHING_MESSAGE = $BREATHING_PATTERNS{$BREATHING_STYLE}{message};
    
    log_message("SUCCESS", "ArtificialBreathing", "تم تهيئة التنفس الاصطناعي");
    return 1;
}

# ============================================
# 🌬️ بدء التنفس
# ============================================

sub start_breathing {
    return if $BREATHING_ACTIVE;
    
    log_message("INFO", "ArtificialBreathing", "بدء التنفس الاصطناعي");
    
    $BREATHING_ACTIVE = 1;
    $LAST_ACTIVITY = time();
    
    # بدء عملية التنفس في الخلفية
    $BREATHING_PID = fork();
    
    if ($BREATHING_PID == 0) {
        # العملية الابن: حلقة التنفس
        _breathing_loop();
        exit(0);
    }
    
    log_message("SUCCESS", "ArtificialBreathing", "تم بدء التنفس الاصطناعي (PID: $BREATHING_PID)");
    return $BREATHING_PID;
}

# ============================================
# 🛑 إيقاف التنفس
# ============================================

sub stop_breathing {
    return unless $BREATHING_ACTIVE;
    
    log_message("INFO", "ArtificialBreathing", "إيقاف التنفس الاصطناعي");
    
    $BREATHING_ACTIVE = 0;
    
    if ($BREATHING_PID > 0) {
        kill('TERM', $BREATHING_PID);
        $BREATHING_PID = 0;
    }
    
    log_message("SUCCESS", "ArtificialBreathing", "تم إيقاف التنفس الاصطناعي");
}

# ============================================
# 💨 تنفس مرة واحدة (للاستخدام اليدوي)
# ============================================

sub breathe_once {
    my ($style) = @_;
    $style //= $BREATHING_STYLE;
    
    my $pattern = $BREATHING_PATTERNS{$style};
    
    # شهيق
    print colorize("\r  $pattern->{symbol_inhale} ", "green");
    sleep($pattern->{inhale_time});
    
    # زفير
    print colorize("\r  $pattern->{symbol_exhale} ", "cyan");
    sleep($pattern->{exhale_time});
    
    # توقف
    if ($pattern->{pause_time} > 0) {
        print colorize("\r  $pattern->{symbol_pause}   ", "white");
        sleep($pattern->{pause_time});
    }
    
    print "\r", " " x 40, "\r";
}

# ============================================
# ⏱️ تعيين عتبة الخمول
# ============================================

sub set_idle_threshold {
    my ($seconds) = @_;
    
    if ($seconds > 0) {
        $IDLE_THRESHOLD = $seconds;
        log_message("INFO", "ArtificialBreathing", "تم تعيين عتبة الخمول إلى ${seconds} ثانية");
    }
    
    return $IDLE_THRESHOLD;
}

# ============================================
# 📊 حالة التنفس الاصطناعي
# ============================================

sub breathing_status {
    my $status = "";
    
    $status .= "\n" . "=" x 60 . "\n";
    $status .= colorize("  🌬️ التنفس الاصطناعي\n", "cyan");
    $status .= "=" x 60 . "\n\n";
    
    $status .= "الحالة: " . ($BREATHING_ACTIVE ? colorize("🟢 نشط", "green") : colorize("🔴 غير نشط", "red")) . "\n";
    $status .= "نمط التنفس: " . $BREATHING_STYLE . "\n";
    $status .= "عتبة الخمول: ${IDLE_THRESHOLD} ثانية\n";
    $status .= "آخر نشاط: " . ($LAST_ACTIVITY > 0 ? localtime($LAST_ACTIVITY) : "غير معروف") . "\n";
    
    my $idle_time = time() - $LAST_ACTIVITY;
    if ($idle_time > $IDLE_THRESHOLD) {
        $status .= "الخمول الحالي: " . int($idle_time) . " ثانية " . colorize("(يتنفس)", "green") . "\n";
    } else {
        $status .= "الخمول الحالي: " . int($idle_time) . " ثانية\n";
    }
    
    $status .= "\nرسالة التنفس: $BREATHING_MESSAGE\n";
    
    $status .= "\n" . "=" x 60 . "\n";
    
    return $status;
}

# ============================================
# 🔄 تسجيل النشاط (يُستدعى عند أي تفاعل)
# ============================================

sub record_activity {
    $LAST_ACTIVITY = time();
    
    # إذا كان التنفس نشطاً وكان هناك خمول سابق، نوقف التنفس مؤقتاً
    if ($BREATHING_ACTIVE && (time() - $LAST_ACTIVITY) < $IDLE_THRESHOLD) {
        # التنفس مستمر لكن نؤجل الدورة التالية
    }
}

# ============================================
# 🔧 دوال مساعدة داخلية
# ============================================

sub _breathing_loop {
    # تعيين اسم العملية
    $0 = "fools_bind_ai_breathing";
    
    while ($BREATHING_ACTIVE) {
        my $idle_time = time() - $LAST_ACTIVITY;
        
        if ($idle_time >= $IDLE_THRESHOLD) {
            # تحديث رسالة التنفس حسب الوقت
            _update_breathing_message();
            
            # تنفس (دورة تنفس واحدة)
            _perform_breath_cycle();
        }
        
        # الانتظار قبل التحقق مرة أخرى (نصف ثانية)
        sleep(0.5);
    }
}

sub _perform_breath_cycle {
    my $pattern = $BREATHING_PATTERNS{$BREATHING_STYLE};
    
    # لا نعرض التنفس إذا كان المستخدم يعمل (فحص إضافي)
    my $idle_time = time() - $LAST_ACTIVITY;
    return if $idle_time < $IDLE_THRESHOLD;
    
    # عرض رسالة مطمئنة بشكل عشوائي
    if (rand() < 0.3) {  # 30% فرصة لعرض رسالة
        my $message = _get_random_message();
        print colorize("\n  💙 $message\n", "cyan");
    }
    
    # عرض رمز الشهيق
    print colorize("\r  $pattern->{symbol_inhale} ", "green");
    sleep($pattern->{inhale_time});
    
    # إعادة فحص النشاط أثناء التنفس
    $idle_time = time() - $LAST_ACTIVITY;
    return if $idle_time < $IDLE_THRESHOLD;
    
    # عرض رمز الزفير
    print colorize("\r  $pattern->{symbol_exhale} ", "cyan");
    sleep($pattern->{exhale_time});
    
    # إعادة فحص النشاط
    $idle_time = time() - $LAST_ACTIVITY;
    return if $idle_time < $IDLE_THRESHOLD;
    
    # عرض رمز التوقف إذا كان موجوداً
    if ($pattern->{pause_time} > 0) {
        print colorize("\r  $pattern->{symbol_pause}   ", "white");
        sleep($pattern->{pause_time});
    }
    
    # مسح السطر
    print "\r", " " x 40, "\r";
}

sub _update_breathing_message {
    my $hour = (localtime(time()))[2];
    
    if ($hour >= 6 && $hour < 12) {
        $BREATHING_MESSAGE = $TIME_MESSAGES[0];
    } elsif ($hour >= 12 && $hour < 18) {
        $BREATHING_MESSAGE = $TIME_MESSAGES[1];
    } elsif ($hour >= 18 && $hour < 22) {
        $BREATHING_MESSAGE = $TIME_MESSAGES[2];
    } else {
        $BREATHING_MESSAGE = $TIME_MESSAGES[3];
    }
}

sub _get_random_message {
    my $index = int(rand(scalar(@REASSURING_MESSAGES)));
    return $REASSURING_MESSAGES[$index];
}

# ============================================
# 🎭 تغيير نمط التنفس
# ============================================

sub set_breathing_style {
    my ($style) = @_;
    
    if (exists $BREATHING_PATTERNS{$style}) {
        $BREATHING_STYLE = $style;
        $BREATHING_MESSAGE = $BREATHING_PATTERNS{$style}{message};
        log_message("INFO", "ArtificialBreathing", "تم تغيير نمط التنفس إلى: $style");
        return 1;
    }
    
    log_message("WARNING", "ArtificialBreathing", "نمط تنفس غير معروف: $style");
    return 0;
}

# ============================================
# 💓 نبض قلب خفيف (اختياري، يظهر أثناء التنفس)
# ============================================

sub show_heartbeat {
    my $heartbeat_symbols = ["❤️ ", "💙 ", "💚 ", "💛 ", "🧡 "];
    my $index = 0;
    
    for (my $i = 0; $i < 3; $i++) {
        print "\r  " . $heartbeat_symbols->[$index % scalar(@$heartbeat_symbols)] . " أنا بخير";
        $index++;
        sleep(1);
    }
    print "\r", " " x 30, "\r";
}

# ============================================
# انتهى الملف
# ============================================
1;
