<#
.SYNOPSIS
    Test Harness for L4 Config Loader
    Automates the testing of config_mgr.ps1 and L4_Config_Loader.ps1 using provided simulation files.

.DESCRIPTION
    1. Runs config_mgr.ps1 to generate the cleaned config file.
    2. Runs L4_Config_Loader.ps1 with "first_try.txt" (Expected: Success).
    3. Runs L4_Config_Loader.ps1 with "second_try.txt" (Expected: Failure/Pending Config).
#>

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path
$ConfigMgr = Join-Path $ScriptDir "config_mgr.ps1"
$Loader = Join-Path $ScriptDir "L4_Config_Loader.ps1"
$RawConfig = Join-Path $ScriptDir "L4_testid_1.1.1.1.txt"
$CleanConfig = Join-Path $ScriptDir "L4_testid_1.1.1.1.cfg"
$SimFile1 = Join-Path $ScriptDir "first_try.txt"
$SimFile2 = Join-Path $ScriptDir "second_try.txt"

function Run-Test {
    param($Name, $Command, $ExpectedExitCode)
    Write-Host "--- Test: $Name ---" -ForegroundColor Cyan
    $proc = Start-Process -FilePath "powershell" -ArgumentList "-ExecutionPolicy Bypass $Command" -NoNewWindow -PassThru -Wait
    
    if ($proc.ExitCode -eq $ExpectedExitCode) {
        Write-Host "[PASS] $Name (Exit Code: $($proc.ExitCode))" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] $Name (Expected: $ExpectedExitCode, Actual: $($proc.ExitCode))" -ForegroundColor Red
    }
    Write-Host ""
}

# 1. Test Config Manager integration is now implicit in L4_Config_Loader.ps1

# 2. Test Case 1: Standard Setup (first_try.txt) with RAW CONFIG
# Expected to succeed (Exit Code 0)
Run-Test -Name "Case 1: Standard Setup (first_try.txt) with Raw Config" `
    -Command "-File `"$Loader`" -ConfigFile `"$RawConfig`" -SimulationFile `"$SimFile1`"" `
    -ExpectedExitCode 0

# 3. Test Case 2: Pending Config (second_try.txt) with RAW CONFIG
# Expected to detect pending config and fail (Exit Code 1)
Run-Test -Name "Case 2: Pending Config (second_try.txt) with Raw Config" `
    -Command "-File `"$Loader`" -ConfigFile `"$RawConfig`" -SimulationFile `"$SimFile2`"" `
    -ExpectedExitCode 1
