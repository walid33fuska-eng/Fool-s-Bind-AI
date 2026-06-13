#!/usr/bin/perl
# ============================================
# Fool's Bind AI - البصمة الحيوية للطرفية (Terminal Biometrics)
# ============================================
# الوظيفة: التعرف على المستخدم من طريقة كتابته وتكييف الواجهة حسب تفضيلاته
# ============================================

package TerminalBiometrics;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);
use Time::HiRes qw(time);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message get_timestamp colorize);

our @EXPORT = qw(
    init_biometrics
    capture_typing_pattern
    identify_user
    get_user_preferences
    update_user_profile
    biometrics_status
);

# ============================================
# 🧬 متغيرات البصمة الحيوية
# ============================================

my $BIOMETRICS_ACTIVE = 0;
my $USER_PROFILES = {};
my $CURRENT_USER = undef;
my $TYPING_BUFFER = [];
my $LAST_KEY_TIME = 0;
my $PROFILES_FILE = "";

# أنماط الكتابة المخزنة
my %TYPING_PATTERNS = ();

# ============================================
# 🚀 تهيئة البصمة الحيوية
# ============================================

sub init_biometrics {
    log_message("INFO", "TerminalBiometrics", "بدء تهيئة البصمة الحيوية");
    
    my $tool_path = dirname(abs_path($0)) . '/../..';
    $PROFILES_FILE = "$tool_path/config/user_profiles.json";
    
    # تحميل الملفات الشخصية المخزنة
    if (-f $PROFILES_FILE) {
        eval {
            use JSON;
            open(my $fh, '<', $PROFILES_FILE);
            local $/ = undef;
            my $json = <$fh>;
            close($fh);
            $USER_PROFILES = decode_json($json);
            log_message("INFO", "TerminalBiometrics", "تم تحميل " . scalar(keys %$USER_PROFILES) . " ملف شخصي");
        };
    }
    
    $BIOMETRICS_ACTIVE = 1;
    log_message("SUCCESS", "TerminalBiometrics", "تم تهيئة البصمة الحيوية");
    
    return 1;
}

# ============================================
# ⌨️ التقاط نمط الكتابة
# ============================================

sub capture_typing_pattern {
    my ($char, $timestamp) = @_;
    $timestamp //= time();
    
    return unless $BIOMETRICS_ACTIVE;
    
    my $current_time = $timestamp;
    my $dwell_time = 0;  # زمن الضغط على المفتاح
    my $flight_time = 0; # زمن الانتقال بين المفاتيح
    
    if ($LAST_KEY_TIME > 0) {
        $flight_time = $current_time - $LAST_KEY_TIME;
    }
    
    # تخزين معلومات الضغطة
    push @$TYPING_BUFFER, {
        char => $char,
        time => $current_time,
        flight_time => $flight_time,
        dwell_time => $dwell_time
    };
    
    # الاحتفاظ بآخر 100 ضغطة فقط
    if (@$TYPING_BUFFER > 100) {
        shift @$TYPING_BUFFER;
    }
    
    $LAST_KEY_TIME = $current_time;
    
    # إذا تجاوزنا 50 ضغطة، نحاول التعرف على المستخدم
    if (@$TYPING_BUFFER >= 50 && !$CURRENT_USER) {
        identify_user();
    }
}

# ============================================
# 🆔 التعرف على المستخدم
# ============================================

sub identify_user {
    return unless $BIOMETRICS_ACTIVE;
    return if @$TYPING_BUFFER < 20;  # نحتاج 20 ضغطة على الأقل للتعرف
    
    log_message("INFO", "TerminalBiometrics", "محاولة التعرف على المستخدم");
    
    my $typing_signature = _extract_typing_signature();
    my $best_match = undef;
    my $best_score = 0;
    
    # مقارنة مع جميع الملفات الشخصية المخزنة
    foreach my $user_id (keys %$USER_PROFILES) {
        my $profile = $USER_PROFILES->{$user_id};
        my $score = _compare_signatures($typing_signature, $profile->{signature});
        
        if ($score > $best_score && $score > 0.6) {  # عتبة 60%
            $best_score = $score;
            $best_match = $user_id;
        }
    }
    
    if ($best_match) {
        $CURRENT_USER = $best_match;
        log_message("SUCCESS", "TerminalBiometrics", "تم التعرف على المستخدم: $best_match (الثقة: " . int($best_score * 100) . "%)");
        
        # تحديث الملف الشخصي بالمعلومات الجديدة
        update_user_profile($best_match);
        
        return ($best_match, $best_score);
    }
    
    # مستخدم جديد
    log_message("INFO", "TerminalBiometrics", "لم يتم التعرف على المستخدم - مستخدم جديد");
    return (undef, 0);
}

# ============================================
# 🎨 الحصول على تفضيلات المستخدم
# ============================================

sub get_user_preferences {
    my ($user_id) = @_;
    $user_id //= $CURRENT_USER;
    
    return {} unless $user_id;
    return {} unless exists $USER_PROFILES->{$user_id};
    
    return $USER_PROFILES->{$user_id}{preferences};
}

# ============================================
# 📝 تحديث الملف الشخصي
# ============================================

sub update_user_profile {
    my ($user_id, $preferences) = @_;
    
    my $typing_signature = _extract_typing_signature();
    
    # إذا كان المستخدم موجوداً، ندمج التوقيع الجديد
    if (exists $USER_PROFILES->{$user_id}) {
        my $old_signature = $USER_PROFILES->{$user_id}{signature};
        my $merged_signature = _merge_signatures($old_signature, $typing_signature);
        $USER_PROFILES->{$user_id}{signature} = $merged_signature;
        
        # تحديث التفضيلات إذا قدمت
        if ($preferences) {
            $USER_PROFILES->{$user_id}{preferences} = _merge_preferences(
                $USER_PROFILES->{$user_id}{preferences},
                $preferences
            );
        }
        
        # تحديث آخر ظهور
        $USER_PROFILES->{$user_id}{last_seen} = get_timestamp();
    } else {
        # إنشاء ملف شخصي جديد
        $USER_PROFILES->{$user_id} = {
            id => $user_id,
            signature => $typing_signature,
            preferences => $preferences || _default_preferences(),
            first_seen => get_timestamp(),
            last_seen => get_timestamp(),
            sessions_count => 1
        };
    }
    
    # حفظ الملفات الشخصية
    _save_profiles();
    
    log_message("INFO", "TerminalBiometrics", "تم تحديث الملف الشخصي للمستخدم: $user_id");
}

# ============================================
# 📊 حالة البصمة الحيوية
# ============================================

sub biometrics_status {
    my $status = "";
    
    $status .= "\n" . "=" x 60 . "\n";
    $status .= colorize("  🔐 البصمة الحيوية للطرفية\n", "cyan");
    $status .= "=" x 60 . "\n\n";
    
    $status .= "الحالة: " . ($BIOMETRICS_ACTIVE ? colorize("🟢 نشطة", "green") : colorize("🔴 غير نشطة", "red")) . "\n";
    $status .= "عدد الملفات الشخصية: " . scalar(keys %$USER_PROFILES) . "\n";
    $status .= "المستخدم الحالي: " . ($CURRENT_USER // "غير معروف") . "\n";
    $status .= "ضغطات المفاتيح المخزنة: " . scalar(@$TYPING_BUFFER) . "\n\n";
    
    if ($CURRENT_USER && exists $USER_PROFILES->{$CURRENT_USER}) {
        my $profile = $USER_PROFILES->{$CURRENT_USER};
        $status .= "تفضيلات المستخدم الحالي:\n";
        $status .= "  • وضع الجلد: " . ($profile->{preferences}{skin} // "افتراضي") . "\n";
        $status .= "  • حجم الخط: " . ($profile->{preferences}{font_size} // "متوسط") . "\n";
        $status .= "  • تأثيرات: " . ($profile->{preferences}{effects} ? "مفعلة" : "معطلة") . "\n";
        $status .= "  • سرعة الكتابة: " . ($profile->{preferences}{typing_speed} // "عادية") . "\n";
    }
    
    $status .= "\n" . "=" x 60 . "\n";
    
    return $status;
}

# ============================================
# 🔧 دوال مساعدة داخلية
# ============================================

sub _extract_typing_signature {
    my $signature = {
        avg_flight_time => 0,
        avg_dwell_time => 0,
        flight_time_variance => 0,
        dwell_time_variance => 0,
        key_frequency => {},
        key_pairs => {},
        rhythm_pattern => []
    };
    
    my $total_flight = 0;
    my $total_dwell = 0;
    my $flight_count = 0;
    my $dwell_count = 0;
    my @flight_times = ();
    my @dwell_times = ();
    
    foreach my $keystroke (@$TYPING_BUFFER) {
        if ($keystroke->{flight_time} > 0) {
            $total_flight += $keystroke->{flight_time};
            push @flight_times, $keystroke->{flight_time};
            $flight_count++;
        }
        
        if ($keystroke->{dwell_time} > 0) {
            $total_dwell += $keystroke->{dwell_time};
            push @dwell_times, $keystroke->{dwell_time};
            $dwell_count++;
        }
        
        # تردد المفاتيح
        my $char = $keystroke->{char};
        $signature->{key_frequency}{$char}++;
        
        # أزواج المفاتيح (للتعرف على أنماط الكتابة)
        if ($keystroke->{char} ne "\n" && @$TYPING_BUFFER > 1) {
            my $prev_char = $TYPING_BUFFER->[-2]{char};
            my $pair = "$prev_char$char";
            $signature->{key_pairs}{$pair}++;
        }
    }
    
    if ($flight_count > 0) {
        $signature->{avg_flight_time} = $total_flight / $flight_count;
        $signature->{flight_time_variance} = _calculate_variance(\@flight_times, $signature->{avg_flight_time});
    }
    
    if ($dwell_count > 0) {
        $signature->{avg_dwell_time} = $total_dwell / $dwell_count;
        $signature->{dwell_time_variance} = _calculate_variance(\@dwell_times, $signature->{avg_dwell_time});
    }
    
    # نمط الإيقاع
    for (my $i = 0; $i < @flight_times && $i < 20; $i++) {
        push @{$signature->{rhythm_pattern}}, $flight_times[$i];
    }
    
    return $signature;
}

sub _calculate_variance {
    my ($values, $mean) = @_;
    
    my $variance = 0;
    foreach my $value (@$values) {
        $variance += ($value - $mean) ** 2;
    }
    
    return @$values > 0 ? $variance / @$values : 0;
}

sub _compare_signatures {
    my ($sig1, $sig2) = @_;
    
    my $score = 0;
    my $total_weight = 0;
    
    # مقارنة متوسط زمن الطيران
    if ($sig1->{avg_flight_time} > 0 && $sig2->{avg_flight_time} > 0) {
        my $diff = abs($sig1->{avg_flight_time} - $sig2->{avg_flight_time});
        my $similarity = 1 / (1 + $diff / 10);
        $score += $similarity * 0.3;
        $total_weight += 0.3;
    }
    
    # مقارنة متوسط زمن الضغط
    if ($sig1->{avg_dwell_time} > 0 && $sig2->{avg_dwell_time} > 0) {
        my $diff = abs($sig1->{avg_dwell_time} - $sig2->{avg_dwell_time});
        my $similarity = 1 / (1 + $diff / 5);
        $score += $similarity * 0.2;
        $total_weight += 0.2;
    }
    
    # مقارنة تردد المفاتيح
    my $key_similarity = _compare_hashmaps($sig1->{key_frequency}, $sig2->{key_frequency});
    $score += $key_similarity * 0.25;
    $total_weight += 0.25;
    
    # مقارنة أزواج المفاتيح
    my $pair_similarity = _compare_hashmaps($sig1->{key_pairs}, $sig2->{key_pairs});
    $score += $pair_similarity * 0.25;
    $total_weight += 0.25;
    
    return $total_weight > 0 ? $score / $total_weight : 0;
}

sub _compare_hashmaps {
    my ($map1, $map2) = @_;
    
    my $common_keys = 0;
    my $total_keys = 0;
    
    foreach my $key (keys %$map1) {
        if (exists $map2->{$key}) {
            $common_keys++;
        }
        $total_keys++;
    }
    
    foreach my $key (keys %$map2) {
        unless (exists $map1->{$key}) {
            $total_keys++;
        }
    }
    
    return $total_keys > 0 ? $common_keys / $total_keys : 0;
}

sub _merge_signatures {
    my ($sig1, $sig2) = @_;
    
    my $merged = {
        avg_flight_time => ($sig1->{avg_flight_time} + $sig2->{avg_flight_time}) / 2,
        avg_dwell_time => ($sig1->{avg_dwell_time} + $sig2->{avg_dwell_time}) / 2,
        flight_time_variance => ($sig1->{flight_time_variance} + $sig2->{flight_time_variance}) / 2,
        dwell_time_variance => ($sig1->{dwell_time_variance} + $sig2->{dwell_time_variance}) / 2,
        key_frequency => _merge_hashmaps($sig1->{key_frequency}, $sig2->{key_frequency}),
        key_pairs => _merge_hashmaps($sig1->{key_pairs}, $sig2->{key_pairs}),
        rhythm_pattern => $sig1->{rhythm_pattern}
    };
    
    return $merged;
}

sub _merge_hashmaps {
    my ($map1, $map2) = @_;
    
    my $merged = {};
    
    foreach my $key (keys %$map1) {
        $merged->{$key} = $map1->{$key};
    }
    
    foreach my $key (keys %$map2) {
        $merged->{$key} += $map2->{$key};
    }
    
    return $merged;
}

sub _merge_preferences {
    my ($old, $new) = @_;
    
    my $merged = {};
    
    foreach my $key (keys %$old) {
        $merged->{$key} = $old->{$key};
    }
    
    foreach my $key (keys %$new) {
        $merged->{$key} = $new->{$key};
    }
    
    return $merged;
}

sub _default_preferences {
    return {
        skin => "hacker",
        font_size => "medium",
        effects => 1,
        typing_speed => "normal",
        color_scheme => "dark",
        sound_enabled => 0,
        animation_speed => "normal"
    };
}

sub _save_profiles {
    eval {
        use JSON;
        my $json = JSON->new->pretty;
        my $json_text = $json->encode($USER_PROFILES);
        
        open(my $fh, '>', $PROFILES_FILE);
        print $fh $json_text;
        close($fh);
        
        log_message("INFO", "TerminalBiometrics", "تم حفظ " . scalar(keys %$USER_PROFILES) . " ملف شخصي");
    };
}

# ============================================
# انتهى الملف
# ============================================
1;
