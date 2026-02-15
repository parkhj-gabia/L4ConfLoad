<#
.SYNOPSIS
    L4 Switch Configuration Loader
    Connects to an L4 switch via Serial Port (or simulation file) and uploads a configuration.

.DESCRIPTION
    This script automates the initial configuration of an L4 switch.
    It supports two modes:
    1. Real Mode: Connects to a physical COM port.
    2. Simulation Mode: Reads switch output from a text file to simulate the interaction.

.PARAMETER ComPort
    The COM port to connect to (e.g., "COM5"). Default is "COM5".

.PARAMETER BaudRate
    The baud rate for the serial connection. Default is 9600.

.PARAMETER ConfigFile
    The path to the configuration file to upload.

.PARAMETER SimulationFile
    (Optional) The path to a text file containing simulated switch output.
    If provided, the script runs in Simulation Mode.
#>

param(
    [string]$ComPort,
    [int]$BaudRate = 9600,
    [string]$ConfigFile,
    [string]$SimulationFile,
    [switch]$Help
)

chcp 65001
$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8


if ($Help) {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "      L4 스위치 설정 로더 (L4 Config Loader)      " -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "목적:"
    Write-Host "  시리얼 포트를 통해 Alteon L4 스위치의 초기 설정을 자동화합니다."
    Write-Host "  로그인 처리, 보류 중인 설정 확인, 설정 마법사 거절,"
    Write-Host "  그리고 정제된 설정 파일 업로드를 수행합니다."
    Write-Host ""
    Write-Host "기능:"
    Write-Host "  1. 실제 모드 (Real Mode): 실제 COM 포트에 연결합니다 (기본값: COM5)."
    Write-Host "  2. 시뮬레이션 모드 (Simulation Mode): 텍스트 파일을 사용하여 스위치 출력을 시뮬레이션합니다."
    Write-Host "  3. 자동 정제 (Auto-Cleaning): 원본 텍스트 파일에서 유효한 설정 명령어만 자동으로 추출합니다."
    Write-Host "     (주석 무시, '/c/sys/access' 부터 '/' 까지의 블록만 추출)"
    Write-Host ""
    Write-Host "사용법 (Usage):"
    Write-Host "  .\L4_Config_Loader.ps1 -ConfigFile `"L4_testid_1.1.1.1.txt`" -ComPort `"COM5`""
    Write-Host "  .\L4_Config_Loader.ps1 -ConfigFile `"L4_testid_1.1.1.1.txt`" -SimulationFile `"first_try.txt`""
    exit 0
}

if ([string]::IsNullOrEmpty($ConfigFile)) {
    Write-Host "Usage: .\L4_Config_Loader.ps1 -ConfigFile `"L4_testid_1.1.1.1.txt`" -SimulationFile `"first_try.txt`""
    exit 0
}



# --- Helper Functions ---

function Get-L4SerialPort {
    Write-Host "Searching for USB Serial Port..." -ForegroundColor Cyan
    
    $port = Get-PnpDevice -Class Ports -Status OK |
    Where-Object {
        $_.FriendlyName -like "*USB Serial Port*" -or
        $_.FriendlyName -like "*USB-SERIAL*" -or
        $_.FriendlyName -like "*USB Serial*" 
    } |
    Select-Object -First 1

    if (-not $port) {
        return $null
    }

    if ($port.FriendlyName -match "COM(\d+)") {
        return "COM$($Matches[1])"
    }

    return $null
}

function Get-CleanedConfig {
    param(
        [string]$InputPath
    )
    
    if (-not (Test-Path $InputPath)) {
        Write-Error "Config file not found: $InputPath"
        return $null
    }

    Write-Host "Reading and cleaning $InputPath..." -ForegroundColor Cyan

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
            $cleanLines += $line 
            
            # Rule 5: End capturing at "/"
            if ($trimmed -eq "/") {
                break
            }
        }
    }

    if ($cleanLines.Count -eq 0) {
        Write-Warning "No valid configuration found matching rules."
    }

    return $cleanLines
}

function Send-Command {
    param(
        [string]$Command,
        [System.IO.Ports.SerialPort]$Port
    )
    # Only write to port if it's real. In sim mode, we just log.
    if ($Port -ne $null -and $Port.IsOpen) {
        $Port.WriteLine($Command)
    }
    Write-Host "Sent: $Command" -ForegroundColor Cyan
}

function Read-Response {
    param(
        [System.IO.Ports.SerialPort]$Port,
        [System.IO.StreamReader]$SimReader
    )
    
    if ($SimReader -ne $null) {
        # Simulation Mode
        if ($SimReader.EndOfStream) { return $null }
        $line = $SimReader.ReadLine()
        Start-Sleep -Milliseconds 50 # Simulate delay
        return "$line`n" # Append newline to mimic serial read line
    }
    elseif ($Port -ne $null -and $Port.IsOpen) {
        # Real Mode
        try {
            # Read existing buffer
            $content = $Port.ReadExisting()
            if ([string]::IsNullOrEmpty($content)) {
                Start-Sleep -Milliseconds 100
            }
            return $content
        }
        catch {
            return $null
        }
    }
    return $null
}

# --- Main Script ---

$ConfigPath = Resolve-Path $ConfigFile
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigFile"
    exit 1
}

$SimReader = $null
$Port = $null

try {
    if (-not [string]::IsNullOrEmpty($SimulationFile)) {
        $SimPath = Resolve-Path $SimulationFile
        Write-Host "--- SIMULATION MODE: Use $SimPath ---" -ForegroundColor Yellow
        $SimReader = [System.IO.StreamReader]::new($SimPath)
    }
    else {
        # Real Mode: Auto-detect or use provided COM port
        if ([string]::IsNullOrEmpty($ComPort)) {
            $DetectedPort = Get-L4SerialPort
            if ($DetectedPort) {
                $ComPort = $DetectedPort
                Write-Host "Auto-detected Serial Port: $ComPort" -ForegroundColor Green
            }
            else {
                Write-Error "No USB Serial Port found and no ComPort specified."
                exit 1
            }
        }

        Write-Host "--- REAL MODE: $ComPort ($BaudRate) ---" -ForegroundColor Green
        $Port = [System.IO.Ports.SerialPort]::new($ComPort, $BaudRate, [System.IO.Ports.Parity]::None, 8, [System.IO.Ports.StopBits]::One)
        $Port.Open()
    }

    # State Variables
    $buffer = ""
    $step = "WAIT_PASSWORD"
    $isDone = $false

    # Loop until done or simulated file ends
    while (-not $isDone) {
        $chunk = Read-Response -Port $Port -SimReader $SimReader
        
        if ($chunk -eq $null -and $SimReader -ne $null) {
            # End of simulation file
            break 
        }

        if ($chunk -ne $null) {
            $buffer += $chunk
            # Print received data for debug
            Write-Host $chunk -NoNewline
        }

        # --- State Machine ---

        # 1. Wait for Password Prompt
        if ($step -eq "WAIT_PASSWORD") {
            if ($buffer -match "Enter password:") {
                Send-Command -Command "admin" -Port $Port
                $buffer = "" # Clear buffer after match
                $step = "WAIT_PROMPT"
            }
        }
        
        # 2. Analyze Prompt/Note
        elseif ($step -eq "WAIT_PROMPT") {
            if ($buffer -match "Would you like to run ""Set Up"" to configure the switch\? \[y/n\]") {
                # Case 1: Setup Prompt
                Send-Command -Command "n" -Port $Port
                $step = "WAIT_MAIN_PROMPT" 
                $buffer = ""
            }
            elseif ($buffer -match "Confirm seeing above note \[y\]:") {
                # Case 2: Pending Config Note
                Write-Host "`n[ERROR] Initialization required. Pending configuration changes detected." -ForegroundColor Red
                $isDone = $true
                exit 1 # Exit with error code
            }
        }

        # 3. Wait for Main Prompt
        elseif ($step -eq "WAIT_MAIN_PROMPT") {
            # Looking for ">> Main#" or similar prompt
            if ($buffer -match ">> Main#") {
                Send-Command -Command "lines 0" -Port $Port
                $buffer = ""
                $step = "UPLOAD"
            }
        }
        
        # 4. Upload Configuration
        elseif ($step -eq "UPLOAD") {
            Write-Host "`n[INFO] Starting Configuration Upload..." -ForegroundColor Green
            
            # Use the internal function to get cleaned config lines
            $configLines = Get-CleanedConfig -InputPath $ConfigPath
            
            if ($configLines -eq $null -or $configLines.Count -eq 0) {
                Write-Error "No valid configuration lines to upload."
                $isDone = $true
                break
            }

            foreach ($line in $configLines) {
                # Skip empty lines or comments if they shouldn't be sent?
                # The user requirement was "read file line by line and send"
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    # Print what we are sending for visibility
                    Write-Host "Uploading: $line" -ForegroundColor Gray
                    Send-Command -Command $line -Port $Port
                    Start-Sleep -Milliseconds 50 # Small delay between lines
                }
            }
            Write-Host "`n[SUCCESS] Configuration Transfer Complete." -ForegroundColor Green
            $isDone = $true
        }
    }
}
catch {
    Write-Error "An error occurred: $_"
}
finally {
    if ($Port -ne $null -and $Port.IsOpen) {
        $Port.Close()
        Write-Host "Serial Port Closed."
    }
    if ($SimReader -ne $null) {
        $SimReader.Close()
        Write-Host "Simulation Reader Closed."
    }
}
