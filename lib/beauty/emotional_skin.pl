#!/usr/bin/perl
# ============================================
# Fool's Bind AI - الجلد العاطفي (Emotional Skin)
# ============================================
# الوظيفة: تغيير واجهة الأداة حسب الحالة المزاجية أو وقت اليوم
# ============================================

package EmotionalSkin;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);
use Term::ANSIColor;

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message get_timestamp colorize);

our @EXPORT = qw(
    init_skin
    set_mood
    get_current_skin
    apply_skin
    get_available_moods
    skin_status
);

# ============================================
# 🎨 متغيرات الجلد العاطفي
# ============================================

my $SKIN_ACTIVE = 1;
my $CURRENT_MOOD = "hacker";  # surgeon, hacker, zen, creative
my $MOOD_SETTINGS = {};
my $LAST_MOOD_CHANGE = 0;
my $AUTO_MOOD = 1;  # تغيير تلقائي حسب وقت اليوم

# تعريفات الجلود العاطفية
my %SKINS = (
    "surgeon" => {
        name => "الجراح",
        description => "نمط بسيط ومركز، ألوان أبيض وأسود، لا تأثيرات",
        colors => {
            primary => "white",
            secondary => "black",
            success => "white",
            error => "white",
            warning => "white",
            info => "white",
            prompt => "white"
        },
        effects => {
            animation => 0,
            sound => 0,
            typing_effect => "none",
            ascii_art => "simple"
        },
        prompt_style => "minimal"
    },
    "hacker" => {
        name => "المخترق",
        description => "أخضر على أسود، تأثير ماتريكس، كتابة متقطعة",
        colors => {
            primary => "green",
            secondary => "black",
            success => "bright_green",
            error => "bright_red",
            warning => "bright_yellow",
            info => "cyan",
            prompt => "bright_green"
        },
        effects => {
            animation => 1,
            sound => 1,
            typing_effect => "matrix",
            ascii_art => "matrix_rain"
        },
        prompt_style => "matrix"
    },
    "zen" => {
        name => "الاسترخاء",
        description => "أزرق على أسود، حركة بطيئة، تأثيرات مهدئة",
        colors => {
            primary => "blue",
            secondary => "black",
            success => "cyan",
            error => "magenta",
            warning => "yellow",
            info => "light_blue",
            prompt => "light_blue"
        },
        effects => {
            animation => 1,
            sound => 0,
            typing_effect => "slow",
            ascii_art => "mountain"
        },
        prompt_style => "gentle"
    },
    "creative" => {
        name => "الإبداع",
        description => "ألوان متغيرة باستمرار، تأثيرات فنية",
        colors => {
            primary => "rainbow",
            secondary => "black",
            success => "green",
            error => "red",
            warning => "yellow",
            info => "cyan",
            prompt => "rainbow"
        },
        effects => {
            animation => 2,
            sound => 1,
            typing_effect => "rainbow",
            ascii_art => "abstract"
        },
        prompt_style => "artistic"
    }
);

# ============================================
# 🚀 تهيئة الجلد العاطفي
# ============================================

sub init_skin {
    log_message("INFO", "EmotionalSkin", "بدء تهيئة الجلد العاطفي");
    
    # تحميل الإعدادات من ملف التكوين إذا وجد
    my $tool_path = dirname(abs_path($0)) . '/../..';
    my $skin_config = "$tool_path/config/skin.conf";
    
    if (-f $skin_config) {
        open(my $fh, '<', $skin_config);
        while (my $line = <$fh>) {
            chomp($line);
            next if $line =~ /^#/;
            if ($line =~ /^MOOD=(.+)$/) {
                $CURRENT_MOOD = $1 if exists $SKINS{$1};
            } elsif ($line =~ /^AUTO_MOOD=(.+)$/) {
                $AUTO_MOOD = $1 eq "yes" ? 1 : 0;
            }
        }
        close($fh);
    }
    
    $MOOD_SETTINGS = $SKINS{$CURRENT_MOOD};
    $LAST_MOOD_CHANGE = time();
    
    # تحديث تلقائي حسب الوقت إذا كان مفعلاً
    if ($AUTO_MOOD) {
        _auto_select_mood();
    }
    
    log_message("SUCCESS", "EmotionalSkin", "تم تهيئة الجلد العاطفي: $CURRENT_MOOD");
    return 1;
}

# ============================================
# 😊 تغيير الحالة المزاجية
# ============================================

sub set_mood {
    my ($mood) = @_;
    
    unless (exists $SKINS{$mood}) {
        log_message("WARNING", "EmotionalSkin", "حالة مزاجية غير معروفة: $mood");
        return 0;
    }
    
    $CURRENT_MOOD = $mood;
    $MOOD_SETTINGS = $SKINS{$mood};
    $LAST_MOOD_CHANGE = time();
    
    # تطبيق الجلد الجديد
    apply_skin();
    
    log_message("INFO", "EmotionalSkin", "تم تغيير الحالة المزاجية إلى: $mood");
    return 1;
}

# ============================================
# 🎨 الحصول على الجلد الحالي
# ============================================

sub get_current_skin {
    return {
        mood => $CURRENT_MOOD,
        settings => $MOOD_SETTINGS,
        changed_at => $LAST_MOOD_CHANGE
    };
}

# ============================================
# ✨ تطبيق الجلد
# ============================================

sub apply_skin {
    # تطبيق الألوان
    _apply_color_scheme();
    
    # تطبيق التأثيرات
    _apply_effects();
    
    # عرض رسالة الترحيب حسب الحالة المزاجية
    _show_welcome_message();
    
    log_message("INFO", "EmotionalSkin", "تم تطبيق الجلد $CURRENT_MOOD");
}

# ============================================
# 📋 قائمة الحالات المزاجية المتاحة
# ============================================

sub get_available_moods {
    my %moods = ();
    
    foreach my $mood (keys %SKINS) {
        $moods{$mood} = $SKINS{$mood}{description};
    }
    
    return \%moods;
}

# ============================================
# 📊 حالة الجلد العاطفي
# ============================================

sub skin_status {
    my $status = "";
    
    $status .= "\n" . "=" x 60 . "\n";
    $status .= colorize("  🎨 الجلد العاطفي (Emotional Skin)\n", "cyan");
    $status .= "=" x 60 . "\n\n";
    
    $status .= "الحالة: " . ($SKIN_ACTIVE ? colorize("🟢 نشط", "green") : colorize("🔴 غير نشط", "red")) . "\n";
    $status .= "الحالة المزاجية الحالية: " . colorize($SKINS{$CURRENT_MOOD}{name}, $SKINS{$CURRENT_MOOD}{colors}{primary}) . "\n";
    $status .= "الوصف: $SKINS{$CURRENT_MOOD}{description}\n";
    $status .= "التغيير التلقائي: " . ($AUTO_MOOD ? "مفعل" : "معطل") . "\n";
    $status .= "آخر تغيير: " . localtime($LAST_MOOD_CHANGE) . "\n\n";
    
    $status .= "الجلود المتاحة:\n";
    foreach my $mood (keys %SKINS) {
        my $marker = ($mood eq $CURRENT_MOOD) ? "→" : "  ";
        $status .= sprintf("  %s %-12s - %s\n", 
            $marker, $SKINS{$mood}{name}, $SKINS{$mood}{description});
    }
    
    $status .= "\n" . "=" x 60 . "\n";
    
    return $status;
}

# ============================================
# 🔧 دوال مساعدة داخلية
# ============================================

sub _auto_select_mood {
    my ($hour) = (localtime(time()))[2];
    
    my $new_mood = $CURRENT_MOOD;
    
    if ($hour >= 6 && $hour < 12) {
        # الصباح: طاقة عالية
        $new_mood = "surgeon" if $CURRENT_MOOD ne "surgeon";
    } elsif ($hour >= 12 && $hour < 18) {
        # بعد الظهر: إبداع
        $new_mood = "creative" if $CURRENT_MOOD ne "creative";
    } elsif ($hour >= 18 && $hour < 22) {
        # المساء: تركيز
        $new_mood = "hacker" if $CURRENT_MOOD ne "hacker";
    } else {
        # الليل: استرخاء
        $new_mood = "zen" if $CURRENT_MOOD ne "zen";
    }
    
    if ($new_mood ne $CURRENT_MOOD) {
        set_mood($new_mood);
        log_message("INFO", "EmotionalSkin", "تغيير تلقائي حسب الوقت إلى: $new_mood");
    }
}

sub _apply_color_scheme {
    my $colors = $MOOD_SETTINGS->{colors};
    
    # تعيين ألوان الطرفية
    if ($colors->{primary} eq "rainbow") {
        print colored("", 'reset');
    } else {
        print colored("", $colors->{primary});
    }
    
    # تعيين لون المطالبة
    $ENV{PS1} = _get_colored_prompt($colors->{prompt});
}

sub _apply_effects {
    my $effects = $MOOD_SETTINGS->{effects};
    
    if ($effects->{typing_effect} eq "matrix") {
        # تأثير كتابة متقطعة
        print colored("\n[system] initializing...\n", 'green');
        sleep(1);
    } elsif ($effects->{typing_effect} eq "slow") {
        sleep(2);
    }
    
    # عرض ASCII art حسب الحالة المزاجية
    _show_ascii_art();
}

sub _show_ascii_art {
    my $ascii_type = $MOOD_SETTINGS->{effects}{ascii_art};
    
    if ($ascii_type eq "simple") {
        print colored("🩺", 'white');
    } elsif ($ascii_type eq "matrix_rain") {
        print colored("⛓️", 'green');
    } elsif ($ascii_type eq "mountain") {
        print colored("🏔️", 'blue');
    } elsif ($ascii_type eq "abstract") {
        print colored("🎨", 'cyan');
    }
    
    print "\n";
}

sub _show_welcome_message {
    my $welcome = "";
    
    if ($CURRENT_MOOD eq "surgeon") {
        $welcome = colorize("\n🩺 مستشفى Fool's Bind AI - جاهز للعمليات الجراحية\n", "white");
    } elsif ($CURRENT_MOOD eq "hacker") {
        $welcome = colorize("\n⛓️ Fool's Bind AI - وضع المخترق. الأداة جاهزة.\n", "green");
    } elsif ($CURRENT_MOOD eq "zen") {
        $welcome = colorize("\n🧘 Fool's Bind AI - وضع الاسترخاء. خذ وقتك.\n", "blue");
    } elsif ($CURRENT_MOOD eq "creative") {
        $welcome = colorize("\n🎨 Fool's Bind AI - وضع الإبداع. فلنبتكر معاً.\n", "cyan");
    }
    
    print $welcome;
}

sub _get_colored_prompt {
    my ($color) = @_;
    
    if ($color eq "rainbow") {
        return "\\[\\033[1;32m\\]⛓️\\[\\033[0m\\] \\[\\033[1;34m\\]\\w\\[\\033[0m\\] \\[\\033[1;33m\\]$\\[\\033[0m\\] ";
    } elsif ($color eq "matrix") {
        return "\\[\\033[1;32m\\][fools-bind]\\[\\033[0m\\] \\[\\033[1;32m\\]\\w\\[\\033[0m\\] \\[\\033[1;32m\\]$\\[\\033[0m\\] ";
    } elsif ($color eq "gentle") {
        return "\\[\\033[1;34m\\]λ\\[\\033[0m\\] ";
    } elsif ($color eq "artistic") {
        return "\\[\\033[1;35m\\]✦\\[\\033[0m\\] ";
    } else {
        return "\\[\\033[1;37m\\]$\\[\\033[0m\\] ";
    }
}

# ============================================
# 🎭 دوال إضافية للحالات المزاجية
# ============================================

sub get_color_for_status {
    my ($status) = @_;
    
    if ($status eq "success") {
        return $MOOD_SETTINGS->{colors}{success};
    } elsif ($status eq "error") {
        return $MOOD_SETTINGS->{colors}{error};
    } elsif ($status eq "warning") {
        return $MOOD_SETTINGS->{colors}{warning};
    } elsif ($status eq "info") {
        return $MOOD_SETTINGS->{colors}{info};
    }
    
    return $MOOD_SETTINGS->{colors}{primary};
}

sub get_animation_speed {
    return $MOOD_SETTINGS->{effects}{animation};
}

# ============================================
# انتهى الملف
# ============================================
1;
