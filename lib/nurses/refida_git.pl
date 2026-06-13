#!/usr/bin/perl
# ============================================
# Fool's Bind AI - الممرضة المتخصصة في Git (Refida Git)
# ============================================
# الوظيفة: استنساخ وإصلاح مستودعات Git
# ============================================

package refida_git;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path cwd);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message run_command retry_command check_internet);

our @EXPORT = qw(heal);

# ============================================
# 📦 الدالة الرئيسية للإصلاح
# ============================================

sub heal {
    my ($task, $params) = @_;
    
    log_message("INFO", "refida_git", "بدء مهمة Git: $task");
    
    # التحقق من وجود Git أولاً
    my $git_version = _check_git();
    unless ($git_version) {
        log_message("WARNING", "refida_git", "Git غير مثبت، جاري التثبيت...");
        my $install_result = _install_git();
        return ("ERROR", "فشل تثبيت Git") unless $install_result;
        $git_version = _check_git();
    }
    
    log_message("INFO", "refida_git", "Git مثبت: $git_version");
    
    # تنفيذ المهمة المطلوبة
    if ($task eq "self_check") {
        return _self_check();
    }
    elsif ($task eq "clone") {
        my $url = $params->{url} // return ("ERROR", "لم يتم تحديد URL المستودع");
        my $target = $params->{target} // cwd();
        return _clone_repo($url, $target);
    }
    elsif ($task eq "pull") {
        my $path = $params->{path} // cwd();
        return _pull_repo($path);
    }
    elsif ($task eq "fetch") {
        my $path = $params->{path} // cwd();
        return _fetch_repo($path);
    }
    elsif ($task eq "status") {
        my $path = $params->{path} // cwd();
        return _status_repo($path);
    }
    elsif ($task eq "checkout") {
        my $path = $params->{path} // cwd();
        my $branch = $params->{branch} // return ("ERROR", "لم يتم تحديد الفرع");
        return _checkout_branch($path, $branch);
    }
    elsif ($task eq "get_latest_tag") {
        my $url = $params->{url} // return ("ERROR", "لم يتم تحديد URL المستودع");
        return _get_latest_tag($url);
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
    
    # فحص Git
    my $git_version = _check_git();
    if ($git_version) {
        $details .= "Git: ✅ $git_version\n";
    } else {
        $status = "WARNING";
        $details .= "Git: ❌ غير مثبت\n";
    }
    
    # فحص إعدادات Git
    my $git_config = `git config --global user.name 2>/dev/null`;
    if ($git_config) {
        $details .= "Git user.name: ✅ " . chomp($git_config) . "\n";
    } else {
        $details .= "Git user.name: ⚠️ غير مضبوط (اختياري)\n";
    }
    
    my $git_email = `git config --global user.email 2>/dev/null`;
    if ($git_email) {
        $details .= "Git user.email: ✅ " . chomp($git_email) . "\n";
    } else {
        $details .= "Git user.email: ⚠️ غير مضبوط (اختياري)\n";
    }
    
    log_message("INFO", "refida_git", "الفحص الذاتي: $status");
    return ($status, $details);
}

# ============================================
# 🔍 دوال فحص Git
# ============================================

sub _check_git {
    my $output = `git --version 2>&1`;
    if ($? == 0 && $output =~ /git version ([\d\.]+)/) {
        return $1;
    }
    return undef;
}

# ============================================
# 📦 تثبيت Git
# ============================================

sub _install_git {
    log_message("INFO", "refida_git", "محاولة تثبيت Git...");
    
    # التحقق من الإنترنت
    unless (check_internet()) {
        log_message("ERROR", "refida_git", "لا يوجد إنترنت لتثبيت Git");
        return 0;
    }
    
    # محاولة التثبيت عبر pkg (Termux)
    my ($output, $success) = retry_command("pkg install git -y", 3, 30);
    
    if ($success) {
        log_message("SUCCESS", "refida_git", "تم تثبيت Git بنجاح");
        return 1;
    }
    
    # محاولة بديلة عبر apt
    ($output, $success) = retry_command("apt install git -y", 2, 30);
    
    if ($success) {
        log_message("SUCCESS", "refida_git", "تم تثبيت Git عبر apt");
        return 1;
    }
    
    log_message("ERROR", "refida_git", "فشل تثبيت Git");
    return 0;
}

# ============================================
# 📥 استنساخ مستودع
# ============================================

sub _clone_repo {
    my ($url, $target) = @_;
    
    log_message("INFO", "refida_git", "استنساخ مستودع: $url إلى $target");
    
    # التحقق من صحة URL
    if ($url !~ /^https?:\/\// && $url !~ /^git@/) {
        return ("ERROR", "URL المستودع غير صالح: $url");
    }
    
    # التحقق من الإنترنت
    unless (check_internet()) {
        return ("ERROR", "لا يوجد إنترنت لاستنساخ المستودع");
    }
    
    # استنساخ بعمق ضحل (shallow clone) لتوفير الوقت والمساحة
    my $clone_cmd = "git clone --depth 1 '$url' '$target' 2>&1";
    my ($output, $success) = retry_command($clone_cmd, 2, 5, 120);
    
    if ($success) {
        log_message("SUCCESS", "refida_git", "تم استنساخ المستودع بنجاح");
        return ("SUCCESS", "تم استنساخ المستودع إلى $target");
    }
    
    # محاولة بدون --depth 1 إذا فشلت الأولى
    log_message("WARNING", "refida_git", "فشل الاستنساخ الضحل، محاولة استنساخ كامل...");
    $clone_cmd = "git clone '$url' '$target' 2>&1";
    ($output, $success) = retry_command($clone_cmd, 2, 5, 180);
    
    if ($success) {
        log_message("SUCCESS", "refida_git", "تم استنساخ المستودع بنجاح (كامل)");
        return ("SUCCESS", "تم استنساخ المستودع إلى $target");
    }
    
    log_message("ERROR", "refida_git", "فشل استنساخ المستودع: $output");
    return ("ERROR", "فشل استنساخ المستودع: $output");
}

# ============================================
# 🔄 سحب آخر التحديثات
# ============================================

sub _pull_repo {
    my ($path) = @_;
    
    log_message("INFO", "refida_git", "سحب التحديثات من: $path");
    
    # التحقق من وجود المجلد
    unless (-d $path) {
        return ("ERROR", "المجلد غير موجود: $path");
    }
    
    # التحقق من وجود مجلد .git
    unless (-d "$path/.git") {
        return ("ERROR", "ليس مستودع Git صالح: $path");
    }
    
    my $current_dir = cwd();
    chdir($path);
    
    my ($output, $success) = retry_command("git pull 2>&1", 2, 5, 60);
    
    chdir($current_dir);
    
    if ($success) {
        log_message("SUCCESS", "refida_git", "تم سحب التحديثات بنجاح");
        return ("SUCCESS", "تم سحب التحديثات من $path");
    }
    
    log_message("ERROR", "refida_git", "فشل سحب التحديثات: $output");
    return ("ERROR", "فشل سحب التحديثات: $output");
}

# ============================================
# 📡 جلب التحديثات (بدون دمج)
# ============================================

sub _fetch_repo {
    my ($path) = @_;
    
    log_message("INFO", "refida_git", "جلب التحديثات من: $path");
    
    unless (-d $path) {
        return ("ERROR", "المجلد غير موجود: $path");
    }
    
    unless (-d "$path/.git") {
        return ("ERROR", "ليس مستودع Git صالح: $path");
    }
    
    my $current_dir = cwd();
    chdir($path);
    
    my ($output, $success) = run_command("git fetch --all 2>&1", 60);
    
    chdir($current_dir);
    
    if ($success) {
        log_message("SUCCESS", "refida_git", "تم جلب التحديثات بنجاح");
        return ("SUCCESS", "تم جلب التحديثات من $path");
    }
    
    return ("WARNING", "فشل جلب التحديثات: $output");
}

# ============================================
# 📊 حالة المستودع
# ============================================

sub _status_repo {
    my ($path) = @_;
    
    unless (-d $path) {
        return ("ERROR", "المجلد غير موجود: $path");
    }
    
    unless (-d "$path/.git") {
        return ("ERROR", "ليس مستودع Git صالح: $path");
    }
    
    my $current_dir = cwd();
    chdir($path);
    
    my $status_output = `git status --short 2>&1`;
    my $branch_output = `git branch --show-current 2>&1`;
    my $remote_output = `git remote -v 2>&1`;
    
    chdir($current_dir);
    
    chomp($status_output);
    chomp($branch_output);
    chomp($remote_output);
    
    my $report = "";
    $report .= "المستودع: $path\n";
    $report .= "الفرع الحالي: $branch_output\n";
    $report .= "الريموت: " . (split(/\n/, $remote_output))[0] . "\n";
    
    if ($status_output) {
        $report .= "التغييرات:\n$status_output\n";
    } else {
        $report .= "الحالة: نظيف (لا توجد تغييرات)\n";
    }
    
    return ("SUCCESS", $report);
}

# ============================================
# 🌿 تبديل الفرع
# ============================================

sub _checkout_branch {
    my ($path, $branch) = @_;
    
    log_message("INFO", "refida_git", "تبديل الفرع إلى: $branch في $path");
    
    unless (-d $path) {
        return ("ERROR", "المجلد غير موجود: $path");
    }
    
    unless (-d "$path/.git") {
        return ("ERROR", "ليس مستودع Git صالح: $path");
    }
    
    my $current_dir = cwd();
    chdir($path);
    
    # جلب آخر التحديثات أولاً
    run_command("git fetch origin $branch 2>&1", 30);
    
    my ($output, $success) = run_command("git checkout $branch 2>&1", 30);
    
    chdir($current_dir);
    
    if ($success) {
        log_message("SUCCESS", "refida_git", "تم التبديل إلى الفرع $branch");
        return ("SUCCESS", "تم التبديل إلى الفرع $branch");
    }
    
    # محاولة إنشاء فرع جديد من الریموت
    log_message("WARNING", "refida_git", "محاولة إنشاء فرع متتبع لـ $branch");
    chdir($path);
    ($output, $success) = run_command("git checkout -b $branch origin/$branch 2>&1", 30);
    chdir($current_dir);
    
    if ($success) {
        log_message("SUCCESS", "refida_git", "تم إنشاء وتتبع الفرع $branch");
        return ("SUCCESS", "تم إنشاء وتتبع الفرع $branch");
    }
    
    log_message("ERROR", "refida_git", "فشل التبديل إلى الفرع $branch");
    return ("ERROR", "فشل التبديل إلى الفرع $branch: $output");
}

# ============================================
# 🏷️ الحصول على آخر إصدار (latest tag)
# ============================================

sub _get_latest_tag {
    my ($url) = @_;
    
    log_message("INFO", "refida_git", "الحصول على آخر إصدار من: $url");
    
    unless (check_internet()) {
        return ("ERROR", "لا يوجد إنترنت للحصول على آخر إصدار");
    }
    
    # استنساخ ضحل للحصول على العلامات فقط
    my $temp_dir = "/data/data/com.termux/files/home/fools-bind-ai/tmp/git_tag_$$";
    system("mkdir -p '$temp_dir' 2>/dev/null");
    
    my $clone_cmd = "git clone --depth 1 --tags '$url' '$temp_dir' 2>&1";
    my ($output, $success) = run_command($clone_cmd, 60);
    
    if (!$success) {
        system("rm -rf '$temp_dir' 2>/dev/null");
        return ("ERROR", "فشل استنساخ المستودع للحصول على الإصدارات");
    }
    
    my $current_dir = cwd();
    chdir($temp_dir);
    
    my $tag = `git describe --tags --abbrev=0 2>/dev/null`;
    chomp($tag);
    
    chdir($current_dir);
    system("rm -rf '$temp_dir' 2>/dev/null");
    
    if ($tag) {
        log_message("SUCCESS", "refida_git", "آخر إصدار: $tag");
        return ("SUCCESS", $tag);
    }
    
    return ("WARNING", "لا توجد إصدارات (tags) في هذا المستودع");
}

# ============================================
# انتهى الملف
# ============================================
1;
