#!/usr/bin/perl
# ============================================
# Fool's Bind AI - الدوال المساعدة (Utils)
# ============================================
# الوظيفة: دوال عامة يستخدمها جميع أجزاء الأداة
# ============================================

package Utils;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);
use Digest::SHA qw(sha256_hex);

our @EXPORT = qw(
    log_message
    get_timestamp
    colorize
    check_internet
    run_command
    retry_command
    file_hash
    verify_integrity
    create_directory
    safe_read_file
    safe_write_file
    get_os_type
    detect_termux_path
    random_range
    is_root
    get_device_id
    encrypt_data
    decrypt_data
    cleanup_temp
);

# ============================================
# 📝 دوال التسجيل (Logging)
# ============================================

sub log_message {
    my ($level, $component, $message) = @_;
    my $timestamp = get_timestamp();
    my $log_dir = "/data/data/com.termux/files/home/fools-bind-ai/logs";
    create_directory($log_dir);
    
    my $log_file = "$log_dir/doctor.log";
    open(my $fh, '>>', $log_file) or return;
    print $fh "[$timestamp] [$level] [$component] $message\n";
    close($fh);
}

sub get_timestamp {
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time);
    $year += 1900;
    $mon += 1;
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
}

# ============================================
# 🎨 دوال الألوان (Colors)
# ============================================

sub colorize {
    my ($text, $color) = @_;
    my %colors = (
        'red'     => "\033[0;31m",
        'green'   => "\033[0;32m",
        'yellow'  => "\033[1;33m",
        'blue'    => "\033[0;34m",
        'purple'  => "\033[0;35m",
        'cyan'    => "\033[0;36m",
        'white'   => "\033[1;37m",
        'reset'   => "\033[0m"
    );
    
    my $code = $colors{$color} // $colors{'reset'};
    return $code . $text . $colors{'reset'};
}

# ============================================
# 🌐 دوال الإنترنت (Internet)
# ============================================

sub check_internet {
    my $host = shift // "1.1.1.1";
    my $timeout = shift // 5;
    
    # محاولة ping أولاً
    my $ping_result = system("ping -c 1 -W $timeout $host > /dev/null 2>&1");
    return 1 if $ping_result == 0;
    
    # محاولة curl إذا فشل ping
    my $curl_result = system("curl -s --max-time $timeout https://$host > /dev/null 2>&1");
    return 1 if $curl_result == 0;
    
    return 0;
}

# ============================================
# 🔧 دوال تنفيذ الأوامر (Command Execution)
# ============================================

sub run_command {
    my ($cmd, $timeout) = @_;
    $timeout //= 30;
    
    log_message("INFO", "Utils", "تنفيذ أمر: $cmd");
    
    my $output = `$cmd 2>&1`;
    my $exit_code = $?;
    
    if ($exit_code == 0) {
        log_message("SUCCESS", "Utils", "تم تنفيذ الأمر بنجاح");
        return ($output, 1);
    } else {
        log_message("ERROR", "Utils", "فشل تنفيذ الأمر: رمز الخطأ $exit_code");
        return ($output, 0);
    }
}

sub retry_command {
    my ($cmd, $max_retries, $delay, $timeout) = @_;
    $max_retries //= 3;
    $delay //= 5;
    $timeout //= 30;
    
    for (my $i = 1; $i <= $max_retries; $i++) {
        log_message("INFO", "Utils", "محاولة $i من $max_retries لأمر: $cmd");
        my ($output, $success) = run_command($cmd, $timeout);
        return ($output, 1) if $success;
        
        sleep($delay) if $i < $max_retries;
    }
    
    return ("فشلت جميع المحاولات $max_retries", 0);
}

# ============================================
# 🛡️ دوال التحقق من السلامة (Integrity)
# ============================================

sub file_hash {
    my ($file) = @_;
    return undef unless -f $file;
    
    open(my $fh, '<', $file) or return undef;
    binmode($fh);
    my $ctx = Digest::SHA->new(256);
    $ctx->addfile($fh);
    close($fh);
    return $ctx->hexdigest();
}

sub verify_integrity {
    my ($expected_hash, $actual_hash) = @_;
    return $expected_hash eq $actual_hash;
}

# ============================================
# 📁 دوال الملفات والمجلدات (File/Directory)
# ============================================

sub create_directory {
    my ($dir) = @_;
    return 1 if -d $dir;
    
    eval {
        system("mkdir -p '$dir' 2>/dev/null");
    };
    return -d $dir;
}

sub safe_read_file {
    my ($file) = @_;
    return undef unless -f $file && -r $file;
    
    open(my $fh, '<', $file) or return undef;
    local $/ = undef;
    my $content = <$fh>;
    close($fh);
    return $content;
}

sub safe_write_file {
    my ($file, $content) = @_;
    
    my $dir = dirname($file);
    create_directory($dir);
    
    open(my $fh, '>', $file) or return 0;
    print $fh $content;
    close($fh);
    return 1;
}

# ============================================
# 📱 دوال التعرف على النظام (OS Detection)
# ============================================

sub get_os_type {
    my $uname = `uname -s 2>/dev/null`;
    chomp($uname);
    
    if ($uname eq "Linux") {
        # محاولة التمييز بين Android و Linux العادي
        if (-d "/data/data/com.termux") {
            return "Android";
        } elsif ($uname =~ /Darwin/i) {
            return "iOS";
        } else {
            return "Linux";
        }
    } elsif ($uname =~ /Darwin/i) {
        return "iOS";
    } else {
        return "Unknown";
    }
}

sub detect_termux_path {
    my $os = get_os_type();
    
    if ($os eq "Android") {
        return "/data/data/com.termux/files/usr" if -d "/data/data/com.termux/files/usr";
    } elsif ($os eq "iOS") {
        my @possible_paths = (
            "$ENV{HOME}/usr",
            "/var/mobile/Library/Application Support/Termux/usr",
            "/private/var/mobile/Containers/Data/Application/Termux/Library/Caches/usr"
        );
        
        foreach my $path (@possible_paths) {
            return $path if -d "$path/bin";
        }
    }
    
    # إذا لم يتم العثور على المسار، نرجع المسار الافتراضي
    return "/data/data/com.termux/files/usr";
}

# ============================================
# 🎲 دوال عشوائية (Random)
# ============================================

sub random_range {
    my ($min, $max) = @_;
    return $min + int(rand($max - $min + 1));
}

# ============================================
# 🔐 دوال الصلاحيات (Permissions)
# ============================================

sub is_root {
    return ($< == 0);
}

sub get_device_id {
    my $os = get_os_type();
    
    if ($os eq "Android") {
        my $android_id = `settings get secure android_id 2>/dev/null`;
        chomp($android_id);
        return $android_id if $android_id;
    }
    
    # بديل: استخدام serial number أو MAC address
    my $serial = `getprop ro.serialno 2>/dev/null`;
    chomp($serial);
    return $serial if $serial;
    
    # آخر بديل: توليد عشوائي وحفظه
    my $config_dir = dirname(abs_path($0)) . "/config";
    my $id_file = "$config_dir/device.id";
    
    if (-f $id_file) {
        my $saved_id = safe_read_file($id_file);
        chomp($saved_id);
        return $saved_id if $saved_id;
    }
    
    # توليد معرف جديد
    my $new_id = `uuidgen 2>/dev/null` || `cat /proc/sys/kernel/random/uuid 2>/dev/null`;
    chomp($new_id);
    $new_id = int(rand(2**32)) unless $new_id;
    safe_write_file($id_file, "$new_id\n");
    return $new_id;
}

# ============================================
# 🔒 دوال التشفير (Encryption) - أساسي وبدون مكتبات خارجية
# ============================================

sub encrypt_data {
    my ($data, $key) = @_;
    # تشفير بسيط (XOR) للأغراض الأساسية
    # للاستخدام الحقيقي، يُفضل استخدام OpenSSL
    my $encrypted = '';
    my $key_len = length($key);
    for (my $i = 0; $i < length($data); $i++) {
        my $char = substr($data, $i, 1);
        my $key_char = substr($key, $i % $key_len, 1);
        $encrypted .= chr(ord($char) ^ ord($key_char));
    }
    return $encrypted;
}

sub decrypt_data {
    my ($encrypted, $key) = @_;
    # نفس عملية XOR للتشفير
    return encrypt_data($encrypted, $key);
}

# ============================================
# 🧹 دوال التنظيف (Cleanup)
# ============================================

sub cleanup_temp {
    my $temp_dir = "/data/data/com.termux/files/home/fools-bind-ai/tmp";
    return unless -d $temp_dir;
    
    system("rm -rf '$temp_dir'/* 2>/dev/null");
    log_message("INFO", "Utils", "تم تنظيف الملفات المؤقتة");
}

# ============================================
# انتهى الملف
# ============================================
1;
