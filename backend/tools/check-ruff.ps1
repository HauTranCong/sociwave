param(
    [string]$Path = ".",
    [switch]$Fix
)

Write-Host "Running ruff on: $Path"

# If a venv exists in the backend folder, prefer its ruff
$venvRuff = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..") -ChildPath ".venv\Scripts\ruff.exe"
if (Test-Path $venvRuff) {
    $ruffCmd = $venvRuff
} else {
    $ruffCmd = "ruff"
}

if ($Fix) {
    Write-Host "-- Fix mode enabled: ruff will try to fix issues"
    & $ruffCmd --fix $Path
} else {
    & $ruffCmd check $Path
}
