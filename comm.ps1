param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$FilePath
)

chcp 65001
$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

# ===== USB Serial Port 자동 검색 (Get-PnpDevice 사용) =====
$port = Get-PnpDevice -Class Ports -Status OK |
Where-Object {
    $_.FriendlyName -like "*USB Serial Port*" -or
    $_.FriendlyName -like "*USB-SERIAL*" -or
    $_.FriendlyName -like "*USB Serial*"      # 필요 시 패턴 추가
} |
Select-Object -First 1

if (-not $port) {
    Write-Error "USB 시리얼 포트를 찾지 못했습니다."
    exit 1
}

if ($port.FriendlyName -notmatch "COM(\d+)") {
    Write-Error "FriendlyName 에서 COM 포트 번호를 찾지 못했습니다: $($port.FriendlyName)"
    exit 1
}

$PortName = "COM$($Matches[1])"
Write-Host "찾은 USB 시리얼 포트: $PortName ($($port.FriendlyName))"
# =========================================================

# 통신 속도 (기본 9600bps)
$BaudRate = 9600

# 패리티 / 데이터 비트 / 스톱 비트 (8N1)
$Parity = [System.IO.Ports.Parity]::None
$DataBits = 8
$StopBits = [System.IO.Ports.StopBits]::One

# 장비가 요구하는 명령어 (예: "RESTORE" + CRLF)
$Command = "RESTORE"
$CommandTerminator = "`r`n"  # CRLF

# 파일 존재 여부 확인
if (-not (Test-Path -LiteralPath $FilePath)) {
    Write-Error "파일을 찾을 수 없습니다: $FilePath"
    exit 1
}

# 파일 전체를 바이너리로 읽기
try {
    $fileBytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $FilePath))
}
catch {
    Write-Error "파일을 읽는 중 오류 발생: $($_.Exception.Message)"
    exit 1
}

# 시리얼 포트 생성
$portObj = New-Object System.IO.Ports.SerialPort $PortName, $BaudRate, $Parity, $DataBits, $StopBits
$portObj.ReadTimeout = 3000
$portObj.WriteTimeout = 3000

try {
    # 포트 열기
    $portObj.Open()
    Write-Host "시리얼 포트 열림: $PortName ($BaudRate bps)"

    # 1) 명령어 전송
    $cmdToSend = $Command + $CommandTerminator
    Write-Host "명령어 전송: '$cmdToSend'"
    $portObj.Write($cmdToSend)

    # 장비가 준비될 시간 약간 대기 (필요 시 조정)
    Start-Sleep -Milliseconds 200

    # 2) 파일 데이터 전송 (바이너리)
    Write-Host "파일 전송 시작: $FilePath  (바이트 수: $($fileBytes.Length))"
    $portObj.BaseStream.Write($fileBytes, 0, $fileBytes.Length)
    $portObj.BaseStream.Flush()

    Write-Host "파일 전송 완료."
}
catch {
    Write-Error "시리얼 전송 중 오류 발생: $($_.Exception.Message)"
    exit 1
}
finally {
    if ($portObj -and $portObj.IsOpen) {
        $portObj.Close()
        $portObj.Dispose()
        Write-Host "시리얼 포트 닫힘: $PortName"
    }
}