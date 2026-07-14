$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$rtlDir = Join-Path $repoRoot 'waterflow_CPU\single_cycle_CPU.srcs\sources_1\new'
$simDir = Join-Path $repoRoot 'waterflow_CPU\single_cycle_CPU.srcs\sim_1\new'
$workDir = Join-Path $repoRoot 'tmp\soc_tests'

if (-not $workDir.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a test directory outside the repository: $workDir"
}
if (Test-Path -LiteralPath $workDir) {
    Remove-Item -LiteralPath $workDir -Recurse -Force
}
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

$rtlFiles = Get-ChildItem -LiteralPath $rtlDir -Filter '*.v' -File |
    Sort-Object Name | ForEach-Object { $_.FullName }
$simNames = @(
    'nand_boot_loader_tb.v',
    'boot_selftest_failure_tb.v',
    'nand_boot_loader_timeout_tb.v',
    'nand_boot_loader_ddr_timeout_tb.v',
    'ddr_cdc_bridge_tb.v',
    'mmio_peripheral_regs_tb.v',
    'ps2_raw_tb.v',
    'sevenseg_scan_tb.v',
    'uart_tx_simple_tb.v',
    'vga_text_tb.v'
)
$simFiles = $simNames | ForEach-Object { Join-Path $simDir $_ }

$testTops = @(
    'nand_boot_loader_tb',
    'nand_boot_loader_max_tb',
    'nand_header_error_tb',
    'nand_header_version_error_tb',
    'nand_header_zero_length_error_tb',
    'nand_header_oversize_error_tb',
    'nand_header_load_error_tb',
    'nand_header_entry_error_tb',
    'nand_header_flags_error_tb',
    'nand_header_reserved_error_tb',
    'nand_crc_error_tb',
    'nand_boot_loader_timeout_tb',
    'nand_boot_loader_page_timeout_tb',
    'nand_boot_loader_ddr_timeout_tb',
    'nand_boot_loader_ddr_req_timeout_tb',
    'nand_boot_loader_ddr_resp_timeout_tb',
    'ddr_cdc_bridge_tb',
    'mmio_peripheral_regs_tb',
    'soc_boot_board_control_tb',
    'ps2_raw_tb',
    'sevenseg_scan_tb',
    'uart_tx_simple_tb',
    'vga_text_tb'
)

Push-Location $workDir
try {
    Write-Host "[xvlog] compiling $($rtlFiles.Count) RTL and $($simFiles.Count) test files"
    & xvlog --sv -i $rtlDir @rtlFiles @simFiles
    if ($LASTEXITCODE -ne 0) {
        throw "xvlog failed with exit code $LASTEXITCODE"
    }

    foreach ($top in $testTops) {
        $snapshot = "${top}_run"
        Write-Host "[xelab] $top"
        & xelab $top -s $snapshot
        if ($LASTEXITCODE -ne 0) {
            throw "xelab failed for $top with exit code $LASTEXITCODE"
        }

        Write-Host "[xsim] $top"
        $simOutput = @(& xsim $snapshot -runall 2>&1)
        $simExitCode = $LASTEXITCODE
        $simOutput | ForEach-Object { Write-Host $_ }
        $simText = $simOutput -join "`n"
        if (($simExitCode -ne 0) -or
            ($simText -match '(?im)(^|\s)(FAIL:|FATAL:)') -or
            ($simText -notmatch '(?im)^PASS:')) {
            throw "xsim failed for $top with exit code $simExitCode"
        }
    }
} finally {
    Pop-Location
}

Write-Host "SOC_TESTS_PASS ($($testTops.Count) test tops)"
