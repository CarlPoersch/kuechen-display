// ============================================================
// Edge Function "deals": gute Angebote nach deinen Stichwörtern.
//   GET  .../deals/catalog                         Vorschläge (Stichwörter)
//   POST .../deals/match   { watch, min }          Treffer je Stichwort + heiße Deals
//   GET  .../deals/preview?t=&alts=&not=&max=&min= Vorschau für ein Stichwort
// Quelle: RSS-Feeds von mydealz (allgemein, Kategorien und Themen-Gruppen).
// Alles, was gelesen wird, landet 7 Tage in deal_cache – so bleiben auch
// ältere Treffer sichtbar, obwohl jeder Feed nur die letzten 30 Deals enthält.
// Stichwörter passen auch ungefähr: Groß/klein, Umlaute (ä/ae), Mehrzahl,
// Wortteile (Saugroboter ↔ Roboter), Tippfehler und Synonyme der Vorschläge.
// ============================================================

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "x-kueche-key, content-type, authorization, apikey",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const SUPA = Deno.env.get("SUPABASE_URL") ?? "";
const SVC = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const MD = "https://www.mydealz.de/";
const UA = { "User-Agent": "Mozilla/5.0 (compatible; Hubert/1.0; privates Wanddisplay)", "Accept": "application/rss+xml, application/xml, text/xml" };

// ---------- Zugang: Haushalts-Schlüssel (Web) oder Login (App) ----------
const good = new Map<string, number>();
async function keyOk(key: string | null): Promise<boolean> {
  if (!key) return false;
  const seen = good.get(key);
  if (seen && Date.now() - seen < 10 * 60_000) return true;
  const r = await fetch(SUPA + "/rest/v1/rpc/kueche_check", {
    method: "POST", headers: { "Content-Type": "application/json", apikey: SVC, Authorization: "Bearer " + SVC },
    body: JSON.stringify({ p_key: key }),
  });
  const ok = r.ok && (await r.json()) === true;
  if (ok) good.set(key, Date.now());
  return ok;
}
async function userOk(auth: string | null): Promise<boolean> {
  if (!auth || !auth.startsWith("Bearer ")) return false;
  const seen = good.get(auth);
  if (seen && Date.now() - seen < 5 * 60_000) return true;
  const r = await fetch(SUPA + "/auth/v1/user", { headers: { apikey: SVC, Authorization: auth } });
  if (r.ok) good.set(auth, Date.now());
  return r.ok;
}

// ============================================================
// VORSCHLÄGE – wie die Grundliste beim Einkaufszettel: sofort nutzbar,
// mit Synonymen (alts), Ausschlüssen (not) und passenden mydealz-Gruppen (g).
// Mode, Streetwear und Schuhe sind nach dem ausgerichtet, was gerade angesagt
// ist (Herbst/Winter 2026: Zara, H&M, Mango, Streetwear-Shops, Modemagazine):
// Barrel-/Baggy-Jeans, Bomber und Leder-Look, Kunstpelz, Strick und Zip-Pullover,
// Karo, Spitze; flache Retro-Sneaker (Samba, Speedcat, Onitsuka), kniehohe Stiefel.
// ============================================================
type Preset = {
  t: string; alts?: string[]; not?: string[]; g?: string[];
  s?: boolean;        // Startvorschlag des Bereichs
  aka?: string[];     // frühere Namen (ältere Karten suchen damit weiter)
  shop?: boolean;     // Shop/Marke: passt auch über den Händler, nicht nur über den Titel
  cat?: string;       // passt auf eine ganze mydealz-Kategorie
  style?: boolean;    // Mode: Basic-Marken raus, Angesagtes nach vorn
};
type Area = { id: string; name: string; emoji: string; style?: boolean; items: Preset[] };
const CATALOG: Area[] = [
  { id: "mode", name: "Mode", emoji: "👗", style: true, items: [
    { t: "Baggy & Barrel Jeans", aka: ["Jeans"], alts: ["Jeans", "Baggy Jeans", "Barrel Jeans", "Wide Leg", "Balloon Jeans", "Ballonhose", "Mom Jeans", "Straight Jeans", "Low Rise", "Levi's 501"],
      not: ["Jeansjacke", "Jeans Short", "Jeansshorts", "Jeans-Shorts", "Skinny", "Push Up", "Stretchjeans", "Poloshirt", "Parka", "Hoodie", "Sweatshirt", "Jacket"], g: ["jeans", "levis"], s: true },
    { t: "Bomber & Lederjacken", alts: ["Bomberjacke", "Bomber", "Lederjacke", "Kunstlederjacke", "Bikerjacke", "Wildlederjacke", "Suede Jacket", "Varsity Jacket", "Collegejacke", "Harrington"],
      not: ["Motorradjacke", "Motorrad"], g: ["jacken"], s: true },
    { t: "Puffer & Daunenjacken", aka: ["Winterjacke"], alts: ["Pufferjacke", "Puffer Jacket", "Puffer", "Daunenjacke", "Steppjacke", "Nuptse", "Down Jacket", "Daunenweste", "Parka", "Winterjacke"],
      not: ["Kinder", "Hund"], g: ["winterjacken", "jacken"], s: true },
    { t: "Strick & Zip-Pullover", aka: ["Pullover"], alts: ["Strickpullover", "Strickpulli", "Cardigan", "Strickjacke", "Kaschmir", "Cashmere", "Merino", "Wollpullover", "Grobstrick", "Zopfstrick", "Rollkragen", "Half Zip", "Quarter Zip", "1/4 Zip", "Troyer", "Better Sweater"],
      not: ["Training", "Kapuzenpullover"], g: ["pullover"], s: true },
    { t: "Mäntel", alts: ["Mantel", "Wollmantel", "Trenchcoat", "Karomantel", "Kurzmantel", "Longcoat", "Wintermantel", "Teddymantel", "Coat"],
      not: ["Regenmantel", "Bademantel", "Coating", "Topcoat", "MTB", "Regenjacke", "Radjacke", "Fahrrad"], g: ["jacken"] },
    { t: "Kunstpelz & Teddy", alts: ["Kunstpelz", "Faux Fur", "Fake Fur", "Teddyjacke", "Teddy Jacke", "Shearling", "Sherpa", "Fellkragen"],
      not: ["Stiefel", "Schuh", "Schuhe", "Boots"], g: ["jacken"] },
    { t: "Kleider & Röcke", aka: ["Kleider"], alts: ["Kleid", "Strickkleid", "Midikleid", "Maxikleid", "Minikleid", "Spitzenkleid", "Slipdress", "Minirock", "Midirock", "Maxirock", "Lederrock", "Faltenrock", "Jeansrock"],
      not: ["Kleidung", "Bekleidung"], g: ["kleider"] },
    { t: "Blusen & Tops", alts: ["Bluse", "Spitzenbluse", "Spitzentop", "Rüschenbluse", "Lace Top", "Korsage", "Corsage", "Satin Top", "Crop Top", "Bodysuit"] },
    { t: "Leggings & Sportswear", aka: ["Leggings"], alts: ["Leggings", "Sport-BH", "Yogahose", "Flared Leggings", "Alo Yoga", "Lululemon", "Gymshark", "Sportleggings"], g: ["leggings", "fitness"] },
    { t: "Unterwäsche", alts: ["BH", "Dessous", "Slip", "Pyjama", "Schlafanzug", "Calvin Klein", "Skims", "Hunkemöller", "Intimissimi"], g: ["unterwaesche", "dessous"] },
    { t: "Alles aus Mode", aka: ["Kleidung"], cat: "Fashion & Accessoires", alts: ["Damenmode", "Herrenmode"], g: ["kleidung", "fashion-accessoires"] },
  ] },
  { id: "streetwear", name: "Streetwear", emoji: "🧢", style: true, items: [
    { t: "Hoodies & Sweats", alts: ["Hoodie", "Kapuzenpullover", "Zip Hoodie", "Sweatshirt", "Crewneck", "Jogginghose", "Sweatpants", "Trackpants", "Trainingsjacke", "Track Jacket", "Track Top", "Firebird"],
      g: ["pullover", "kleidung"], s: true },
    { t: "Cargo & Workwear", alts: ["Cargohose", "Cargo Pants", "Cargo Hose", "Parachute Pants", "Double Knee", "Carpenter", "Workwear", "Work Jacket", "Detroit Jacket"], not: ["Sicherheitsschuh", "Arbeitsschuh"] },
    { t: "Caps & Beanies", alts: ["Beanie", "Mütze", "Cap", "New Era", "Baseball Cap", "Strickmütze", "Bucket Hat", "Balaclava"] },
    { t: "Carhartt WIP", alts: ["Carhartt"], g: ["carhartt"], shop: true, s: true },
    { t: "The North Face", alts: ["North Face", "TNF", "Nuptse"], g: ["the-north-face"], shop: true, s: true },
    { t: "Nike", alts: ["Jordan", "Air Jordan"], not: ["Jordanien"], g: ["nike"], shop: true, s: true },
    { t: "Adidas Originals", aka: ["Adidas"], alts: ["Samba", "Gazelle", "Handball Spezial", "SL 72", "Taekwondo", "Campus 00s", "Superstar", "Adistar", "Firebird", "Adicolor", "Trefoil"],
      not: ["Trikot", "Fußball"], g: ["adidas"], shop: true, s: true },
    { t: "New Balance", g: ["new-balance"], shop: true, s: true },
    { t: "Stüssy", alts: ["Stussy"], shop: true },
    { t: "Arc'teryx", alts: ["Arcteryx"], shop: true },
    { t: "Salomon", alts: ["XT-6", "XT 6", "ACS Pro"], not: ["Ski", "Skischuh", "Skischuhe", "Wanderschuh"], shop: true },
    { t: "Ralph Lauren", alts: ["Polo Ralph Lauren"], shop: true },
    { t: "Tommy Jeans", shop: true },
    { t: "Dickies", shop: true },
    { t: "Puma", alts: ["Speedcat", "Palermo"], g: ["puma"], shop: true },
  ] },
  { id: "schuhe", name: "Schuhe", emoji: "👟", style: true, items: [
    { t: "Trend-Sneaker", aka: ["Sneaker"], s: true, g: ["sneaker", "adidas", "nike", "new-balance", "asics", "puma"], alts: [
      "Samba", "Gazelle", "Handball Spezial", "SL 72", "Taekwondo", "Adidas Japan", "Campus 00s", "Superstar", "Adistar",
      "Speedcat", "Palermo", "Onitsuka Tiger", "Mexico 66", "Gel-1130", "Gel-Kayano 14", "GT-2160", "Gel-NYC",
      "New Balance 530", "New Balance 9060", "New Balance 204L", "New Balance 1906", "New Balance 2002R", "New Balance 550", "New Balance 990",
      "Air Jordan 1", "Jordan 4", "Dunk Low", "Air Force 1", "Vomero 5", "Cortez", "V2K", "P-6000", "Air Max 1", "Air Max 95", "Air Max Plus",
      "XT-6", "Chuck 70", "Chuck Taylor", "Old Skool", "Knu Skool", "Club C", "Sneakerina"] },
    { t: "Stiefel & Boots", aka: ["Stiefel"], alts: ["Boots", "Stiefeletten", "Chelsea Boots", "Kniehohe Stiefel", "Overknee", "Cowboystiefel", "Westernstiefel", "Cowboy Boots", "Dr. Martens", "Timberland", "Bikerboots", "Winterstiefel"],
      not: ["Gummistiefel", "Sicherheitsschuh", "Sicherheitsstiefel", "Kinder", "Wanderschuh"], g: ["stiefel"], s: true },
    { t: "UGG", alts: ["Ugg Boots", "Tasman", "Ultra Mini", "Lowmel", "Tazz"], g: ["ugg"], s: true },
    { t: "Ballerinas & Loafer", alts: ["Ballerina", "Mary Jane", "Mary Janes", "Loafer", "Mokassin", "Mules", "Sneakerina", "Kitten Heels", "Slingpumps"], g: ["schuhe"] },
    { t: "Clogs & Hausschuhe", aka: ["Hausschuhe"], alts: ["Birkenstock", "Clogs", "Hausschuhe", "Pantoffeln", "Crocs"], g: ["schuhe"] },
    { t: "Laufschuhe", alts: ["Running", "Asics", "Hoka", "On Cloud", "Brooks", "Pegasus"], g: ["laufschuhe"], style: false },
  ] },
  { id: "makeup", name: "Make-up", emoji: "💄", items: [
    { t: "Make-up", alts: ["Makeup", "Mascara", "Foundation", "Concealer", "Lippenstift", "Lipgloss", "Lidschatten", "Eyeliner", "Rouge", "Highlighter", "Bronzer", "Make-up Primer"], g: ["kosmetik", "beauty"], s: true },
    { t: "Beauty-Adventskalender", alts: ["Kosmetik Adventskalender", "Douglas Adventskalender", "Rituals Adventskalender", "Lookfantastic Adventskalender", "Make-up Adventskalender", "Parfum Adventskalender", "Flaconi Adventskalender", "Notino Adventskalender"], g: ["adventskalender"], s: true },
    { t: "Nagellack", alts: ["Gel-Nagellack", "Essie", "OPI", "Nail Polish"], g: ["kosmetik"] },
  ] },
  { id: "pflege", name: "Pflege & Haare", emoji: "🧴", items: [
    { t: "Hautpflege", alts: ["Gesichtscreme", "Serum", "Feuchtigkeitscreme", "Sonnencreme", "Retinol", "Hyaluron", "The Ordinary", "La Roche-Posay", "CeraVe", "Clinique", "Augencreme"], g: ["hautpflege", "koerperpflege"], s: true },
    { t: "Haarstyling", alts: ["Dyson Airwrap", "Airwrap", "Glätteisen", "Lockenstab", "Föhn", "Haartrockner", "ghd", "Dyson Supersonic"], not: ["Staubsauger", "Stielsauger", "Akkusauger", "Handstaubsauger", "Saugroboter"], g: ["glaetteisen", "haartrockner"], s: true },
    { t: "Haarpflege", alts: ["Shampoo", "Haarkur", "Olaplex", "Haarmaske", "Haaröl"], g: ["haarpflege"] },
    { t: "Körperpflege", alts: ["Duschgel", "Bodylotion", "Body Butter", "Epilierer", "Rasierer"], g: ["koerperpflege"] },
    { t: "Elektrische Zahnbürste", alts: ["Oral-B", "Sonicare"], g: ["gesundheit"] },
  ] },
  { id: "parfum", name: "Parfum", emoji: "🌸", items: [
    { t: "Parfum", alts: ["Eau de Parfum", "Eau de Toilette", "Parfüm", "Duft"], g: ["parfum"], s: true },
    { t: "Duft-Geschenkset", alts: ["Geschenkset", "Duftset"], g: ["parfum"] },
    { t: "Rituals", g: ["rituals"], shop: true },
  ] },
  { id: "accessoires", name: "Taschen & Schmuck", emoji: "👜", style: true, items: [
    { t: "Handtaschen", alts: ["Umhängetasche", "Schultertasche", "Shopper", "Clutch", "Mini Bag", "Crossbody", "Baguette Bag", "Michael Kors", "Coach", "Longchamp", "Liebeskind", "Marc Jacobs"],
      not: ["Kühltasche", "Laptoptasche", "Laptop-Tasche", "Kameratasche", "Erste-Hilfe", "Werkzeugtasche"], g: ["handtaschen", "taschen"], s: true },
    { t: "Schmuck", alts: ["Halskette", "Kette", "Ohrringe", "Armkette", "Armreif", "Pandora", "Thomas Sabo", "Swarovski", "Silberschmuck", "Goldschmuck", "Paul Valentine", "Purelei"],
      not: ["Schlüsselring", "Ringlicht", "Lichterkette", "Fahrradkette", "Schneekette", "Kettenfett", "Kettenöl", "Kettensäge", "Apple Watch", "Smartwatch"], g: ["schmuck"], s: true },
    { t: "Sonnenbrille", alts: ["Ray-Ban", "Wayfarer"], g: ["sonnenbrillen"] },
    { t: "Gürtel & Schals", alts: ["Gürtel", "Ledergürtel", "Schal", "Kaschmirschal", "Lederhandschuhe", "Handschuhe"], not: ["Sicherheitsgurt", "Spanngurt", "Fahrradhandschuhe", "Arbeitshandschuhe", "Einweghandschuhe"] },
    { t: "Uhren", alts: ["Armbanduhr", "Fossil", "Casio"], g: ["uhren"], style: false },
    { t: "Rucksack", alts: ["Kånken", "Fjällräven", "Eastpak", "Herschel"], not: ["Laptop-Rucksack", "Laptoprucksack", "Wanderrucksack", "Trekkingrucksack"], g: ["taschen"] },
  ] },
  { id: "shops", name: "Shops", emoji: "🛍️", items: [
    { t: "Zalando", shop: true }, { t: "About You", shop: true }, { t: "H&M", shop: true }, { t: "Zara", shop: true }, { t: "Mango", shop: true },
    { t: "Weekday", shop: true }, { t: "COS", shop: true }, { t: "Arket", shop: true }, { t: "& Other Stories", alts: ["Other Stories"], shop: true },
    { t: "Pull&Bear", alts: ["Pull & Bear", "Pull and Bear"], shop: true }, { t: "Bershka", shop: true }, { t: "Stradivarius", shop: true },
    { t: "Urban Outfitters", shop: true }, { t: "Asos", shop: true }, { t: "Snipes", shop: true }, { t: "Levi's", alts: ["Levis"], shop: true },
    { t: "Douglas", shop: true }, { t: "Flaconi", shop: true }, { t: "Sephora", shop: true }, { t: "Notino", shop: true },
    { t: "Lookfantastic", shop: true }, { t: "dm", shop: true }, { t: "Rossmann", shop: true },
  ] },
  { id: "wohnen", name: "Wohnen & Deko", emoji: "🕯️", items: [
    { t: "Kerzen", alts: ["Duftkerze", "Yankee Candle", "Lichterkette", "Weihnachtsdeko"], g: ["kerzen", "home-living"], s: true },
    { t: "Bettwäsche", alts: ["Kissen", "Kuscheldecke", "Bettdecke", "Spannbettlaken"], g: ["bettwaesche"], s: true },
    { t: "IKEA", shop: true },
  ] },
  { id: "technik", name: "Technik", emoji: "🎧", items: [
    { t: "Kopfhörer", alts: ["AirPods", "Earbuds", "Ohrhörer", "In-Ear-Kopfhörer", "Over-Ear-Kopfhörer", "Headphones", "Headset", "True Wireless", "Bose QuietComfort"], not: ["Ersatzpolster"], g: ["kopfhoerer", "airpods"], s: true },
    { t: "AirPods", g: ["airpods"] },
    { t: "Smartphone", alts: ["Handy", "iPhone", "Samsung Galaxy", "Galaxy S", "Galaxy Z", "Galaxy A", "Pixel", "Xiaomi"],
      not: ["Hülle", "Lederhülle", "Lederhüllen", "Panzerglas", "Schutzfolie", "Displayschutz", "Tarif", "Vertrag", "Ladekabel", "Gimbal", "Halterung", "Stativ", "Laufschuh"], g: ["smartphone", "iphone"], s: true },
    { t: "iPhone", not: ["Hülle", "Panzerglas", "Schutzfolie", "Displayschutz", "Ladekabel"], g: ["iphone"] },
    { t: "Fernseher", alts: ["TV", "Smart TV", "OLED", "QLED", "Fernsehgerät"], not: ["Wandhalterung", "Halterung", "Fernbedienung", "Antenne"], g: ["fernseher"] },
    { t: "Laptop", alts: ["Notebook", "MacBook", "Ultrabook", "Chromebook"], not: ["Tasche", "Hülle", "Ständer", "Rucksack"], g: ["laptop"] },
    { t: "Tablet", alts: ["iPad", "Galaxy Tab"], not: ["Hülle", "Panzerglas", "Schutzfolie"], g: ["tablet", "ipad"] },
    { t: "Smartwatch", alts: ["Apple Watch", "Galaxy Watch", "Garmin", "Fitnesstracker"], not: ["Armband", "Schutzfolie"], g: ["smartwatch"] },
  ] },
  { id: "gaming", name: "Gaming", emoji: "🎮", items: [
    { t: "Nintendo Switch", alts: ["Switch 2", "Switch OLED"], g: ["nintendo-switch", "nintendo"], s: true },
    { t: "PlayStation 5", alts: ["PS5", "DualSense"], g: ["playstation-5", "playstation"] },
    { t: "Xbox", alts: ["Game Pass"], g: ["xbox"] },
    { t: "Gratis-Spiele", alts: ["kostenlos Spiel", "gratis Spiel", "Epic Games", "Prime Gaming", "free to keep"], g: ["freebies", "gaming"], s: true },
  ] },
  { id: "haushalt", name: "Haushalt & Küche", emoji: "🏠", items: [
    { t: "Staubsauger", alts: ["Saugroboter", "Akkusauger", "Stielsauger", "Handstaubsauger", "Wischroboter", "Dyson", "Roborock"], not: ["Staubsaugerbeutel", "Beutel", "Filter", "Ersatzteil", "Zubehör", "Airwrap", "Supersonic"], g: ["staubsauger"], s: true },
    { t: "Kaffeevollautomat", alts: ["Kaffeemaschine", "Siebträger", "Espressomaschine", "Nespresso", "Dolce Gusto"], not: ["Entkalker", "Reinigungstabletten"], g: ["kaffeevollautomaten", "kaffeemaschinen"], s: true },
    { t: "Heißluftfritteuse", alts: ["Airfryer", "Air Fryer", "Ninja Foodi"], g: ["heissluftfriteuse"] },
    { t: "Küchenmaschine", alts: ["Thermomix", "Monsieur Cuisine", "KitchenAid", "Standmixer"] },
    { t: "Werkzeug", alts: ["Akkuschrauber", "Bohrmaschine", "Makita", "Werkzeugkoffer"], g: ["werkzeug"] },
  ] },
  { id: "einkauf", name: "Lebensmittel & Drogerie", emoji: "🛒", items: [
    { t: "Kaffee", alts: ["Kaffeebohnen", "Espresso", "Kaffeepads", "Kaffeekapseln"], not: ["Kaffeemaschine", "Kaffeevollautomat", "Tasse", "Becher"], g: ["kaffee"], s: true },
    { t: "Süßigkeiten", alts: ["Schokolade", "Milka", "Lindt", "Haribo", "Ritter Sport"], g: ["lebensmittel"], s: true },
    { t: "Wein", alts: ["Rotwein", "Weißwein", "Sekt", "Champagner", "Prosecco"], not: ["Weinglas", "Weingläser", "Weinkühlschrank"], g: ["wein"] },
    { t: "Bier", alts: ["Kasten Bier", "Craft Beer"], not: ["Bierglas", "Biergläser"], g: ["bier"] },
    { t: "Waschmittel", alts: ["Persil", "Ariel", "Weichspüler", "Spülmaschinentabs", "Geschirrtabs"], g: ["drogerie"] },
    { t: "Lidl", shop: true }, { t: "Aldi", shop: true },
  ] },
  { id: "freizeit", name: "Freizeit & Familie", emoji: "🎁", items: [
    { t: "Lego", g: ["lego"], s: true },
    { t: "Spielzeug", alts: ["Playmobil", "Carrera", "Ravensburger", "Puzzle", "Brettspiel", "Toniebox"], g: ["spielzeug", "spiele-brettspiele"], s: true },
    { t: "Streaming", alts: ["Kino", "Kinoticket", "Netflix", "Disney+", "Spotify", "DAZN", "WOW"], g: ["kino", "filme-serien"] },
    { t: "Fitness", alts: ["Fitnessstudio", "Yogamatte", "Hanteln", "Sportuhr"], g: ["fitness"] },
    { t: "Fahrrad", alts: ["E-Bike", "Ebike", "Pedelec", "Fahrradhelm"], g: ["fahrraeder", "e-bikes"] },
  ] },
  { id: "reisen", name: "Reisen", emoji: "✈️", items: [
    { t: "Reisen", alts: ["Urlaub", "Hotel", "Kurzurlaub", "Städtetrip"], cat: "Urlaub & Reisen",
      not: ["Reiseetui", "Reisegröße", "Reisegrößen", "Reisekoffer", "Koffer", "Trolley", "Pflaster", "Zahnbürste"], g: ["reisen"], s: true },
    { t: "Flüge", alts: ["Flug", "Ryanair", "Eurowings", "Lufthansa", "Condor"], g: ["fluege"], s: true },
    { t: "Bahn", alts: ["Bahntickets", "Sparpreis", "BahnCard", "Deutschlandticket", "Flixtrain", "Flixbus"], g: ["bahntickets", "bahncard"] },
    { t: "Wellness", alts: ["Therme", "Spa", "Wellnesshotel", "Sauna"] },
  ] },
  { id: "aktionen", name: "Aktionen", emoji: "🏷️", items: [
    { t: "Black Friday", alts: ["Black Week", "Cyber Monday"], s: true },
    { t: "Gratisproben", alts: ["Gratisprobe", "kostenlose Probe", "Produkttest", "Freebie"], g: ["freebies"], s: true },
    { t: "Adventskalender", g: ["adventskalender"] },
    { t: "Preisfehler", g: ["preisfehler"] },
  ] },
];
// „style“ des Bereichs gilt für seine Vorschläge (außer wo ausdrücklich aus, z. B. Laufschuhe)
for (const c of CATALOG) for (const i of c.items) if (c.style && i.style === undefined) i.style = true;
const PRESETS = CATALOG.flatMap((c) => c.items);

// ============================================================
// WAS GERADE ANGESAGT IST – Stand Herbst/Winter 2026.
// Gewicht 1–3; ein Deal sammelt Punkte für jedes passende Stichwort (höchstens 6).
// Quellen: Kollektionen von Zara, H&M, Mango, Weekday; Sneaker- und Streetwear-
// Shops (Asphaltgold, Overkill, Breuninger) und Modemagazine. Regelmäßig pflegen.
// ============================================================
const TREND: [string, number][] = [
  // Sneaker: flach und retro, dazu Running-Klassiker der 2000er
  ["Samba", 3], ["Gazelle", 3], ["Handball Spezial", 3], ["SL 72", 3], ["Taekwondo", 3], ["Adidas Japan", 3], ["Campus 00s", 2],
  ["Superstar", 1], ["Adistar", 2], ["Speedcat", 3], ["Palermo", 2], ["Onitsuka", 3], ["Mexico 66", 3],
  ["Gel-1130", 3], ["Gel-Kayano 14", 3], ["GT-2160", 2], ["Gel-NYC", 2],
  ["New Balance 530", 3], ["New Balance 9060", 3], ["New Balance 204L", 3], ["New Balance 1906", 2], ["New Balance 2002R", 2],
  ["New Balance 550", 2], ["New Balance 990", 2], ["Air Jordan 1", 3], ["Jordan 4", 3], ["Dunk Low", 3], ["Vomero 5", 3],
  ["Cortez", 2], ["V2K", 2], ["P-6000", 2], ["Air Force 1", 2], ["Air Max 1", 2], ["Air Max 95", 2], ["Air Max Plus", 2],
  ["XT-6", 3], ["Chuck 70", 2], ["Knu Skool", 2], ["Club C", 1], ["Sneakerina", 3],
  ["Tasman", 3], ["Lowmel", 3], ["Ultra Mini", 3], ["UGG", 2], ["Birkenstock Boston", 3], ["Birkenstock", 1],
  // Marken
  ["Carhartt", 3], ["Stüssy", 3], ["Stussy", 3], ["The North Face", 2], ["Nuptse", 3], ["Arc'teryx", 3], ["Arcteryx", 3],
  ["Salomon", 2], ["Patagonia", 2], ["Ralph Lauren", 2], ["Tommy Jeans", 1], ["Levi's", 1], ["Dickies", 2], ["New Balance", 2],
  ["Asics", 1], ["Converse", 1], ["Vans", 1], ["Dr. Martens", 2], ["Represent", 2], ["Axel Arigato", 2], ["Veja", 2], ["Autry", 2],
  ["Golden Goose", 2], ["Ganni", 3], ["Acne Studios", 3], ["Jacquemus", 3], ["Miu Miu", 2], ["Coach", 1], ["Longchamp", 1],
  ["Marc Jacobs", 2], ["Alo Yoga", 2], ["Lululemon", 2], ["Skims", 2], ["Adidas Originals", 1], ["Jordan", 1],
  ["Zara", 2], ["Weekday", 2], ["Arket", 2], ["Other Stories", 2], ["COS", 1], ["Mango", 1], ["Pull&Bear", 1], ["Bershka", 1],
  ["Stradivarius", 1], ["Urban Outfitters", 1], ["Snipes", 1],
  // Teile und Stoffe der Saison
  ["Barrel", 2], ["Baggy", 2], ["Wide Leg", 2], ["Balloon", 2], ["Ballonhose", 2], ["Bomber", 2], ["Lederjacke", 2], ["Wildleder", 2],
  ["Suede", 2], ["Kunstpelz", 2], ["Faux Fur", 2], ["Shearling", 2], ["Tartan", 2], ["Kaschmir", 2], ["Cashmere", 2],
  ["Half Zip", 2], ["Quarter Zip", 2], ["1/4 Zip", 2], ["Trenchcoat", 2], ["Puffer", 2], ["Spitzenbluse", 2], ["Korsage", 2],
  ["Mary Jane", 2], ["Loafer", 2], ["Cowboystiefel", 2], ["Westernstiefel", 2], ["Kniehohe Stiefel", 2], ["Firebird", 2],
  ["Track Jacket", 2], ["Trackpants", 2], ["Double Knee", 2], ["Detroit Jacket", 3], ["Varsity", 2], ["Cardigan", 1],
  ["Beanie", 1], ["Balaclava", 1], ["Bucket Hat", 1], ["Schultertasche", 1], ["Wayfarer", 1], ["Oversized", 1],
];
// Basic-, Bequem- und Funktionskram – bei Mode-Vorschlägen nicht zeigen (eigene Suchen bleiben unberührt)
const BASIC = [
  "Amazon Essentials", "Amazon Basics", "Camel Active", "Skechers", "Rieker", "Jack & Jones", "Jack and Jones", "Esmara", "Livergy",
  "Crivit", "Ernsting", "Kik", "Takko", "engbers", "Maier Sports", "McKinley", "Killtec", "Elten", "HAIX", "Sicherheitsschuh",
  "Sicherheitsschuhe", "Arbeitsschuhe", "Arbeitshose", "Arbeitsjacke", "Funktionssocken", "Wandersocken", "Fahrradsocken", "Socken",
  "Thermounterwäsche", "Thermo Unterwäsche", "Kompressionsstrümpfe", "Gummistiefel", "Lauflernschuhe", "Kinderschuhe", "Kinder",
  "Memory Foam", "Bequemschuhe", "Barfußschuhe", "Spreadshirt", "Qwertee", "Fanshop", "FC Bayern Store", "NFL", "Wellensteyn",
  "Bugatti", "Pierre Cardin", "Bruno Banani", "Tom Tailor", "Lerros", "Schiesser", "Trigema", "Laptoptasche", "Laptop-Tasche",
  "Kühltasche", "Erste-Hilfe", "Koffer", "Trolley", "Reisekoffer", "Handgepäck", "Under Armour", "teamFINAL", "teamGOAL",
  "Runfalcon", "Adidas Galaxy", "adi365", "adidas Essentials", "Jako", "Erima", "Padel",
];
const FASHION_CATS = new Set(["Fashion & Accessoires", "Sport & Outdoor"]);
/** Trend-Punkte (0–6) und ob es Basic-Kram ist */
function score(tp: Prepared, all: Prepared): { hype: number; basic: boolean } {
  let hype = 0;
  for (const [k, w] of TREND) if (phraseOk(k, all)) hype += w;
  return { hype: Math.min(6, hype), basic: BASIC.some((b) => phraseOk(b, tp)) };
}
/** Reihenfolge bei Mode: neu zuerst, Angesagtes rutscht bis zu drei Tage nach vorn */
const rank = (d: Item) => Date.parse(d.d) + Math.max(0, d.hype ?? 0) * 12 * 3600_000;

// ============================================================
// UNGEFÄHRES PASSEN
// ============================================================
/** Klein, ohne Akzente; Umlaute und ihre Ersatzschreibung (ae/oe/ue) gelten gleich */
const fold = (s: string) => s.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/ß/g, "ss")
  .replace(/ae/g, "a").replace(/oe/g, "o").replace(/ue/g, "u");
/** Wörter; Zahlen werden abgetrennt (PS5 → ps 5) */
const toks = (s: string) => fold(s).replace(/([a-z])(\d)/g, "$1 $2").replace(/(\d)([a-z])/g, "$1 $2")
  .split(/[^a-z0-9]+/).filter(Boolean);
const STOP = new Set(["und", "fur", "mit", "der", "die", "das", "von", "im", "in", "the", "and", "for", "de"]);
/** Grobe Grundform: Mehrzahl und Endungen ab (Kopfhörern → kopfhor, Winterjacken → winterjack) */
function stem(t: string): string {
  if (/^\d+$/.test(t)) return t;
  for (let i = 0; i < 2; i++) {
    const m = t.length > 5 ? /(en|er|es|n|s|e)$/.exec(t) : null;
    if (!m) break;
    t = t.slice(0, -m[1].length);
  }
  return t;
}
function lev(a: string, b: string, max: number): number {
  if (Math.abs(a.length - b.length) > max) return max + 1;
  let prev = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const cur = [i];
    let best = i;
    for (let j = 1; j <= b.length; j++) {
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
      best = Math.min(best, cur[j]);
    }
    if (best > max) return max + 1;
    prev = cur;
  }
  return prev[b.length];
}
/** Passt ein Suchwort auf ein Wort im Titel? */
function tokOk(k: string, t: string): boolean {
  if (k === t) return true;
  if (/^\d+$/.test(k) || /^\d+$/.test(t)) return false;
  if (k.length >= 4 && t.startsWith(k)) return true;              // Lego → Legosteine
  if (k.length >= 5 && t.endsWith(k)) return true;                // Sauger → Akkusauger, Kleid → Strickkleid (nicht „Bekleidung“)
  if (k.length >= 7 && t.includes(k)) return true;                // lange Wörter auch mitten im Wort
  if (k.length >= 7 && k.slice(0, 2) === t.slice(0, 2)) {         // Tippfehler (nicht bei kurzen Wörtern: Mantel ≠ Mandel)
    const max = k.length >= 10 ? 2 : 1;
    return lev(k, t, max) <= max;
  }
  return false;
}
type Prepared = { words: string[]; joined: string[]; text: string };
function prepare(text: string): Prepared {
  const w = toks(text).map(stem);
  const joined: string[] = [];
  for (let i = 0; i + 1 < w.length; i++) if (w[i].length >= 2 && w[i + 1].length >= 2) joined.push(stem(w[i] + w[i + 1]));   // „Air Pods“ ↔ „AirPods“
  return { words: w, joined, text: fold(text) };
}
/** Eine Suchphrase, einmal zerlegt (wird oft gegen alle Deals geprüft) */
type Phrase = { short?: RegExp; ks: string[]; c?: string };
const phrases = new Map<string, Phrase | null>();
function compile(phrase: string): Phrase | null {
  const have = phrases.get(phrase);
  if (have !== undefined) return have;
  const raw = toks(phrase).filter((x) => !STOP.has(x));
  let out: Phrase | null = null;
  if (raw.length && raw.every((x) => x.length <= 2)) {
    // Kurze Namen wie „H&M“, „dm“ oder „TV“ nur als ganzes Wort (sonst passt „h“ überall)
    out = { ks: [], short: new RegExp("(^|[^a-z0-9])" + raw.join("[^a-z0-9]{0,3}") + "($|[^a-z0-9])") };
  } else if (raw.length) {
    const c = raw.length > 1 ? stem(raw.join("")) : undefined;                // „Play Station“ ↔ „PlayStation“
    out = { ks: raw.map(stem), c: c && c.length >= 5 ? c : undefined };
  }
  if (phrases.size > 5000) phrases.clear();
  phrases.set(phrase, out);
  return out;
}
/** Passt eine Suchphrase (alle Wörter, Reihenfolge egal) auf den Text? */
function phraseOk(phrase: string, p: Prepared): boolean {
  const c = compile(phrase);
  if (!c) return false;
  if (c.short) return c.short.test(p.text);
  // Zusammengezogene Wortpaare nur für längere Suchwörter (sonst passt „ear“ auf „e aroma“)
  // Wortpaare nur genau bzw. am Anfang („Air Pods“ = „AirPods“), sonst passt „Shopper“ auf „Proshop Proshop“
  const hit = (k: string) => p.words.some((t) => tokOk(k, t)) ||
    (k.length >= 5 && p.joined.some((t) => t === k || (t.startsWith(k) && t.length - k.length <= 3)));
  if (c.ks.every(hit)) return true;
  return c.c !== undefined && hit(c.c);
}
/** Gleicher Begriff? (für Vorschläge: „kopfhoerer“, „Kopfhörern“ → „Kopfhörer“) */
function same(a: string, b: string): boolean {
  const x = stem(toks(a).join("")), y = stem(toks(b).join(""));
  return x === y || (x.length >= 5 && lev(x, y, 1) <= 1);
}

type Watch = { t: string; alts?: string[]; not?: string[]; max?: number | null };
type Rule = { t: string; phrases: string[]; not: string[]; max?: number | null; groups: string[]; std: { alts: string[]; not: string[] };
  title: boolean; cat?: string; style: boolean };
type Item = Deal & { prep: Prepared; tprep: Prepared; basic?: boolean };
const slug = (s: string) => s.toLowerCase().replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ü/g, "ue").replace(/ß/g, "ss")
  .normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
function rule(w: Watch): Rule {
  const p = PRESETS.find((x) => same(x.t, w.t)) ?? PRESETS.find((x) => (x.aka ?? []).some((a) => same(a, w.t)));
  const alts = (w.alts ?? []).filter(Boolean), not = (w.not ?? []).filter(Boolean);
  const groups = [...(p?.g ?? [slug(w.t)])];
  for (const a of alts.slice(0, 2)) if (slug(a).length >= 3) groups.push(slug(a));
  // Ausschlüsse greifen nicht, wenn das Stichwort selbst danach fragt („Panzerglas“ sucht Panzerglas)
  const self = prepare(w.t);
  return {
    t: w.t, phrases: [p ? p.t : w.t, ...(p?.alts ?? []), ...alts], not: [...(p?.not ?? []), ...not].filter((n) => !phraseOk(n, self)), max: w.max ?? null,
    groups: [...new Set(groups.filter((g) => g.length >= 2))], std: { alts: p?.alts ?? [], not: p?.not ?? [] },
    // Vorschläge passen nur über den Titel (Händler „Mantel“ ist kein Mantel); Shops und eigene Suchen auch über den Händler
    title: !!p && !p.shop, cat: p?.cat, style: !!p?.style,
  };
}

// ============================================================
// FEEDS LESEN
// ============================================================
type Deal = { id: string; t: string; m?: string; p?: number | null; pt?: string; temp?: number; cat?: string; img?: string; u: string; x?: string; d: string;
  off?: number; code?: boolean; hype?: number };
/** „-30%“, „30 % Rabatt“, „bis zu 70%“ → 30/70 (höchster genannter Wert, 5–90 %) */
function discount(t: string): number | undefined {
  const all = [...t.matchAll(/(\d{1,2})\s?%/g)].map((m) => +m[1]).filter((n) => n >= 5 && n <= 90);
  return all.length ? Math.max(...all) : undefined;
}
function decode(s: string): string {
  return s.replace(/<!\[CDATA\[|\]\]>/g, "").replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(+d)).replace(/&quot;/g, '"').replace(/&apos;/g, "'")
    .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&");
}
function price(s: string | undefined): number | null {
  if (!s) return null;
  if (/kostenlos|gratis|free/i.test(s)) return 0;
  const m = /(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{1,2}))?/.exec(s);
  return m ? parseFloat(m[1].replace(/\./g, "") + (m[2] ? "." + m[2] : "")) : null;
}
function parseRss(xml: string): Deal[] {
  const out: Deal[] = [];
  for (const it of xml.split("<item>").slice(1)) {
    const get = (re: RegExp) => { const m = re.exec(it); return m ? decode(m[1]).trim() : undefined; };
    const rawTitle = get(/<title>([\s\S]*?)<\/title>/);
    const u = get(/<link>([\s\S]*?)<\/link>/);
    if (!rawTitle || !u) continue;
    const tm = /^(-?\d+)°\s*-\s*/.exec(rawTitle);
    const t = tm ? rawTitle.slice(tm[0].length) : rawTitle;
    const merchant = /<pepper:merchant([^>]*)\/?>/.exec(it)?.[1] ?? "";
    const m = /name="([^"]*)"/.exec(merchant)?.[1];
    const pt = /price="([^"]*)"/.exec(merchant)?.[1];
    const id = /-(\d{5,})(?:[/?#]|$)/.exec(u)?.[1];
    const desc = get(/<description>([\s\S]*?)<\/description>/) ?? "";
    const x = desc.replace(/^<strong>[\s\S]*?<\/strong>/, "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim().slice(0, 260);
    const pub = get(/<pubDate>([\s\S]*?)<\/pubDate>/);
    const d = pub ? new Date(pub) : new Date();
    let p = price(pt);
    if (p === null) { const tp = /(\d+(?:[.,]\d{1,2})?)\s?€/.exec(t); p = tp ? price(tp[1]) : null; }
    out.push({
      id: id ? "md" + id : u, t, m: m ? decode(m) : undefined, p, pt: pt ? decode(pt) : undefined,
      temp: tm ? +tm[1] : undefined, cat: get(/<category>([\s\S]*?)<\/category>/), u, x: x || undefined,
      img: /<media:content[^>]*url="([^"]+)"/.exec(it)?.[1], d: isNaN(d.getTime()) ? new Date().toISOString() : d.toISOString(),
    });
  }
  return out;
}

const BASE = ["rss/hot", "rss/new", "rss/deals", "rss/gutscheine",
  ...["fashion-accessoires", "beauty", "kosmetik", "kleidung", "sneaker", "schuhe", "jacken", "elektronik", "gaming", "family-kids", "home-living", "lebensmittel",
    "drogerie", "kultur-freizeit", "reisen", "freebies", "sport", "garten-baumarkt"].map((g) => "rss/gruppe/" + g)];
let baseAt = 0, cleanAt = 0;
const groupOk = new Map<string, { ok: boolean; at: number }>();
const groupAt = new Map<string, number>();

async function fetchFeed(path: string): Promise<Deal[]> {
  const r = await fetch(MD + path, { headers: UA });
  if (r.status === 404) throw new Error("404");
  if (!r.ok) throw new Error("HTTP " + r.status);
  return parseRss(await r.text());
}

async function rest(method: string, path: string, body?: unknown, extra: Record<string, string> = {}) {
  const r = await fetch(SUPA + "/rest/v1/" + path, {
    method, headers: { apikey: SVC, Authorization: "Bearer " + SVC, "Content-Type": "application/json", ...extra },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!r.ok) throw new Error("DB " + r.status + " " + (await r.text()).slice(0, 200));
  return r;
}

/** Feeds neu lesen (allgemeine alle 5 Min., Themen-Gruppen der Stichwörter alle 10 Min.) und speichern */
async function refresh(groups: string[]) {
  const now = Date.now();
  const paths: string[] = [];
  if (now - baseAt > 5 * 60_000) { baseAt = now; paths.push(...BASE); }
  for (const g of groups.slice(0, 30)) {
    const st = groupOk.get(g);
    if (st && !st.ok && now - st.at < 24 * 3600_000) continue;          // gibt es nicht – einen Tag nicht mehr fragen
    if (now - (groupAt.get(g) ?? 0) < 10 * 60_000) continue;
    groupAt.set(g, now);
    if (!paths.includes("rss/gruppe/" + g)) paths.push("rss/gruppe/" + g);
  }
  if (!paths.length) return;
  const lists = await Promise.all(paths.map(async (p) => {
    const g = p.startsWith("rss/gruppe/") ? p.slice(11) : null;
    try {
      const d = await fetchFeed(p);
      if (g) groupOk.set(g, { ok: true, at: now });
      return d;
    } catch (e) {
      if (g && String(e).includes("404")) groupOk.set(g, { ok: false, at: now });
      else console.error("Feed", p, String(e));
      return [] as Deal[];
    }
  }));
  // Nur die Trend-Feeds nennen die Temperatur – fehlende Werte überschreiben nie vorhandene
  const byId = new Map<string, Deal>();
  for (const d of lists.flat()) {
    const prev = byId.get(d.id);
    const merged: any = { ...(prev ?? {}) };
    for (const [k, v] of Object.entries(d)) if (v !== undefined && v !== null) merged[k] = v;
    byId.set(d.id, merged);
  }
  if (!byId.size) return;
  const row = (d: Deal) => ({
    id: d.id, title: d.t, merchant: d.m ?? null, price: d.p ?? null, price_text: d.pt ?? null,
    cat: d.cat ?? null, img: d.img ?? null, url: d.u, snippet: d.x ?? null, pub: d.d, seen: new Date().toISOString(),
  });
  const withTemp = [...byId.values()].filter((d) => d.temp !== undefined).map((d) => ({ ...row(d), temp: d.temp }));
  const noTemp = [...byId.values()].filter((d) => d.temp === undefined).map(row);
  const cols = "id,title,merchant,price,price_text,cat,img,url,snippet,pub,seen";
  try {
    const up = { Prefer: "resolution=merge-duplicates,return=minimal" };
    if (noTemp.length) await rest("POST", "deal_cache?on_conflict=id&columns=" + cols, noTemp, up);
    if (withTemp.length) await rest("POST", "deal_cache?on_conflict=id&columns=" + cols + ",temp", withTemp, up);
    if (now - cleanAt > 3600_000) {
      cleanAt = now;
      await rest("DELETE", "deal_cache?pub=lt." + new Date(now - 10 * 24 * 3600_000).toISOString(), undefined, { Prefer: "return=minimal" });
    }
  } catch (e) { console.error("Speichern", String(e)); }
  memo = null;
}

/** Alle Deals der letzten 7 Tage (1 Min. im Speicher) */
let memo: { at: number; deals: Item[] } | null = null;
async function load() {
  if (memo && Date.now() - memo.at < 60_000) return memo.deals;
  const since = new Date(Date.now() - 7 * 24 * 3600_000).toISOString();
  const rows: any[] = [];
  for (let off = 0; off < 6000; off += 1000) {
    const r = await rest("GET", "deal_cache?select=*&pub=gte." + since + "&order=pub.desc&limit=1000&offset=" + off);
    const page = await r.json();
    rows.push(...page);
    if (page.length < 1000) break;
  }
  const deals = rows.map((r) => {
    const d: Deal = { id: r.id, t: r.title, m: r.merchant ?? undefined, p: r.price === null ? null : Number(r.price), pt: r.price_text ?? undefined,
      temp: r.temp ?? undefined, cat: r.cat ?? undefined, img: r.img ?? undefined, u: r.url, x: r.snippet ?? undefined, d: new Date(r.pub).toISOString() };
    d.off = discount(d.t);
    if (d.u.includes("/gutscheine/")) d.code = true;
    const prep = prepare([d.t, d.m ?? "", d.cat ?? ""].join(" ")), tprep = prepare(d.t);
    // Trend-Punkte nur bei Mode und Sport (spart Rechenzeit), Basic-Erkennung bei allen
    const sc = FASHION_CATS.has(d.cat ?? "") || !d.cat ? score(tprep, prepare([d.t, d.m ?? ""].join(" ")))
      : { hype: 0, basic: BASIC.some((b) => phraseOk(b, tprep)) };
    if (sc.hype > 0) d.hype = sc.hype;
    return { ...d, prep, tprep, basic: sc.basic };
  });
  memo = { at: Date.now(), deals };
  return deals;
}

function matches(r: Rule, d: Item, min: number): boolean {
  if ((d.temp ?? 0) < min) return false;
  if (r.max !== null && r.max !== undefined && (d.p === null || d.p === undefined || d.p > r.max)) return false;
  if (r.style && (d.basic || (d.cat && !FASHION_CATS.has(d.cat)))) return false;      // Mode: nur Mode, ohne Basic-Kram
  const text = r.title ? d.tprep : d.prep;
  if (!(r.cat && d.cat === r.cat) && !r.phrases.some((p) => phraseOk(p, text))) return false;
  // Ausschlüsse nur gegen den Titel
  return !r.not.some((n) => phraseOk(n, d.tprep));
}
const strip = ({ prep: _p, tprep: _t, basic: _b, ...d }: Item): Deal => d;
/** Treffer einer Regel – bei Mode Angesagtes zuerst */
function hits(r: Rule, all: Item[], min: number): Item[] {
  const hit = all.filter((d) => matches(r, d, min));
  return r.style ? hit.sort((a, b) => rank(b) - rank(a)) : hit;
}

async function match(watch: Watch[], min: number) {
  const rules = watch.slice(0, 40).map(rule);
  await refresh(rules.flatMap((r) => r.groups));
  const all = await load();
  const groups = rules.map((r) => {
    const hit = hits(r, all, min);
    return { t: r.t, n: hit.length, deals: hit.slice(0, 40).map(strip) };
  });
  const recent = Date.now() - 36 * 3600_000;
  const hot = all.filter((d) => (d.temp ?? 0) >= 200 && Date.parse(d.d) > recent)
    .sort((a, b) => (b.temp ?? 0) - (a.temp ?? 0)).slice(0, 15).map(strip);
  // Gerade im Trend: angesagte Mode der letzten 5 Tage, egal ob gesucht
  const since = Date.now() - 5 * 24 * 3600_000;
  const trend = all.filter((d) => (d.hype ?? 0) >= 3 && !d.basic && FASHION_CATS.has(d.cat ?? "") && Date.parse(d.d) > since && (d.temp ?? 0) >= min)
    .sort((a, b) => rank(b) - rank(a)).slice(0, 24).map(strip);
  return { at: new Date().toISOString(), total: all.length, groups, hot, trend };
}

async function preview(w: Watch, min: number) {
  const r = rule(w);
  await refresh(r.groups);
  const hit = hits(r, await load(), min);
  return { n: hit.length, deals: hit.slice(0, 8).map(strip), std: r.std };
}

// ============================================================
const clean = (s: unknown, n = 60) => String(s ?? "").replace(/\s+/g, " ").trim().slice(0, n);
const list = (v: unknown) => (Array.isArray(v) ? v : typeof v === "string" ? v.split(",") : []).map((x) => clean(x)).filter(Boolean).slice(0, 15);
const num = (v: unknown) => { const n = typeof v === "number" ? v : parseFloat(String(v ?? "").replace(",", ".")); return isFinite(n) && n > 0 ? n : null; };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  const url = new URL(req.url);
  const what = url.pathname.split("/").filter(Boolean).pop() ?? "";
  if (!["catalog", "match", "preview", "probe"].includes(what)) return new Response("Unbekannte Abfrage", { status: 404, headers: cors });
  if (!(await keyOk(req.headers.get("x-kueche-key"))) && !(await userOk(req.headers.get("authorization")))) {
    return new Response("Kein Zugang", { status: 401, headers: cors });
  }
  let body: unknown;
  try {
    if (what === "catalog") {
      body = CATALOG.map((c) => ({ id: c.id, name: c.name, emoji: c.emoji,
        items: c.items.map((i) => ({ t: i.t, alts: i.alts ?? [], not: i.not ?? [], s: i.s ?? false })) }));
    } else if (what === "probe") {
      // Welche mydealz-Gruppen gibt es? (zum Pflegen der Vorschläge)
      const gs = list(url.searchParams.get("g")).map(slug);
      body = Object.fromEntries(await Promise.all(gs.map(async (g) => {
        const r = await fetch(MD + "rss/gruppe/" + g, { headers: UA });
        return [g, r.status === 200 ? (await r.text()).split("<item>").length - 1 : r.status];
      })));
    } else if (what === "preview") {
      const q = url.searchParams;
      body = await preview({ t: clean(q.get("t")), alts: list(q.get("alts")), not: list(q.get("not")), max: num(q.get("max")) }, Number(q.get("min") ?? 0) || 0);
    } else {
      const j: any = req.method === "POST" ? await req.json() : {};
      const watch: Watch[] = (Array.isArray(j.watch) ? j.watch : []).map((w: any) => ({ t: clean(w?.t), alts: list(w?.alts), not: list(w?.not), max: num(w?.max) }))
        .filter((w: Watch) => w.t.length >= 2);
      body = await match(watch, Number(j.min ?? 0) || 0);
    }
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
  }
  return new Response(JSON.stringify(body), { headers: { ...cors, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" } });
});
