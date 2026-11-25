"""Zutaten je Rezeptschritt – vorberechnet für die App (Kochmodus und Rezeptansicht).

Wie StepIngredients in der App: Wörter im Schritttext gegen die Zutatennamen, erst genau, dann lose.
Dazu Sammelwörter: „Gemüse würfeln, Kräuter hacken“ → welche Zutaten gemeint sind (Gemüse aus der
Zutatenliste, das in keinem früheren Schritt schon dran war und nicht erst später genannt wird).
Der Schritttext bekommt sie in Klammern dazu: „Gemüse (Salatgurke, Kirschtomaten, rote Zwiebel) würfeln“.
"""
import re
import naehrwerte as NW

STOP = set(("frisch frische frischer gehackt gehackte gemahlen gemahlener getrocknet getrocknete klein kleine "
            "große groß rot rote roter gelb gelbe grün grüne weiß weiße schwarz schwarzer optional fein feine gewürfelt geschält ca etwas "
            "zum braten für den die das und oder nach geschmack bio tk dose glas reif reife sehr geschmolzene braune brauner heller dunkle "
            "zerlassen festkochende mehligkochende servieren kühlregal").split())


def words(s):
    return [w for w in re.split(r"[^a-zäöüß]+", s.lower()) if w]


def stem(w):
    for suf in ("innen", "en", "er", "n", "e", "s"):
        if w.endswith(suf) and len(w) - len(suf) >= 4:
            return w[: -len(suf)]
    return w


# „Knoblauchzehen“ soll auch bei „Knoblauch“ im Schritt passen, „Lachsfilets“ bei „Lachs“
SUFFIX = ("zehen", "zehe", "stangen", "stange", "filets", "filet", "schoten", "schote", "knolle", "kapseln",
          "körner", "samen", "würfel")


def keys(name):
    n = re.sub(r"\([^)]*\)", "", name)
    n = n.split(",")[0]
    w = words(n)
    k = [x for x in w if len(x) >= 3 and x not in STOP]
    k = k if k else w[-1:]
    for x in list(k):
        for suf in SUFFIX:
            if x.endswith(suf) and len(x) - len(suf) >= 4:
                k.append(x[: -len(suf)])
                break
    return k


def strong(k, w):
    return w == k or stem(w) == stem(k) or (len(k) >= 4 and w.endswith(k))


def weak(k, w):
    ks = stem(k)
    return ((len(w) >= 3 and k.endswith(w) and len(w) >= max(3, len(k) // 3))
            or (w == "öl" and k.endswith("öl"))
            or (len(ks) >= 5 and w.startswith(ks)))


def explicit(text, ings, ik):
    out = []
    for w in words(text):
        if len(w) < 2:
            continue
        hit = [i for i in range(len(ings)) if any(strong(k, w) for k in ik[i])]
        if not hit:
            hit = [i for i in range(len(ings)) if any(weak(k, w) for k in ik[i])]
        for i in hit:
            if i not in out:
                out.append(i)
    return out


GENERIC = [  # (Muster im Text, Kategorien, Gruppenname)
    (re.compile(r"(?<![-\w])(Gemüse)(?![-\w])"), {"veg"}, "gemüse"),
    (re.compile(r"(?<![-\w])(Kräuter|Kräutern)(?![-\w])"), {"herb"}, "kräuter"),
    (re.compile(r"(?<![-\w])(Gewürze|Gewürzen|Gewürzmischung)(?![-\w])"), {"spice"}, "gewürze"),
]
# Würzendes wie Knoblauch steht fast immer extra im Schritt – nicht als „Gemüse“ mitzählen
AROMA = re.compile(r"knoblauch|ingwer|galgant|chili|jalapeño|peperoni|zitronengras")
SIMPLE = [
    (re.compile(r"(?<![-\w])(Fleisch|Fleischs|Fleisches)(?![-\w])"),
     re.compile(r"(?<![a-zäöüß])(hähnchen|huhn|hühn|pute|rind|schwein|kalb|lamm|hack|gulasch|steak|rumpsteak|schnitzel|"
                r"ente|gans|gänse|reh|hirsch|wild|kassler|kasseler|kotelett|tafelspitz|roulade|roastbeef|beinscheibe|"
                r"suppenfleisch|schäufele|chicken)")),
    (re.compile(r"(?<![-\w])(Käse)(?![-\w])"),
     re.compile(r"(?<!frisch)käse|parmesan|pecorino|gouda|emmentaler|gruyère|greyerzer|cheddar|mozzarella|feta|raclette|"
                r"vacherin|camembert|gorgonzola|halloumi|grana|appenzeller")),
    (re.compile(r"(?<![-\w])(Fisch|Fischfilets?)(?![-\w])"),
     re.compile(r"lachs|kabeljau|fisch|forelle|seelachs|thunfisch|dorsch|zander|karpfen|matjes|scholle")),
]
NOT_FOOD = re.compile(r"brühe|fond|sauce|soße|rinderknochen|markknochen|gewürz|leberkäse|fischsauce|brät|wildreis|wildkräuter")
LEAFY = re.compile(r"salat|rucola|spinat|kresse|feldsalat|sprossen")
PREP = re.compile(r"schneiden|würfeln|putzen|schälen|hacken|zerkleinern|raspeln|hobeln|waschen|zupfen|reiben|stücke|streifen|scheiben")
DRY = re.compile(r"^\s*[\d½¼¾⅓⅔,.–-]*\s*(tl|el|prise|msp)\b", re.I)


def category(ing):
    f = NW.find(ing["name"])
    if not f:
        return None
    c = f["cat"]
    if c == "herb" and (DRY.match(ing.get("amount") or "") or "getrocknet" in ing["name"].lower()):
        return "spice"                       # „1 TL Oregano“ gehört zu den Gewürzen
    if c == "veg" and "=paprika" in f["keys"] and DRY.match(ing.get("amount") or ""):
        return "spice"
    return c


def short(name):
    n = re.sub(r"\s*\([^)]*\)", "", name).split(",")[0].strip()
    m = NW.NAME_UNIT.match(n.lower())
    if m:                                    # „Zweige Thymian“ → „Thymian“
        n = n[len(n) - len(m.group(2)):]
    return n[:1].upper() + n[1:] if n[:1].islower() and n.split()[0].lower() not in ("rote", "roter", "grüne", "grüner", "gelbe", "kleiner", "kleine", "große", "sehr", "frische", "getrocknete", "geräuchertes", "edelsüßes", "weiße", "schwarze") else n


def annotate(r):
    """r: Rezept-JSON. Setzt step["use"] (Indizes in die Zutaten ohne Gruppen) und ergänzt Sammelwörter im Text."""
    ings, groups, g = [], [], ""
    for x in r["ingredients"]:
        if "name" in x:
            ings.append(x); groups.append(g)
        else:
            g = x["group"].lower()
    ik = [keys(x["name"]) for x in ings]
    steps = r["steps"]
    exp = [explicit(s["text"], ings, ik) for s in steps]
    first = {}
    for si, e in enumerate(exp):
        for i in e:
            first.setdefault(i, si)
    cats = [category(x) for x in ings]
    changed = 0
    for si, s in enumerate(steps):
        use = list(exp[si])
        text = s["text"]
        for pat, cs, gname in GENERIC:
            m = pat.search(text)
            if not m:
                continue
            # der Satz mit dem Sammelwort; „Warum …“-Erklärungen bleiben, wie sie sind
            a = max(text.rfind(". ", 0, m.start()) + 2, 0) if text.rfind(". ", 0, m.start()) >= 0 else 0
            b = text.find(". ", m.end())
            sentence = text[a: b if b >= 0 else len(text)]
            if sentence.lstrip().startswith("Warum"):
                continue
            word = m.group(1).lower()
            if any(strong(k, word) or strong(k, stem(word)) for kk in ik for k in kk):
                continue                         # es gibt eine Zutat „Kräuter“ o. Ä. – dann passt der normale Abgleich
            def fits(i):
                return cats[i] in cs and not (gname == "gemüse" and AROMA.search(ings[i]["name"].lower()))
            grp = [i for i in range(len(ings)) if gname in groups[i]]
            if grp:
                cand = [i for i in grp if fits(i)] or grp
            elif PREP.search(sentence.lower()):
                # Vorbereiten: alles Passende, das nicht schon vorher oder in diesem Schritt dran war
                # (Blattgrün, das erst später genannt wird, wird dort verarbeitet – nicht gewürfelt)
                cand = [i for i in range(len(ings)) if fits(i) and i not in exp[si] and first.get(i, si) >= si
                        and not (first.get(i, si) > si and LEAFY.search(ings[i]["name"].lower()))]
            else:
                # Weiterverarbeiten: was vorher schon vorbereitet wurde (oder nie genannt ist)
                cand = [i for i in range(len(ings)) if fits(i) and i not in exp[si] and first.get(i, si) <= si]
            if not cand:
                continue
            for i in cand:
                if i not in use:
                    use.append(i)
            names = [short(ings[i]["name"]) for i in cand]
            after = text[m.end():m.end() + 2]
            if len(names) <= 6 and not after.lstrip().startswith("("):
                text = text[:m.end()] + " (" + ", ".join(names) + ")" + text[m.end():]
                changed += 1
        # „Fleisch anbraten“, „mit Käse bestreuen“: welches, zeigt die Zutatenliste im Schritt (Text bleibt)
        low = text.lower()
        for pat, rx in SIMPLE:
            if pat.search(text):
                hits = [i for i in range(len(ings)) if rx.search(ings[i]["name"].lower())
                        and not NOT_FOOD.search(ings[i]["name"].lower())]
                if hits and not any(i in use for i in hits):
                    use += [i for i in hits if first.get(i, si) <= si] or hits
        s["text"] = text
        s["use"] = use
    return changed
