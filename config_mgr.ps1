<#
.SYNOPSIS
    Alteon L4 Switch Config Manager
    Extracts valid configuration commands from a raw dump file.

.DESCRIPTION
    Based on the rules provided in config_mgr.md:
    1. Reads the input text file.
    2. Ignores comments (lines starting with "/*") and header/footer info.
    3. Extracts the configuration block starting from "/c/sys/access".
    4. Stops extraction at the final "/" line.
    5. Saves the result to a .cfg file.

.PARAMETER InputFile
    The path to the source configuration file (e.g., L4_testid_1.1.1.1.txt).

.EXAMPLE
    .\config_mgr.ps1 -InputFile "L4_testid_1.1.1.1.txt"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile
)

$InputPath = Resolve-Path $InputFile
if (-not (Test-Path $InputPath)) {
    Write-Error "Input file not found: $InputFile"
    exit 1
}

# Define Output Path (.txt -> .cfg)
$Directory = Split-Path -Parent $InputPath
$FileName = [System.IO.Path]::GetFileNameWithoutExtension($InputPath)
$OutputPath = Join-Path -Path $Directory -ChildPath "$FileName.cfg"

Write-Host "Reading $InputPath..." -ForegroundColor Cyan

$lines = Get-Content $InputPath
$cleanLines = @()
$capture = $false

foreach ($line in $lines) {
    $trimmed = $line.Trim()

    # Rule 3: Ignore lines starting with "/*"
    if ($trimmed.StartsWith("/*")) {
        continue
    }

    # Rule 4: Start capturing from "/c/sys/access"
    if (-not $capture -and $trimmed -eq "/c/sys/access") {
        $capture = $true
    }

    if ($capture) {
        $cleanLines += $line # Preserve original indentation? Keeping original line for now.
        
        # Rule 5: End capturing at "/" (but include it?)
        # The requirement says "실제 컨피그의 내용의 끝은 "/" 로 시작한다."
        # Usually "/" is the command to go up or exit, so we likely include it and stop.
        if ($trimmed -eq "/") {
            break
        }
    }
}

if ($cleanLines.Count -eq 0) {
    Write-Warning "No valid configuration found matching rules."
    exit
}

# Save to .cfg file
$cleanLines | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "Configuration extracted to: $OutputPath" -ForegroundColor Green
