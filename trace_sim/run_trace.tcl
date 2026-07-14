proc fail {message} {
    puts stderr "\nERROR: $message"
    return -code error $message
}

set exp 12
set mode gui
if {[llength $argv] >= 1} { set exp [lindex $argv 0] }
if {[llength $argv] >= 2} { set mode [string tolower [lindex $argv 1]] }
if {[llength $argv] > 2}  { fail "usage: run_trace.tcl ?EXP? ?batch|gui?" }

if {![string is integer -strict $exp] || $exp < 12 || $exp > 16} {
    fail "the current trace environment supports EXP=12 through EXP=16"
}
if {$mode ni {batch gui}} {
    fail "mode must be batch or gui"
}

set script_text [string map {\\ /} [info script]]
set root_guess [file dirname [file dirname $script_text]]
if {[string first "/Desktop/" $root_guess] < 0 && [info exists env(USERPROFILE)]} {
    set home [string trimright [string map {\\ /} $env(USERPROFILE)] /]
    set bad_prefix "${home}/"
    if {[string first $bad_prefix $root_guess] == 0} {
        set tail [string range $root_guess [string length $bad_prefix] end]
        set project_root "${home}/Desktop/${tail}"
    } else {
        set project_root "${home}/Desktop/small_term/waterflow_CPU"
    }
} else {
    set project_root $root_guess
}

set runner "${project_root}/trace_watchdog/scripts/run_trace_watchdog.ps1"
set powershell [auto_execok powershell.exe]
if {$powershell eq ""} { fail "powershell.exe was not found" }

puts "=============================================================="
puts "Starting CPU trace: EXP=$exp, mode=$mode"
puts "Project: $project_root"
puts "The terminal will show functional points and the final PASS/FAIL result."
puts "=============================================================="

set run_status [catch {
    exec $powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Exp $exp >@ stdout 2>@ stderr
} run_error run_options]
if {$run_status != 0} {
    fail "trace runner failed: $run_error"
}

if {$mode eq "gui"} {
    # Find the run just produced and reopen its compiled CPU snapshot in XSim.
    set find_script [format {
        $root = '%s'
        $run = Get-ChildItem -LiteralPath (Join-Path $root 'trace_watchdog\runs') -Directory -Filter 'exp%s_*' |
            Sort-Object Name -Descending | Select-Object -First 1
        if (-not $run) { throw 'No completed trace run was found.' }
        (Join-Path $run.FullName 'cpu')
    } [string map {' ''} $project_root] $exp]

    set cpu_run [string trim [exec $powershell -NoProfile -Command $find_script]]
    set gui_script [format {
        $cpu = '%s'
        $xsim = 'C:\Xilinx\Vivado\2019.2\bin\xsim.bat'
        if (-not (Test-Path -LiteralPath $xsim)) { $xsim = 'xsim.bat' }
        Start-Process -FilePath $xsim -WorkingDirectory $cpu -ArgumentList @('cpu_tb','-gui') -Wait
    } [string map {' ''} $cpu_run]]

    puts "Opening XSim GUI from: $cpu_run"
    exec $powershell -NoProfile -Command $gui_script >@ stdout 2>@ stderr
}

puts "=============================================================="
puts "EXP=$exp trace finished."
puts "Results and run artifacts are under trace_watchdog/runs/."
puts "=============================================================="
