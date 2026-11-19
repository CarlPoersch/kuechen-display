"""Erzeugt Rezept-JSON-Dateien + index.json aus den kompakten Datendateien."""
import json, os, re, sys

RECIPES = []

def R(id, title, icon, cuisine, servings, time, ings, steps, airfryer=False):
    RECIPES.append(dict(id=id, title=title, icon=icon, cuisine=cuisine, servings=servings,
                        time=time, ings=ings, steps=steps, airfryer=airfryer))

def build(out_dir):
    import importlib
    sys.modules["gen"] = sys.modules[__name__]
    for m in ["data_asien1", "data_asien2", "data_europa", "data_welt", "data_airfryer"]:
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
        data = {"id": r["id"], "title": r["title"], "icon": r["icon"], "cuisine": r["cuisine"],
                "servings": r["servings"], "time": r["time"], "ingredients": ingredients, "steps": steps}
        if r["airfryer"]:
            data["airfryer"] = True  # nutzt den Airfryer
        if r["id"].startswith("af-"):
            data["tab"] = "airfryer"  # speziell für den Airfryer -> eigener Tab
        with open(os.path.join(out_dir, r["id"] + ".json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
        entry = {k: data[k] for k in ("id", "title", "icon", "cuisine", "servings", "time", "airfryer", "tab") if k in data}
        # Zutatennamen für "Was kann ich kochen?" (ohne Mengen), damit dafür nicht jedes Rezept geladen werden muss
        entry["ing"] = [i["name"] for i in ingredients if "name" in i]
        index.append(entry)

    # Bestehendes Biang-Biang-Rezept übernehmen
    bb_path = os.path.join(out_dir, "biang-biang.json")
    bb = json.load(open(bb_path, encoding="utf-8"))
    bb["cuisine"] = "Chinesisch"
    json.dump(bb, open(bb_path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    bbe = {k: bb[k] for k in ("id", "title", "icon", "cuisine", "servings", "time")}
    bbe["ing"] = [i["name"] for i in bb["ingredients"] if "name" in i]
    index.insert(0, bbe)

    index.sort(key=lambda x: (x["cuisine"], x["title"]))
    with open(os.path.join(out_dir, "index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=1)
    from collections import Counter
    print(len(index), "Rezepte, davon Airfryer:", sum(1 for i in index if i.get("airfryer")), dict(Counter(i["cuisine"] for i in index if i["id"].startswith("af-"))), "|", dict(Counter(i["cuisine"] for i in index)))

if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    build(sys.argv[1])
