# Smart Home (Lampen) – Design

Stand: 24.11.2026 · Status: **Entwurf, wartet auf Freigabe**

## Absicht und Warum

Carl will seine Lampen aus Hubert heraus schalten, vor allem am Wand-iPad in der Küche: tippen, Licht an. Die Lampen hängen an **HBN-WLAN-Steckdosen**. Das sind Tuya-Geräte, sie laufen über Smart Life bzw. Tuya Smart und können kein Apple Home.

## Ziele

- Neuer Bucket **„Smart Home“** (Art: Glance, mit App), wie die anderen pro Gerät ein-/ausblendbar.
- **Widget:** große Kacheln pro Steckdose mit Name und Zustand. Ein Tipp schaltet um.
- **App:** alle Steckdosen als Liste mit Schalter, dazu „Alle aus“, Umbenennen und Neu laden.
- **Einmalige Einrichtung „Mit Tuya verbinden“** in den Einstellungen des Buckets: Zugangsdaten des Tuya-Entwicklerkontos eingeben. Hubert holt alle Steckdosen mit Namen und Schlüsseln und findet sie im WLAN.
- Neue Steckdosen per Knopf „Geräte neu laden“ nachholen.
- Schalten **lokal im WLAN**, spürbar unter 0,5 s. Die Tuya-Cloud wird nur bei der Einrichtung und beim Neuladen gebraucht.

## Nicht-Ziele

- Keine Steuerung von unterwegs (Carl, 24.11.: „Es reicht mir zuhause“).
- Kein Dimmen, keine Farben, keine Zeitpläne, keine Szenen, kein Stromverbrauch.
- Keine anderen Marken (Shelly, Hue, Apple Home) in dieser Runde. Die Bauweise lässt weitere Gerätearten später zu, wie bei der Fernbedienung.
- Kein Home Assistant und kein Zusatzgerät.

## Anti-Ziele (Fehlschlag, auch wenn es technisch läuft)

- Schalten dauert spürbar länger als 1 s, oder die Kachel zeigt einen falschen Zustand.
- Hubert hört auf zu funktionieren, sobald der kostenlose Tuya-Cloud-Zugang abläuft. Im Alltag darf die Cloud nicht gebraucht werden.
- Fehler ohne Erklärung, statt klarer Ursachen wie „Steckdose nicht im WLAN gefunden“ oder „Schlüssel passt nicht mehr – Geräte neu laden“.
- Die Tuya-Zugangsdaten landen auf dem Server.

## Einschränkungen

- iOS 15 (iPad mini 4), Swift-5-Modus – siehe Technik-Regeln im Projektwissen.
- **Tuya-Cloud (nur zur Einrichtung):**
  - Tuya OpenAPI, Rechenzentrum Mitteleuropa (`openapi.tuyaeu.com`).
  - Anmeldung mit Access ID und Access Secret, jede Anfrage ist mit HMAC-SHA256 signiert.
  - Carl hat das Entwicklerkonto schon angelegt (24.11.). Im Cloud-Projekt müssen die Smart-Life-App verknüpft und IoT Core aktiv sein.
  - Die Geräteliste liefert pro Steckdose ID, Name und den lokalen Schlüssel (`local_key`).
- **Lokales Tuya-Protokoll:**
  - TCP-Port 6668. Je nach Firmware Version 3.3 (AES-ECB), 3.4 (Sitzungsschlüssel, HMAC) oder 3.5 (AES-GCM).
  - Welche Version die HBN-Steckdosen sprechen, ist offen und zeigt sich erst beim Test.
- **Der lokale Schlüssel ändert sich**, wenn eine Steckdose in Smart Life neu gekoppelt wird. Dann wieder „Geräte neu laden“.
- **Finden im WLAN:**
  - Tuya-Steckdosen melden sich per UDP-Broadcast. Broadcasts empfangen darf eine iOS-App aber nur mit Apples Multicast-Berechtigung (Antrag bei Apple) – die nutzen wir nicht.
  - Stattdessen sucht Hubert im eigenen Netz nach Geräten mit offenem Port 6668 und erkennt jede Steckdose daran, welcher Schlüssel passt.
  - Die zuletzt bekannte IP wird gemerkt.
- Lokales Netzwerk: `NSLocalNetworkUsageDescription` gibt es schon (Fernbedienung).
- Claude kann nicht kompilieren und nicht im WLAN testen. Jeder Schritt muss einzeln baubar sein.

## Ansätze

1. **Lokal im WLAN, Schlüssel einmal über die Tuya-Cloud holen** – gewählt (Carl, 24.11.).
   Schnell, unabhängig von der Cloud im Alltag, Namen kommen aus Smart Life.
2. Lokal, Schlüssel von Hand eintragen (per tinytuya am Mac). Weniger Code, aber umständlich, und nach jedem neuen Koppeln wieder Handarbeit. Verworfen.
3. Schalten über die Tuya-Cloud (Server-Baustein bei Supabase). Ginge auch unterwegs, ist aber langsamer, und der kostenlose Zugang muss regelmäßig verlängert werden. Nicht nötig, weil Carl nur zu Hause schalten will. Verworfen.
4. Home Assistant auf einem Raspberry Pi. Braucht ein Zusatzgerät. Verworfen (schon am 22.11.).

## Vom Nutzer entschieden

- Lampen nur zu Hause schalten.
- Ansatz 1 mit „Mit Tuya verbinden“ in Hubert.
- Tuya-Entwicklerkonto ist angelegt.

## Vorschläge von Claude (korrigierbar)

- **Geteilt im Haushalt:**
  - Geräteliste in einer neuen Supabase-Tabelle `smart_devices` mit Row Level Security (`is_household_member`): ID, Name, lokaler Schlüssel, Protokollversion, letzte IP.
  - So funktionieren iPhone und iPad nach einer einzigen Einrichtung.
  - Abwägung: Der lokale Schlüssel ist auch ein Geheimnis, nützt aber nur im eigenen WLAN. Durch RLS sieht ihn nur der Haushalt. Die Tuya-Zugangsdaten selbst bleiben vom Server fern (Anti-Ziel).
- **Mehrfachsteckdosen:** Hat ein Gerät mehrere schaltbare Ausgänge (Kategorie `pc`, mehrere Schalter-Datenpunkte), wird jeder Ausgang eine eigene Kachel mit eigenem Namen. „Alle aus“ schaltet alle Ausgänge. Einzelsteckdosen haben einen Ausgang (Datenpunkt 1).
- **Ersatz, falls die Suche nichts findet** (z. B. Steckdosen in einem eigenen IoT- oder Gastnetz): IP-Adresse pro Steckdose von Hand eintragen, mit Hinweis „Steckdosen müssen im selben WLAN wie dieses Gerät sein“.
- **Tuya-Zugangsdaten** (Access ID/Secret) liegen nur im Schlüsselbund des Geräts, auf dem eingerichtet wird, nie auf dem Server.
- **Nur Steckdosen** (Tuya-Kategorie `cz`/`pc`) werden übernommen. Alles andere aus Smart Life wird ignoriert.
- **Zustand:** Beim Öffnen und alle 15 s fragt Hubert den Zustand lokal ab, solange die Karte sichtbar ist. Nach dem Schalten wird sofort angezeigt und dann bestätigt.
- **Name:** zuerst der Name aus Smart Life. In Hubert umbenennen ändert nur den Hubert-Namen.
- **Widget-Kachel:**
  - an: gelb gefülltes Lampensymbol, Name, „An“.
  - aus: graues Symbol, Name, „Aus“.
  - nicht erreichbar: Symbol durchgestrichen und „Nicht erreichbar“.
  - Mindestens 88 pt hoch (Wand-iPad), Raster je nach Kartenbreite 2–4 Kacheln pro Reihe.
- **Symbol im Katalog:** `lightbulb.fill`, Tint Gelb. Der Eintrag „smarthome“ aus „Kommt bald“ wird durch den echten Bucket ersetzt.
- **Neuer Bucket:** Bestehende Nutzer werden nach dem Update einmal gefragt (`Views/NewBuckets.swift`).
- **Protokolle:** 3.3, 3.4 und 3.5 einbauen, Version automatisch erkennen und merken.

## Dem Entwickler überlassen

- Aufteilung in Dateien unter `Core/SmartHome/` und `Buckets/SmartHomeBucket.swift`.
- Genaue Netzsuche: Adressbereich aus der eigenen WLAN-IP, Zeitlimits, Parallelität.
- Krypto mit CryptoKit (GCM, HMAC) bzw. CommonCrypto (AES-ECB).
- Texte der Einrichtungsanleitung (Schritte im Tuya-Portal).
