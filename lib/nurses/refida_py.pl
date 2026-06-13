#!/usr/bin/perl
# ============================================
# Fool's Bind AI - الممرضة المتخصصة في Python (Refida Py)
# ============================================
# الوظيفة: تثبيت وإصلاح مكتبات وأدوات Python
# ============================================

package refida_py;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message run_command retry_command check_internet);

our @EXPORT = qw(heal);

# ============================================
# 🐍 الدالة الرئيسية للإصلاح
# ============================================

sub heal {
    my ($task, $params) = @_;
    
    log_message("INFO", "refida_py", "بدء مهمة Python: $task");
    
    # التحقق من وجود Python
    my $python_version = _check_python();
    unless ($python_version) {
        log_message("WARNING", "refida_py", "Python غير مثبت، جاري التثبيت...");
        my $install_result = _install_python();
        return ("ERROR", "فشل تثبيت Python") unless $install_result;
        $python_version = _check_python();
    }
    
    log_message("INFO", "refida_py", "Python مثبت: $python_version");
    
    # تنفيذ المهمة المطلوبة
    if ($task eq "self_check") {
        return _self_check();
    } 
    elsif ($task eq "install_package") {
        my $package = $params->{package} // return ("ERROR", "لم يتم تحديد الحزمة");
        return _install_package($package);
    }
    elsif ($task eq "install_requirements") {
        my $requirements_file = $params->{file} // return ("ERROR", "لم يتم تحديد ملف requirements");
        return _install_requirements($requirements_file);
    }
    elsif ($task eq "check_package") {
        my $package = $params->{package} // return ("ERROR", "لم يتم تحديد الحزمة");
        return _check_package($package);
    }
    elsif ($task eq "upgrade_pip") {
        return _upgrade_pip();
    }
    elsif ($task eq "fix_venv") {
        return _fix_venv();
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
    
    # فحص Python
    my $python = _check_python();
    if ($python) {
        $details .= "Python: ✅ $python\n";
    } else {
        $status = "WARNING";
        $details .= "Python: ❌ غير مثبت\n";
    }
    
    # فحص pip
    my $pip = _check_pip();
    if ($pip) {
        $details .= "pip: ✅ $pip\n";
    } else {
        $status = "WARNING";
        $details .= "pip: ❌ غير مثبت\n";
    }
    
    # فحص الحزم الأساسية
    my @core_packages = qw(setuptools wheel virtualenv);
    my $missing = [];
    
    foreach my $pkg (@core_packages) {
        unless (_check_package($pkg)) {
            push @$missing, $pkg;
        }
    }
    
    if (@$missing) {
        $status = "WARNING";
        $details .= "الحزم الناقصة: " . join(", ", @$missing) . "\n";
    } else {
        $details .= "الحزم الأساسية: ✅ جميعها مثبتة\n";
    }
    
    log_message("INFO", "refida_py", "الفحص الذاتي: $status");
    return ($status, $details);
}

# ============================================
# 🐍 دوال فحص Python
# ============================================

sub _check_python {
    my $output = `python3 --version 2>&1`;
    if ($? == 0 && $output =~ /Python\s+(\d+\.\d+\.\d+)/) {
        return $1;
    }
    
    $output = `python --version 2>&1`;
    if ($? == 0 && $output =~ /Python\s+(\d+\.\d+\.\d+)/) {
        return $1;
    }
    
    return undef;
}

sub _check_pip {
    my $output = `pip3 --version 2>&1`;
    if ($? == 0 && $output =~ /pip\s+(\d+\.\d+\.\d+)/) {
        return $1;
    }
    
    $output = `pip --version 2>&1`;
    if ($? == 0 && $output =~ /pip\s+(\d+\.\d+\.\d+)/) {
        return $1;
    }
    
    return undef;
}

# ============================================
# 📦 تثبيت Python
# ============================================

sub _install_python {
    log_message("INFO", "refida_py", "محاولة تثبيت Python...");
    
    # محاولة التثبيت عبر pkg (Termux)
    my ($output, $success) = retry_command("pkg install python -y", 3, 5);
    
    if ($success) {
        log_message("SUCCESS", "refida_py", "تم تثبيت Python بنجاح");
        return 1;
    }
    
    # محاولة بديلة عبر apt
    ($output, $success) = retry_command("apt install python -y", 2, 5);
    
    if ($success) {
        log_message("SUCCESS", "refida_py", "تم تثبيت Python عبر apt");
        return 1;
    }
    
    log_message("ERROR", "refida_py", "فشل تثبيت Python");
    return 0;
}

# ============================================
# 📦 تثبيت حزمة Python
# ============================================

sub _install_package {
    my ($package) = @_;
    
    log_message("INFO", "refida_py", "محاولة تثبيت حزمة: $package");
    
    # التحقق من الإنترنت
    unless (check_internet()) {
        return ("ERROR", "لا يوجد إنترنت لتثبيت الحزمة $package");
    }
    
    # الترقية المسبقة لـ pip
    _upgrade_pip();
    
    # محاولة التثبيت عبر pip3
    my ($output, $success) = retry_command("pip3 install $package -q", 3, 10);
    
    if ($success) {
        log_message("SUCCESS", "refida_py", "تم تثبيت الحزمة $package بنجاح");
        
        # التحقق من التثبيت
        if (_check_package($package)) {
            return ("SUCCESS", "تم تثبيت الحزمة $package وتأكيدها");
        }
        return ("SUCCESS", "تم تثبيت الحزمة $package");
    }
    
    # محاولة بديلة عبر pip
    ($output, $success) = retry_command("pip install $package -q", 2, 10);
    
    if ($success) {
        log_message("SUCCESS", "refida_py", "تم تثبيت الحزمة $package عبر pip");
        return ("SUCCESS", "تم تثبيت الحزمة $package");
    }
    
    log_message("ERROR", "refida_py", "فشل تثبيت الحزمة $package");
    return ("ERROR", "فشل تثبيت الحزمة $package: $output");
}

# ============================================
# 📄 تثبيت متطلبات من ملف
# ============================================

sub _install_requirements {
    my ($file) = @_;
    
    unless (-f $file) {
        return ("ERROR", "الملف غير موجود: $file");
    }
    
    log_message("INFO", "refida_py", "تثبيت المتطلبات من: $file");
    
    unless (check_internet()) {
        return ("ERROR", "لا يوجد إنترنت لتثبيت المتطلبات");
    }
    
    my ($output, $success) = retry_command("pip3 install -r $file -q", 3, 30);
    
    if ($success) {
        log_message("SUCCESS", "refida_py", "تم تثبيت جميع المتطلبات");
        return ("SUCCESS", "تم تثبيت جميع المتطلبات من $file");
    }
    
    log_message("ERROR", "refida_py", "فشل تثبيت المتطلبات");
    return ("ERROR", "فشل تثبيت المتطلبات: $output");
}

# ============================================
# 🔍 فحص وجود حزمة
# ============================================

sub _check_package {
    my ($package) = @_;
    
    my $check = `pip3 show $package 2>/dev/null | grep -c "Name"`;
    if ($check =~ /1/) {
        return 1;
    }
    
    $check = `pip show $package 2>/dev/null | grep -c "Name"`;
    if ($check =~ /1/) {
        return 1;
    }
    
    # محاولة import بسيطة
    my $import_check = `python3 -c "import $package" 2>&1`;
    return 1 if $? == 0;
    
    return 0;
}

# ============================================
# ⬆️ ترقية pip
# ============================================

sub _upgrade_pip {
    log_message("INFO", "refida_py", "ترقية pip...");
    
    unless (check_internet()) {
        log_message("WARNING", "refida_py", "لا يوجد إنترنت لترقية pip");
        return 0;
    }
    
    my ($output, $success) = run_command("pip3 install --upgrade pip -q", 30);
    
    if ($success) {
        log_message("SUCCESS", "refida_py", "تم ترقية pip");
        return 1;
    }
    
    log_message("WARNING", "refida_py", "فشل ترقية pip");
    return 0;
}

# ============================================
# 🔧 إصلاح البيئة الافتراضية
# ============================================

sub _fix_venv {
    log_message("INFO", "refida_py", "فحص وإصلاح البيئة الافتراضية...");
    
    my $venv_path = $ENV{VIRTUAL_ENV} // "";
    
    if ($venv_path && -d $venv_path) {
        log_message("INFO", "refida_py", "البيئة الافتراضية موجودة: $venv_path");
        
        # فحص صلاحيات البيئة الافتراضية
        my $fix_cmd = "chmod -R u+rwx '$venv_path/bin' 2>/dev/null";
        run_command($fix_cmd, 10);
        
        return ("SUCCESS", "تم إصلاح البيئة الافتراضية: $venv_path");
    }
    
    return ("SUCCESS", "لا توجد بيئة افتراضية نشطة");
}

# ============================================
# انتهى الملف
# ============================================
1;
