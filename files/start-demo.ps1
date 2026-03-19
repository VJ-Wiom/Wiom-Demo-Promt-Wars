# Wiom Demo - Full Startup Script

$DEMO_DIR = "C:\Users\abc\Desktop\wiom-demo"
$BOND_WIFI = "dhoni_0000"

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  WIOM ROUTER VERIFICATION DEMO - STARTUP" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

# STEP 1: Kill old processes
Write-Host "[1/5] Cleaning up old processes..." -ForegroundColor Yellow
Stop-Process -Name node -Force -ErrorAction SilentlyContinue
Stop-Process -Name python -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Write-Host "      Done." -ForegroundColor Green

# STEP 2: Start Flask
Write-Host "[2/5] Starting Flask signature server..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$DEMO_DIR'; python bond_firmware.py"
Start-Sleep -Seconds 3
Write-Host "      Flask running on http://localhost:8080" -ForegroundColor Green

# STEP 3: Start Node
Write-Host "[3/5] Starting Node verification backend..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$DEMO_DIR'; node server.js"
Start-Sleep -Seconds 3
Write-Host "      Node running on http://localhost:3001" -ForegroundColor Green

# STEP 4: Open Dashboard
Write-Host "[4/5] Opening live dashboard..." -ForegroundColor Yellow
$dashboardPath = "$DEMO_DIR\files\dashboard.html"
Start-Process $dashboardPath
Write-Host "      Dashboard opened in browser." -ForegroundColor Green

# STEP 5: Instructions
Write-Host ""
Write-Host "[5/5] Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  NEXT: Switch WiFi to $BOND_WIFI" -ForegroundColor Yellow
Write-Host "  THEN: Run .\verify-bond.ps1" -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""
