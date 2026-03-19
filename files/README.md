# Wiom Router Verification Demo
## Complete Setup & Run Guide

---

## FILES — Copy all to `C:\Users\abc\Desktop\wiom-demo\`
- `dashboard.html` — Live audience dashboard (open in browser)
- `start-demo.ps1` — One-click full startup
- `verify-bond.ps1` — Re-verify router any time
- `bond_firmware.py` — Flask RSA server (already exists)
- `server.js` — Node backend (already exists)
- `partners.csv` — Partner list (already exists, Bond MAC updated)

---

## ONE-TIME SETUP (do this once)

1. Copy all new files to `C:\Users\abc\Desktop\wiom-demo\`
2. Open PowerShell as Administrator
3. Run:
   ```
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

---

## DEMO DAY — STEP BY STEP

### Before the presentation (on internet WiFi):
1. Open PowerShell as Administrator
2. Run:
   ```
   cd C:\Users\abc\Desktop\wiom-demo
   .\start-demo.ps1
   ```
3. This will:
   - Kill old processes
   - Start Flask on port 8080
   - Start Node on port 3001
   - Open dashboard in browser

### Live demo moment (switch to Bond WiFi):
1. Manually connect WiFi to `dhoni_0000` (password: `12345678`)
2. Run:
   ```
   .\verify-bond.ps1
   ```
3. Watch the dashboard — Bond Partner flips from MISSING → VERIFIED live!

---

## MANUAL COMMANDS (if scripts fail)

### Start Flask:
```
cd C:\Users\abc\Desktop\wiom-demo
python bond_firmware.py
```

### Start Node:
```
cd C:\Users\abc\Desktop\wiom-demo
node server.js
```

### Get signed proof:
```
curl http://localhost:8080/verify
```

### Post to backend:
```
Invoke-RestMethod -Uri http://localhost:3001/upload -Method POST -ContentType "application/json" -Body '{"mac":"04:E8:B9:0B:AE:90","signature":"<sig>","timestamp":"<ts>"}'
```

### Check report:
```
curl http://localhost:3001/report
```

---

## NETWORK CHEATSHEET
- Bond WiFi: `dhoni_0000` / password: `12345678`
- Router SSH: `ssh -i ~/.ssh/gx-key1 wiom@172.16.2.1` (passphrase: `smortsecurity`)
- Router web: `http://172.16.2.1:50080`
- Flask: `http://localhost:8080/verify`
- Node: `http://localhost:3001`
- Router nc server: `http://172.16.2.1:5000`

---

## TROUBLESHOOTING

| Problem | Fix |
|---|---|
| Port 3001 in use | `Stop-Process -Name node -Force` |
| Port 8080 in use | `Stop-Process -Name python -Force` |
| SSH connection timeout | Make sure WiFi is on `dhoni_0000` |
| MAC not found | Check `partners.csv` has `04:E8:B9:0B:AE:90` for Bond Partner |
| Dashboard blank | Check Node is running on port 3001 |
