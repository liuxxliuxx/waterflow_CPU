$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$drive = 'W:'
$driveName = 'W'
$createdDrive = $false

try {
    if (Get-PSDrive $driveName -ErrorAction SilentlyContinue) {
        throw "Temporary build drive $drive is already in use."
    }

    & subst $drive $repoRoot
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to create the temporary W: workspace mapping.'
    }
    $createdDrive = $true

    Push-Location "$drive\"
    try {
        & vivado -mode batch -source W:/tools/build_soc_bitstream.tcl -tclargs W:/
        $vivadoExitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($vivadoExitCode -ne 0) {
        throw "Vivado build failed with exit code $vivadoExitCode."
    }
} finally {
    if ($createdDrive) {
        & subst $drive /d 2>$null
    }
}
