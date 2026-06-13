#!/usr/bin/perl
# ============================================
# Fool's Bind AI - الواقع المعزز النصي (TAR)
# ============================================
# الوظيفة: عرض معلومات إضافية تتراكب فوق النص الأصلي دون حذفه
# ============================================

package TextualAugmentedReality;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);
use Term::ANSIScreen qw(colored);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message get_timestamp colorize);

our @EXPORT = qw(
    init_tar
    overlay_text
    clear_overlay
    add_annotation
    show_help_overlay
    tar_status
);

# ============================================
# 📋 متغيرات الواقع المعزز
# ============================================

my $TAR_ACTIVE = 0;
my @OVERLAYS = ();
my @ANNOTATIONS = ();
my $OVERLAY_COLOR = "cyan";
my $OVERLAY_OPACITY = 50;  # 0-100 نسبة الشفافية (محاكاة)
my $LAST_RENDER = 0;

# ============================================
# 🚀 تهيئة الواقع المعزز
# ============================================

sub init_tar {
    log_message("INFO", "TAR", "بدء تهيئة الواقع المعزز النصي");
    
    $TAR_ACTIVE = 1;
    
    log_message("SUCCESS", "TAR", "تم تهيئة الواقع المعزز النصي");
    return 1;
}

# ============================================
# 📝 تراكب نص فوق النص الأصلي
# ============================================

sub overlay_text {
    my ($text, $position, $color, $duration) = @_;
    $position //= "top";
    $color //= $OVERLAY_COLOR;
    $duration //= 3;  # ثواني
    
    return unless $TAR_ACTIVE;
    
    my $overlay = {
        id => scalar(@OVERLAYS) + 1,
        text => $text,
        position => $position,
        color => $color,
        created_at => time(),
        duration => $duration,
        active => 1
    };
    
    push @OVERLAYS, $overlay;
    
    # عرض التراكب فوراً
    _render_overlay($overlay);
    
    # إزالة التراكب بعد المدة المحددة
    if ($duration > 0) {
        my $pid = fork();
        unless ($pid) {
            sleep($duration);
            _remove_overlay($overlay->{id});
            exit(0);
        }
    }
    
    log_message("INFO", "TAR", "تم إضافة تراكب: $text");
    return $overlay->{id};
}

# ============================================
# 🧹 إزالة التراكب
# ============================================

sub clear_overlay {
    my ($overlay_id) = @_;
    
    if ($overlay_id) {
        _remove_overlay($overlay_id);
    } else {
        # إزالة جميع التراكبات
        @OVERLAYS = ();
        _clear_screen_overlays();
    }
    
    log_message("INFO", "TAR", "تم إزالة التراكبات");
}

# ============================================
# 📝 إضافة تعليق توضيحي
# ============================================

sub add_annotation {
    my ($target_text, $annotation, $position) = @_;
    $position //= "right";
    
    return unless $TAR_ACTIVE;
    
    my $annotation_obj = {
        id => scalar(@ANNOTATIONS) + 1,
        target => $target_text,
        annotation => $annotation,
        position => $position,
        created_at => time(),
        active => 1
    };
    
    push @ANNOTATIONS, $annotation_obj;
    
    log_message("INFO", "TAR", "تم إضافة تعليق توضيحي: $annotation");
    return $annotation_obj->{id};
}

# ============================================
# 🆘 عرض تعليمات مساعدة متراكبة
# ============================================

sub show_help_overlay {
    my $help_text = "";
    $help_text .= "═══════════════════════════════════════════════════\n";
    $help_text .= colorize("  🩺 Fool's Bind AI - تعليمات سريعة\n", "cyan");
    $help_text .= "═══════════════════════════════════════════════════\n\n";
    $help_text .= "الأوامر الأساسية:\n";
    $help_text .= "  • perl fools_bind_ai.pl        - تشغيل الأداة\n";
    $help_text .= "  • perl fools_bind_ai.pl --help - عرض هذه التعليمات\n";
    $help_text .= "  • perl fools_bind_ai.pl --tools nmap,wireshark - تشغيل لأدوات محددة\n\n";
    $help_text .= "الأداة صامتة. سترى التقرير فقط في النهاية.\n";
    $help_text .= "═══════════════════════════════════════════════════\n";
    
    overlay_text($help_text, "center", "cyan", 10);
    
    log_message("INFO", "TAR", "تم عرض تعليمات المساعدة");
}

# ============================================
# 📊 حالة الواقع المعزز
# ============================================

sub tar_status {
    my $status = "";
    
    $status .= "\n" . "=" x 60 . "\n";
    $status .= colorize("  🔮 الواقع المعزز النصي (TAR)\n", "cyan");
    $status .= "=" x 60 . "\n\n";
    
    $status .= "الحالة: " . ($TAR_ACTIVE ? colorize("🟢 نشط", "green") : colorize("🔴 غير نشط", "red")) . "\n";
    $status .= "التراكبات النشطة: " . scalar(grep { $_->{active} } @OVERLAYS) . "\n";
    $status .= "التعليقات التوضيحية: " . scalar(grep { $_->{active} } @ANNOTATIONS) . "\n";
    $status .= "لون التراكب الافتراضي: $OVERLAY_COLOR\n";
    $status .= "الشفافية: ${OVERLAY_OPACITY}%\n\n";
    
    if (@OVERLAYS) {
        $status .= "التراكبات النشطة:\n";
        foreach my $overlay (@OVERLAYS) {
            next unless $overlay->{active};
            my $remaining = $overlay->{duration} - (time() - $overlay->{created_at});
            $status .= sprintf("  • ID %d: %s (متبقي: %d ثانية)\n", 
                $overlay->{id}, substr($overlay->{text}, 0, 50), $remaining);
        }
    }
    
    $status .= "\n" . "=" x 60 . "\n";
    
    return $status;
}

# ============================================
# 🔧 دوال مساعدة داخلية
# ============================================

sub _render_overlay {
    my ($overlay) = @_;
    
    # حفظ موضع المؤشر الحالي
    print "\033[s";  # حفظ الموضع
    
    # الانتقال إلى الموضع المناسب
    if ($overlay->{position} eq "top") {
        print "\033[1;1H";  # السطر الأول
    } elsif ($overlay->{position} eq "bottom") {
        print "\033[" . _get_terminal_height() . ";1H";  # السطر الأخير
    } elsif ($overlay->{position} eq "center") {
        my $height = _get_terminal_height();
        my $center_row = int($height / 2);
        print "\033[${center_row};1H";
    }
    
    # عرض التراكب بلون مناسب
    my $colored_text = colorize($overlay->{text}, $overlay->{color});
    print $colored_text;
    
    # استعادة الموضع الأصلي
    print "\033[u";
}

sub _remove_overlay {
    my ($overlay_id) = @_;
    
    foreach my $overlay (@OVERLAYS) {
        if ($overlay->{id} == $overlay_id) {
            $overlay->{active} = 0;
            last;
        }
    }
    
    # إعادة رسم الشاشة
    _refresh_screen();
}

sub _clear_screen_overlays {
    # إعادة رسم الشاشة بدون تراكبات
    system("clear");
}

sub _refresh_screen {
    # إعادة عرض جميع التراكبات النشطة
    foreach my $overlay (@OVERLAYS) {
        if ($overlay->{active}) {
            _render_overlay($overlay);
        }
    }
}

sub _get_terminal_height {
    my $height = 24;  # القيمة الافتراضية
    eval {
        my ($rows, $cols) = `stty size 2>/dev/null` =~ /(\d+)\s+(\d+)/;
        $height = $rows if $rows;
    };
    return $height;
}

# ============================================
# 🔄 تراكب تقدم العملية (Progress Overlay)
# ============================================

sub show_progress_overlay {
    my ($message, $percentage) = @_;
    
    my $progress_bar = "";
    my $bar_length = 30;
    my $filled = int($bar_length * $percentage / 100);
    
    $progress_bar .= "[" . ("=" x $filled) . (">" x ($filled < $bar_length)) . (" " x ($bar_length - $filled)) . "]";
    
    my $overlay_text = "$message $progress_bar $percentage%";
    overlay_text($overlay_text, "bottom", "green", 1);
}

# ============================================
# ⚠️ تراكب تحذير (Warning Overlay)
# ============================================

sub show_warning_overlay {
    my ($warning_message) = @_;
    
    my $collected_warning = "⚠️ تحذير: $warning_message";
    overlay_text($collected_warning, "top", "yellow", 5);
}

# ============================================
# ✅ تراكب نجاح (Success Overlay)
# ============================================

sub show_success_overlay {
    my ($success_message) = @_;
    
    my $collected_success = "✅ نجاح: $success_message";
    overlay_text($collected_success, "top", "green", 3);
}

# ============================================
# ❌ تراكب خطأ (Error Overlay)
# ============================================

sub show_error_overlay {
    my ($error_message) = @_;
    
    my $collected_error = "❌ خطأ: $error_message";
    overlay_text($collected_error, "top", "red", 5);
}

# ============================================
# ℹ️ تراكب معلومات (Info Overlay)
# ============================================

sub show_info_overlay {
    my ($info_message) = @_;
    
    my $collected_info = "ℹ️ معلومات: $info_message";
    overlay_text($collected_info, "bottom", "cyan", 2);
}

# ============================================
# انتهى الملف
# ============================================
1;
