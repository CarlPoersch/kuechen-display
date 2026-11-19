// ============================================================
// Einstellungen für den Betrieb.
//
// supabaseUrl leer  -> lokaler Betrieb mit server.py (Daten in daten/speicher.json,
//                      Fahrplan über /efa/)
// supabaseUrl gesetzt -> Cloud-Betrieb: Daten in Supabase, Fahrplan über die
//                      Edge Function "efa". Die Seite selbst liegt auf GitHub Pages.
//
// Der Supabase-Key hier ist der ÖFFENTLICHE Schlüssel (publishable/anon).
// Er darf im Code stehen: Ohne den Haushalts-Schlüssel, den du auf jedem Gerät
// einmal eingibst, kommt damit niemand an deine Daten.
// ============================================================
window.CONFIG = {
  supabaseUrl: "https://jcnpfkyntdujgudewmzb.supabase.co",
  supabaseKey: "sb_publishable_CYlA5db0qaRSHec7pMlk8w_2L39e_AV"
};
