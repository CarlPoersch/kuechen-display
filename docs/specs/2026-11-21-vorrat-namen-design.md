# Saubere Vorratsnamen beim Scannen – Design (kleine Änderung)

**Absicht:** Kassenzettel-Zeilen wie „G&G AVOCADOS“ oder „BIO VOLLM. 3,8%“ landen als „Avocados“ / „Vollmilch“ im Vorrat. Warum: Nur mit sauberen Namen erkennt Hubert Vorrat im Rezept (grüner Haken) und beim Abgleich mit der Einkaufsliste.

**Ziele:** Ohne KI, offline; vom ersten Einkauf an meist richtig; wird mit jeder Korrektur besser. **Nicht-Ziele:** Preise, Mengen, Mindesthaltbarkeit aus dem Kassenzettel. **Anti-Ziel:** Hubert „rät“ etwas Falsches, ohne dass man es sieht.

**Ansätze:** A) Wörterbuch (Marken, Mengen, Abkürzungen, Lebensmittelliste) · B) Lernen aus Korrekturen · C) Produktdatenbank per Textsuche – verworfen (Kassen-Abkürzungen finden selten Treffer). **Gewählt (Carl): A + B.**

**Ablauf je Zeile:**
1. Gelernte Zuordnung des Haushalts? → nehmen (B).
2. Sonst bereinigen (A): Marken entfernen, Mengen/Prozente/Pfand streichen, Abkürzungen auflösen.
3. Rest mit Lebensmittelliste abgleichen (Zutaten der Rezepte + Grundliste); bester Treffer gewinnt, sonst bereinigter Text in schöner Schreibweise.
4. Im Prüfschritt sichtbar: „G&G AVOCADOS → Avocados“. Wer den Namen ändert, bringt Hubert die Zuordnung bei – gilt für den ganzen Haushalt.

**Meine Entscheidungen:**
- Marke wird weggelassen (keine Zusatzanzeige) – Vorrat soll sagen, *was* da ist.
- Gelerntes in neuer Tabelle `kitchen_aliases` (Haushalt, Kassentext-Schlüssel, Name); gilt auch für Barcodes (Schlüssel = Barcode).
- Wörterbuch und Lebensmittelliste liegen in der App (`Core/FoodNames.swift`), Grundliste ca. 300 Lebensmittel.
