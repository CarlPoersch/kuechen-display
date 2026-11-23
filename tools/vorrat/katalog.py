"""Lebensmittel-Katalog für den Vorrat in Hubert.

Eine Quelle für zwei Dinge:
  1. Bausteine zum schnellen Hinzufügen (Kategorie → Gruppe → Sorten)
  2. Abgleich Vorrat ↔ Rezept (Oberbegriff, Sorte, austauschbar)

Aufruf:
  python3 tools/vorrat/katalog.py          → erzeugt ios/HubertNext/HubertNext/Core/FoodCatalogData.swift
  python3 tools/vorrat/katalog.py --test   → prüft den Abgleich an allen Rezept-Zutaten

Regeln für den Abgleich (von Carl festgelegt, 23.11.2026):
  - Oberbegriff im Vorrat („Nudeln“) passt zu jeder Sorte im Rezept – und umgekehrt.
  - Sorte gegen Sorte: nur in austauschbaren Gruppen (Spaghetti ↔ Tagliatelle).
  - Kategorie-Oberbegriff („Käse“, „Fleisch“, „Fisch“) passt zu allem in der Kategorie.
  - Verschiedene Gruppen passen nie zusammen („Reis“ ≠ „Reisnudeln“, „Käse“ ≠ „Leberkäse“).
"""
import json, os, re, sys, collections

K, G, V = "Kühlschrank", "Gefrierfach", "Vorrat"


def grp(name, sorts=(), swap=False, also=(), place=None):
    return {"name": name, "sorts": list(sorts), "swap": swap, "also": list(also), "place": place}


# (Kategorie, Standard-Ort, Kategorie-Oberbegriffe, Gruppen)
CATALOG = [
    ("Nudeln & Reis", V, [], [
        grp("Nudeln", ["Spaghetti", "Spaghettini", "Linguine", "Tagliatelle", "Pappardelle", "Fettuccine", "Bandnudeln",
                       "Penne", "Rigatoni", "Fusilli", "Spirelli", "Farfalle", "Makkaroni", "Maccheroni", "Hörnchennudeln",
                       "Orecchiette", "Conchiglie", "Orzo", "Eiernudeln", "Suppennudeln", "Vollkornnudeln"],
            swap=True, also=["Pasta"]),
        grp("Gefüllte Pasta", ["Tortellini", "Tortelloni", "Ravioli"], swap=True, place=K),
        grp("Lasagneplatten", also=["Lasagneblätter"]),
        grp("Asia-Nudeln", ["Reisnudeln", "Reisbandnudeln", "Glasnudeln", "Mie-Nudeln", "Mienudeln", "Udon-Nudeln", "Udon",
                            "Ramen-Nudeln", "Soba-Nudeln", "Wok-Nudeln"], swap=True),
        grp("Spätzle", also=["Knöpfle"], place=K),
        grp("Gnocchi", place=K),
        grp("Schupfnudeln", place=K),
        grp("Reis", ["Basmatireis", "Jasminreis", "Langkornreis", "Vollkornreis", "Parboiled Reis", "Wildreis"], swap=True),
        grp("Risottoreis", ["Arborio", "Carnaroli"], swap=True),
        grp("Sushireis", ["Klebreis"], swap=True),
        grp("Milchreis"),
        grp("Couscous"),
        grp("Bulgur"),
        grp("Quinoa"),
        grp("Polenta"),
        grp("Haferflocken"),
    ]),
    ("Fleisch", K, ["Fleisch"], [
        grp("Hähnchen", ["Hähnchenbrust", "Hähnchenschenkel", "Hähnchenkeulen", "Hähnchenflügel", "Chicken Wings", "Hähnchenteile"],
            swap=True, also=["Huhn", "Hühnchen", "Hähnchenfleisch"]),
        grp("Pute", ["Putenbrust", "Putenschnitzel", "Putengeschnetzeltes"], swap=True, also=["Putenfleisch"]),
        grp("Hackfleisch", ["Rinderhack", "Schweinehack", "Gemischtes Hackfleisch", "Gemischtes Hack", "Hähnchenhack",
                            "Lammhack"], swap=True, also=["Hack"]),
        grp("Rind", ["Rindersteak", "Rinderfilet", "Rumpsteak", "Entrecôte", "Rindergulasch", "Rinderhüfte", "Roastbeef",
                     "Beinscheibe", "Suppenfleisch"], also=["Rindfleisch"]),
        grp("Schwein", ["Schweinefilet", "Schweinenacken", "Schweinebauch", "Schweinekotelett", "Schnitzel", "Schweinegulasch",
                        "Kasseler", "Schweinebraten"], also=["Schweinefleisch"]),
        grp("Lamm", ["Lammschulter", "Lammkeule", "Lammkoteletts"], also=["Lammfleisch"]),
        grp("Kalb", ["Kalbsschnitzel", "Kalbfleisch"]),
        grp("Ente", ["Entenbrust", "Entenkeule"]),
        grp("Speck", ["Speckwürfel", "Frühstücksspeck", "Bacon", "Pancetta"], swap=True),
        grp("Wurst & Schinken", ["Schinken", "Kochschinken",
                                 "Parmaschinken", "Serranoschinken", "Salami", "Chorizo", "Bratwurst", "Wiener Würstchen",
                                 "Würstchen", "Leberkäse", "Mortadella", "Weißwürste", "Fleischwurst"], also=["Wurst", "Aufschnitt"]),
    ]),
    ("Fisch", K, ["Fisch"], [
        grp("Lachs", ["Lachsfilet", "Räucherlachs"]),
        grp("Weißfisch", ["Kabeljau", "Kabeljaufilet", "Seelachs", "Dorsch", "Pangasius", "Rotbarsch", "Fischfilet"],
            swap=True, place=G),
        grp("Forelle"),
        grp("Thunfisch", place=V),
        grp("Garnelen", also=["Garnele", "Shrimps", "Crevetten", "Scampi", "Riesengarnelen"], place=G),
        grp("Fischstäbchen", place=G),
        grp("Sardellen", ["Sardellenfilets"], place=V),
        grp("Muscheln", ["Miesmuscheln", "Venusmuscheln"]),
    ]),
    ("Käse", K, ["Käse", "Geriebener Käse"], [
        grp("Hartkäse", ["Parmesan", "Grana Padano", "Pecorino", "Pecorino Romano", "Kefalotyri"], swap=True),
        grp("Mozzarella", ["Büffelmozzarella", "Burrata"], swap=True),
        grp("Feta", ["Schafskäse", "Hirtenkäse"], swap=True),
        grp("Reibekäse", ["Gratinkäse", "Pizzakäse"], swap=True),
        grp("Schnittkäse", ["Gouda", "Emmentaler", "Bergkäse", "Gruyère", "Cheddar", "Edamer", "Butterkäse", "Tilsiter",
                            "Raclettekäse"], swap=True),
        grp("Weichkäse", ["Camembert", "Brie"], swap=True),
        grp("Frischkäse", ["Doppelrahmfrischkäse", "Ziegenfrischkäse"], swap=True),
        grp("Ricotta"),
        grp("Mascarpone"),
        grp("Halloumi"),
        grp("Paneer"),
        grp("Ziegenkäse"),
        grp("Gorgonzola"),
        grp("Hüttenkäse"),
    ]),
    ("Milch & Eier", K, [], [
        grp("Milch", ["Vollmilch", "H-Milch", "Fettarme Milch", "Frischmilch"], swap=True),
        grp("Pflanzendrink", ["Haferdrink", "Hafermilch", "Sojadrink", "Sojamilch", "Mandeldrink", "Mandelmilch"], swap=True),
        grp("Buttermilch"),
        grp("Sahne", ["Schlagsahne", "Kochsahne"], swap=True, also=["Rahm"]),
        grp("Saure Sahne", ["Schmand", "Crème fraîche", "Creme fraiche", "Sauerrahm"], swap=True),
        grp("Butter", ["Margarine"], swap=True),
        grp("Joghurt", ["Naturjoghurt", "Griechischer Joghurt", "Skyr"], swap=True),
        grp("Quark", ["Magerquark", "Speisequark", "Sahnequark"], swap=True),
        grp("Eier", also=["Ei", "Eigelb", "Eiweiß"]),
        grp("Tofu", ["Fester Tofu", "Seidentofu", "Räuchertofu"]),
    ]),
    ("Gemüse", K, [], [
        grp("Kartoffeln", ["Festkochende Kartoffeln", "Mehligkochende Kartoffeln", "Vorwiegend festkochende Kartoffeln",
                           "Drillinge"], swap=True, also=["Kartoffel"], place=V),
        grp("Süßkartoffeln", also=["Süßkartoffel"], place=V),
        grp("Zwiebeln", ["Rote Zwiebeln", "Gemüsezwiebeln", "Schalotten"], swap=True, also=["Zwiebel"], place=V),
        grp("Frühlingszwiebeln", also=["Lauchzwiebeln"]),
        grp("Knoblauch", also=["Knoblauchzehe"], place=V),
        grp("Ingwer"),
        grp("Zitronengras"),
        grp("Tomaten", ["Kirschtomaten", "Cherrytomaten", "Rispentomaten", "Strauchtomaten", "Romatomaten"], swap=True,
            also=["Tomate"]),
        grp("Paprika", ["Rote Paprika", "Gelbe Paprika", "Grüne Paprika", "Spitzpaprika"], swap=True,
            also=["Paprikaschote"]),
        grp("Gurke", ["Salatgurke", "Minigurken"], swap=True),
        grp("Karotten", ["Möhren"], swap=True, also=["Karotte", "Möhre"]),
        grp("Zucchini"),
        grp("Aubergine"),
        grp("Brokkoli"),
        grp("Blumenkohl"),
        grp("Spinat", ["Blattspinat", "Babyspinat"], swap=True),
        grp("Salat", ["Eisbergsalat", "Kopfsalat", "Romanasalat", "Feldsalat", "Rucola"], also=["Blattsalat"]),
        grp("Kohl", ["Weißkohl", "Rotkohl", "Spitzkohl", "Wirsing"], also=["Kraut"]),
        grp("Chinakohl"),
        grp("Rosenkohl"),
        grp("Kohlrabi"),
        grp("Pak Choi"),
        grp("Lauch", also=["Porree"]),
        grp("Sellerie", ["Staudensellerie", "Knollensellerie", "Sellerieknolle"]),
        grp("Suppengrün"),
        grp("Fenchel"),
        grp("Pilze", ["Champignons", "Braune Champignons", "Shiitake", "Kräuterseitlinge", "Pfifferlinge", "Steinpilze"],
            swap=True),
        grp("Kürbis", ["Hokkaido-Kürbis", "Hokkaidokürbis", "Butternut-Kürbis"], swap=True),
        grp("Rote Bete", also=["Rote Beete"]),
        grp("Radieschen"),
        grp("Avocado"),
        grp("Mais", ["Maiskolben", "Zuckermais"], place=V),
        grp("Erbsen", place=G),
        grp("Grüne Bohnen", also=["Prinzessbohnen", "Brechbohnen"]),
        grp("Sojasprossen", also=["Mungobohnensprossen"]),
        grp("Chili", ["Chilischote", "Grüne Chili", "Rote Chili", "Jalapeño"], swap=True),
        grp("Spargel", ["Grüner Spargel", "Weißer Spargel"]),
    ]),
    ("Obst", K, [], [
        grp("Zitrone", ["Bio-Zitrone", "Zitronensaft"], swap=True, also=["Zitronen"]),
        grp("Limette", ["Limettensaft"], swap=True, also=["Limetten"]),
        grp("Orange", also=["Orangen"]),
        grp("Äpfel", ["Säuerliche Äpfel"], also=["Apfel"], place=V),
        grp("Birne", also=["Birnen"]),
        grp("Granatapfel"),
        grp("Bananen", also=["Banane"], place=V),
        grp("Beeren", ["Heidelbeeren", "Himbeeren", "Erdbeeren", "Johannisbeeren", "Brombeeren", "Preiselbeeren"]),
        grp("Weintrauben", also=["Trauben"]),
        grp("Ananas", place=V),
        grp("Mango", place=V),
    ]),
    ("Kräuter & Gewürze", V, [], [
        grp("Petersilie", place=K),
        grp("Koriander", also=["Koriandergrün"], place=K),
        grp("Basilikum", ["Thai-Basilikum"], place=K),
        grp("Schnittlauch", place=K),
        grp("Dill", place=K),
        grp("Minze", place=K),
        grp("Thymian"),
        grp("Rosmarin"),
        grp("Oregano"),
        grp("Majoran"),
        grp("Salbei"),
        grp("Lorbeer", also=["Lorbeerblatt", "Lorbeerblätter"]),
        grp("Paprikapulver", ["Paprika edelsüß", "Paprika rosenscharf", "Paprika scharf", "Paprika geräuchert"], swap=True),
        grp("Kreuzkümmel", also=["Kreuzkümmelsamen", "Cumin"]),
        grp("Kümmel"),
        grp("Kurkuma"),
        grp("Curry", ["Currypulver", "Garam Masala", "Rote Currypaste", "Grüne Currypaste"]),
        grp("Zimt", also=["Zimtstange"]),
        grp("Muskat", also=["Muskatnuss"]),
        grp("Chilipulver", ["Chiliflocken", "Pul Biber", "Gochugaru", "Cayennepfeffer"], swap=True),
        grp("Knoblauchpulver"),
        grp("Kräuter der Provence"),
        grp("Sternanis"),
        grp("Nelken", also=["Gewürznelken"]),
        grp("Kardamom", also=["Kardamomkapseln"]),
        grp("Vanille", ["Vanilleschote", "Vanilleextrakt"]),
        grp("Sesam"),
    ]),
    ("Saucen & Konserven", V, [], [
        grp("Butterschmalz", ["Ghee", "Schmalz", "Schweineschmalz"], swap=True),
        grp("Öl", ["Olivenöl", "Rapsöl", "Sonnenblumenöl", "Neutrales Öl", "Sesamöl", "Kokosöl", "Erdnussöl"]),
        grp("Essig", ["Balsamico", "Weißweinessig", "Rotweinessig", "Apfelessig", "Reisessig", "Schwarzer Reisessig"]),
        grp("Brühe", ["Gemüsebrühe", "Hühnerbrühe", "Rinderbrühe", "Geflügelfond", "Wildfond", "Fond"]),
        grp("Dosentomaten", ["Stückige Tomaten", "Passierte Tomaten", "Geschälte Tomaten", "Tomatenwürfel"], swap=True,
            also=["Tomatenstücke"]),
        grp("Tomatenmark"),
        grp("Kokosmilch"),
        grp("Kichererbsen"),
        grp("Linsen", ["Rote Linsen", "Gelbe Linsen", "Tellerlinsen", "Belugalinsen"]),
        grp("Bohnen", ["Kidneybohnen", "Weiße Bohnen", "Schwarze Bohnen", "Edamame"]),
        grp("Sojasauce", ["Helle Sojasauce", "Dunkle Sojasauce", "Ketjap Manis"], also=["Sojasoße"]),
        grp("Fischsauce"),
        grp("Worcestersauce"),
        grp("Austernsauce"),
        grp("Hoisinsauce"),
        grp("Senf", ["Dijonsenf", "Mittelscharfer Senf", "Süßer Senf", "Körniger Senf"]),
        grp("Ketchup"),
        grp("Mayonnaise"),
        grp("Honig"),
        grp("Ahornsirup"),
        grp("Erdnussbutter"),
        grp("Tahin", also=["Tahini"]),
        grp("Gewürzgurken"),
        grp("Kapern"),
        grp("Oliven", ["Schwarze Oliven", "Grüne Oliven", "Kalamata-Oliven"]),
        grp("Sauerkraut"),
        grp("Kimchi", place=K),
        grp("Asia-Würzpasten", ["Gochujang", "Sambal Oelek", "Sriracha", "Doubanjiang", "Miso"]),
        grp("Saft", ["Apfelsaft", "Orangensaft", "Ananassaft"]),
        grp("Nori", also=["Nori-Blatt", "Noriblätter"]),
        grp("Wein", ["Weißwein", "Rotwein", "Shaoxing-Wein", "Mirin", "Sake"]),
    ]),
    ("Backen & Süßes", V, [], [
        grp("Mehl", ["Weizenmehl", "Dinkelmehl", "Vollkornmehl", "Roggenmehl"], swap=True),
        grp("Zucker", ["Brauner Zucker", "Rohrzucker"], swap=True),
        grp("Puderzucker"),
        grp("Vanillezucker"),
        grp("Speisestärke", ["Maisstärke", "Kartoffelstärke"], swap=True),
        grp("Backpulver"),
        grp("Natron"),
        grp("Hefe", ["Frische Hefe", "Trockenhefe"]),
        grp("Schokolade", ["Zartbitterschokolade", "Vollmilchschokolade", "Zartbitterkuvertüre", "Kuvertüre"]),
        grp("Kakao", also=["Kakaopulver"]),
        grp("Nüsse", ["Mandeln", "Gemahlene Mandeln", "Haselnüsse", "Gemahlene Haselnüsse", "Walnüsse", "Cashewkerne",
                      "Erdnüsse", "Pinienkerne"]),
        grp("Trockenobst", ["Getrocknete Aprikosen", "Datteln", "Cranberrys"]),
        grp("Kerne", ["Sonnenblumenkerne", "Kürbiskerne"]),
        grp("Rosinen"),
        grp("Kokosraspel"),
        grp("Blätterteig", place=K),
        grp("Semmelbrösel", ["Paniermehl", "Panko"], swap=True),
    ]),
    ("Brot", V, [], [
        grp("Brot", ["Toastbrot", "Baguette", "Fladenbrot", "Vollkornbrot"]),
        grp("Brötchen", ["Burgerbrötchen", "Altbackene Brötchen"]),
        grp("Knödelbrot"),
        grp("Tortillas", ["Weizentortillas"], also=["Wraps"]),
        grp("Pitabrot", also=["Pita"]),
    ]),
]

PORTION = {"zeh", "schot", "filet", "würfel", "streif", "scheib", "ring", "blätt", "blätter", "blatt", "stang", "knoll",
           "kugel", "zweig", "stück", "hälft", "flock", "flöckch", "kapsel", "röschen", "stiel"}


def stem(w):
    for suf in ("en", "n", "e", "s"):
        if w.endswith(suf) and len(w) - len(suf) >= 4:
            return w[: -len(suf)]
    return w


def words(s):
    s = s.lower()
    s = re.split(r"[,(]", s)[0]
    return [stem(w) for w in re.split(r"[\s\-/]+", s) if w]


def portion_rest(rest):
    for link in ("", "en", "n", "s", "e"):
        if rest.startswith(link):
            r = rest[len(link):]
            if r and (r in PORTION or stem(r) in PORTION):
                return True
    return False


def word_hit(w, t):
    """0 = kein Treffer, 2 = gleich, 1 = Wortende/Portion"""
    if w == t:
        return 2
    if len(t) >= 4 and w.endswith(t):
        return 1
    if len(t) >= 4 and w.startswith(t) and portion_rest(w[len(t):]):
        return 1
    return 0


def build_terms():
    terms = []  # (words, länge, cat, group, sort)
    def add(text, c, g, s):
        terms.append((words(text), len(text), c, g, s))
    for ci, (cname, _, cal, groups) in enumerate(CATALOG):
        for a in cal:
            add(a, ci, None, None)
        for gi, g in enumerate(groups):
            add(g["name"], ci, gi, None)
            for a in g["also"]:
                add(a, ci, gi, None)
            for s in g["sorts"]:
                add(s, ci, gi, s)
    return terms


TERMS = build_terms()


def resolve_one(text):
    W = words(text)
    best, score = None, 0
    for tw, ln, c, g, s in TERMS:
        n = len(tw)
        for i in range(len(W) - n + 1):
            ok = all(W[i + k] == tw[k] for k in range(n - 1))
            if not ok:
                continue
            h = word_hit(W[i + n - 1], tw[-1])
            if not h:
                continue
            sc = ln * 10 + (5 if h == 2 else 0)
            if sc > score:
                best, score = (c, g, s), sc
    return best


def resolve(text):
    return [resolve_one(p) for p in re.split(r"\s+oder\s+", text.lower())]


def key(s):
    return re.split(r"[,(]", s.lower())[0].strip()


def match_ids(p, i):
    if p is None or i is None:
        return False
    if p[0] != i[0]:
        return False
    if p[1] is None or i[1] is None:
        return True
    if p[1] != i[1]:
        return False
    if p[2] is None or i[2] is None or p[2] == i[2]:
        return True
    return CATALOG[p[0]][3][p[1]]["swap"]


def matches(pantry, ingredient):
    pk, ik = key(pantry), key(ingredient)
    if not pk or not ik:
        return False
    if pk == ik:
        return True
    P = [(key(t), resolve_one(t)) for t in re.split(r"\s+oder\s+", pk)]
    I = [(key(t), resolve_one(t)) for t in re.split(r"\s+oder\s+", ik)]
    for pt, pi in P:
        for it, ii in I:
            if pi is None and ii is None:
                if pt and it and (pt in it or it in pt):   # beides unbekannt: alter Textvergleich
                    return True
            elif match_ids(pi, ii):
                return True
    return False


def label(r):
    if r is None:
        return "–"
    c, g, s = r
    cn = CATALOG[c][0]
    return cn if g is None else f"{cn} › {CATALOG[c][3][g]['name']}" + (f" › {s}" if s else "")


# ---------- Test ----------

def test():
    root = os.path.join(os.path.dirname(__file__), "..", "..")
    data = json.load(open(os.path.join(root, "apps/rezepte/data/index.json")))
    cnt = collections.Counter(i for r in data for i in (r.get("ing") or []))
    unresolved = collections.Counter()
    for name, n in cnt.items():
        if all(x is None for x in resolve(name)):
            unresolved[key(name)] += n
    total = sum(cnt.values())
    print(f"Zutaten-Nennungen: {total}, ohne Treffer: {sum(unresolved.values())}")
    print("Häufigste ohne Treffer:", unresolved.most_common(60))
    cases = [
        ("Nudeln", "Tagliatelle", True), ("Spaghetti", "Tagliatelle", True), ("Tagliatelle", "Nudeln", True),
        ("Spaghetti", "Penne", True), ("Penne", "Reisnudeln", False), ("Reis", "Reisnudeln", False),
        ("Reis", "Basmatireis", True), ("Basmatireis", "Jasminreis", True), ("Basmatireis", "Risottoreis", False),
        ("Käse", "Frischkäse", True), ("Käse", "Parmesan", True), ("Parmesan", "Mozzarella", False),
        ("Parmesan", "Pecorino", True), ("Gouda", "geriebener Käse", True), ("Käse", "Leberkäse", False),
        ("Fleisch", "Hähnchenbrust", True), ("Hähnchenbrust", "Hackfleisch", False), ("Hackfleisch", "Rinderhack", True),
        ("Rinderhack", "Schweinehack", True), ("Knoblauch", "Knoblauchzehen", True), ("Zwiebeln", "rote Zwiebel", True),
        ("Zwiebeln", "Frühlingszwiebeln", False), ("Paprika", "Paprika edelsüß", False), ("Paprika", "rote Paprikaschote", True),
        ("Milch", "Milch oder Haferdrink", True), ("Hafermilch", "Milch oder Haferdrink", True), ("Milch", "Kokosmilch", False),
        ("Milch", "Buttermilch", False), ("Butter", "weiche Butter", True), ("Butter", "Erdnussbutter", False),
        ("Erbsen", "Kichererbsen", False), ("Lauch", "Schnittlauch", False), ("Tomaten", "Tomatenmark", False),
        ("Tomaten", "Kirschtomaten", True), ("Tomaten", "passierte Tomaten", False), ("Lachs", "Lachsfilets", True),
        ("Kartoffeln", "festkochende Kartoffeln", True), ("Kartoffeln", "Kartoffelstärke", False),
        ("Eier", "Eigelb", True), ("Eier", "Ei", True), ("Reis", "Reisessig", False), ("Mehl", "Weizenmehl", True),
        ("Zitrone", "Bio-Zitrone", True), ("Spinat", "Babyspinat", True), ("Speck", "Speckwürfel", True),
        ("Fisch", "Kabeljaufilet", True), ("Thunfisch", "Lachs", False), ("Sahne", "saure Sahne", False),
        ("Schmand", "Crème fraîche", True), ("Zucker", "Puderzucker", False), ("Mozzarella", "Burrata", True),
        ("Dashi", "Dashi oder Brühe", True), ("Äpfel", "Granatapfel", False), ("Salami", "Speck", False),
    ]
    bad = 0
    for p, i, want in cases:
        got = matches(p, i)
        if got != want:
            bad += 1
            print(f"FALSCH: {p!r} ↔ {i!r}: {got} (soll {want})  [{label(resolve(p)[0])} | {[label(x) for x in resolve(i)]}]")
    print(f"{len(cases) - bad}/{len(cases)} Fälle richtig")
    return bad == 0


# ---------- Swift erzeugen ----------

def swift_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def generate():
    out = ["// Erzeugt von tools/vorrat/katalog.py – nicht von Hand ändern.", "", "extension FoodCatalog {",
           "    static let categories: [FoodCategory] = ["]
    for cname, place, cal, groups in CATALOG:
        out.append(f"        FoodCategory(name: {swift_str(cname)}, place: {swift_str(place)}, "
                   f"also: [{', '.join(map(swift_str, cal))}], groups: [")
        for g in groups:
            out.append(f"            FoodGroup(name: {swift_str(g['name'])}, place: {swift_str(g['place'] or place)}, "
                       f"swap: {'true' if g['swap'] else 'false'}, also: [{', '.join(map(swift_str, g['also']))}], "
                       f"sorts: [{', '.join(map(swift_str, g['sorts']))}]),")
        out.append("        ]),")
    out += ["    ]", "", f"    static let portionWords: Set<String> = [{', '.join(map(swift_str, sorted(PORTION)))}]", "}", ""]
    path = os.path.join(os.path.dirname(__file__), "..", "..", "ios/HubertNext/HubertNext/Core/FoodCatalogData.swift")
    open(path, "w").write("\n".join(out))
    print("geschrieben:", os.path.normpath(path))


if __name__ == "__main__":
    if "--test" in sys.argv:
        sys.exit(0 if test() else 1)
    generate()
