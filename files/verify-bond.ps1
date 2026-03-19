# Wiom Demo - Router Verify Script
# Must be on Bond WiFi (dhoni_0000) before running!

$SSH_KEY     = "$env:USERPROFILE\.ssh\gx-key1"
$ROUTER_IP   = "172.16.2.1"
$ROUTER_USER = "wiom"
$FLASK_URL   = "http://localhost:8080/verify"
$NODE_URL    = "http://localhost:3001"

Write-Host ""
Write-Host "  Wiom - Router Verification" -ForegroundColor Cyan
Write-Host ""

# Check WiFi
$wifiIP = (Get-NetIPAddress -InterfaceAlias "Wi-Fi" -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
if ($wifiIP -notlike "172.16.2.*") {
    Write-Host "[!] Not on Bond WiFi! Current WiFi IP: $wifiIP" -ForegroundColor Red
    Write-Host "    Connect to dhoni_0000 first, then re-run." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] On Bond WiFi - IP: $wifiIP" -ForegroundColor Green

# Get signed proof from Flask
Write-Host "[*] Getting signed proof from Flask..." -ForegroundColor Yellow
try {
    $proof = Invoke-RestMethod -Uri $FLASK_URL -Method GET -ErrorAction Stop
    $mac = $proof.mac
    $sig = $proof.signature
    $ts  = $proof.timestamp
    Write-Host "[OK] Got proof for MAC: $mac" -ForegroundColor Green
} catch {
    Write-Host "[!] Flask not running! Start bond_firmware.py first." -ForegroundColor Red
    exit 1
}

# POST proof directly to Node backend (skip SSH deploy, nc already running)
Write-Host "[*] Posting proof to verification backend..." -ForegroundColor Yellow
try {
    $body = "{`"mac`":`"$mac`",`"signature`":`"$sig`",`"timestamp`":`"$ts`"}"
    $result = Invoke-RestMethod -Uri "$NODE_URL/upload" -Method POST -ContentType "application/json" -Body $body -ErrorAction Stop
    if ($result.success) {
        Write-Host "[OK] VERIFIED: $($result.device.partner_name)" -ForegroundColor Green
        Write-Host "     MAC: $($result.device.mac_address)" -ForegroundColor Green
        Write-Host "     Status: $($result.device.status)" -ForegroundColor Green
    } else {
        Write-Host "[!] Verification failed: $($result.reason)" -ForegroundColor Red
    }
} catch {
    Write-Host "[!] Node backend error: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "  Done! Check the dashboard." -ForegroundColor Cyan
Write-Host ""
