#!/usr/bin/env python3
"""
Kleiner Webserver für das Küchen-Display.

1. Liefert die App-Dateien aus (wie `python3 -m http.server`).
2. Reicht Fahrplan-Abfragen an die Bayern-Fahrplanauskunft (EFA) weiter:
   /efa/XML_DM_REQUEST?...  ->  https://mobile.defas-fgi.de/beg/XML_DM_REQUEST?...

Warum der Umweg: Browser dürfen aus Sicherheitsgründen keine Daten von
fremden Servern lesen, wenn diese das nicht ausdrücklich erlauben (CORS).
Der EFA-Server erlaubt es nicht. Ein Server (wie hier oder das ESP32) ist
davon nicht betroffen und reicht die Antwort einfach durch.

Start:  python3 server.py        (Port 8000)
        python3 server.py 8080   (anderer Port)
Nur Python-Standardbibliothek, nichts zu installieren.
"""
import http.server
import json
import os
import socketserver
import threading
import ssl
import sys
import time
import urllib.error
import urllib.request

EFA_BASE = "https://mobile.defas-fgi.de/beg/"
# Nur diese Abfragen werden weitergereicht. Warum: Der Server soll kein
# offenes Tor ins Internet sein, sondern genau das tun, was die App braucht.
ALLOWED = {"XML_DM_REQUEST", "XML_TRIP_REQUEST2"}
CACHE_SECONDS = 30  # gleiche Abfrage innerhalb von 30 s nicht erneut senden

_cache = {}

# ---------- Gemeinsamer Datenspeicher (Einkaufsliste, Vorrat, Wochenplan, ...) ----------
# Warum auf dem Server: So sehen iPad und Handy dieselben Daten.
# Jeder Eintrag hat einen Zeitstempel "t"; bei Konflikten gewinnt der neuere
# ("last write wins"). Gelöschte Einträge bleiben als {"d": 1} markiert, damit
# ein anderes Gerät die Löschung mitbekommt.
STORE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "daten", "speicher.json")
_store_lock = threading.Lock()


def store_load():
    try:
        with open(STORE_FILE, encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def store_merge(changes):
    with _store_lock:
        data = store_load()
        for key, entry in (changes or {}).items():
            if not isinstance(entry, dict) or "t" not in entry:
                continue
            if key not in data or entry["t"] >= data[key].get("t", 0):
                data[key] = entry
        if changes:
            os.makedirs(os.path.dirname(STORE_FILE), exist_ok=True)
            tmp = STORE_FILE + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False)
            os.replace(tmp, STORE_FILE)  # Warum über eine Temp-Datei: nie halb geschriebene Daten
        return data
_ssl_context = ssl.create_default_context()
_ssl_warned = False


def fetch(url):
    """Holt eine URL; fällt bei fehlenden Zertifikaten auf ungeprüftes TLS zurück."""
    global _ssl_context, _ssl_warned
    req = urllib.request.Request(url, headers={"User-Agent": "Kuechen-Display/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=25, context=_ssl_context) as r:
            return r.read()
    except urllib.error.URLError as e:
        # Python von python.org auf dem Mac bringt manchmal keine Stammzertifikate mit.
        # Öffentliche Fahrplandaten ohne Login: dann wie das ESP32 ohne Zertifikatsprüfung.
        if isinstance(e.reason, ssl.SSLCertVerificationError):
            if not _ssl_warned:
                print("Hinweis: Zertifikatsprüfung nicht möglich, nutze ungeprüftes TLS "
                      "(wie das Bus-Display).")
                _ssl_warned = True
            _ssl_context = ssl._create_unverified_context()
            with urllib.request.urlopen(req, timeout=25, context=_ssl_context) as r:
                return r.read()
        raise


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/efa/"):
            return self.proxy_efa()
        if self.path.split("?")[0] == "/api/store":
            return self.send_json({"data": store_merge(None)})
        return super().do_GET()

    def do_POST(self):
        if self.path.split("?")[0] != "/api/store":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length) or b"{}")
        except (ValueError, json.JSONDecodeError):
            self.send_error(400, "Ungültige Daten")
            return
        self.send_json({"data": store_merge(body.get("changes"))})

    def send_json(self, obj):
        raw = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def proxy_efa(self):
        rest = self.path[len("/efa/"):]
        endpoint = rest.split("?", 1)[0]
        if endpoint not in ALLOWED:
            self.send_error(403, "Abfrage nicht erlaubt")
            return
        url = EFA_BASE + rest
        now = time.time()
        hit = _cache.get(url)
        if hit and now - hit[0] < CACHE_SECONDS:
            body = hit[1]
        else:
            try:
                body = fetch(url)
            except Exception as e:  # Netz weg, Server langsam, ...
                print("EFA-Fehler:", e)
                self.send_error(502, "Fahrplanauskunft nicht erreichbar")
                return
            _cache[url] = (now, body)
            # Alte Einträge aufräumen, damit der Speicher nicht wächst
            for k in [k for k, v in _cache.items() if now - v[0] > 300]:
                _cache.pop(k, None)
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def end_headers(self):
        # Warum: Das iPad soll geänderte App-Dateien sofort laden, nicht aus dem Cache.
        if not self.path.startswith(("/efa/", "/api/")):
            self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, fmt, *args):
        # Fahrplan-Abfragen kommen jede Minute: nur Fehler und App-Aufrufe loggen
        if ("/efa/" in (self.path or "") or "/api/" in (self.path or "")) and " 200 " in (fmt % args):
            return
        super().log_message(fmt, *args)


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    import os
    os.chdir(os.path.dirname(os.path.abspath(__file__)))  # immer aus dem App-Ordner ausliefern
    try:
        httpd = Server(("", port), Handler)
    except OSError as e:
        if e.errno == 48:  # macOS: Port belegt
            print(f"Port {port} ist schon belegt – läuft noch ein anderer Server?\n"
                  f"Alten Server beenden mit:  lsof -ti :{port} | xargs kill\n"
                  f"Oder anderen Port nutzen:  python3 server.py 8001")
            sys.exit(1)
        raise
    with httpd:
        print(f"Küchen-Display läuft auf Port {port}. Beenden mit Ctrl+C.")
        httpd.serve_forever()
