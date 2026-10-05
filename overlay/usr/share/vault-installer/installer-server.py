#!/usr/bin/env python3
"""
VaultOS Local Installer Backend Server
Serves the HTML/SVG frontend and handles installation API endpoints
"""

import http.server
import socketserver
import os
import json
import subprocess
import sys

PORT = 8765
WEB_DIR = os.path.join(os.path.dirname(__file__), "web")

class InstallerHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def do_GET(self):
        if self.path == "/api/disks":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            disks = self.get_available_disks()
            self.wfile.write(json.dumps({"disks": disks}).encode("utf-8"))
        else:
            super().do_GET()

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length > 0 else b"{}"

        if self.path == "/api/try-os":
            print("[INFO] Try OS requested via API. Closing installer window...")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status": "ok", "message": "Entering Try OS mode"}')
            # Signal Sway/Firefox to close installer window
            subprocess.Popen(["swaymsg", "[title=\"VaultOS Installer\"] kill"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.Popen(["pkill", "-f", "firefox.*vault-installer"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        elif self.path == "/api/install":
            print("[INFO] Installation started via API:", body.decode("utf-8", errors="ignore"))
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status": "installing"}')

        elif self.path == "/api/reboot":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status": "rebooting"}')
            subprocess.Popen(["systemctl", "reboot"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        elif self.path == "/api/poweroff":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status": "powering_off"}')
            subprocess.Popen(["systemctl", "poweroff"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            self.send_response(404)
            self.end_headers()

    def get_available_disks(self):
        disks = []
        try:
            res = subprocess.run(
                ["lsblk", "-J", "-b", "-d", "-o", "NAME,SIZE,MODEL,TYPE,TRAN"],
                capture_output=True,
                text=True
            )
            if res.returncode == 0:
                data = json.loads(res.stdout)
                for dev in data.get("blockdevices", []):
                    name = dev.get("name", "")
                    if name.startswith("loop") or name.startswith("zram") or name.startswith("sr"):
                        continue
                    size_bytes = int(dev.get("size", 0))
                    size_gb = f"{size_bytes / (1024**3):.1f} GB"
                    model = dev.get("model") or "Penyimpanan Utama"
                    disks.append({
                        "name": f"/dev/{name}",
                        "size": size_gb,
                        "model": model.strip()
                    })
        except Exception as e:
            print("[WARN] Error listing disks via lsblk:", e)

        if not disks:
            # Fallback detected via /sys/block
            try:
                for d in os.listdir("/sys/block"):
                    if d.startswith(("sd", "vd", "nvme")):
                        disks.append({
                            "name": f"/dev/{d}",
                            "size": "Terdeteksi",
                            "model": "Media Penyimpanan Internal"
                        })
            except Exception:
                pass

        return disks

def main():
    os.chdir(WEB_DIR)
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", PORT), InstallerHandler) as httpd:
        print(f"[VaultOS Installer Server] Melayani pada http://127.0.0.1:{PORT}")
        httpd.serve_forever()

if __name__ == "__main__":
    main()
