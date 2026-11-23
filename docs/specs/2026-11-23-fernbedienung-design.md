# Fernbedienung – Design

Stand: 23.11.2026 · Status: **freigegeben (Carl, 23.11.2026)** – umgesetzt in einem Schritt (Philips + Mi Stick)

## Absicht und Warum

Carl will Fernseher und Streaming-Stick aus Hubert heraus bedienen, mit iPhone oder iPad als Fernbedienung, wenn die echte gerade nicht greifbar ist. Zum Testen geht es erst einmal um zwei Geräte:

- **Philips Smart-TV** (älter, Smart-TV-Funktionen vorhanden, genaues Modell offen)
- **Xiaomi Mi TV Stick** (Android TV)

Hat sich das bewährt, sollen später weitere Geräte dazukommen.

## Ziele

- Neuer Bucket **„Fernbedienung“** (Art: Tool), auch als App-Symbol nutzbar, wie die anderen Buckets.
- Ein Bildschirm, oben die Auswahl des Geräts (Philips / Mi Stick), darunter die Fernbedienung:
  Ein/Aus, Steuerkreuz mit OK, Zurück, Home, Lautstärke +/−, Stumm, Wiedergabe/Pause.
  Gerätespezifisch zusätzlich: Philips → Quelle, Programm +/−; Mi Stick → Texteingabe (Tastatur des iPhones).
- Einmalige, geführte Einrichtung je Gerät: Gerät finden oder IP-Adresse eingeben, falls nötig koppeln (Code vom Fernseher abtippen), Name vergeben.
- Danach: Bucket öffnen und sofort steuern, ohne Wartezeit spürbar über 1 s.

## Nicht-Ziele (erste Runde)

- Kein Apple TV, Fire TV, Samsung, LG, Roku. Die Bauweise lässt aber weitere Gerätearten zu (siehe Technik).
- Keine Sprachsteuerung, kein Touchpad-Wischen, keine Senderliste/EPG, kein Ambilight.
- Keine Steuerung von unterwegs. Es geht nur im selben WLAN.

## Anti-Ziele (wäre ein Fehlschlag, auch wenn es technisch läuft)

- Tasten reagieren verzögert oder doppelt → schlechter als die echte Fernbedienung.
- Einrichtung, die Entwicklermodus, ADB oder Computer verlangt.
- Fehler ohne Erklärung („geht nicht“) statt einer klaren Ursache, etwa „Fernseher ist aus oder nicht im WLAN“ oder „Kopplung abgelaufen, neu koppeln“.
- Private Schlüssel oder Zugangsdaten verlassen das Gerät.

## Einschränkungen

- iOS 15 als Mindestversion (iPad mini 4) – siehe Technik-Regeln im Projektwissen.
- Lokales Netzwerk: iOS fragt einmal nach der Erlaubnis. Nötig sind `NSLocalNetworkUsageDescription` und `NSBonjourServices` (`_androidtvremote2._tcp`).
- Philips-Schnittstelle (JointSPACE) gibt es in mehreren Varianten:
  - ohne Android: `http://IP:1925/{1|5|6}/…`, ohne Anmeldung
  - mit Android: `https://IP:1926/6/…` mit Kopplung (PIN auf dem Fernseher) und Digest-Anmeldung, selbstsigniertes Zertifikat
  - ganz alte Geräte: Schnittstelle erst freischalten (Code 5646877223 auf der Fernbedienung)
- Mi TV Stick: Android TV Remote Protocol v2 (dasselbe wie die Google-TV-App). TLS mit eigenem Client-Zertifikat, Kopplung über Port 6467 (Code auf dem TV), Befehle über Port 6466, Nachrichten als Protobuf mit Längenpräfix.
- Protokoll v2 setzt beim Mi Stick „Android TV Remote Service“ ab Version 5 voraus (Einstellungen → Apps → Alle Apps). Ist sie älter, hilft ein Update über den Play Store. Das alte Protokoll v1 wird nicht gebaut (Entscheidung von Claude).
- Claude kann nicht kompilieren und nicht im WLAN testen. Jeder Schritt muss einzeln baubar sein, Fehlersuche läuft über Carls Tests.

## Ansätze

1. **Beide Geräte direkt ansteuern** – gewählt (Carl, 23.11.).
   Vorteil: Beide Geräte sind voll steuerbar, auch die Menüs des Fernsehers. Nachteil: Der Mi Stick ist aufwendig (TLS mit Client-Zertifikat, Protobuf).
2. Nur den Mi Stick ansteuern, den Fernseher über HDMI-CEC mitschalten. Weniger Arbeit, aber die Philips-Menüs und -Quellen sind nicht erreichbar, und es hängt von der CEC-Einstellung ab. Verworfen.
3. Über eine Steuerzentrale (Home Assistant). Braucht ein Zusatzgerät, das ständig läuft. Verworfen.

## Vom Nutzer entschieden

- Ansatz 1, zum Test nur Philips-TV und Mi TV Stick.

## Vorschläge von Claude (korrigierbar)

- **Lieferung in zwei Schritten:** zuerst Bucket, Oberfläche und Philips (schnell testbar), danach der Mi Stick. So sieht Carl früh, ob Aufbau und Bedienung passen.
- **Welche Variante spricht der Philips?** Hubert probiert sie der Reihe nach selbst aus: `http:1925/6/system`, `http:1925/5/system`, `http:1925/1/system`, `https:1926/6/system`. Der Nutzer muss das Modell nicht kennen. Antwortet keine, erklärt Hubert den Freischalt-Code.
- **Gerät finden:** Mi Stick per Bonjour (`_androidtvremote2._tcp`), Philips über IP-Eingabe mit kurzer Hilfe, wo man die IP am Fernseher findet. Automatisch finden beim Philips (SSDP) später, falls nötig.
- **Wo wird gespeichert?** Die Geräteliste (Name, Art, IP) steht in der Bucket-Konfiguration und ist damit im Haushalt geteilt. Kopplungen (Client-Zertifikat, Philips-Zugangsdaten) bleiben im Schlüsselbund des jeweiligen Geräts. Jedes iPhone/iPad koppelt also einmal selbst. Grund: Private Schlüssel gehören nicht in die Cloud.
- **Bedienung:** großes rundes Steuerkreuz in der Mitte, für den Daumen erreichbar. Lautstärke rechts, Zurück/Home links unten. Haptisches Feedback bei jedem Tastendruck. Langes Drücken wiederholt Pfeil- und Lautstärketasten.
- **Startseiten-Widget:** klein, nur Gerätename, Ein/Aus und Lautstärke. Antippen öffnet die Fernbedienung.
- **Verbindung:** zum Mi Stick eine Verbindung offen halten, solange die Fernbedienung sichtbar ist (inklusive Ping/Pong des Protokolls), beim Verlassen schließen. Philips: einzelne HTTP-Anfragen.
- **Zertifikat für den Mi Stick:** RSA-2048-Schlüssel im Schlüsselbund erzeugen, selbstsigniertes X.509-Zertifikat mit einem kleinen eigenen DER-Encoder bauen. Keine Fremdbibliothek. Grund: iOS 15 hat dafür keine fertige Funktion, und das Projekt nutzt bisher keine Abhängigkeiten.

## Technik (Rahmen)

- Neue Dateien: `Buckets/RemoteBucket.swift` (Bucket, Ansichten), `Core/Remote/` mit `RemoteDevice` (Protokoll), `PhilipsTV.swift`, `AndroidTVRemote.swift`, `Protobuf.swift` (minimaler Kodierer/Dekodierer nur für die benötigten Nachrichten), `SelfSignedCert.swift`.
- Gemeinsames Protokoll `RemoteDevice` mit `send(key:)`, `connect()`, `pair(code:)`. Weitere Gerätearten hängen sich hier an.
- Tasten als eigenes Enum (`RemoteKey`), je Geräteart auf die Codes übersetzt (Philips: „CursorUp“, „Confirm“ …; Android TV: KEYCODE_DPAD_UP = 19 …).

## Dem Entwickler überlassen

- Genaues Layout im Apple-Look (Skill `hubert-apple-look`), Farben, Größen auf iPhone und iPad.
- Aufbau der Protobuf-Nachrichten im Detail, nach der Protokollbeschreibung (androidtvremote2 / Aymkdn-Wiki).
- Zeitüberschreitungen und Wiederholversuche, sofern die Anti-Ziele eingehalten werden.

## Offene Punkte

- Genaues Philips-Modell: unbekannt, wird durch das Ausprobieren der Varianten abgedeckt.
