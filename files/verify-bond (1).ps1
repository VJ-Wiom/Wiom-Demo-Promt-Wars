# Wiom Demo - Bulletproof Verify Script
# Handles: WiFi check, Flask auto-start, Node auto-start, router nc auto-deploy

$DEMO_DIR    = "C:\Users\abc\Desktop\wiom-demo"
$SSH_KEY     = "$env:USERPROFILE\.ssh\gx-key1"
$ROUTER_IP   = "172.16.2.1"
$ROUTER_USER = "wiom"
$PASSPHRASE  = "smortsecurity"
$FLASK_URL   = "http://localhost:8080/verify"
$NODE_URL    = "http://localhost:3001"
$ROUTER_NC   = "http://$ROUTER_IP`:5000"
$BOND_WIFI   = "dhoni_0000"
$BOND_PASS   = "12345678"

function Write-Step($msg) { Write-Host "[*] $msg" -ForegroundColor Yellow }
function Write-OK($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "[!!] $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "   WIOM VERIFICATION - BULLETPROOF MODE" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. ENSURE ON BOND WIFI ─────────────────────────────────
Write-Step "Checking WiFi connection..."
$wifiIP = (Get-NetIPAddress -InterfaceAlias "Wi-Fi" -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
if ($wifiIP -notlike "172.16.2.*") {
    Write-Fail "Not on Bond WiFi (current IP: $wifiIP)"
    Write-Host "     Attempting to connect to $BOND_WIFI..." -ForegroundColor Yellow
    netsh wlan connect name="$BOND_WIFI" | Out-Null
    Start-Sleep -Seconds 5
    $wifiIP = (Get-NetIPAddress -InterfaceAlias "Wi-Fi" -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
    if ($wifiIP -notlike "172.16.2.*") {
        Write-Fail "Still not on Bond WiFi. Please manually connect to $BOND_WIFI and re-run."
        exit 1
    }
}
Write-OK "On Bond WiFi - IP: $wifiIP"

# ── 2. ENSURE FLASK IS RUNNING ─────────────────────────────
Write-Step "Checking Flask server..."
try {
    Invoke-RestMethod -Uri $FLASK_URL -Method GET -ErrorAction Stop | Out-Null
    Write-OK "Flask is running"
} catch {
    Write-Fail "Flask not running - starting it now..."
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$DEMO_DIR'; python bond_firmware.py"
    Start-Sleep -Seconds 5
    try {
        Invoke-RestMethod -Uri $FLASK_URL -Method GET -ErrorAction Stop | Out-Null
        Write-OK "Flask started successfully"
    } catch {
        Write-Fail "Flask failed to start. Check bond_firmware.py manually."
        exit 1
    }
}

# ── 3. ENSURE NODE IS RUNNING ──────────────────────────────
Write-Step "Checking Node backend..."
try {
    Invoke-RestMethod -Uri "$NODE_URL/health" -Method GET -ErrorAction Stop | Out-Null
    Write-OK "Node is running"
} catch {
    Write-Fail "Node not running - starting it now..."
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$DEMO_DIR'; node server.js"
    Start-Sleep -Seconds 5
    try {
        Invoke-RestMethod -Uri "$NODE_URL/health" -Method GET -ErrorAction Stop | Out-Null
        Write-OK "Node started successfully"
    } catch {
        Write-Fail "Node failed to start. Check server.js manually."
        exit 1
    }
}

# ── 4. ENSURE ROUTER NC SERVER IS RUNNING ──────────────────
Write-Step "Checking router nc server at $ROUTER_IP`:5000..."
$routerAlive = $false
try {
    $r = Invoke-WebRequest -Uri $ROUTER_NC -TimeoutSec 4 -ErrorAction Stop
    if ($r.StatusCode -eq 200) { $routerAlive = $true }
} catch {}

if ($routerAlive) {
    Write-OK "Router nc server is already running"
} else {
    Write-Fail "Router nc server not responding - deploying via SSH..."

    # Get proof first to embed in router script
    $proof = Invoke-RestMethod -Uri $FLASK_URL -Method GET
    $RESP = $proof | ConvertTo-Json -Compress

    # Build the shell script to run on router
    $remoteCmd = "pkill nc 2>/dev/null; echo '#!/bin/sh' > /tmp/s.sh; echo 'while true; do printf ""HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n$RESP"" | nc -l -p 5000; done' >> /tmp/s.sh; chmod +x /tmp/s.sh; /tmp/s.sh " + '"' + "&" + '"'

    # Try SSH
    try {
        $sshArgs = "-o StrictHostKeyChecking=no -o ConnectTimeout=10 -i `"$SSH_KEY`" $ROUTER_USER@$ROUTER_IP `"$remoteCmd`""
        $proc = Start-Process -FilePath "ssh" -ArgumentList $sshArgs -PassThru -WindowStyle Hidden
        Start-Sleep -Seconds 6

        # Verify it worked
        try {
            $r2 = Invoke-WebRequest -Uri $ROUTER_NC -TimeoutSec 4 -ErrorAction Stop
            if ($r2.StatusCode -eq 200) {
                Write-OK "Router nc server deployed and running!"
                $routerAlive = $true
            }
        } catch {
            Write-Fail "Router still not responding after SSH deploy."
            Write-Host ""
            Write-Host "  MANUAL FIX: SSH into router and run:" -ForegroundColor Yellow
            Write-Host "  ssh -i ~/.ssh/gx-key1 wiom@172.16.2.1" -ForegroundColor White
            Write-Host "  Then type: /tmp/serve.sh " -ForegroundColor White
            Write-Host "  (passphrase: smortsecurity)" -ForegroundColor White
            Write-Host ""
            Write-Host "  Press any key once done..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    } catch {
        Write-Fail "SSH failed: $_"
    }
}

# ── 5. GET SIGNED PROOF ────────────────────────────────────
Write-Step "Getting signed proof from Flask..."
try {
    $proof = Invoke-RestMethod -Uri $FLASK_URL -Method GET -ErrorAction Stop
    $mac = $proof.mac
    $sig = $proof.signature
    $ts  = $proof.timestamp
    Write-OK "Got proof for MAC: $mac"
} catch {
    Write-Fail "Could not get proof from Flask."
    exit 1
}

# ── 6. POST TO NODE BACKEND ────────────────────────────────
Write-Step "Posting proof to verification backend..."
try {
    $body = "{`"mac`":`"$mac`",`"signature`":`"$sig`",`"timestamp`":`"$ts`"}"
    $result = Invoke-RestMethod -Uri "$NODE_URL/upload" -Method POST -ContentType "application/json" -Body $body -ErrorAction Stop
    if ($result.success) {
        Write-Host ""
        Write-Host "======================================================" -ForegroundColor Green
        Write-Host "   VERIFIED: $($result.device.partner_name)" -ForegroundColor Green
        Write-Host "   MAC:      $($result.device.mac_address)" -ForegroundColor Green
        Write-Host "   STATUS:   $($result.device.status)" -ForegroundColor Green
        Write-Host "======================================================" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Fail "Verification failed: $($result.reason)"
    }
} catch {
    Write-Fail "Node backend error: $_"
}

Write-Host "  Check the dashboard for live update!" -ForegroundColor Cyan
Write-Host ""
