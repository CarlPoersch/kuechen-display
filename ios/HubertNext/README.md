# HubertNext – native SwiftUI-App (Etappe 1: Fundament)

Läuft neben der alten Web-Hülle `ios/Hubert` (eigene Bundle-ID `com.carlpoersch.HubertNext`, Name „Hubert Neu“),
bis Etappe 2 alles übernommen hat. Mindestversion iOS/iPadOS 15.

- `App/` Start, Wechsel zwischen Onboarding und Startseite
- `Core/` Supabase-Zugriff (nur URLSession), Schlüsselbund, Zustand (`AppStore`), Modelle, Farben
- `Buckets/` Bucket-Baukasten (`Bucket.swift`) + einzelne Buckets (Wetter, Countdowns)
- `Views/` Startseite (Briefing-Raster + Apps), Einstellungen, Katalog
- `Onboarding/` Mit Apple anmelden → Haushalt → Interessen → Buckets → Einstellungen

Neuer Bucket: Datei in `Buckets/` mit `static let kind = BucketKind(...)` und in `BucketRegistry.all` eintragen.
Datenbank: `supabase/migrations/002_hubert_accounts.sql`. Design: `docs/specs/2026-11-20-hubert-native-design.md`.
