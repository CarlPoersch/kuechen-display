# Spotify-Bucket – Design (kurz)

Stand: 23.11.2026

## Absicht
Carl will sich in Hubert bei Spotify anmelden und über Hubert Musik hören. Die Musik läuft auf dem Gerät selbst (iPad mini 4 oder iPhone).

## Entschieden (Carl)
- Variante **B**: Steuern **und** aus der eigenen Bibliothek wählen (Playlists, Lieblingssongs, zuletzt gehört). Suche kommt später.
- Wiedergabe auf dem Gerät selbst.
- Geführter Zugriff spielt keine Rolle mehr: Hubert darf kurz zu Spotify wechseln.

## Rahmen
- Spotify erlaubt keine Wiedergabe in fremden Apps. Hubert steuert die **Spotify-App** über das Spotify iOS SDK (App Remote). Die Spotify-App muss installiert sein.
- Spotify Development Mode (seit Feb. 2026): Entwickler braucht Premium, eine Client ID, höchstens 5 freigegebene Nutzer (Dashboard → User Management).
- Titel/Playlist gezielt starten braucht Premium.
- Mindestversion iOS 15 bleibt (SDK unterstützt iOS 12+).

## Ansätze
1. **iOS SDK (App Remote) + Web API für die Bibliothek** – gewählt. Kein eigener Server (PKCE), Musik auf dem Gerät.
2. Nur Web API (Spotify Connect) – verworfen: Die Spotify-App auf dem iPad taucht als Gerät nur auf, solange sie aktiv ist; zum Aufwecken bräuchte es trotzdem das SDK.
3. Nur Steuern ohne Bibliothek (Variante A) – zu wenig: Carl will die Koch-Playlist aus Hubert starten.

## Verhalten (Claudes Entscheidungen, korrigierbar)
- Anmelden/Verbinden öffnet kurz Spotify, spielt dort weiter („“ = letzter Stand) und kommt automatisch zurück (Redirect `hubert-spotify://callback`).
- Läuft Spotify im Hintergrund, verbindet Hubert leise beim Öffnen. Sonst zeigt die Karte „Weiter hören“.
- Antippen einer Playlist ohne Verbindung: Spotify öffnet kurz und spielt genau diese Playlist.
- Im Hintergrund löst Hubert die Verbindung (Spotify spielt weiter).
- Anmeldung pro Gerät im Schlüsselbund, nicht im Haushalt geteilt (jede Person hat ihr eigenes Spotify).
- Karte klein: Cover, Titel, Play/Zurück/Weiter. Mittel: zusätzlich Interpret und Playlist-Name.
- App: großes Cover, Zufall/Zurück/Play/Weiter, darunter „Zuletzt gehört“ (Reihe), Playlists (mit „Lieblingssongs“ oben), die ersten 20 Lieblingssongs.
- Lieblingssongs komplett abspielen über `spotify:user:<id>:collection`.

## Dateien
- `Core/Spotify/SpotifyCenter.swift` – Anmeldung, Verbindung, Steuerung, Web API
- `Buckets/SpotifyBucket.swift` – Karte, App, Einstellungen
- `HubertNext-Info.plist` – `LSApplicationQueriesSchemes` (spotify), URL-Schema `hubert-spotify`
- `Core/Config.swift` – `spotifyClientID`, `spotifyRedirect`
- Paket: `https://github.com/spotify/ios-sdk` (Produkt `SpotifyiOS`). Ohne Paket baut die App trotzdem, der Bucket zeigt dann „nicht eingerichtet“.
