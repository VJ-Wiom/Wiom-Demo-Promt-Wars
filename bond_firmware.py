import base64
import hashlib
import json
import os
import time
import uuid

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from flask import Flask, jsonify
from flask_cors import CORS

# ── CONFIG ────────────────────────────────────────────────────────────────────
PRIVATE_KEY_PATH = "private_key.pem"
PUBLIC_KEY_PATH  = "public_key.pem"
PORT             = 8080

# ── KEY MANAGEMENT ────────────────────────────────────────────────────────────

def generate_keys():
    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
    )
    with open(PRIVATE_KEY_PATH, "wb") as f:
        f.write(private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.TraditionalOpenSSL,
            encryption_algorithm=serialization.NoEncryption(),
        ))
    with open(PUBLIC_KEY_PATH, "wb") as f:
        f.write(private_key.public_key().public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo,
        ))
    print("Generated new RSA key pair.")
    return private_key


def load_keys():
    with open(PRIVATE_KEY_PATH, "rb") as f:
        private_key = serialization.load_pem_private_key(f.read(), password=None)
    print("Loaded existing RSA key pair.")
    return private_key


def get_or_create_keys():
    if os.path.exists(PRIVATE_KEY_PATH) and os.path.exists(PUBLIC_KEY_PATH):
        return load_keys()
    return generate_keys()

# ── MAC ADDRESS ───────────────────────────────────────────────────────────────

def get_mac():
    # uuid.getnode() returns the hardware address as a 48-bit integer.
    # Format it as a standard colon-separated MAC string.
    raw = uuid.getnode()
    mac_bytes = raw.to_bytes(6, byteorder="big")
    return ":".join(f"{b:02X}" for b in mac_bytes)

# ── FLASK APP ─────────────────────────────────────────────────────────────────

def create_app(private_key, mac):
    app = Flask(__name__)
    CORS(app)

    @app.route("/health")
    def health():
        return jsonify({"status": "ok", "mac": mac})

    @app.route("/verify")
    def verify():
        timestamp = str(int(time.time()))
        message   = f"{mac}|{timestamp}".encode()

        signature_bytes = private_key.sign(
            message,
            padding.PKCS1v15(),
            hashes.SHA256(),
        )
        signature_b64 = base64.b64encode(signature_bytes).decode()

        return jsonify({
            "mac":       mac,
            "timestamp": timestamp,
            "signature": signature_b64,
        })

    return app

# ── ENTRY POINT ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    private_key = get_or_create_keys()
    mac         = get_mac()

    print(f"Bond is live. MAC: {mac}. Waiting for verification requests.")

    app = create_app(private_key, mac)
    app.run(host="0.0.0.0", port=PORT)
