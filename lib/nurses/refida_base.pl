#!/usr/bin/perl
# ============================================
# Fool's Bind AI - الممرضة الأساسية (Refida Base)
# ============================================
# الوظيفة: الممرضة الرئيسية التي تدير وتنسق جميع الممرضات المتخصصات
# ============================================

package RefidaBase;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename;
use Cwd qw(abs_path);

use lib dirname(abs_path($0)) . '/../..';
use Utils qw(log_message get_timestamp colorize run_command retry_command check_internet);

our @EXPORT = qw(
    initialize_nurses
    call_nurse
    call_all_nurses
    get_nurse_report
    get_nurse_log
    nurse_healing_complete
);

# ============================================
# 📋 تسجيل الممرضات المتخصصات
# ============================================

my %NURSES = ();
my %NURSE_LOGS = ();
my $NURSES_PATH = "";

# ============================================
# 🧬 تهيئة الممرضات
# ============================================

sub initialize_nurses {
    my $script_dir = dirname(abs_path($0));
    $NURSES_PATH = "$script_dir";
    
    # قائمة الممرضات المتخصصات
    my @nurse_list = qw(
        refida_py
        refida_apt
        refida_node
        refida_git
        refida_config
        refida_permission
        refida_hash
    );
    
    foreach my $nurse (@nurse_list) {
        my $nurse_file = "$NURSES_PATH/$nurse.pl";
        if (-f $nurse_file) {
            eval {
                require $nurse_file;
                $NURSES{$nurse} = 1;
                log_message("INFO", "RefidaBase", "تم تحميل الممرضة: $nurse");
            };
            if ($@) {
                log_message("ERROR", "RefidaBase", "فشل تحميل الممرضة $nurse: $@");
            }
        } else {
            log_message("WARNING", "RefidaBase", "الملف غير موجود: $nurse_file");
        }
    }
    
    log_message("INFO", "RefidaBase", "تم تهيئة " . scalar(keys %NURSES) . " ممرضة");
    return scalar(keys %NURSES);
}

# ============================================
# 📞 استدعاء ممرضة واحدة
# ============================================

sub call_nurse {
    my ($nurse_name, $task, $params) = @_;
    
    # التحقق من وجود الممرضة
    unless ($NURSES{$nurse_name}) {
        my $error = "الممرضة غير موجودة: $nurse_name";
        log_message("ERROR", "RefidaBase", $error);
        return ("ERROR", $error);
    }
    
    # التحقق من الإنترنت إذا كانت المهمة تحتاج إليه
    my $needs_internet = $params->{needs_internet} // 1;
    if ($needs_internet && !check_internet()) {
        log_message("WARNING", "RefidaBase", "الممرضة $nurse_name تحتاج إلى إنترنت ولكن لا يوجد اتصال");
        return ("NO_INTERNET", "لا يوجد اتصال بالإنترنت. الرجاء تشغيل WiFi أو البيانات.");
    }
    
    log_message("INFO", "RefidaBase", "استدعاء الممرضة: $nurse_name للمهمة: $task");
    
    # تسجيل بداية المهمة في سجل الممرضة
    _log_to_nurse($nurse_name, "START", "مهمة: $task");
    
    # محاولة استدعاء الممرضة
    my $result = "";
    my $status = "";
    
    eval {
        # بناء اسم الدالة (مثلاً: refida_py::heal)
        my $function = "${nurse_name}::heal";
        no strict 'refs';
        ($status, $result) = $function->($task, $params);
    };
    
    if ($@) {
        log_message("ERROR", "RefidaBase", "خطأ في استدعاء الممرضة $nurse_name: $@");
        _log_to_nurse($nurse_name, "ERROR", $@);
        return ("ERROR", "فشل استدعاء الممرضة: $@");
    }
    
    _log_to_nurse($nurse_name, "END", "الحالة: $status - $result");
    log_message("INFO", "RefidaBase", "انتهت الممرضة $nurse_name بـ $status");
    
    return ($status, $result);
}

# ============================================
# 🚀 استدعاء جميع الممرضات دفعة واحدة (ضربة واحدة)
# ============================================

sub call_all_nurses {
    my ($task, $params) = @_;
    $task //= "self_check";
    $params //= {};
    
    log_message("INFO", "RefidaBase", "استدعاء جميع الممرضات دفعة واحدة للمهمة: $task");
    
    my %results = ();
    
    foreach my $nurse_name (keys %NURSES) {
        log_message("INFO", "RefidaBase", "جارٍ استدعاء الممرضة: $nurse_name");
        my ($status, $result) = call_nurse($nurse_name, $task, $params);
        $results{$nurse_name} = {
            status => $status,
            result => $result,
            timestamp => get_timestamp()
        };
    }
    
    # تقرير موجز
    my $success_count = 0;
    my $failed_count = 0;
    
    foreach my $nurse (keys %results) {
        if ($results{$nurse}{status} eq "SUCCESS") {
            $success_count++;
        } else {
            $failed_count++;
        }
    }
    
    log_message("INFO", "RefidaBase", "نتيجة استدعاء جميع الممرضات: نجاح $success_count، فشل $failed_count");
    
    return (\%results, $success_count, $failed_count);
}

# ============================================
# 📊 الحصول على تقرير حالة الممرضات
# ============================================

sub get_nurse_report {
    my $report = "";
    
    $report .= "\n" . "=" x 60 . "\n";
    $report .= "  👩‍⚕️ تقرير الممرضات (Refida)\n";
    $report .= "=" x 60 . "\n\n";
    
    my $active = scalar(keys %NURSES);
    $report .= "عدد الممرضات النشطات: $active\n\n";
    
    foreach my $nurse (sort keys %NURSES) {
        $report .= "  👩‍⚕️ $nurse\n";
        $report .= "     الحالة: نشطة\n";
        
        # عرض آخر نشاط من سجل الممرضة
        if (exists $NURSE_LOGS{$nurse}) {
            my $last_log = $NURSE_LOGS{$nurse}[-1] if @{$NURSE_LOGS{$nurse}};
            if ($last_log) {
                $report .= "     آخر نشاط: $last_log->{action}\n";
            }
        }
        $report .= "\n";
    }
    
    $report .= "=" x 60 . "\n";
    
    return $report;
}

# ============================================
# 📝 الحصول على سجل ممرضة معينة
# ============================================

sub get_nurse_log {
    my ($nurse_name, $lines) = @_;
    $lines //= 20;
    
    unless (exists $NURSE_LOGS{$nurse_name}) {
        return "لا يوجد سجل للممرضة $nurse_name";
    }
    
    my $log_entries = $NURSE_LOGS{$nurse_name};
    my @recent = @$log_entries;
    
    if (@recent > $lines) {
        @recent = @recent[-$lines .. -1];
    }
    
    my $output = "سجل الممرضة $nurse_name (آخر " . scalar(@recent) . " سطر):\n";
    $output .= "-" x 60 . "\n";
    
    foreach my $entry (@recent) {
        $output .= sprintf("[%s] %s: %s\n", 
            $entry->{timestamp}, 
            $entry->{action}, 
            $entry->{message});
    }
    
    $output .= "-" x 60 . "\n";
    
    return $output;
}

# ============================================
# 📝 تسجيل داخلي في سجل الممرضة
# ============================================

sub _log_to_nurse {
    my ($nurse_name, $action, $message) = @_;
    
    $NURSE_LOGS{$nurse_name} = [] unless exists $NURSE_LOGS{$nurse_name};
    
    push @{$NURSE_LOGS{$nurse_name}}, {
        timestamp => get_timestamp(),
        action => $action,
        message => $message
    };
    
    # الاحتفاظ بآخر 100 سجل فقط
    if (@{$NURSE_LOGS{$nurse_name}} > 100) {
        shift @{$NURSE_LOGS{$nurse_name}};
    }
}

# ============================================
# ✅ إكمال الشفاء (تنظيف الممرضات)
# ============================================

sub nurse_healing_complete {
    log_message("INFO", "RefidaBase", "تم إكمال جميع عمليات الشفاء");
    
    my $final_report = "";
    $final_report .= "\n✨ " . colorize("تم شفاء جميع الأدوات بنجاح!", "green") . " ✨\n";
    
    return $final_report;
}

# ============================================
# 🧬 تهيئة الممرضات عند تحميل الملف
# ============================================

initialize_nurses();

# ============================================
# انتهى الملف
# ============================================
1;
