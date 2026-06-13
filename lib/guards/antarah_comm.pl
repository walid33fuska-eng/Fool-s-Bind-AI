#!/usr/bin/perl
# ============================================
# Fool's Bind AI - ضابط الاتصالات (Antarah Communications)
# ============================================
# الوظيفة: مراقبة جميع الاتصالات الصادرة والواردة وحماية الأداة من التهديدات الشبكية
# ============================================

package antarah_comm;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);
use IO::Socket::INET;
use Socket;

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message get_timestamp colorize check_internet);

our @EXPORT = qw(execute);

# ============================================
# 🌐 قوائم العناوين المسموحة والممنوعة
# ============================================

my @ALLOWED_DOMAINS = (
    'packages.termux.org',
    'github.com',
    'raw.githubusercontent.com',
    'pypi.org',
    'files.pythonhosted.org',
    'registry.npmjs.org',
    '1.1.1.1',
    '8.8.8.8',
    'google.com'
);

my @BLOCKED_DOMAINS = (
    'evil.com',
    'malware.org',
    'hackers.net',
    'darkweb.onion',
    'torproject.org'
);

my @SUSPICIOUS_PATTERNS = (
    'cmd=',
    'wget.*\|',
    'curl.*\|',
    'bash -c',
    'sh -c',
    'eval',
    'base64 -d',
    'chmod 777',
    'chmod \+x'
);

my $COMM_MONITORING = 1;
my $LAST_REPORT_TIME = 0;
my @CONNECTION_LOG = ();

# ============================================
# 🚀 الدالة الرئيسية للتنفيذ
# ============================================

sub execute {
    my ($task, $params) = @_;
    
    log_message("INFO", "antarah_comm", "بدء مهمة: $task");
    
    if ($task eq "quick_scan") {
        return _quick_scan();
    }
    elsif ($task eq "security_check") {
        return _security_check();
    }
    elsif ($task eq "monitor_connection") {
        my $url = $params->{url} // return ("ERROR", "لم يتم تحديد URL");
        return _monitor_connection($url);
    }
    elsif ($task eq "check_domain") {
        my $domain = $params->{domain} // return ("ERROR", "لم يتم تحديد المجال");
        return _check_domain($domain);
    }
    elsif ($task eq "scan_command") {
        my $command = $params->{command} // return ("ERROR", "لم يتم تحديد الأمر");
        return _scan_command($command);
    }
    elsif ($task eq "lockdown") {
        return _lockdown();
    }
    elsif ($task eq "open") {
        return _open();
    }
    elsif ($task eq "log_connection") {
        my $url = $params->{url} // "";
        my $type = $params->{type} // "unknown";
        return _log_connection($url, $type);
    }
    else {
        return ("ERROR", "مهمة غير معروفة: $task");
    }
}

# ============================================
# 🔍 الفحص السريع للاتصالات النشطة
# ============================================

sub _quick_scan {
    log_message("INFO", "antarah_comm", "الفحص السريع للاتصالات");
    
    my $threats = 0;
    my $report = "";
    
    # فحص الاتصالات النشطة باستخدام netstat
    my $netstat = `netstat -an 2>/dev/null | grep ESTABLISHED | grep -E '(:443|:80|:22)' | head -10`;
    
    if ($netstat) {
        $report .= "الاتصالات النشطة الحالية:\n";
        $report .= "$netstat\n";
        
        foreach my $line (split(/\n/, $netstat)) {
            if ($line =~ /(\d+\.\d+\.\d+\.\d+):(\d+)/) {
                my $ip = $1;
                my $port = $2;
                
                # فحص المنافذ الخطيرة
                if ($port == 23 || $port == 445 || $port == 3389) {
                    $threats++;
                    $report .= "  ⚠️ منفذ خطير: $port\n";
                    _report_threat("dangerous_port", "$ip:$port");
                }
            }
        }
    }
    
    if ($threats > 0) {
        return ("THREAT_DETECTED", "تم اكتشاف $threats مشكلة في الاتصالات:\n$report");
    }
    
    return ("SUCCESS", "لا توجد اتصالات مشبوهة");
}

# ============================================
# 🛡️ الفحص الأمني الشامل
# ============================================

sub _security_check {
    log_message("INFO", "antarah_comm", "الفحص الأمني الشامل للاتصالات");
    
    my $report = "";
    my $threats = 0;
    
    # 1. فحص الإنترنت
    my $internet = check_internet();
    $report .= "الاتصال بالإنترنت: " . ($internet ? "✅ متصل" : "❌ غير متصل") . "\n";
    
    # 2. فحص DNS
    if ($internet) {
        my $dns_test = `nslookup google.com 2>/dev/null | head -2`;
        if ($dns_test =~ /Address:/) {
            $report .= "DNS: ✅ يعمل\n";
        } else {
            $report .= "DNS: ❌ لا يعمل\n";
            $threats++;
        }
    }
    
    # 3. فحص الوكيل (Proxy)
    my $http_proxy = $ENV{http_proxy} // "غير مضبوط";
    my $https_proxy = $ENV{https_proxy} // "غير مضبوط";
    $report .= "HTTP Proxy: $http_proxy\n";
    $report .= "HTTPS Proxy: $https_proxy\n";
    
    # 4. فحص التهديدات المسجلة
    my $recent_threats = _get_recent_threats();
    if (@$recent_threats > 0) {
        $threats += scalar(@$recent_threats);
        $report .= "\n⚠️ التهديدات المسجلة مؤخراً:\n";
        foreach my $threat (@$recent_threats) {
            $report .= "  • $threat->{type}: $threat->{details}\n";
        }
    }
    
    if ($threats > 0) {
        return ("THREAT_DETECTED", "تم اكتشاف $threats مشكلة:\n$report");
    }
    
    return ("SUCCESS", $report);
}

# ============================================
# 🔍 مراقبة اتصال محدد
# ============================================

sub _monitor_connection {
    my ($url) = @_;
    
    log_message("INFO", "antarah_comm", "مراقبة الاتصال: $url");
    
    # استخراج المجال من URL
    my $domain = $url;
    $domain =~ s|^https?://||;
    $domain =~ s|/.*$||;
    
    # فحص المجال
    my ($status, $result) = _check_domain($domain);
    
    if ($status eq "BLOCKED") {
        _report_threat("blocked_connection", $url);
        return ("BLOCKED", "الاتصال ممنوع: $domain ($result)");
    }
    
    if ($status eq "SUSPICIOUS") {
        _report_threat("suspicious_connection", $url);
        return ("SUSPICIOUS", "تحذير: الاتصال مشبوه بـ $domain ($result)");
    }
    
    _log_connection($url, "allowed");
    return ("ALLOWED", "الاتصال مسموح بـ $domain");
}

# ============================================
# 🏷️ فحص المجال (مسموح / ممنوع / مشبوه)
# ============================================

sub _check_domain {
    my ($domain) = @_;
    
    $domain = lc($domain);
    
    # فحص القائمة الممنوعة
    foreach my $blocked (@BLOCKED_DOMAINS) {
        if ($domain =~ /$blocked/) {
            log_message("WARNING", "antarah_comm", "محاولة اتصال بمجال ممنوع: $domain");
            return ("BLOCKED", "المجال ممنوع: $blocked");
        }
    }
    
    # فحص القائمة المسموحة
    foreach my $allowed (@ALLOWED_DOMAINS) {
        if ($domain =~ /$allowed/) {
            return ("ALLOWED", "المجال مسموح");
        }
    }
    
    # المجالات غير المعروفة تعتبر مشبوهة
    log_message("WARNING", "antarah_comm", "اتصال بمجال غير معروف: $domain");
    return ("SUSPICIOUS", "المجال غير معروف، يوصى بالحذر");
}

# ============================================
# 🔎 فحص الأوامر المشبوهة
# ============================================

sub _scan_command {
    my ($command) = @_;
    
    log_message("INFO", "antarah_comm", "فحص الأمر: $command");
    
    my $threats = 0;
    my $found_patterns = "";
    
    foreach my $pattern (@SUSPICIOUS_PATTERNS) {
        if ($command =~ /$pattern/i) {
            $threats++;
            $found_patterns .= "  • $pattern\n";
        }
    }
    
    # فحص محاولات تنزيل وتنفيذ
    if ($command =~ /(wget|curl).*\|.*(sh|bash|perl|python)/i) {
        $threats++;
        $found_patterns .= "  • تنزيل وتنفيذ فوري\n";
    }
    
    # فحص محاولات رفع بيانات
    if ($command =~ /(curl|nc|telnet).*--upload|-T/i) {
        $threats++;
        $found_patterns .= "  • رفع بيانات خارجية\n";
    }
    
    if ($threats > 0) {
        log_message("WARNING", "antarah_comm", "أمر مشبوه: $command");
        _report_threat("suspicious_command", $command);
        return ("SUSPICIOUS", "تم اكتشاف $threats نمطاً مشبوهاً:\n$found_patterns");
    }
    
    return ("CLEAN", "الأمر آمن");
}

# ============================================
# 🔒 وضع الإغلاق (قطع الاتصالات المشبوهة)
# ============================================

sub _lockdown {
    log_message("INFO", "antarah_comm", "تفعيل وضع الإغلاق - تقييد الاتصالات");
    
    $COMM_MONITORING = 2;  # مستوى مراقبة مشدد
    
    # تسجيل حالة الإغلاق
    _log_connection("LOCKDOWN_ACTIVATED", "system");
    
    return ("SUCCESS", "تم تفعيل وضع الإغلاق. سيتم فحص جميع الاتصالات بدقة متناهية.");
}

# ============================================
# 🔓 العودة إلى الوضع العادي
# ============================================

sub _open {
    log_message("INFO", "antarah_comm", "العودة إلى الوضع العادي");
    
    $COMM_MONITORING = 1;
    _log_connection("LOCKDOWN_DEACTIVATED", "system");
    
    return ("SUCCESS", "تم العودة إلى الوضع العادي.");
}

# ============================================
# 📝 تسجيل اتصال
# ============================================

sub _log_connection {
    my ($url, $type) = @_;
    
    push @CONNECTION_LOG, {
        timestamp => get_timestamp(),
        url => $url,
        type => $type,
        status => $COMM_MONITORING == 2 ? "monitored" : "normal"
    };
    
    # الاحتفاظ بآخر 100 اتصال فقط
    if (@CONNECTION_LOG > 100) {
        shift @CONNECTION_LOG;
    }
    
    # إضافة إلى ملف السجل
    my $log_file = dirname(abs_path($0)) . '/../../logs/connections.log';
    open(my $fh, '>>', $log_file) or return;
    print $fh "[" . get_timestamp() . "] [$type] $url\n";
    close($fh);
    
    return 1;
}

# ============================================
# 📊 الحصول على التهديدات المسجلة مؤخراً
# ============================================

sub _get_recent_threats {
    my @threats = ();
    
    # قراءة من سجل التهديدات
    my $threat_file = dirname(abs_path($0)) . '/../../logs/threats.log';
    if (-f $threat_file) {
        open(my $fh, '<', $threat_file) or return [];
        my @lines = <$fh>;
        close($fh);
        
        # آخر 5 أسطر فقط
        my $start = @lines > 5 ? @lines - 5 : 0;
        for (my $i = $start; $i < @lines; $i++) {
            chomp($lines[$i]);
            if ($lines[$i] =~ /^\[(.*?)\] \[(.*?)\] (.*)$/) {
                push @threats, {
                    timestamp => $1,
                    type => $2,
                    details => $3
                };
            }
        }
    }
    
    return \@threats;
}

# ============================================
# 📝 الإبلاغ عن تهديد
# ============================================

sub _report_threat {
    my ($type, $details) = @_;
    
    log_message("THREAT", "antarah_comm", "$type: $details");
    
    # تسجيل في ملف التهديدات
    my $threat_file = dirname(abs_path($0)) . '/../../logs/threats.log';
    open(my $fh, '>>', $threat_file) or return;
    print $fh "[" . get_timestamp() . "] [$type] $details\n";
    close($fh);
    
    # إذا كان في وضع الإغلاق، سجل إنذاراً إضافياً
    if ($COMM_MONITORING == 2) {
        log_message("CRITICAL", "antarah_comm", "إنذار أمني في وضع الإغلاق: $type - $details");
    }
}

# ============================================
# انتهى الملف
# ============================================
1;
