# Runde 5: Frühstück, Suppen, Welt-Klassiker
from gen import R

# ---------- Frühstück ----------
R("shakshuka-feta-spinat", "Spinat-Feta-Eier aus der Pfanne", "🍳", "Orientalisch", 2, "ca. 20 Min.",
  ["200 g|Babyspinat", "1|Zwiebel", "1|Knoblauchzehe", "4|Eier", "80 g|Feta", "1 TL|Kreuzkümmel", "1 EL|Olivenöl", "1|Fladenbrot"],
  ["Zwiebel und Knoblauch fein würfeln und in Öl glasig dünsten, Kreuzkümmel kurz mitrösten. @4",
   "Spinat zugeben und zusammenfallen lassen, salzen und pfeffern. @2",
   "Vier Mulden formen, Eier hineingleiten lassen, Feta darüberbröseln.",
   "Zugedeckt stocken lassen, bis das Eiweiß fest ist. @6",
   "Mit warmem Fladenbrot servieren."], cat="Frühstück", level="einfach")

R("porridge-apfel-zimt", "Porridge mit Apfel und Zimt", "🥣", "Britisch", 2, "ca. 15 Min.",
  ["100 g|zarte Haferflocken", "400 ml|Milch oder Haferdrink", "1|Apfel", "1 TL|Zimt", "1 EL|Ahornsirup", "2 EL|gehackte Walnüsse", "1 Prise|Salz"],
  ["Haferflocken mit Milch und Salz aufkochen und unter Rühren cremig köcheln. @5",
   "Apfel würfeln und mit Zimt und Sirup in einer kleinen Pfanne weich dünsten. @5",
   "Porridge in Schalen füllen, Äpfel und Walnüsse darauf verteilen."], cat="Frühstück", level="einfach")

R("breakfast-burrito", "Breakfast Burrito", "🌯", "Mexikanisch", 2, "ca. 20 Min.",
  ["2|große Weizentortillas", "4|Eier", "1|Paprika", "1 Dose|schwarze Bohnen (klein)", "60 g|geriebener Cheddar", "1|Avocado",
   "2 EL|Salsa", "1 EL|Butter"],
  ["Paprika würfeln und in Butter anbraten, abgetropfte Bohnen kurz mitwärmen. @5",
   "Eier verquirlen, salzen und in der Pfanne zu cremigem Rührei stocken lassen. @3",
   "Tortillas kurz ohne Fett erwärmen. @1",
   "Rührei, Gemüse, Käse, Avocadoscheiben und Salsa daraufgeben, einrollen und halbieren."], cat="Frühstück", level="einfach")

R("tamagoyaki", "Tamagoyaki (japanisches Omelett)", "🍳", "Japanisch", 2, "ca. 15 Min.",
  ["4|Eier", "2 EL|Dashi oder Wasser", "1 EL|Zucker", "1 TL|Sojasauce", "1 TL|Mirin", "1 TL|Öl"],
  ["Eier mit Dashi, Zucker, Sojasauce und Mirin verquirlen, ohne viel Schaum zu schlagen.",
   "Eckige Pfanne dünn ölen, ein Viertel der Masse hineingießen und fast stocken lassen. @1",
   "Von einer Seite her aufrollen, Rolle zur Seite schieben, nachölen und die nächste Schicht darunterlaufen lassen.",
   "Wiederholen, bis die Masse aufgebraucht ist. @5",
   "In ein Tuch wickeln, kurz in Form drücken und in Scheiben schneiden."], cat="Frühstück", level="mittel")

# ---------- Suppen ----------
R("tomatensuppe-geroestet", "Geröstete Tomatensuppe", "🍅", "Mediterran", 4, "ca. 50 Min.",
  ["1 kg|Tomaten", "1|rote Paprika", "1|Zwiebel", "4|Knoblauchzehen", "3 EL|Olivenöl", "600 ml|Gemüsebrühe", "1 TL|Zucker",
   "1 Bund|Basilikum", "100 ml|Sahne"],
  ["Ofen auf 220 °C vorheizen. Tomaten halbieren, Paprika und Zwiebel grob schneiden, mit Knoblauch und Öl auf ein Blech geben.",
   "Rösten, bis die Ränder dunkel werden. @30",
   "Mit Brühe in einen Topf geben, kurz aufkochen und fein pürieren. @5",
   "Mit Salz, Pfeffer und Zucker abschmecken, Sahne einrühren und mit Basilikum servieren."], cat="Suppe", level="einfach")

R("linsensuppe-zitrone", "Libanesische Linsensuppe mit Zitrone", "🍋", "Libanesisch", 4, "ca. 35 Min.",
  ["250 g|rote Linsen", "1|Zwiebel", "1|Karotte", "2|Knoblauchzehen", "1 TL|Kreuzkümmel", "1 l|Gemüsebrühe", "1|Zitrone", "2 EL|Olivenöl",
   "½ Bund|Petersilie"],
  ["Zwiebel, Karotte und Knoblauch würfeln und in Öl weich dünsten, Kreuzkümmel kurz mitrösten. @6",
   "Linsen abspülen, mit Brühe zugeben und köcheln, bis sie zerfallen. @20",
   "Fein pürieren und mit Zitronensaft, Salz und Pfeffer kräftig abschmecken.",
   "Mit Olivenöl und gehackter Petersilie servieren."], cat="Suppe", level="einfach")

R("kartoffel-kokos-suppe", "Süßkartoffel-Kokos-Suppe", "🥥", "Thailändisch", 4, "ca. 35 Min.",
  ["800 g|Süßkartoffeln", "1|Zwiebel", "20 g|Ingwer", "1 EL|rote Currypaste", "400 ml|Kokosmilch", "600 ml|Gemüsebrühe", "1|Limette",
   "2 EL|Erdnüsse", "½ Bund|Koriander"],
  ["Zwiebel und Ingwer fein hacken und in etwas Öl andünsten, Currypaste kurz mitrösten. @4",
   "Süßkartoffeln würfeln, mit Brühe und Kokosmilch zugeben und weich kochen. @20",
   "Pürieren und mit Limettensaft und Salz abschmecken.",
   "Mit gehackten Erdnüssen und Koriander servieren."], cat="Suppe", level="einfach")

R("udon-suppe", "Udon-Nudelsuppe mit Pilzen", "🍜", "Japanisch", 2, "ca. 25 Min.",
  ["2 Pck.|Udon-Nudeln (vorgegart)", "800 ml|Dashi oder Gemüsebrühe", "3 EL|Sojasauce", "2 EL|Mirin", "150 g|Shiitake", "2|Frühlingszwiebeln",
   "100 g|Pak Choi", "2|Eier"],
  ["Eier wachsweich kochen und abschrecken. @7",
   "Brühe mit Sojasauce und Mirin aufkochen, Pilze in Scheiben darin garen. @5",
   "Pak Choi und Nudeln zugeben und erhitzen. @3",
   "In Schalen füllen, mit halbierten Eiern und Frühlingszwiebelringen servieren."], cat="Suppe", level="einfach")

# ---------- Welt ----------
R("chicken-adobo", "Chicken Adobo", "🍗", "International", 4, "ca. 50 Min.",
  ["1 kg|Hähnchenschenkel", "100 ml|Sojasauce", "80 ml|Reisessig", "6|Knoblauchzehen", "3|Lorbeerblätter", "1 TL|schwarze Pfefferkörner",
   "1 EL|brauner Zucker", "1 EL|Öl", "250 g|Reis"],
  ["Hähnchen mit Sojasauce, Essig, angedrücktem Knoblauch, Lorbeer und Pfeffer mischen und ziehen lassen. @15",
   "Hähnchen herausnehmen, trocken tupfen und in Öl rundum anbraten. @8",
   "Marinade, Zucker und 150 ml Wasser zugeben und zugedeckt schmoren. @25",
   "Deckel abnehmen und die Sauce sirupartig einkochen. @8",
   "Mit Reis servieren."], level="einfach")

R("jerk-chicken", "Jerk Chicken mit Reis und Bohnen", "🌶️", "International", 4, "ca. 1 Std. (plus Marinieren)",
  ["1 kg|Hähnchenschenkel", "4|Frühlingszwiebeln", "1|Chili (Scotch Bonnet oder milder)", "3|Knoblauchzehen", "2 EL|Sojasauce",
   "1 EL|Piment, gemahlen", "1 TL|Thymian", "1 EL|brauner Zucker", "1|Limette", "250 g|Reis", "1 Dose|Kidneybohnen", "200 ml|Kokosmilch"],
  ["Frühlingszwiebeln, Chili, Knoblauch, Sojasauce, Piment, Thymian, Zucker und Limettensaft zu einer Paste pürieren.",
   "Hähnchen damit einreiben und kalt stellen, am besten über Nacht. @60",
   "Im Ofen bei 200 °C knusprig garen. @40",
   "Reis mit Kokosmilch, abgetropften Bohnen und Wasser nach Packung garen. @20",
   "Zusammen servieren."], level="mittel")

R("couscous-merguez", "Couscous mit Merguez und Gemüse", "🌭", "Marokkanisch", 4, "ca. 35 Min.",
  ["8|Merguez", "250 g|Couscous", "1|Zucchini", "1|Paprika", "1|rote Zwiebel", "1 Dose|Kichererbsen", "1 TL|Ras el-Hanout",
   "300 ml|Gemüsebrühe", "2 EL|Olivenöl", "½ Bund|Minze"],
  ["Würstchen in einer Pfanne rundum braten und herausnehmen. @10",
   "Gemüse würfeln und im Bratfett mit Ras el-Hanout anbraten. @8",
   "Abgetropfte Kichererbsen zugeben und warm werden lassen.",
   "Couscous mit kochender Brühe übergießen, quellen lassen und auflockern. @5",
   "Alles mischen, Würstchen daraufsetzen und mit Minze bestreuen."], level="einfach")

R("enchiladas-verdes", "Enchiladas verdes mit Bohnen und Käse", "🫔", "Mexikanisch", 4, "ca. 45 Min.",
  ["8|Maistortillas", "1 Dose|schwarze Bohnen", "200 g|Mais", "1|Zwiebel", "300 g|Salsa verde (Glas)", "150 g|saure Sahne",
   "150 g|geriebener Käse", "1 TL|Kreuzkümmel", "½ Bund|Koriander"],
  ["Ofen auf 200 °C vorheizen. Zwiebel würfeln, mit Bohnen, Mais und Kreuzkümmel kurz anbraten. @5",
   "Salsa verde mit saurer Sahne verrühren, ein Drittel in eine Form streichen.",
   "Tortillas kurz erwärmen, füllen, aufrollen und nebeneinander in die Form legen.",
   "Mit restlicher Sauce und Käse bedecken und goldbraun backen. @20",
   "Mit Koriander servieren."], level="einfach")

R("palak-dal", "Dal Palak (Linsen mit Spinat)", "🍛", "Indisch", 4, "ca. 40 Min.",
  ["250 g|gelbe Linsen (Toor oder Mung)", "200 g|Spinat", "1|Zwiebel", "2|Tomaten", "3|Knoblauchzehen", "20 g|Ingwer", "1 TL|Kurkuma",
   "1 TL|Kreuzkümmelsamen", "1 TL|Garam Masala", "2 EL|Ghee oder Öl"],
  ["Linsen mit Kurkuma und 900 ml Wasser weich kochen. @25",
   "Kreuzkümmel in Ghee anrösten, Zwiebel, Knoblauch und Ingwer goldbraun braten. @8",
   "Tomaten zugeben und einkochen, Garam Masala unterrühren. @5",
   "Linsen und gehackten Spinat zugeben und kurz köcheln. Mit Salz abschmecken. @5",
   "Mit Reis oder Naan servieren."], level="einfach")

R("paneer-tikka-blech", "Paneer Tikka vom Blech", "🧀", "Indisch", 4, "ca. 40 Min. (plus Marinieren)",
  ["400 g|Paneer", "2|Paprika", "1|rote Zwiebel", "200 g|Joghurt", "2 TL|Tikka-Masala-Gewürz", "1 TL|Kurkuma", "1|Zitrone", "2 EL|Öl"],
  ["Joghurt mit Gewürzen, Zitronensaft, Öl und Salz verrühren.",
   "Paneer, Paprika und Zwiebel in große Stücke schneiden und in der Marinade ziehen lassen. @30",
   "Ofen auf 230 °C Grill vorheizen und alles auf einem Blech verteilen.",
   "Grillen, bis die Ränder schwarze Stellen bekommen; einmal wenden. @15",
   "Mit Minz-Joghurt und Naan servieren."], level="einfach")

R("kimchi-pancake", "Kimchi-Pfannkuchen (Kimchijeon)", "🥞", "Koreanisch", 2, "ca. 25 Min.",
  ["200 g|Kimchi (vegan oder klassisch)", "100 g|Mehl", "2 EL|Speisestärke", "150 ml|kaltes Wasser", "2 EL|Kimchi-Saft", "2|Frühlingszwiebeln", "3 EL|Öl",
   "#Dip", "2 EL|Sojasauce", "1 EL|Reisessig", "1 TL|Sesam"],
  ["Kimchi klein schneiden. Mit Mehl, Stärke, Wasser, Kimchi-Saft und Frühlingszwiebeln zu einem dickflüssigen Teig rühren.",
   "Öl in einer Pfanne stark erhitzen und den Teig dünn verstreichen.",
   "Knusprig braten, wenden und auch die zweite Seite bräunen. @8",
   "Für den Dip Sojasauce, Essig und Sesam mischen. Pfannkuchen in Stücke schneiden."], cat="Snack", level="einfach")

R("poke-tofu", "Tofu-Poke-Bowl", "🥗", "International", 2, "ca. 30 Min.",
  ["200 g|Sushireis", "200 g|fester Tofu", "3 EL|Sojasauce", "1 TL|Sesamöl", "1|Avocado", "½|Gurke", "100 g|Edamame (TK)", "1|Karotte",
   "2 EL|Mayonnaise (vegan)", "1 TL|Sriracha", "1 EL|Sesam"],
  ["Reis nach Packung garen und mit etwas Reisessig würzen. @20",
   "Tofu würfeln, mit 2 EL Sojasauce und Sesamöl marinieren und in der Pfanne knusprig braten. @8",
   "Edamame kurz kochen, Gurke, Karotte und Avocado schneiden. @3",
   "Mayonnaise mit Sriracha verrühren.",
   "Reis in Schalen füllen, alles darauf anrichten, mit Sauce, Sesam und restlicher Sojasauce servieren."], level="einfach")

R("pasta-norma", "Pasta alla Norma", "🍆", "Italienisch", 4, "ca. 40 Min.",
  ["400 g|Rigatoni", "2|Auberginen", "2|Knoblauchzehen", "800 g|stückige Tomaten", "1 Bund|Basilikum", "100 g|Ricotta salata oder Pecorino",
   "6 EL|Olivenöl", "1 Prise|Chiliflocken"],
  ["Auberginen würfeln, salzen und abtropfen lassen. @15",
   "Trocken tupfen und portionsweise in Olivenöl goldbraun braten. @10",
   "Knoblauch und Chili im restlichen Öl kurz anbraten, Tomaten zugeben und einkochen. @15",
   "Nudeln garen, mit Sauce, Auberginen und Basilikum mischen. @11",
   "Mit geriebenem Käse servieren."], level="einfach")

R("gnocchi-pfanne-kuerbis", "Gnocchi-Pfanne mit Kürbis und Salbei", "🎃", "Italienisch", 3, "ca. 25 Min.",
  ["500 g|Gnocchi (Kühlregal)", "400 g|Hokkaidokürbis", "1|rote Zwiebel", "8|Salbeiblätter", "2 EL|Butter", "1 EL|Olivenöl",
   "40 g|Parmesan", "30 g|Haselnüsse"],
  ["Kürbis entkernen und klein würfeln, Zwiebel in Spalten schneiden.",
   "Kürbis und Zwiebel in Öl bissfest braten. @10",
   "Gnocchi zugeben und mitbraten, bis sie goldbraun sind. @6",
   "Butter und Salbei zugeben und aufschäumen lassen. @2",
   "Mit gehackten Haselnüssen und Parmesan servieren."], level="einfach")

R("schupfnudel-pfanne-rosenkohl", "Schupfnudel-Pfanne mit Rosenkohl", "🥬", "Deutsch", 3, "ca. 25 Min.",
  ["500 g|Schupfnudeln", "400 g|Rosenkohl", "100 g|Speckwürfel", "1|Zwiebel", "100 ml|Sahne", "1 EL|Butterschmalz", "1 Prise|Muskat"],
  ["Rosenkohl halbieren und in Salzwasser bissfest kochen. @6",
   "Speck und Zwiebel in Butterschmalz anbraten. @5",
   "Schupfnudeln zugeben und goldbraun braten. @6",
   "Rosenkohl und Sahne unterrühren, kurz einkochen und mit Muskat und Pfeffer würzen. @3"], level="einfach")

R("flammkuchen-birne", "Flammkuchen mit Birne, Gorgonzola und Walnuss", "🍐", "Französisch", 2, "ca. 25 Min.",
  ["1 Rolle|Flammkuchenteig", "150 g|Crème fraîche", "1|Birne", "100 g|Gorgonzola", "30 g|Walnüsse", "1 EL|Honig", "1 Zweig|Thymian"],
  ["Ofen auf 250 °C vorheizen. Teig auf dem Blech ausrollen und mit Crème fraîche bestreichen, salzen und pfeffern.",
   "Birne in dünne Spalten schneiden und mit Gorgonzola und Walnüssen verteilen.",
   "Knusprig backen. @10",
   "Mit Honig beträufeln und mit Thymian bestreuen."], level="einfach")

# ---------- Süßes ----------
R("apfel-crumble", "Apple Crumble", "🍏", "Britisch", 6, "ca. 50 Min.",
  ["1 kg|säuerliche Äpfel", "1 EL|Zitronensaft", "50 g|Zucker", "1 TL|Zimt", "#Streusel", "150 g|Mehl", "100 g|kalte Butter",
   "80 g|brauner Zucker", "50 g|Haferflocken", "1 Prise|Salz"],
  ["Ofen auf 190 °C vorheizen. Äpfel schälen, würfeln und mit Zitrone, Zucker und Zimt in eine Form geben.",
   "Mehl, Butter, braunen Zucker, Haferflocken und Salz zu groben Streuseln reiben.",
   "Streusel über die Äpfel verteilen.",
   "Goldbraun backen, bis der Saft am Rand blubbert. @35",
   "Warm mit Vanilleeis oder Vanillesauce servieren."], cat="Dessert", level="einfach")

R("schoko-lebkuchen-muffins", "Schoko-Lebkuchen-Muffins", "🧁", "Deutsch", 12, "ca. 40 Min.",
  ["250 g|Mehl", "2 EL|Kakao", "2 TL|Backpulver", "2 TL|Lebkuchengewürz", "150 g|Zucker", "2|Eier", "100 ml|Öl", "200 ml|Milch",
   "100 g|Zartbitterschokolade, gehackt"],
  ["Ofen auf 180 °C vorheizen und ein Muffinblech mit Förmchen auslegen.",
   "Mehl, Kakao, Backpulver, Gewürz und Zucker mischen.",
   "Eier, Öl und Milch verquirlen, kurz unter die trockenen Zutaten rühren und Schokolade unterheben.",
   "Teig in die Förmchen füllen und backen (Stäbchenprobe). @22"], cat="Backen", level="einfach")

R("milchreis-zimt-pflaume", "Ofen-Pflaumen mit Zimt-Milchreis", "🍮", "Deutsch", 4, "ca. 45 Min.",
  ["200 g|Milchreis", "1 l|Milch", "60 g|Zucker", "1 Pck.|Vanillezucker", "1 Prise|Salz", "500 g|Pflaumen (TK oder frisch)", "2 EL|brauner Zucker",
   "1 TL|Zimt"],
  ["Milch mit Zucker, Vanillezucker und Salz aufkochen, Reis einrühren und bei kleinster Hitze quellen lassen; ab und zu rühren. @35",
   "Ofen auf 200 °C vorheizen. Pflaumen halbieren, mit braunem Zucker und Zimt mischen und in einer Form backen. @20",
   "Milchreis mit den warmen Pflaumen servieren."], cat="Dessert", level="einfach")
