# Runde 8: Winterküche, Salate, Frühstück, Getränke, Snacks, Beilagen und Gebäck
from gen import R

# ---------- Hauptgerichte ----------
R("paprikahuhn", "Paprikahuhn (Paprikás csirke)", "🌶️", "Ungarisch", 4, "ca. 1 Std.",
  ["1,2 kg|Hähnchenschenkel", "2|Zwiebeln", "1|rote Paprika", "2 EL|edelsüßes Paprikapulver", "1 TL|scharfes Paprikapulver",
   "2 EL|Tomatenmark", "300 ml|Hühnerbrühe", "200 g|saure Sahne", "1 EL|Mehl", "2 EL|Öl"],
  ["Hähnchen salzen und in Öl rundum goldbraun anbraten, herausnehmen. @10",
   "Zwiebeln fein würfeln und im Bratfett weich dünsten, Paprika in Streifen dazugeben. @8",
   "Topf kurz vom Herd nehmen, Paprikapulver und Tomatenmark einrühren (Paprika verbrennt sonst schnell bitter).",
   "Mit Brühe ablöschen, Hähnchen zurück in den Topf legen und zugedeckt schmoren. @35",
   "Saure Sahne mit Mehl glatt rühren, unter die Sauce ziehen und kurz aufkochen lassen. @2",
   "Abschmecken – dazu Nockerl, Spätzle oder Reis."], cat="Hauptgericht", level="mittel")

R("albondigas", "Albóndigas in Tomatensauce", "🍅", "Spanisch", 4, "ca. 45 Min.",
  ["500 g|gemischtes Hackfleisch", "1|Ei", "40 g|Paniermehl", "3|Knoblauchzehen", "1|Zwiebel", "1 TL|geräuchertes Paprikapulver",
   "1 Dose|stückige Tomaten", "100 ml|Weißwein", "½ Bund|Petersilie", "3 EL|Olivenöl"],
  ["Hack mit Ei, Paniermehl, 1 gepressten Knoblauchzehe, Salz und Pfeffer verkneten und walnussgroße Bällchen formen.",
   "Bällchen in Olivenöl rundum anbraten und herausnehmen. @8",
   "Zwiebel und restlichen Knoblauch fein würfeln und im Bratfett glasig dünsten, Paprikapulver kurz mitrösten. @4",
   "Mit Weißwein ablöschen, Tomaten dazugeben und die Bällchen darin zugedeckt garen. @20",
   "Mit gehackter Petersilie bestreuen – dazu Weißbrot oder Reis."], cat="Hauptgericht", level="einfach")

R("kefta-tajine", "Kefta-Tajine mit Ei", "🍳", "Marokkanisch", 4, "ca. 45 Min.",
  ["500 g|Rinderhackfleisch", "1|Zwiebel", "2|Knoblauchzehen", "1 TL|Kreuzkümmel", "1 TL|edelsüßes Paprikapulver", "½ TL|Zimt",
   "1 Bund|Koriander", "1 Dose|stückige Tomaten", "4|Eier", "2 EL|Olivenöl"],
  ["Hack mit der Hälfte der Gewürze, gehacktem Koriander, Salz und Pfeffer verkneten und kleine Bällchen formen.",
   "Zwiebel und Knoblauch würfeln und in einer breiten Pfanne in Olivenöl anschwitzen, restliche Gewürze kurz mitrösten. @4",
   "Tomaten zugeben und etwas einkochen lassen. @8",
   "Bällchen in die Sauce setzen und zugedeckt garen. @15",
   "Vier Mulden formen, Eier hineinschlagen und zugedeckt stocken lassen. @6",
   "Mit Koriander bestreuen und direkt aus der Pfanne mit Fladenbrot essen."], cat="Hauptgericht", level="mittel")

R("ossobuco", "Ossobuco alla Milanese", "🍖", "Italienisch", 4, "ca. 2 Std.",
  ["4 Scheiben|Kalbshaxe (je ca. 4 cm)", "2 EL|Mehl", "1|Zwiebel", "1|Karotte", "1 Stange|Staudensellerie", "200 ml|Weißwein",
   "400 ml|Kalbsfond", "1 Dose|geschälte Tomaten", "3 EL|Butter", "#Gremolata", "1|Bio-Zitrone (Schale)", "1|Knoblauchzehe",
   "½ Bund|Petersilie"],
  ["Haxenscheiben am Rand einschneiden, salzen, pfeffern und in Mehl wenden.",
   "In Butter von beiden Seiten kräftig anbraten und herausnehmen. @10",
   "Zwiebel, Karotte und Sellerie fein würfeln und im Bratfett andünsten. @6",
   "Mit Wein ablöschen, Fond und Tomaten zugeben, Fleisch hineinlegen und zugedeckt bei kleiner Hitze schmoren. @90",
   "Für die Gremolata Zitronenschale, Knoblauch und Petersilie fein hacken und mischen.",
   "Ossobuco mit Gremolata bestreuen – klassisch dazu Risotto alla Milanese oder Polenta."], cat="Hauptgericht", level="anspruchsvoll")

R("mercimek-koeftesi", "Linsenbällchen (Mercimek Köftesi)", "🥬", "Türkisch", 4, "ca. 45 Min.",
  ["200 g|rote Linsen", "150 g|feiner Bulgur", "1|Zwiebel", "2 EL|Tomatenmark", "1 EL|Paprikamark", "1 TL|Kreuzkümmel",
   "½ Bund|Frühlingszwiebeln", "½ Bund|Petersilie", "1|Zitrone", "3 EL|Olivenöl", "1|Romanasalat"],
  ["Linsen mit 500 ml Wasser weich kochen, bis das Wasser fast aufgesogen ist. @15",
   "Vom Herd nehmen, Bulgur einrühren und zugedeckt quellen lassen. @15",
   "Zwiebel fein würfeln und in Olivenöl glasig dünsten, Tomaten- und Paprikamark kurz mitrösten. @5",
   "Zwiebelmischung, Kreuzkümmel, fein geschnittene Frühlingszwiebeln, Petersilie und Zitronensaft unter die Linsen kneten, salzen.",
   "Mit feuchten Händen längliche Bällchen formen und in Salatblättern mit Zitrone servieren."], cat="Hauptgericht", level="einfach")

R("ofen-haehnchen-rosenkohl", "Ofen-Hähnchenkeulen mit Rosenkohl und Kartoffeln", "🍗", "Deutsch", 4, "ca. 55 Min.",
  ["4|Hähnchenkeulen", "800 g|kleine Kartoffeln", "500 g|Rosenkohl", "1|rote Zwiebel", "3 EL|Olivenöl", "1 EL|Senf",
   "1 EL|Honig", "1 TL|edelsüßes Paprikapulver", "3 Zweige|Thymian"],
  ["Backofen auf 200 °C Umluft vorheizen. Kartoffeln halbieren, Rosenkohl putzen und halbieren, Zwiebel in Spalten schneiden.",
   "Gemüse mit 2 EL Öl, Salz und Thymian auf einem Blech mischen.",
   "Öl, Senf, Honig, Paprika, Salz und Pfeffer verrühren und die Keulen damit einpinseln.",
   "Keulen auf das Gemüse legen und im Ofen garen, bis die Haut knusprig ist. @45",
   "Kurz ruhen lassen und mit dem Bratensaft servieren."], cat="Hauptgericht", level="einfach")

R("walnuss-salbei-pasta", "Pasta mit Walnuss-Salbei-Sauce", "🌰", "Italienisch", 4, "ca. 25 Min.",
  ["400 g|Tagliatelle", "100 g|Walnüsse", "60 g|Butter", "12|Salbeiblätter", "1|Knoblauchzehe", "150 ml|Sahne",
   "60 g|Parmesan", "1 Prise|Muskat"],
  ["Pasta in Salzwasser bissfest kochen, eine Tasse Nudelwasser aufheben. @10",
   "Walnüsse ohne Fett anrösten und grob hacken. @4",
   "Butter mit Salbei und angedrücktem Knoblauch aufschäumen lassen, bis der Salbei knusprig ist. @3",
   "Sahne, die Hälfte der Nüsse und Muskat zugeben und kurz köcheln. @3",
   "Pasta mit etwas Nudelwasser und Parmesan in der Sauce schwenken, mit restlichen Nüssen bestreuen."], cat="Hauptgericht", level="einfach")

R("kartoffel-pilz-gulasch", "Kartoffel-Pilz-Gulasch", "🍄", "Österreichisch", 4, "ca. 45 Min.",
  ["800 g|festkochende Kartoffeln", "500 g|Champignons", "2|Zwiebeln", "2 EL|edelsüßes Paprikapulver", "1 EL|Tomatenmark",
   "800 ml|Gemüsebrühe", "1 TL|Kümmel", "1 TL|Majoran", "2 EL|Öl", "Schmand|zum Servieren"],
  ["Zwiebeln würfeln und in Öl goldbraun dünsten. @8",
   "Pilze vierteln, dazugeben und anbraten, bis die Flüssigkeit verdampft ist. @6",
   "Paprikapulver und Tomatenmark einrühren, mit Brühe ablöschen.",
   "Kartoffeln würfeln, mit Kümmel und Majoran zugeben und köcheln, bis sie weich sind und die Sauce bindet. @25",
   "Salzen, pfeffern und mit einem Klecks Schmand servieren."], cat="Hauptgericht", level="einfach")

# ---------- Suppen ----------
R("wirsingeintopf-hackbaellchen", "Wirsingeintopf mit Hackbällchen", "🥬", "Deutsch", 4, "ca. 50 Min.",
  ["1|kleiner Wirsing", "400 g|gemischtes Hackfleisch", "1|Ei", "1|Zwiebel", "500 g|Kartoffeln", "2|Karotten",
   "1,2 l|Gemüsebrühe", "1 Prise|Muskat", "½ Bund|Petersilie"],
  ["Hack mit Ei, Salz, Pfeffer und Muskat verkneten und kleine Bällchen formen.",
   "Zwiebel würfeln und im großen Topf glasig dünsten. @3",
   "Kartoffeln und Karotten würfeln, Wirsing in Streifen schneiden, alles in den Topf geben und mit Brühe aufgießen.",
   "Köcheln, bis das Gemüse fast gar ist. @15",
   "Hackbällchen einlegen und bei kleiner Hitze gar ziehen lassen. @12",
   "Mit Muskat abschmecken und mit Petersilie bestreuen."], cat="Suppe", level="einfach")

R("petersilienwurzel-suppe", "Petersilienwurzel-Suppe mit Haselnüssen", "🥣", "Deutsch", 4, "ca. 35 Min.",
  ["600 g|Petersilienwurzeln", "1|mehligkochende Kartoffel", "1|Zwiebel", "1 l|Gemüsebrühe", "150 ml|Sahne", "30 g|Butter",
   "40 g|Haselnüsse", "1 Spritzer|Zitronensaft"],
  ["Zwiebel würfeln, Petersilienwurzeln und Kartoffel schälen und klein schneiden.",
   "Zwiebel in Butter andünsten, Gemüse kurz mitdünsten. @5",
   "Mit Brühe aufgießen und weich köcheln. @20",
   "Sahne zugeben, fein pürieren und mit Salz, Pfeffer und Zitronensaft abschmecken.",
   "Haselnüsse ohne Fett rösten, hacken und über die Suppe streuen. @4"], cat="Suppe", level="einfach")

R("harissa-kichererbsen-suppe", "Tomaten-Kichererbsen-Suppe mit Harissa", "🌶️", "Orientalisch", 4, "ca. 30 Min.",
  ["2 Dosen|Kichererbsen", "1 Dose|stückige Tomaten", "1|Zwiebel", "2|Knoblauchzehen", "1 EL|Harissa", "1 TL|Kreuzkümmel",
   "800 ml|Gemüsebrühe", "100 g|Blattspinat", "1|Zitrone", "Naturjoghurt|zum Servieren"],
  ["Zwiebel und Knoblauch würfeln und in Olivenöl andünsten, Harissa und Kreuzkümmel kurz mitrösten. @4",
   "Abgetropfte Kichererbsen, Tomaten und Brühe zugeben und köcheln. @15",
   "Ein Drittel der Suppe pürieren und zurückgießen, damit sie sämig wird.",
   "Spinat unterrühren und zusammenfallen lassen, mit Zitronensaft und Salz abschmecken. @2",
   "Mit einem Klecks Joghurt servieren."], cat="Suppe", level="einfach")

# ---------- Salate ----------
R("rotkohlsalat-orange", "Rotkohlsalat mit Orange und Walnüssen", "🥗", "Deutsch", 4, "ca. 20 Min.",
  ["½|Rotkohl", "2|Orangen", "50 g|Walnüsse", "2 EL|Apfelessig", "3 EL|Rapsöl", "1 TL|Honig", "1 Prise|Zimt"],
  ["Rotkohl sehr fein hobeln, mit ½ TL Salz kräftig durchkneten, damit er weich wird.",
   "Orangen schälen, filetieren und den Saft auffangen.",
   "Saft mit Essig, Öl, Honig, Zimt, Salz und Pfeffer verrühren und unter den Kohl mischen.",
   "Walnüsse rösten, grob hacken und mit den Orangenfilets darübergeben. @4",
   "Kurz durchziehen lassen – passt gut zu Braten und Wild. @10"], cat="Salat", level="einfach")

R("ofenkuerbis-salat", "Ofenkürbis-Salat mit Feta und Kürbiskernen", "🎃", "Mediterran", 4, "ca. 35 Min.",
  ["1|Hokkaido-Kürbis", "100 g|Rucola", "150 g|Feta", "40 g|Kürbiskerne", "1|Granatapfel", "3 EL|Olivenöl",
   "2 EL|Balsamico", "1 TL|Honig", "1 TL|Chiliflocken"],
  ["Backofen auf 200 °C Umluft vorheizen. Kürbis entkernen und in Spalten schneiden (Schale bleibt dran).",
   "Mit 2 EL Öl, Salz und Chili mischen und im Ofen weich und leicht gebräunt rösten. @25",
   "Kürbiskerne ohne Fett rösten. @3",
   "Restliches Öl, Balsamico, Honig, Salz und Pfeffer verrühren.",
   "Rucola mit dem Dressing mischen, Kürbis, zerbröselten Feta, Granatapfelkerne und Kürbiskerne darauf verteilen."], cat="Salat", level="einfach")

R("asia-krautsalat", "Asiatischer Krautsalat mit Erdnuss-Dressing", "🥜", "Asiatisch", 4, "ca. 20 Min.",
  ["½|Spitzkohl", "2|Karotten", "1|rote Paprika", "3|Frühlingszwiebeln", "½ Bund|Koriander", "3 EL|Erdnussbutter",
   "2 EL|Sojasauce", "2 EL|Limettensaft", "1 TL|Sesamöl", "1 TL|Ahornsirup", "40 g|geröstete Erdnüsse"],
  ["Spitzkohl fein schneiden, Karotten raspeln, Paprika und Frühlingszwiebeln in feine Streifen schneiden.",
   "Erdnussbutter mit Sojasauce, Limettensaft, Sesamöl, Ahornsirup und 3 EL warmem Wasser cremig rühren.",
   "Gemüse mit dem Dressing mischen.",
   "Mit Koriander und gehackten Erdnüssen bestreuen."], cat="Salat", level="einfach")

R("thunfisch-bohnen-salat", "Thunfisch-Bohnen-Salat", "🐟", "Italienisch", 4, "ca. 15 Min.",
  ["2 Dosen|weiße Bohnen", "2 Dosen|Thunfisch (in Öl)", "1|rote Zwiebel", "250 g|Kirschtomaten", "½ Bund|Petersilie",
   "3 EL|Olivenöl", "2 EL|Weißweinessig", "1 EL|Kapern"],
  ["Bohnen abspülen und abtropfen lassen, Zwiebel in feine Ringe schneiden.",
   "Tomaten halbieren, Petersilie grob hacken.",
   "Öl, Essig, Salz und Pfeffer verrühren.",
   "Bohnen, Zwiebel, Tomaten, Kapern und zerpflückten Thunfisch mit dem Dressing mischen und mit Petersilie bestreuen."], cat="Salat", level="einfach")

# ---------- Frühstück ----------
R("hafer-bananen-pancakes", "Hafer-Bananen-Pancakes", "🥞", "International", 2, "ca. 20 Min.",
  ["2|reife Bananen", "2|Eier", "100 g|zarte Haferflocken", "100 ml|Milch", "1 TL|Backpulver", "1 Prise|Zimt",
   "1 EL|Butter", "Ahornsirup|zum Servieren", "Beeren|zum Servieren"],
  ["Bananen zerdrücken und mit Eiern, Haferflocken, Milch, Backpulver, Zimt und einer Prise Salz verrühren.",
   "Teig kurz quellen lassen. @5",
   "Butter in einer Pfanne erhitzen und kleine Pancakes bei mittlerer Hitze von beiden Seiten backen. @10",
   "Mit Beeren und Ahornsirup servieren."], cat="Frühstück", level="einfach")

R("joghurt-bowl-beeren", "Joghurt-Bowl mit Beeren und Nüssen", "🫐", "International", 2, "ca. 5 Min.",
  ["400 g|griechischer Joghurt", "200 g|Beeren (frisch oder TK, aufgetaut)", "4 EL|Granola", "2 EL|Walnüsse", "1 EL|Honig",
   "1 EL|Leinsamen"],
  ["Joghurt in zwei Schalen verteilen.",
   "Beeren, Granola, gehackte Walnüsse und Leinsamen darauf geben.",
   "Mit Honig beträufeln."], cat="Frühstück", level="einfach")

# ---------- Getränke ----------
R("golden-milk", "Golden Milk (Kurkuma-Latte)", "🥛", "Indisch", 2, "ca. 10 Min.",
  ["500 ml|Milch oder Haferdrink", "1 TL|Kurkuma", "½ TL|Zimt", "1 Stück|Ingwer (2 cm)", "1 Prise|schwarzer Pfeffer", "1 EL|Honig"],
  ["Ingwer schälen und fein reiben.",
   "Milch mit Kurkuma, Zimt, Ingwer und Pfeffer unter Rühren erhitzen, nicht kochen lassen. @5",
   "Durch ein Sieb gießen, mit Honig süßen und aufschäumen."], cat="Getränk", level="einfach")

R("matcha-latte", "Matcha Latte", "🍵", "Japanisch", 1, "ca. 5 Min.",
  ["1 TL|Matcha-Pulver", "60 ml|heißes Wasser (ca. 80 °C)", "200 ml|Milch oder Haferdrink", "1 TL|Ahornsirup"],
  ["Matcha in eine Tasse sieben und mit dem heißen Wasser klümpchenfrei aufschlagen (am besten mit einem Bambusbesen).",
   "Milch erwärmen und aufschäumen. @2",
   "Milch auf den Matcha gießen und nach Geschmack süßen."], cat="Getränk", level="einfach")

# ---------- Snacks ----------
R("gefuellte-champignons", "Gefüllte Champignons mit Frischkäse", "🍄", "International", 4, "ca. 30 Min.",
  ["16|große Champignons", "150 g|Frischkäse", "1|Knoblauchzehe", "2 EL|Schnittlauch", "40 g|geriebener Parmesan",
   "2 EL|Paniermehl", "1 EL|Olivenöl"],
  ["Backofen auf 200 °C vorheizen. Stiele aus den Pilzen drehen und fein hacken.",
   "Gehackte Stiele mit Frischkäse, gepresstem Knoblauch, Schnittlauch, Salz und Pfeffer verrühren.",
   "Pilzköpfe füllen, mit Parmesan und Paniermehl bestreuen und mit Öl beträufeln.",
   "Im Ofen goldbraun backen. @15"], cat="Snack", level="einfach")

R("rote-bete-hummus", "Rote-Bete-Hummus", "🩷", "Orientalisch", 4, "ca. 10 Min.",
  ["1 Dose|Kichererbsen", "250 g|gekochte Rote Bete", "2 EL|Tahin", "1|Knoblauchzehe", "1|Zitrone", "3 EL|Olivenöl",
   "1 TL|Kreuzkümmel"],
  ["Kichererbsen abgießen, etwas Kochwasser auffangen.",
   "Alle Zutaten mit Salz in einem Mixer sehr fein pürieren, bei Bedarf etwas Kichererbsenwasser zugeben.",
   "Abschmecken und mit Olivenöl beträufelt servieren – dazu Gemüsesticks oder Fladenbrot."], cat="Snack", level="einfach")

# ---------- Beilagen ----------
R("hausgemachte-spaetzle", "Hausgemachte Spätzle", "🍝", "Deutsch", 4, "ca. 30 Min.",
  ["400 g|Mehl (Type 405 oder Spätzlemehl)", "4|Eier", "ca. 150 ml|Wasser", "1 Prise|Muskat", "2 EL|Butter"],
  ["Mehl, Eier, Wasser, 1 TL Salz und Muskat zu einem zähen Teig schlagen, bis er Blasen wirft.",
   "Teig ruhen lassen. @10",
   "Teig portionsweise in kochendes Salzwasser schaben oder pressen. @8",
   "Sobald die Spätzle oben schwimmen, mit einer Schaumkelle herausheben.",
   "In Butter schwenken – passt zu Braten, Gulasch und Rahmgerichten."], cat="Beilage", level="mittel")

R("ofen-rosenkohl-parmesan", "Ofen-Rosenkohl mit Parmesan", "🥦", "International", 4, "ca. 30 Min.",
  ["600 g|Rosenkohl", "3 EL|Olivenöl", "40 g|Parmesan", "1|Bio-Zitrone", "1 Prise|Chiliflocken"],
  ["Backofen auf 220 °C vorheizen. Rosenkohl putzen und halbieren.",
   "Mit Öl, Salz, Pfeffer und Chili mischen und mit der Schnittfläche nach unten aufs Blech legen.",
   "Rösten, bis die Unterseite tief goldbraun ist. @20",
   "Mit fein geriebenem Parmesan und etwas Zitronenschale bestreuen."], cat="Beilage", level="einfach")

R("rahmwirsing", "Rahmwirsing", "🥬", "Deutsch", 4, "ca. 25 Min.",
  ["1|kleiner Wirsing", "1|Zwiebel", "20 g|Butter", "150 ml|Sahne", "100 ml|Gemüsebrühe", "1 Prise|Muskat"],
  ["Wirsing vierteln, Strunk entfernen und in feine Streifen schneiden, Zwiebel würfeln.",
   "Zwiebel in Butter glasig dünsten, Wirsing zugeben und zusammenfallen lassen. @5",
   "Brühe und Sahne angießen und offen köcheln, bis der Wirsing weich und die Sauce cremig ist. @12",
   "Mit Salz, Pfeffer und Muskat abschmecken."], cat="Beilage", level="einfach")

# ---------- Desserts ----------
R("apfelkuechle", "Apfelküchle mit Zimtzucker", "🍎", "Deutsch", 4, "ca. 30 Min.",
  ["3|säuerliche Äpfel", "150 g|Mehl", "2|Eier", "150 ml|Milch", "1 EL|Zucker", "Öl|zum Ausbacken",
   "3 EL|Zucker (für Zimtzucker)", "1 TL|Zimt"],
  ["Mehl, Eier, Milch, Zucker und eine Prise Salz zu einem glatten Teig rühren und ruhen lassen. @10",
   "Äpfel schälen, Kerngehäuse ausstechen und in 1 cm dicke Ringe schneiden.",
   "Öl in einer Pfanne gut 1 cm hoch erhitzen.",
   "Apfelringe durch den Teig ziehen und von beiden Seiten goldbraun ausbacken. @10",
   "Auf Küchenpapier abtropfen lassen und noch warm in Zimtzucker wenden."], cat="Dessert", level="einfach")

R("schoko-lava-kuchen", "Schokoladen-Lava-Kuchen", "🍫", "Französisch", 4, "ca. 25 Min.",
  ["100 g|Zartbitterschokolade", "100 g|Butter", "2|Eier", "2|Eigelb", "60 g|Zucker", "30 g|Mehl", "Puderzucker|zum Bestäuben"],
  ["Backofen auf 220 °C vorheizen, vier Förmchen buttern und mit Kakao oder Mehl ausstreuen.",
   "Schokolade und Butter über dem Wasserbad schmelzen. @5",
   "Eier, Eigelb und Zucker hell aufschlagen, Schokolade unterrühren und Mehl unterheben.",
   "Teig in die Förmchen füllen und backen, bis der Rand fest und die Mitte noch weich ist. @9",
   "Kurz ruhen lassen, auf Teller stürzen und mit Puderzucker bestäuben. @1"], cat="Dessert", level="mittel")

# ---------- Backen ----------
R("hefezopf", "Hefezopf", "🍞", "Deutsch", 12, "ca. 2 Std. 30 Min.",
  ["500 g|Mehl", "1 Würfel|frische Hefe", "250 ml|lauwarme Milch", "80 g|Zucker", "80 g|weiche Butter", "1|Ei",
   "1|Eigelb (zum Bestreichen)", "2 EL|Hagelzucker"],
  ["Hefe in der lauwarmen Milch mit 1 TL Zucker auflösen.",
   "Mit Mehl, restlichem Zucker, Butter, Ei und einer Prise Salz zu einem glatten Teig kneten. @8",
   "Zugedeckt an einem warmen Ort gehen lassen, bis er sich verdoppelt hat. @60",
   "Teig in drei Stränge teilen, zu einem Zopf flechten und auf ein Blech legen.",
   "Nochmals gehen lassen, Backofen auf 180 °C Ober-/Unterhitze vorheizen. @30",
   "Mit Eigelb bestreichen, mit Hagelzucker bestreuen und goldbraun backen. @30"], cat="Backen", level="mittel")

R("nussecken", "Nussecken", "🌰", "Deutsch", 24, "ca. 1 Std. 15 Min.",
  ["#Teig", "300 g|Mehl", "1 TL|Backpulver", "130 g|Zucker", "1|Ei", "130 g|kalte Butter", "#Belag", "4 EL|Aprikosenmarmelade",
   "200 g|Butter", "200 g|Zucker", "2 EL|Wasser", "200 g|gemahlene Haselnüsse", "200 g|gehackte Haselnüsse",
   "200 g|Zartbitterkuvertüre"],
  ["Mehl, Backpulver, Zucker, Ei und Butter rasch zu einem Mürbeteig verkneten und auf einem Blech (ca. 30 × 40 cm) ausrollen.",
   "Teig mit Marmelade bestreichen. Backofen auf 180 °C vorheizen.",
   "Butter, Zucker und Wasser aufkochen, Nüsse unterrühren und abkühlen lassen. @5",
   "Nussmasse auf dem Teig verteilen und backen, bis sie goldbraun ist. @25",
   "Abkühlen lassen, in Quadrate und dann in Dreiecke schneiden. @20",
   "Die Ecken in geschmolzene Kuvertüre tauchen und fest werden lassen."], cat="Backen", level="mittel")
