param(
    [int]$Exp = 6
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$TraceRoot = Join-Path $Root "trace_exp6"
$WorkRoot = Join-Path $TraceRoot "work"
$LabRoot = "C:\Users\liuxx\Desktop\small_term\lab6-23\cdp_ede_local-master\cdp_ede_local-master\mycpu_env"
$ToolchainBin = "/mnt/c/Users/liuxx/Downloads/loongson-gnu-toolchain-8.3-x86_64-loongarch32r-linux-gnusf-v2.0/bin"
$VivadoBin = "C:\Xilinx\Vivado\2019.2\bin"
$RunStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogDir = Join-Path $TraceRoot "logs"
$LogFile = Join-Path $LogDir "exp${Exp}_${RunStamp}.log"

New-Item -ItemType Directory -Force -Path $LogDir, $WorkRoot | Out-Null

function Write-Step {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line
}

function Invoke-Logged {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$WorkingDirectory
    )
    Write-Step ("> " + $FilePath + " " + ($Arguments -join " "))
    Push-Location $WorkingDirectory
    $oldErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $FilePath @Arguments 2>&1 | Tee-Object -FilePath $LogFile -Append
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        $ErrorActionPreference = $oldErrorActionPreference
        Pop-Location
    }
}

function Reset-Directory {
    param([string]$Path)
    $full = [System.IO.Path]::GetFullPath($Path)
    $allowed = [System.IO.Path]::GetFullPath($WorkRoot)
    if (-not $full.StartsWith($allowed, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to reset outside work root: $full"
    }
    if (Test-Path -LiteralPath $full) {
        Remove-Item -LiteralPath $full -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $full | Out-Null
}

Write-Step "EXP=$Exp trace run started"

$WorkMycpu = Join-Path $WorkRoot "mycpu_env"
$WorkFunc = Join-Path $WorkMycpu "func"
$WorkGettrace = Join-Path $WorkMycpu "gettrace"
Reset-Directory $WorkMycpu

Write-Step "Copying func and gettrace sources into workspace scratch"
Copy-Item -LiteralPath (Join-Path $LabRoot "func") -Destination $WorkMycpu -Recurse
New-Item -ItemType Directory -Force -Path $WorkGettrace | Out-Null
Copy-Item -LiteralPath (Join-Path $LabRoot "gettrace\src") -Destination $WorkGettrace -Recurse

Write-Step "Building func program with WSL LoongArch toolchain"
$FuncWsl = (& wsl -e wslpath -a $WorkFunc).Trim()
$BuildCmd = "cd '$FuncWsl' && export PATH='$ToolchainBin':`$PATH && make clean && make EXP=$Exp"
Invoke-Logged -FilePath "wsl" -Arguments @("-e", "bash", "-lc", $BuildCmd) -WorkingDirectory $Root

Write-Step "Generating golden_trace.txt with Vivado xsim"
$GettraceXsimDir = Join-Path $WorkGettrace "gettrace.sim\sim_1\behav\xsim"
New-Item -ItemType Directory -Force -Path $GettraceXsimDir | Out-Null
$GettraceFiles = @(
    (Join-Path $WorkGettrace "src\soc_lite_top.v"),
    (Join-Path $WorkGettrace "src\tb_top.v"),
    (Join-Path $WorkGettrace "src\BRIDGE\bridge_1x2.v"),
    (Join-Path $WorkGettrace "src\CONFREG\confreg.v"),
    (Join-Path $WorkGettrace "src\myCPU\SimpleLACoreWrapRAM.v")
)
Invoke-Logged -FilePath (Join-Path $VivadoBin "xvlog.bat") -Arguments $GettraceFiles -WorkingDirectory $GettraceXsimDir
Invoke-Logged -FilePath (Join-Path $VivadoBin "xelab.bat") -Arguments @("tb_top", "-snapshot", "tb_top_gettrace", "-timescale", "1ns/1ps") -WorkingDirectory $GettraceXsimDir
Invoke-Logged -FilePath (Join-Path $VivadoBin "xsim.bat") -Arguments @("tb_top_gettrace", "-runall") -WorkingDirectory $GettraceXsimDir

$GoldenTrace = Join-Path $WorkGettrace "golden_trace.txt"
if (-not (Test-Path -LiteralPath $GoldenTrace)) {
    throw "golden_trace.txt was not generated"
}

Write-Step "Preparing current CPU simulation inputs"
$CurrentSim = Join-Path $TraceRoot "current_cpu"
Copy-Item -LiteralPath (Join-Path $WorkFunc "obj\inst_ram.mif") -Destination (Join-Path $CurrentSim "inst_ram.mif") -Force
Copy-Item -LiteralPath $GoldenTrace -Destination (Join-Path $CurrentSim "golden_trace.txt") -Force

Write-Step "Running current CPU EXP=$Exp trace comparison with watchdog"
$CpuSrc = Join-Path $Root "waterflow_CPU\single_cycle_CPU.srcs\sources_1\new"
$CurrentFiles = @(
    (Join-Path $CurrentSim "current_cpu_exp6_tb.v"),
    (Join-Path $CpuSrc "CPU.v"),
    (Join-Path $CpuSrc "reg_32bit.v"),
    (Join-Path $CpuSrc "ALU.v"),
    (Join-Path $CpuSrc "BRU.v"),
    (Join-Path $CpuSrc "adder.v"),
    (Join-Path $CpuSrc "adder_4bit.v"),
    (Join-Path $CpuSrc "booth_wallace.v"),
    (Join-Path $CpuSrc "booth_radix4_encoder.v"),
    (Join-Path $CpuSrc "csa_64bit.v"),
    (Join-Path $CpuSrc "bsh1.v"),
    (Join-Path $CpuSrc "bsh2.v"),
    (Join-Path $CpuSrc "bsh4.v"),
    (Join-Path $CpuSrc "bsh8.v"),
    (Join-Path $CpuSrc "bsh16.v"),
    (Join-Path $CpuSrc "bsh32.v"),
    (Join-Path $CpuSrc "ander.v"),
    (Join-Path $CpuSrc "orer.v"),
    (Join-Path $CpuSrc "xorer.v"),
    (Join-Path $CpuSrc "norer.v")
)
Invoke-Logged -FilePath (Join-Path $VivadoBin "xvlog.bat") -Arguments $CurrentFiles -WorkingDirectory $CurrentSim
Invoke-Logged -FilePath (Join-Path $VivadoBin "xelab.bat") -Arguments @("tb_top", "-snapshot", "current_cpu_exp6", "-timescale", "1ns/1ps") -WorkingDirectory $CurrentSim
Invoke-Logged -FilePath (Join-Path $VivadoBin "xsim.bat") -Arguments @("current_cpu_exp6", "-runall") -WorkingDirectory $CurrentSim

$CpuXsimLog = Join-Path $CurrentSim "xsim.log"
if (-not (Test-Path -LiteralPath $CpuXsimLog)) {
    Write-Step "RESULT: UNKNOWN (missing current CPU xsim.log)"
    exit 3
}

$ResultText = Get-Content -LiteralPath $CpuXsimLog -Raw
if ($ResultText -match "(?m)^\s*----PASS!!!\s*$") {
    Write-Step "RESULT: PASS"
    exit 0
}
elseif ($ResultText -match "WATCHDOG TIMEOUT") {
    Write-Step "RESULT: WATCHDOG TIMEOUT"
    exit 2
}
elseif ($ResultText -match "Error!!!|Fail!!!") {
    Write-Step "RESULT: FAIL"
    exit 1
}
else {
    Write-Step "RESULT: UNKNOWN"
    exit 3
}
