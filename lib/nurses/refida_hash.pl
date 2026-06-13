#!/usr/bin/perl
# ============================================
# Fool's Bind AI - الممرضة المتخصصة في التحقق من السلامة (Refida Hash)
# ============================================
# الوظيفة: التحقق من سلامة الملفات باستخدام Hashing (SHA256/MD5)
# ============================================

package refida_hash;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);
use Digest::SHA qw(sha256_hex sha256);
use Digest::MD5 qw(md5_hex);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message run_command);

our @EXPORT = qw(heal);

# ============================================
# 📁 الدالة الرئيسية للإصلاح
# ============================================

sub heal {
    my ($task, $params) = @_;
    
    log_message("INFO", "refida_hash", "بدء مهمة Hash: $task");
    
    if ($task eq "self_check") {
        return _self_check();
    }
    elsif ($task eq "calculate_hash") {
        my $file = $params->{file} // return ("ERROR", "لم يتم تحديد الملف");
        my $algo = $params->{algo} // "sha256";
        return _calculate_hash($file, $algo);
    }
    elsif ($task eq "verify_hash") {
        my $file = $params->{file} // return ("ERROR", "لم يتم تحديد الملف");
        my $expected_hash = $params->{expected_hash} // return ("ERROR", "لم يتم تحديد الهاش المتوقع");
        my $algo = $params->{algo} // "sha256";
        return _verify_hash($file, $expected_hash, $algo);
    }
    elsif ($task eq "generate_integrity_file") {
        my $directory = $params->{directory} // cwd();
        return _generate_integrity_file($directory);
    }
    elsif ($task eq "verify_integrity_file") {
        my $directory = $params->{directory} // cwd();
        my $integrity_file = $params->{integrity_file} // "$directory/config/integrity.sha256";
        return _verify_integrity_file($directory, $integrity_file);
    }
    elsif ($task eq "compare_files") {
        my $file1 = $params->{file1} // return ("ERROR", "لم يتم تحديد الملف الأول");
        my $file2 = $params->{file2} // return ("ERROR", "لم يتم تحديد الملف الثاني");
        return _compare_files($file1, $file2);
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
    
    # فحص وجود مكتبات التشفير
    eval {
        require Digest::SHA;
        $details .= "Digest::SHA: ✅ متاحة\n";
    };
    if ($@) {
        $status = "WARNING";
        $details .= "Digest::SHA: ❌ غير متاحة\n";
    }
    
    eval {
        require Digest::MD5;
        $details .= "Digest::MD5: ✅ متاحة\n";
    };
    if ($@) {
        $status = "WARNING";
        $details .= "Digest::MD5: ❌ غير متاحة\n";
    }
    
    # فحص وجود أوامر بديلة
    my $has_sha256sum = `which sha256sum 2>/dev/null` ? "✅" : "❌";
    $details .= "sha256sum: $has_sha256sum\n";
    
    my $has_md5sum = `which md5sum 2>/dev/null` ? "✅" : "❌";
    $details .= "md5sum: $has_md5sum\n";
    
    log_message("INFO", "refida_hash", "الفحص الذاتي: $status");
    return ($status, $details);
}

# ============================================
# 🔢 حساب هاش لملف
# ============================================

sub _calculate_hash {
    my ($file, $algo) = @_;
    
    unless (-f $file) {
        return ("ERROR", "الملف غير موجود: $file");
    }
    
    log_message("INFO", "refida_hash", "حساب هاش للملف: $file باستخدام $algo");
    
    my $hash = "";
    $algo = lc($algo);
    
    if ($algo eq "sha256") {
        # محاولة استخدام المكتبة أولاً
        eval {
            open(my $fh, '<', $file);
            binmode($fh);
            my $ctx = Digest::SHA->new(256);
            $ctx->addfile($fh);
            $hash = $ctx->hexdigest();
            close($fh);
        };
        
        # إذا فشلت المكتبة، نحاول استخدام الأمر
        if (!$hash && -x "/data/data/com.termux/files/usr/bin/sha256sum") {
            my $output = `sha256sum '$file' 2>/dev/null`;
            if ($output =~ /^([a-f0-9]{64})/) {
                $hash = $1;
            }
        }
        
        # بديل آخر: استخدام openssl
        if (!$hash) {
            my $output = `openssl sha256 '$file' 2>/dev/null`;
            if ($output =~ /= ([a-f0-9]{64})/) {
                $hash = $1;
            }
        }
    }
    elsif ($algo eq "md5") {
        eval {
            open(my $fh, '<', $file);
            binmode($fh);
            my $ctx = Digest::MD5->new();
            $ctx->addfile($fh);
            $hash = $ctx->hexdigest();
            close($fh);
        };
        
        if (!$hash) {
            my $output = `md5sum '$file' 2>/dev/null`;
            if ($output =~ /^([a-f0-9]{32})/) {
                $hash = $1;
            }
        }
        
        if (!$hash) {
            my $output = `openssl md5 '$file' 2>/dev/null`;
            if ($output =~ /= ([a-f0-9]{32})/) {
                $hash = $1;
            }
        }
    }
    else {
        return ("ERROR", "خوارزمية غير مدعومة: $algo (مدعوم: sha256, md5)");
    }
    
    if ($hash) {
        log_message("SUCCESS", "refida_hash", "تم حساب هاش $algo للملف $file");
        return ("SUCCESS", $hash);
    }
    
    log_message("ERROR", "refida_hash", "فشل حساب هاش للملف $file");
    return ("ERROR", "فشل حساب هاش للملف $file");
}

# ============================================
# ✅ التحقق من صحة هاش ملف
# ============================================

sub _verify_hash {
    my ($file, $expected_hash, $algo) = @_;
    
    log_message("INFO", "refida_hash", "التحقق من هاش $algo للملف: $file");
    
    unless (-f $file) {
        return ("ERROR", "الملف غير موجود: $file");
    }
    
    my ($status, $actual_hash) = _calculate_hash($file, $algo);
    
    if ($status ne "SUCCESS") {
        return ("ERROR", "فشل حساب هاش الملف: $actual_hash");
    }
    
    if ($actual_hash eq lc($expected_hash)) {
        log_message("SUCCESS", "refida_hash", "الملف $file سليم (هاش متطابق)");
        return ("SUCCESS", "✅ الملف سليم: الهاش متطابق");
    }
    
    log_message("WARNING", "refida_hash", "الملف $file تالف أو معدل (هاش غير متطابق)");
    return ("FAILED", "❌ الملف تالف أو معدل\n   المتوقع: $expected_hash\n   الموجود: $actual_hash");
}

# ============================================
# 📝 إنشاء ملف متكامل للتحقق من السلامة
# ============================================

sub _generate_integrity_file {
    my ($directory) = @_;
    
    unless (-d $directory) {
        return ("ERROR", "المجلد غير موجود: $directory");
    }
    
    log_message("INFO", "refida_hash", "إنشاء ملف تكامل للمجلد: $directory");
    
    my $integrity_file = "$directory/config/integrity.sha256";
    my $integrity_dir = dirname($integrity_file);
    system("mkdir -p '$integrity_dir' 2>/dev/null");
    
    # جمع كل ملفات Perl في المجلد
    my @files = ();
    my $find_cmd = "find '$directory' -type f \\( -name '*.pl' -o -name '*.sh' -o -name '*.conf' -o -name '*.json' \\) 2>/dev/null";
    my $files_list = `$find_cmd`;
    
    if ($files_list) {
        @files = split(/\n/, $files_list);
    }
    
    my $integrity_content = "";
    my $count = 0;
    
    foreach my $file (@files) {
        # تخطي ملف integrity نفسه
        next if $file eq $integrity_file;
        
        my ($status, $hash) = _calculate_hash($file, "sha256");
        if ($status eq "SUCCESS" && $hash) {
            # نستخدم المسار النسبي بدلاً من المطلق
            my $relative_path = $file;
            $relative_path =~ s/^\Q$directory\E\///;
            $integrity_content .= "$hash  $relative_path\n";
            $count++;
        }
    }
    
    if (open(my $fh, '>', $integrity_file)) {
        print $fh "# ============================================\n";
        print $fh "# Fool's Bind AI - Integrity File\n";
        print $fh "# تم إنشاؤه في: " . localtime(time) . "\n";
        print $fh "# ============================================\n\n";
        print $fh $integrity_content;
        close($fh);
        
        log_message("SUCCESS", "refida_hash", "تم إنشاء ملف التكامل: $integrity_file ($count ملف)");
        return ("SUCCESS", "تم إنشاء ملف التكامل: $integrity_file ($count ملف)");
    }
    
    log_message("ERROR", "refida_hash", "فشل إنشاء ملف التكامل");
    return ("ERROR", "فشل إنشاء ملف التكامل");
}

# ============================================
# 🔍 التحقق من التكامل باستخدام ملف integrity.sha256
# ============================================

sub _verify_integrity_file {
    my ($directory, $integrity_file) = @_;
    
    unless (-d $directory) {
        return ("ERROR", "المجلد غير موجود: $directory");
    }
    
    unless (-f $integrity_file) {
        return ("ERROR", "ملف التكامل غير موجود: $integrity_file");
    }
    
    log_message("INFO", "refida_hash", "التحقق من تكامل المجلد: $directory");
    
    my $failed = 0;
    my $passed = 0;
    my $missing = 0;
    my $report = "";
    
    open(my $fh, '<', $integrity_file) or return ("ERROR", "لا يمكن قراءة ملف التكامل");
    
    while (my $line = <$fh>) {
        chomp($line);
        next if $line =~ /^#/;
        next if $line =~ /^\s*$/;
        
        if ($line =~ /^([a-f0-9]{64})\s+(.+)$/) {
            my ($expected_hash, $relative_path) = ($1, $2);
            my $full_path = "$directory/$relative_path";
            
            if (-f $full_path) {
                my ($status, $actual_hash) = _calculate_hash($full_path, "sha256");
                if ($status eq "SUCCESS" && $actual_hash eq $expected_hash) {
                    $passed++;
                } else {
                    $failed++;
                    $report .= "  ❌ $relative_path (تالف/معدل)\n";
                }
            } else {
                $missing++;
                $report .= "  ⚠️ $relative_path (مفقود)\n";
            }
        }
    }
    
    close($fh);
    
    my $total = $passed + $failed + $missing;
    my $result_status = ($failed == 0 && $missing == 0) ? "SUCCESS" : "FAILED";
    
    my $summary = "";
    $summary .= "تم فحص $total ملف:\n";
    $summary .= "  ✅ سليم: $passed\n";
    $summary .= "  ❌ تالف: $failed\n";
    $summary .= "  ⚠️ مفقود: $missing\n";
    
    if ($report) {
        $summary .= "\nالتفاصيل:\n$report";
    }
    
    log_message("INFO", "refida_hash", "نتيجة التحقق: $passed سليم، $failed تالف، $missing مفقود");
    
    return ($result_status, $summary);
}

# ============================================
# 🔄 مقارنة ملفين
# ============================================

sub _compare_files {
    my ($file1, $file2) = @_;
    
    unless (-f $file1) {
        return ("ERROR", "الملف الأول غير موجود: $file1");
    }
    
    unless (-f $file2) {
        return ("ERROR", "الملف الثاني غير موجود: $file2");
    }
    
    log_message("INFO", "refida_hash", "مقارنة الملفين: $file1 و $file2");
    
    my ($status1, $hash1) = _calculate_hash($file1, "sha256");
    my ($status2, $hash2) = _calculate_hash($file2, "sha256");
    
    if ($status1 ne "SUCCESS") {
        return ("ERROR", "فشل حساب هاش الملف الأول: $hash1");
    }
    
    if ($status2 ne "SUCCESS") {
        return ("ERROR", "فشل حساب هاش الملف الثاني: $hash2");
    }
    
    if ($hash1 eq $hash2) {
        log_message("SUCCESS", "refida_hash", "الملفان متطابقان");
        
        # الحصول على أحجام الملفات
        my $size1 = -s $file1;
        my $size2 = -s $file2;
        
        my $result = "✅ الملفان متطابقان\n";
        $result .= "   الحجم: $size1 بايت\n";
        $result .= "   الهاش: $hash1\n";
        
        return ("SUCCESS", $result);
    }
    
    log_message("WARNING", "refida_hash", "الملفان مختلفان");
    
    my $result = "❌ الملفان مختلفان\n";
    $result .= "   $file1: $hash1\n";
    $result .= "   $file2: $hash2\n";
    
    return ("FAILED", $result);
}

# ============================================
# انتهى الملف
# ============================================
1;
