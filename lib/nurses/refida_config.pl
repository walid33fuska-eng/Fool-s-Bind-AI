#!/usr/bin/perl
# ============================================
# Fool's Bind AI - الممرضة المتخصصة في الإعدادات (Refida Config)
# ============================================
# الوظيفة: إصلاح وإعادة إنشاء ملفات الإعدادات التالفة
# ============================================

package refida_config;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);
use File::Copy;

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message run_command get_os_type detect_termux_path);

our @EXPORT = qw(heal);

# ============================================
# 📁 الدالة الرئيسية للإصلاح
# ============================================

sub heal {
    my ($task, $params) = @_;
    
    log_message("INFO", "refida_config", "بدء مهمة Config: $task");
    
    if ($task eq "self_check") {
        return _self_check();
    }
    elsif ($task eq "fix_bashrc") {
        return _fix_bashrc();
    }
    elsif ($task eq "fix_profile") {
        return _fix_profile();
    }
    elsif ($task eq "fix_path") {
        return _fix_path();
    }
    elsif ($task eq "fix_sources_list") {
        return _fix_sources_list();
    }
    elsif ($task eq "restore_defaults") {
        return _restore_defaults();
    }
    elsif ($task eq "backup_configs") {
        return _backup_configs();
    }
    else {
        return ("ERROR", "مهمة غير معروفة: $task");
    }
}

# ============================================
# 🔍 الفحص الذاتي
# ============================================

sub _self_check {
    my $status = "SUCCESS";
    my $details = "";
    
    my $home = $ENV{HOME} // "/data/data/com.termux/files/home";
    my $termux_path = detect_termux_path();
    
    # فحص ملفات الإعدادات الأساسية
    my @config_files = (
        "$home/.bashrc",
        "$home/.profile",
        "$home/.bash_profile",
        "$termux_path/etc/apt/sources.list",
        "$termux_path/etc/bash.bashrc"
    );
    
    foreach my $file (@config_files) {
        if (-f $file) {
            $details .= basename($file) . ": ✅ موجود\n";
        } else {
            $details .= basename($file) . ": ⚠️ غير موجود\n";
            $status = "WARNING";
        }
    }
    
    # فحص متغير PATH
    my $path = $ENV{PATH};
    my $has_termux_bin = ($path =~ /$termux_path\/bin/) ? "✅" : "❌";
    $details .= "PATH contains termux/bin: $has_termux_bin\n";
    $status = "WARNING" if $has_termux_bin eq "❌";
    
    log_message("INFO", "refida_config", "الفحص الذاتي: $status");
    return ($status, $details);
}

# ============================================
# 🔧 إصلاح ملف .bashrc
# ============================================

sub _fix_bashrc {
    log_message("INFO", "refida_config", "إصلاح ملف .bashrc");
    
    my $home = $ENV{HOME} // "/data/data/com.termux/files/home";
    my $bashrc_path = "$home/.bashrc";
    my $backup_path = "$bashrc_path.bak." . time();
    
    # إنشاء نسخة احتياطية
    if (-f $bashrc_path) {
        copy($bashrc_path, $backup_path);
        log_message("INFO", "refida_config", "تم إنشاء نسخة احتياطية: $backup_path");
    }
    
    # إنشاء ملف .bashrc جديد صحيح
    my $new_bashrc = _generate_bashrc();
    
    if (open(my $fh, '>', $bashrc_path)) {
        print $fh $new_bashrc;
        close($fh);
        log_message("SUCCESS", "refida_config", "تم إصلاح ملف .bashrc");
        return ("SUCCESS", "تم إصلاح ملف .bashrc. نسخة احتياطية: $backup_path");
    }
    
    log_message("ERROR", "refida_config", "فشل في كتابة ملف .bashrc");
    return ("ERROR", "فشل في إصلاح ملف .bashrc");
}

# ============================================
# 🔧 إصلاح ملف .profile
# ============================================

sub _fix_profile {
    log_message("INFO", "refida_config", "إصلاح ملف .profile");
    
    my $home = $ENV{HOME} // "/data/data/com.termux/files/home";
    my $profile_path = "$home/.profile";
    my $backup_path = "$profile_path.bak." . time();
    
    if (-f $profile_path) {
        copy($profile_path, $backup_path);
    }
    
    my $new_profile = _generate_profile();
    
    if (open(my $fh, '>', $profile_path)) {
        print $fh $new_profile;
        close($fh);
        log_message("SUCCESS", "refida_config", "تم إصلاح ملف .profile");
        return ("SUCCESS", "تم إصلاح ملف .profile");
    }
    
    return ("ERROR", "فشل في إصلاح ملف .profile");
}

# ============================================
# 🔧 إصلاح متغير PATH
# ============================================

sub _fix_path {
    log_message("INFO", "refida_config", "إصلاح متغير PATH");
    
    my $termux_path = detect_termux_path();
    my $current_path = $ENV{PATH};
    
    # إصلاح PATH في .bashrc
    my $home = $ENV{HOME} // "/data/data/com.termux/files/home";
    my $bashrc_path = "$home/.bashrc";
    
    # إضافة PATH صحيح إذا لم يكن موجوداً
    my $correct_path_export = "export PATH=$termux_path/bin:/usr/local/bin:/usr/bin:/bin:\$HOME/bin\n";
    
    if (-f $bashrc_path) {
        my $content = Utils::safe_read_file($bashrc_path);
        
        # إزالة أي export PATH قديم
        $content =~ s/^export PATH=.*$//gm;
        
        # إضافة الـ PATH الجديد في البداية
        $content = $correct_path_export . $content;
        
        if (Utils::safe_write_file($bashrc_path, $content)) {
            log_message("SUCCESS", "refida_config", "تم إصلاح PATH في .bashrc");
        }
    } else {
        # إنشاء ملف .bashrc جديد
        _fix_bashrc();
    }
    
    # تحديث PATH للجلسة الحالية
    $ENV{PATH} = "$termux_path/bin:/usr/local/bin:/usr/bin:/bin:$ENV{HOME}/bin";
    
    return ("SUCCESS", "تم إصلاح متغير PATH. أعد تشغيل Termux أو افتح نافذة جديدة لتفعيل التغييرات");
}

# ============================================
# 🔧 إصلاح مصادر المستودعات
# ============================================

sub _fix_sources_list {
    log_message("INFO", "refida_config", "إصلاح ملف sources.list");
    
    my $termux_path = detect_termux_path();
    my $sources_file = "$termux_path/etc/apt/sources.list";
    my $backup_path = "$sources_file.bak." . time();
    
    if (-f $sources_file) {
        copy($sources_file, $backup_path);
    }
    
    my $os = get_os_type();
    my $new_sources = "";
    
    if ($os eq "Android") {
        $new_sources = _generate_termux_sources();
    } elsif ($os eq "iOS") {
        $new_sources = _generate_ios_sources();
    } else {
        $new_sources = _generate_generic_sources();
    }
    
    if (open(my $fh, '>', $sources_file)) {
        print $fh $new_sources;
        close($fh);
        log_message("SUCCESS", "refida_config", "تم إصلاح ملف sources.list");
        return ("SUCCESS", "تم إصلاح ملف sources.list");
    }
    
    return ("ERROR", "فشل في إصلاح ملف sources.list");
}

# ============================================
# 📄 إنشاء محتوى .bashrc
# ============================================

sub _generate_bashrc {
    my $bashrc = <<'EOF';
# ============================================
# Fool's Bind AI - .bashrc (تم إصلاحه تلقائياً)
# ============================================

# متغيرات PATH الأساسية
export PREFIX="/data/data/com.termux/files/usr"
export HOME="/data/data/com.termux/files/home"
export PATH="$PREFIX/bin:/usr/local/bin:/usr/bin:/bin:$HOME/bin"

# إعدادات Termux الأساسية
if [ -f "$PREFIX/etc/profile" ]; then
    . "$PREFIX/etc/profile"
fi

# الألوان في المخرجات
export PS1='\[\033[1;32m\]\u@\h\[\033[00m\]:\[\033[1;34m\]\w\[\033[00m\]\$ '

# الأوامر المختصرة (Aliases)
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'

# تحميل إضافات Termux-API إذا كانت موجودة
if [ -d "$HOME/.termux" ]; then
    for script in "$HOME/.termux/"*.sh; do
        if [ -f "$script" ]; then
            . "$script"
        fi
    done
fi

# دالة ترحيب بسيطة
echo "🩺 Fool's Bind AI - Termux جاهز"
EOF
    
    return $bashrc;
}

# ============================================
# 📄 إنشاء محتوى .profile
# ============================================

sub _generate_profile {
    my $profile = <<'EOF';
# ============================================
# Fool's Bind AI - .profile (تم إصلاحه تلقائياً)
# ============================================

# تحميل .bashrc إذا كان موجوداً
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi

# إعدادات اللغة
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# إعدادات محرر النصوص الافتراضي
export EDITOR="nano"
export VISUAL="nano"

# إعدادات Git (إذا لم تكن مضبوطة)
if command -v git >/dev/null 2>&1; then
    if [ -z "$(git config --global user.name)" ]; then
        git config --global user.name "Fool's Bind AI User"
    fi
    if [ -z "$(git config --global user.email)" ]; then
        git config --global user.email "user@foolsbind.ai"
    fi
fi

echo "✅ Fool's Bind AI - البيئة جاهزة"
EOF
    
    return $profile;
}

# ============================================
# 📦 إنشاء مصادر Termux
# ============================================

sub _generate_termux_sources {
    my $sources = <<'EOF';
# ============================================
# Fool's Bind AI - Termux Sources (تم إصلاحه تلقائياً)
# ============================================

# مستودع Termux الرسمي (F-Droid)
deb https://packages.termux.org/apt/termux-main stable main

# مستودع Termux Root (للأجهزة المفتوحة الجذور - اختياري)
# deb https://packages.termux.org/apt/termux-root root stable
EOF
    
    return $sources;
}

# ============================================
# 📦 إنشاء مصادر iOS
# ============================================

sub _generate_ios_sources {
    my $sources = <<'EOF';
# ============================================
# Fool's Bind AI - iOS Termux Sources
# ============================================

# مستودع Termux الرسمي لـ iOS (يختلف عن Android)
deb https://packages.termux.org/apt/termux-main stable main
EOF
    
    return $sources;
}

# ============================================
# 📦 إنشاء مصادر عامة
# ============================================

sub _generate_generic_sources {
    my $sources = <<'EOF';
# ============================================
# Fool's Bind AI - Generic Linux Sources
# ============================================

# مستودعات Debian/Ubuntu الأساسية
deb http://deb.debian.org/debian stable main contrib non-free
deb http://deb.debian.org/debian stable-updates main contrib non-free
deb http://security.debian.org/debian-security stable-security main contrib non-free
EOF
    
    return $sources;
}

# ============================================
# 🔄 استعادة الإعدادات الافتراضية
# ============================================

sub _restore_defaults {
    log_message("INFO", "refida_config", "استعادة الإعدادات الافتراضية");
    
    my $result = "";
    my $success_count = 0;
    my $fail_count = 0;
    
    # إصلاح كل الملفات
    my ($status, $msg) = _fix_bashrc();
    if ($status eq "SUCCESS") {
        $success_count++;
        $result .= "✅ .bashrc\n";
    } else {
        $fail_count++;
        $result .= "❌ .bashrc: $msg\n";
    }
    
    ($status, $msg) = _fix_profile();
    if ($status eq "SUCCESS") {
        $success_count++;
        $result .= "✅ .profile\n";
    } else {
        $fail_count++;
        $result .= "❌ .profile: $msg\n";
    }
    
    ($status, $msg) = _fix_path();
    if ($status eq "SUCCESS") {
        $success_count++;
        $result .= "✅ PATH\n";
    } else {
        $fail_count++;
        $result .= "❌ PATH: $msg\n";
    }
    
    ($status, $msg) = _fix_sources_list();
    if ($status eq "SUCCESS") {
        $success_count++;
        $result .= "✅ sources.list\n";
    } else {
        $fail_count++;
        $result .= "❌ sources.list: $msg\n";
    }
    
    log_message("INFO", "refida_config", "تم استعادة $success_count إعداد، فشل $fail_count");
    return ("SUCCESS", "تم استعادة الإعدادات:\n$result");
}

# ============================================
# 💾 إنشاء نسخة احتياطية
# ============================================

sub _backup_configs {
    log_message("INFO", "refida_config", "إنشاء نسخة احتياطية للإعدادات");
    
    my $home = $ENV{HOME} // "/data/data/com.termux/files/home";
    my $backup_dir = "$home/fools-bind-ai-backup-" . time();
    
    system("mkdir -p '$backup_dir' 2>/dev/null");
    
    my @configs = (
        "$home/.bashrc",
        "$home/.profile",
        "$home/.bash_profile",
        "$home/.termux",
        detect_termux_path() . "/etc/apt/sources.list"
    );
    
    my $backup_count = 0;
    
    foreach my $config (@configs) {
        if (-e $config) {
            system("cp -r '$config' '$backup_dir/' 2>/dev/null");
            $backup_count++;
        }
    }
    
    log_message("SUCCESS", "refida_config", "تم نسخ $backup_count عنصر إلى $backup_dir");
    return ("SUCCESS", "تم إنشاء النسخة الاحتياطية في: $backup_dir");
}

# ============================================
# انتهى الملف
# ============================================
1;
