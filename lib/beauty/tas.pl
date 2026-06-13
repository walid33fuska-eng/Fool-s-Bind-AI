#!/usr/bin/perl
# ============================================
# Fool's Bind AI - التوقيع الصوتي النصي (TAS)
# ============================================
# الوظيفة: إضافة رموز موسيقية بجانب الأوامر لكل أمر نغمة فريدة
# ============================================

package TextualAudioSignature;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message get_timestamp colorize);

our @EXPORT = qw(
    init_tas
    get_command_signature
    display_signature
    learn_command
    get_tas_status
);

# ============================================
# 🎵 متغيرات التوقيع الصوتي النصي
# ============================================

my $TAS_ACTIVE = 1;
my %COMMAND_SIGNATURES = ();
my %LEARNED_PATTERNS = ();
my $SIGNATURE_VERSION = 1;

# النوتات الموسيقية المستخدمة كرموز
my @MUSICAL_NOTES = qw(♩ ♪ ♫ ♬ ♭ ♮ ♯);
my @NOTE_NAMES = qw(quarter eighth beamed sharp flat natural);

# تعريفات الأوامر الأساسية مع نغماتها الفريدة
sub _init_default_signatures {
    %COMMAND_SIGNATURES = (
        # أوامر النظام الأساسية
        "ls" => { notes => "♩", pattern => "single", description => "قائمة الملفات" },
        "cd" => { notes => "♪", pattern => "single", description => "تغيير المجلد" },
        "pwd" => { notes => "♫", pattern => "single", description => "المجلد الحالي" },
        "mkdir" => { notes => "♬", pattern => "single", description => "إنشاء مجلد" },
        "rm" => { notes => "♭", pattern => "single", description => "حذف ملف" },
        "cp" => { notes => "♮", pattern => "single", description => "نسخ ملف" },
        "mv" => { notes => "♯", pattern => "single", description => "نقل ملف" },
        
        # أوامر Termux المتقدمة
        "pkg" => { notes => "♩♪", pattern => "double", description => "مدير حزم Termux" },
        "apt" => { notes => "♪♫", pattern => "double", description => "مدير حزم APT" },
        "git" => { notes => "♫♬", pattern => "double", description => "التحكم في الإصدارات" },
        "python" => { notes => "♬♭", pattern => "double", description => "لغة Python" },
        "perl" => { notes => "♭♮", pattern => "double", description => "لغة Perl" },
        "nmap" => { notes => "♮♯", pattern => "double", description => "فحص الشبكات" },
        "wireshark" => { notes => "♯♪♫", pattern => "triple", description => "تحليل حزم" },
        
        # أوامر خاصة بـ Fool's Bind AI
        "fools_bind_ai" => { notes => "⛓️♩♪♫", pattern => "special", description => "الأداة الرئيسية" },
        "doctor" => { notes => "🩺♩", pattern => "special", description => "الطبيب الجراح" },
        "nurse" => { notes => "👩‍⚕️♪", pattern => "special", description => "الممرضات" },
        "guard" => { notes => "🛡️♫", pattern => "special", description => "رجال الأمن" },
        
        # أدوات خطيرة (نغمات تحذيرية)
        "hydra" => { notes => "⚠️♭♭♭", pattern => "warning", description => "تحذير: أداة إجرامية" },
        "sqlmap" => { notes => "⚠️♮♮♮", pattern => "warning", description => "تحذير: أداة إجرامية" },
        "zphisher" => { notes => "⛔♯♯♯", pattern => "forbidden", description => "ممنوع: أداة إجرامية" }
    );
}

# ============================================
# 🚀 تهيئة التوقيع الصوتي النصي
# ============================================

sub init_tas {
    log_message("INFO", "TAS", "بدء تهيئة التوقيع الصوتي النصي");
    
    _init_default_signatures();
    
    # تحميل الأنماط المتعلمة من ملف
    my $tool_path = dirname(abs_path($0)) . '/../..';
    my $patterns_file = "$tool_path/config/tas_patterns.json";
    
    if (-f $patterns_file) {
        eval {
            use JSON;
            open(my $fh, '<', $patterns_file);
            local $/ = undef;
            my $json = <$fh>;
            close($fh);
            my $data = decode_json($json);
            %LEARNED_PATTERNS = %{$data->{patterns}} if $data->{patterns};
            log_message("INFO", "TAS", "تم تحميل " . scalar(keys %LEARNED_PATTERNS) . " نمط متعلم");
        };
    }
    
    log_message("SUCCESS", "TAS", "تم تهيئة التوقيع الصوتي النصي");
    return 1;
}

# ============================================
# 🎵 الحصول على توقيع أمر
# ============================================

sub get_command_signature {
    my ($command) = @_;
    
    # استخراج الأمر الأساسي (بدون معاملات)
    my $base_command = (split(/\s+/, $command))[0];
    $base_command =~ s/^\W+//;
    
    # البحث في الأنماط المتعلمة أولاً
    if (exists $LEARNED_PATTERNS{$base_command}) {
        return $LEARNED_PATTERNS{$base_command};
    }
    
    # البحث في التوقيعات الافتراضية
    if (exists $COMMAND_SIGNATURES{$base_command}) {
        return $COMMAND_SIGNATURES{$base_command};
    }
    
    # إذا كان الأمر غير معروف، نعطي توقيعاً عاماً
    return {
        notes => "?",
        pattern => "unknown",
        description => "أمر غير معروف"
    };
}

# ============================================
# 🖨️ عرض التوقيع بجانب الأمر
# ============================================

sub display_signature {
    my ($command) = @_;
    
    return unless $TAS_ACTIVE;
    
    my $signature = get_command_signature($command);
    my $notes = $signature->{notes};
    
    # اختيار اللون حسب نوع التوقيع
    my $color = "white";
    if ($signature->{pattern} eq "warning") {
        $color = "yellow";
        $notes = colorize($notes, $color);
    } elsif ($signature->{pattern} eq "forbidden") {
        $color = "red";
        $notes = colorize($notes, $color);
    } elsif ($signature->{pattern} eq "special") {
        $color = "cyan";
        $notes = colorize($notes, $color);
    } else {
        $notes = colorize($notes, "green");
    }
    
    # عرض التوقيع
    my $output = sprintf("  %-3s %s", $notes, $command);
    
    # إضافة وصف للأمر إذا كان موجوداً
    if ($signature->{description} && $signature->{pattern} ne "unknown") {
        $output .= colorize("  # $signature->{description}", "white");
    }
    
    print "$output\n";
    
    return $output;
}

# ============================================
# 📚 تعلم أمر جديد (تخصيص التوقيع)
# ============================================

sub learn_command {
    my ($command, $notes, $description) = @_;
    
    $command = (split(/\s+/, $command))[0];
    
    $LEARNED_PATTERNS{$command} = {
        notes => $notes,
        pattern => "custom",
        description => $description // "أمر مخصص",
        learned_at => get_timestamp()
    };
    
    log_message("INFO", "TAS", "تم تعلم أمر جديد: $command -> $notes");
    
    # حفظ الأنماط المتعلمة
    _save_learned_patterns();
    
    return 1;
}

# ============================================
# 🎼 إنشاء نغمة مركبة لأمر معقد
# ============================================

sub compose_signature {
    my ($command, $complexity) = @_;
    $complexity //= "auto";
    
    my @parts = split(/\s+/, $command);
    my $signature = "";
    
    if ($complexity eq "auto") {
        # توقيع يعتمد على عدد الكلمات في الأمر
        my $note_count = scalar(@parts);
        $note_count = 3 if $note_count > 3;
        
        for (my $i = 0; $i < $note_count; $i++) {
            $signature .= $MUSICAL_NOTES[$i % scalar(@MUSICAL_NOTES)];
        }
    } elsif ($complexity eq "simple") {
        $signature = $MUSICAL_NOTES[0];
    } elsif ($complexity eq "complex") {
        $signature = join("", @MUSICAL_NOTES[0..3]);
    }
    
    return $signature;
}

# ============================================
# 📊 حالة التوقيع الصوتي النصي
# ============================================

sub get_tas_status {
    my $status = "";
    
    $status .= "\n" . "=" x 60 . "\n";
    $status .= colorize("  🎵 التوقيع الصوتي النصي (TAS)\n", "cyan");
    $status .= "=" x 60 . "\n\n";
    
    $status .= "الحالة: " . ($TAS_ACTIVE ? colorize("🟢 نشط", "green") : colorize("🔴 غير نشط", "red")) . "\n";
    $status .= "إصدار التوقيع: $SIGNATURE_VERSION\n";
    $status .= "الأوامر المعرفة: " . (scalar(keys %COMMAND_SIGNATURES) + scalar(keys %LEARNED_PATTERNS)) . "\n";
    $status .= "الأوامر الافتراضية: " . scalar(keys %COMMAND_SIGNATURES) . "\n";
    $status .= "الأوامر المتعلمة: " . scalar(keys %LEARNED_PATTERNS) . "\n\n";
    
    $status .= "الرموز الموسيقية المستخدمة:\n";
    for (my $i = 0; $i < scalar(@MUSICAL_NOTES); $i++) {
        $status .= sprintf("  %s - %s\n", $MUSICAL_NOTES[$i], $NOTE_NAMES[$i]);
    }
    
    $status .= "\nأمثلة على التوقيعات:\n";
    my @examples = (["ls", "♩"], ["pkg install", "♩♪"], ["fools_bind_ai", "⛓️♩♪♫"]);
    foreach my $ex (@examples) {
        $status .= sprintf("  %-20s → %s\n", $ex->[0], colorize($ex->[1], "green"));
    }
    
    $status .= "\n" . "=" x 60 . "\n";
    
    return $status;
}

# ============================================
# 🔧 دوال مساعدة
# ============================================

sub _save_learned_patterns {
    my $tool_path = dirname(abs_path($0)) . '/../..';
    my $patterns_file = "$tool_path/config/tas_patterns.json";
    
    eval {
        use JSON;
        my $data = {
            version => $SIGNATURE_VERSION,
            patterns => \%LEARNED_PATTERNS,
            saved_at => get_timestamp()
        };
        my $json = JSON->new->pretty;
        my $json_text = $json->encode($data);
        
        open(my $fh, '>', $patterns_file);
        print $fh $json_text;
        close($fh);
    };
}

# ============================================
# 🎤 عرض توقيع موسيقي للأداة الرئيسية
# ============================================

sub play_signature_intro {
    my @intro_notes = qw(♩ ♪ ♫ ♬ ♩ ♪ ♫ ♬);
    my @colors = qw(green cyan blue magenta);
    
    print "\n";
    for (my $i = 0; $i < scalar(@intro_notes); $i++) {
        my $color = $colors[$i % scalar(@colors)];
        print colorize($intro_notes[$i] . " ", $color);
        select(undef, undef, undef, 0.05);
    }
    print "\n";
    
    log_message("INFO", "TAS", "تم تشغيل المقدمة الموسيقية النصية");
}

# ============================================
# 🎯 الحصول على نغمة تحذيرية لأمر خطير
# ============================================

sub get_warning_signature {
    my ($command, $reason) = @_;
    
    my $warning_notes = "⚠️" . ("♭" x 3);
    my $message = "تحذير: الأمر $command قد يكون خطيراً";
    $message .= " - $reason" if $reason;
    
    return {
        notes => $warning_notes,
        pattern => "warning",
        description => $message,
        color => "yellow"
    };
}

# ============================================
# 🚫 نغمة ممنوع لأمر إجرامي
# ============================================

sub get_forbidden_signature {
    my ($command, $reason) = @_;
    
    my $forbidden_notes = "⛔" . ("♯" x 3);
    my $message = "ممنوع: الأمر $command غير مسموح به";
    $message .= " - $reason" if $reason;
    
    return {
        notes => $forbidden_notes,
        pattern => "forbidden",
        description => $message,
        color => "red"
    };
}

# ============================================
# ✨ تحليل توقيع الأمر وعرض تقرير
# ============================================

sub analyze_signature {
    my ($command) = @_;
    
    my $signature = get_command_signature($command);
    
    my $analysis = "";
    $analysis .= "\n" . "-" x 40 . "\n";
    $analysis .= "تحليل التوقيع الصوتي النصي:\n";
    $analysis .= "  الأمر: $command\n";
    $analysis .= "  التوقيع: " . colorize($signature->{notes}, "green") . "\n";
    $analysis .= "  النمط: $signature->{pattern}\n";
    $analysis .= "  الوصف: $signature->{description}\n";
    $analysis .= "-" x 40 . "\n";
    
    return $analysis;
}

# ============================================
# انتهى الملف
# ============================================
1;
