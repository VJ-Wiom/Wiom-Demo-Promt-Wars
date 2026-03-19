const express = require('express');
const cors = require('cors');
const http = require('http');
const { WebSocketServer } = require('ws');
const { parse } = require('csv-parse');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const wss = new WebSocketServer({ server });

// In-memory device store: keyed by mac_address
// { mac_address: { partner_name, partner_id, mac_address, status, timestamp } }
const devices = {};

// Load partners.csv and initialise all devices as MISSING
function loadCSV() {
  const csvPath = path.join(__dirname, 'partners.csv');
  const fileContent = fs.readFileSync(csvPath, 'utf8');

  parse(fileContent, { columns: true, trim: true }, (err, records) => {
    if (err) {
      console.error('Failed to parse partners.csv:', err.message);
      process.exit(1);
    }
    for (const row of records) {
      devices[row.mac_address] = {
        partner_name: row.partner_name,
        partner_id: row.partner_id,
        mac_address: row.mac_address,
        status: 'MISSING',
        timestamp: null,
      };
    }
    console.log(`Loaded ${records.length} partners from partners.csv`);
  });
}

// Load public key once at startup
const publicKey = crypto.createPublicKey(
  fs.readFileSync(path.join(__dirname, 'public_key.pem'), 'utf8')
);

// Broadcast the full device list to every connected WebSocket client
function broadcast() {
  const payload = JSON.stringify(Object.values(devices));
  for (const client of wss.clients) {
    if (client.readyState === client.OPEN) {
      client.send(payload);
    }
  }
}

// Send current state to a newly connected client
wss.on('connection', (ws) => {
  ws.send(JSON.stringify(Object.values(devices)));
});

// POST /upload — mark a device as VERIFIED
app.post('/upload', (req, res) => {
  const { mac, timestamp, signature } = req.body;

  if (!mac || !timestamp) {
    return res.status(400).json({ error: 'mac and timestamp are required' });
  }

  const device = devices[mac];
  if (!device) {
    return res.status(404).json({ error: 'MAC address not found in partner list' });
  }

  // Verify RSA signature of "mac|timestamp"
  try {
    const message = Buffer.from(`${mac}|${timestamp}`);
    const sigBuffer = Buffer.from(signature, 'base64');
    const valid = crypto.verify('sha256', message, publicKey, sigBuffer);
    if (!valid) {
      return res.status(400).json({ success: false, reason: 'invalid signature' });
    }
  } catch {
    return res.status(400).json({ success: false, reason: 'invalid signature' });
  }

  device.status = 'VERIFIED';
  device.timestamp = timestamp;

  broadcast();

  return res.json({ success: true, device });
});

// GET /report — return all devices with current state
app.get('/report', (req, res) => {
  res.json(Object.values(devices));
});

// GET /health
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

const PORT = 3001;

loadCSV();

server.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});

// Serve operator panel
const path2 = require('path');
app.get('/', (req, res) => {
  res.sendFile(path2.join(__dirname, 'files', 'operator.html'));
});

// Proxy Flask verify
app.get('/proxy/verify', async (req, res) => {
  try {
    const r = await fetch('http://localhost:8080/verify');
    const data = await r.json();
    res.json(data);
  } catch { res.status(500).json({ error: 'Flask unreachable' }); }
});

// Proxy router check
app.get('/proxy/router', async (req, res) => {
  try {
    const r = await fetch('http://172.16.2.1:5000');
    const data = await r.text();
    res.send(data);
  } catch { res.status(500).json({ error: 'Router unreachable' }); }
});
