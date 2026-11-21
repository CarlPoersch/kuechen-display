"""Erzeugt Rezept-JSON-Dateien + index.json aus den kompakten Datendateien."""
import json, os, re, sys

RECIPES = []

def R(id, title, icon, cuisine, servings, time, ings, steps, airfryer=False, cat=None, level=None, diet=None):
    RECIPES.append(dict(id=id, title=title, icon=icon, cuisine=cuisine, servings=servings,
                        time=time, ings=ings, steps=steps, airfryer=airfryer, cat=cat, level=level, diet=diet))

OLD_DIET = {"af-gyoza": "fleisch", "rotkohl": "vegetarisch"}

# ---------- Einordnung: Kategorie, Ernährung, Zeit, Aufwand ----------
CATS = ["Hauptgericht", "Suppe", "Salat", "Beilage", "Snack", "Frühstück", "Dessert", "Backen", "Getränk"]

# Kategorien der ersten 120 Rezepte (alles andere: Hauptgericht)
OLD_CATS = {
    "af-chicken-wings": "Snack", "af-suesskartoffel": "Beilage", "af-fruehlingsrollen": "Snack", "suan-la-tang": "Suppe",
    "af-apfeltaschen": "Dessert", "af-pommes": "Beilage", "kaiserschmarrn": "Dessert", "kartoffelsuppe": "Suppe",
    "linseneintopf": "Suppe", "obatzda": "Snack", "apfelkuchen": "Backen", "crepes": "Dessert", "zwiebelsuppe": "Suppe",
    "naan": "Beilage", "mango-lassi": "Getränk", "af-samosa": "Snack", "minestrone": "Suppe", "tiramisu": "Dessert",
    "miso-suppe": "Suppe", "af-gyoza": "Snack", "gazpacho": "Suppe", "horiatiki": "Salat", "guacamole": "Snack",
    "hummus": "Snack", "tabouleh": "Salat", "larb-gai": "Salat", "mango-sticky-rice": "Dessert", "som-tam": "Salat",
    "tom-kha-gai": "Suppe", "tom-yum-goong": "Suppe", "goi-cuon": "Snack", "pho-bo": "Suppe", "kimchi-jjigae": "Suppe",
    "shoyu-ramen": "Suppe", "af-baked-potato": "Beilage",
}

MEAT = r"hähnchen|huhn|hühner|geflügel|rind|schwein|hack(?!t)|speck|pancetta|guanciale|schinken|wurst|würst|lamm|kalb|ente\b|entenbrust|pute|truthahn|chorizo|salami|bacon|leber|gulasch|fleisch|gelatine|frikadelle|kassler|leberkäse|\bwild(?:schwein|fleisch|gulasch)?\b|hirsch|\breh\b|\bmett\b|nduja|prosciutto|serrano|lardo|knochen|markknochen|(?<!butter)schmalz|nierenfett|kochschinken|chicken|tafelspitz|steak|roastbeef|beef|kotelett|schnitzel|gänse|\bgans|brät\b|lyoner|mettend|salsiccia|hendl|ochsen|kutteln|zunge|ossobuco|merguez|cevapcici|döner|gyros|pulled pork|spareribs|rippchen|haxe|eisbein|weißwurst|weisswurst|nürnberger|krakauer|kabanos|pastrami|bresaola|mortadella|coppa|chorizo"
FISH = r"lachs|thunfisch|garnele|fisch|kabeljau|forelle|sardelle|sardine|muschel|tintenfisch|calamar|shrimp|krabbe|austernsauce|bonito|dashi|hering|matjes|scholle|seelachs|zander|makrele|scampi|hummer|krebs|meeresfrüchte|anchovis|alaska|dorsch|saibling|wolfsbarsch|dorade|pangasius|rotbarsch|surimi|kaviar"
ANIMAL = r"\bei\b|\beier\b|eigelb|eiweiß|\bmilch\b|vollmilch|butter(?!milch)|buttermilch|sahne|käse|parmesan|mozzarella|feta|pecorino|gouda|emmentaler|ricotta|mascarpone|quark|joghurt|crème|creme fraîche|schmand|paneer|halloumi|ghee|honig|frischkäse|gruyère|bergkäse|kondensmilch|burrata|grana|cheddar|camembert|brie|raclette|skyr|kefir|molke|hüttenkäse|ziegenkäse|schafskäse|labneh|eierlikör|baiser|lassi|dickmilch"
VEGAN_OK = r"kokosmilch|kokossahne|hafermilch|mandelmilch|sojamilch|pflanzenmilch|sojasahne|hafersahne|erdnussbutter|mandelbutter|vegane|veganer|veganes|vegan|kakaobutter|sojajoghurt|kokosjoghurt|tahin|cashewmus|nussmus|reismilch"
GLUTEN = r"mehl|nudel|spaghetti|penne|tagliatelle|fusilli|farfalle|linguine|rigatoni|lasagne|makkaroni|maccheroni|brot|brötchen|semmel|weizen|teig|paniermehl|panko|brezn|breze|couscous|bulgur|gerste|graupen|dinkel|sojasauce|tortilla|gnocchi|spätzle|spatzen|bier|seitan|udon|ramen|pizza|toast|baguette|pita|fladen|naan|grieß|hafer|knödel|croissant|keks|zwieback|biskuit|löffelbiskuit|tortellini|ravioli|orzo|trofie|maultasche|wan-tan|wonton|filo|yufka|blätterteig|ciabatta|focaccia|crouton|crêpe|waffel|kuchen|biscuit|cracker|cornflakes|müsli|malz|weißwein-?essig"
GLUTEN_OK = r"reismehl|maismehl|maisstärke|kichererbsenmehl|buchweizenmehl|kartoffelmehl|glutenfrei|tamari|reisnudel|glasnudel|reisteig|reispapier|mandelmehl|kokosmehl|tapiokamehl|teigwaren aus reis"

def _has(pat, text):
    return re.search(pat, text) is not None

def classify_diet(names):
    t = " | ".join(n.lower() for n in names)
    clean = re.sub(VEGAN_OK, "", t)
    c2 = re.sub(r"gemüsebrühe|gemüsefond|pilzbrühe|gemüse-?brühe|leberwurst-?frei", "", clean)
    # "Fleischtomate" ist Gemüse, "Wildreis" kein Wild, "Ei" in "Reis" ist durch \b geschützt
    c2 = re.sub(r"fleischtomate|wildreis|wildkräuter|rinderbrühe ersatz|eisbergsalat|eiskalt|eiswürfel|wildbeere", "", c2)
    if _has(MEAT, c2): return "fleisch"
    if _has(FISH, c2): return "fisch"
    if _has(ANIMAL, c2): return "vegetarisch"
    return "vegan"

def gluten_free(names):
    t = " | ".join(n.lower() for n in names)
    t = re.sub(GLUTEN_OK, "", t)
    return not _has(GLUTEN, t)

def parse_minutes(time):
    t = (time or "").split("(")[0]
    h = re.search(r"(\d+)\s*Std", t); m = re.search(r"(\d+)\s*Min", t)
    total = (int(h.group(1)) * 60 if h else 0) + (int(m.group(1)) if m else 0)
    return total or None

def guess_level(minutes, steps, ings):
    if minutes is None: minutes = 45
    if minutes <= 30 and len(steps) <= 6 and len(ings) <= 10: return "einfach"
    if minutes >= 120 or len(steps) >= 9 or len(ings) >= 16: return "anspruchsvoll"
    return "mittel"

def build(out_dir):
    import importlib
    sys.modules["gen"] = sys.modules[__name__]
    mods = ["data_asien1", "data_asien2", "data_europa", "data_welt", "data_airfryer"]
    here = os.path.dirname(os.path.abspath(__file__))
    mods += sorted(f[:-3] for f in os.listdir(here) if f.startswith("neu_") and f.endswith(".py"))
    for m in mods:
        importlib.import_module(m)

    ids = set()
    index = []
    for r in RECIPES:
        assert r["id"] not in ids, r["id"]
        ids.add(r["id"])
        ingredients = []
        for s in r["ings"]:
            if s.startswith("#"):
                ingredients.append({"group": s[1:]})
                continue
            assert "|" in s, (r["id"], s)
            amount, name = s.split("|", 1)
            # "Parmesan|zum Servieren" -> ohne Menge, Hinweis in Klammern
            if re.match(r"^(zum|nach) ", name):
                amount, name = "", f"{amount} ({name})"
            ingredients.append({"amount": amount, "name": name})
        steps = []
        for s in r["steps"]:
            m = re.search(r"\s*@(\d+)$", s)
            if m:
                steps.append({"text": s[:m.start()], "minutes": int(m.group(1))})
            else:
                steps.append({"text": s})
        assert ingredients and steps, r["id"]
        names = [i["name"] for i in ingredients if "name" in i]
        cat = r["cat"] or OLD_CATS.get(r["id"], "Hauptgericht")
        assert cat in CATS, (r["id"], cat)
        minutes = parse_minutes(r["time"])
        data = {"id": r["id"], "title": r["title"], "icon": r["icon"], "cuisine": r["cuisine"],
                "servings": r["servings"], "time": r["time"], "ingredients": ingredients, "steps": steps,
                "cat": cat, "diet": r["diet"] or OLD_DIET.get(r["id"]) or classify_diet(names), "level": r["level"] or guess_level(minutes, steps, names)}
        if minutes: data["min"] = minutes
        if gluten_free(names): data["gf"] = True
        if r["airfryer"]:
            data["airfryer"] = True  # nutzt den Airfryer
        if r["id"].startswith("af-"):
            data["tab"] = "airfryer"  # speziell für den Airfryer -> eigener Tab
        with open(os.path.join(out_dir, r["id"] + ".json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
        entry = {k: data[k] for k in ("id", "title", "icon", "cuisine", "servings", "time", "airfryer", "tab", "cat", "diet", "level", "min", "gf") if k in data}
        # Zutatennamen für "Was kann ich kochen?" (ohne Mengen), damit dafür nicht jedes Rezept geladen werden muss
        entry["ing"] = [i["name"] for i in ingredients if "name" in i]
        index.append(entry)

    # Bestehendes Biang-Biang-Rezept übernehmen
    bb_path = os.path.join(out_dir, "biang-biang.json")
    bb = json.load(open(bb_path, encoding="utf-8"))
    bb["cuisine"] = "Chinesisch"
    json.dump(bb, open(bb_path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    bnames = [i["name"] for i in bb["ingredients"] if "name" in i]
    bb.update(cat="Hauptgericht", diet=classify_diet(bnames), level="anspruchsvoll", min=105)
    json.dump(bb, open(bb_path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    bbe = {k: bb[k] for k in ("id", "title", "icon", "cuisine", "servings", "time", "cat", "diet", "level", "min")}
    bbe["ing"] = [i["name"] for i in bb["ingredients"] if "name" in i]
    index.insert(0, bbe)

    index.sort(key=lambda x: (x["cuisine"], x["title"]))
    with open(os.path.join(out_dir, "index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=1)
    from collections import Counter
    from collections import Counter
    print("Kategorien:", dict(Counter(i["cat"] for i in index)), "| Ernährung:", dict(Counter(i["diet"] for i in index)),
          "| Aufwand:", dict(Counter(i["level"] for i in index)), "| glutenfrei:", sum(1 for i in index if i.get("gf")))
    print(len(index), "Rezepte, davon Airfryer:", sum(1 for i in index if i.get("airfryer")), dict(Counter(i["cuisine"] for i in index if i["id"].startswith("af-"))), "|", dict(Counter(i["cuisine"] for i in index)))

if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    build(sys.argv[1])
