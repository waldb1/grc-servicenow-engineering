<#
.SYNOPSIS
    Weekly runner for sod_weekly_check.py

.DESCRIPTION
    Executes the existing Python SoD conflict check script, logs the
    outcome, and generates a SHA-256 hash of the log file after each run
    to provide tamper-evidence for audit purposes. Meant to be triggered
    by Windows Task Scheduler weekly.

    Paths to the Python executable and script are loaded from .env
    rather than hardcoded, so this file contains no machine-specific
    or user-specific information.
#>

# --- Load .env into environment variables ---
Get-Content (Join-Path $PSScriptRoot ".env") | ForEach-Object {
    if ($_ -match "^\s*([^#][^=]*)=(.*)$") {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
}

# --- Config: pulled from .env (see .env.example for required keys) ---
$PythonExe   = $env:SOD_PYTHON_EXE
$ScriptPath  = $env:SOD_SCRIPT_PATH

if ([string]::IsNullOrWhiteSpace($PythonExe) -or [string]::IsNullOrWhiteSpace($ScriptPath)) {
    Write-Host "ERROR: SOD_PYTHON_EXE or SOD_SCRIPT_PATH missing from .env. See .env.example."
    exit 1
}

# --- Log file sits next to this .ps1 script ---
$LogPath      = Join-Path $PSScriptRoot "sod_check_run.log"
$HashLogPath  = Join-Path $PSScriptRoot "sod_check_hashes.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp  $Message" | Out-File -FilePath $LogPath -Append
}

# Force UTF-8 so emoji (✅ / ❌) in the Python script's output doesn't crash under output redirection (cp1252 fallback can't encode them).
$env:PYTHONIOENCODING = "utf-8"

Write-Log "=== Starting weekly SoD check ==="

try {
    # Run the Python script and capture its console output
    $output = & $PythonExe $ScriptPath 2>&1
    $exitCode = $LASTEXITCODE

    # Write everything the Python script printed into the log too
    $output | Out-File -FilePath $LogPath -Append

    if ($exitCode -eq 0) {
        Write-Log "Python script completed successfully (exit code 0)."
    } else {
        Write-Log "Python script exited with code $exitCode -- check output above."
    }
}
catch {
    Write-Log "Failed to run Python script: $($_.Exception.Message)"
}

Write-Log "=== Weekly SoD check finished ==="

# --- Hash the log to create tamper-evidence ---
# Written to a SEPARATE file from the log itself. If someone edits sod_check_run.log after the fact, re-hashing it will no longer match the value recorded here, proving the log was altered.
$hash = Get-FileHash -Path $LogPath -Algorithm SHA256
$hashRecord = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  |  Log hash (SHA256): $($hash.Hash)"
$hashRecord | Out-File -FilePath $HashLogPath -Append