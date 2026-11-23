# Runde 7: Feierabend, Beilagen, Frühstück und Wintersüßes
from gen import R

# ---------- Hauptgerichte ----------
R("haehnchen-cacciatore", "Hähnchen Cacciatore", "🍗", "Italienisch", 4, "ca. 50 Min.",
  ["8|Hähnchenschenkel (mit Haut)", "1|Zwiebel", "1|rote Paprika", "200 g|Champignons", "2|Knoblauchzehen", "1 Dose|stückige Tomaten",
   "100 ml|Rotwein", "2 Zweige|Rosmarin", "50 g|schwarze Oliven", "2 EL|Olivenöl"],
  ["Hähnchenschenkel salzen und pfeffern, in Öl auf der Hautseite knusprig braten, wenden und herausnehmen. @10",
   "Zwiebel, Paprika und Pilze in Streifen schneiden und im Bratfett anbraten, Knoblauch kurz mitbraten. @6",
   "Mit Rotwein ablöschen und kurz einkochen lassen. @2",
   "Tomaten, Rosmarin und Oliven zugeben, Hähnchen mit der Haut nach oben daraufsetzen und zugedeckt schmoren. @30",
   "Abschmecken – dazu Ciabatta, Polenta oder Pasta."], cat="Hauptgericht", level="mittel")

R("gnudi-spinat-ricotta", "Gnudi mit Spinat und Ricotta", "🥬", "Italienisch", 4, "ca. 45 Min.",
  ["500 g|Ricotta", "300 g|Blattspinat (TK, aufgetaut)", "80 g|Parmesan", "1|Ei", "80 g|Mehl", "1 Prise|Muskat",
   "60 g|Butter", "8|Salbeiblätter"],
  ["Spinat sehr gut ausdrücken und fein hacken.",
   "Ricotta, Spinat, Ei, die Hälfte vom Parmesan, Muskat, Salz und Mehl zu einem weichen Teig verrühren.",
   "Mit zwei Esslöffeln Nocken formen und in leicht siedendem Salzwasser garen, bis sie oben schwimmen. @4",
   "Butter mit Salbei aufschäumen lassen, bis sie leicht nussig riecht. @3",
   "Gnudi in der Salbeibutter schwenken und mit restlichem Parmesan servieren."], cat="Hauptgericht", level="mittel")

R("cremige-polenta-pilze", "Cremige Polenta mit gebratenen Pilzen", "🍄", "Italienisch", 4, "ca. 35 Min.",
  ["250 g|Polenta (Maisgrieß)", "1 l|Gemüsebrühe", "50 g|Parmesan", "30 g|Butter", "500 g|braune Champignons", "2|Knoblauchzehen",
   "3 Zweige|Thymian", "2 EL|Olivenöl", "½ Bund|Petersilie"],
  ["Brühe aufkochen, Polenta unter Rühren einrieseln lassen und bei kleiner Hitze quellen lassen, öfter umrühren. @15",
   "Pilze in Scheiben schneiden und in heißem Öl portionsweise scharf anbraten. @8",
   "Knoblauch und Thymian zu den Pilzen geben, salzen und pfeffern. @2",
   "Butter und Parmesan unter die Polenta rühren, eventuell mit etwas Brühe cremiger machen.",
   "Polenta auf Teller geben, Pilze darauf verteilen und mit Petersilie bestreuen."], cat="Hauptgericht", level="einfach")

R("erdnuss-nudeln-tofu", "Erdnuss-Nudeln mit knusprigem Tofu", "🥜", "Thailändisch", 4, "ca. 30 Min.",
  ["250 g|Reisnudeln", "400 g|fester Tofu", "2 EL|Speisestärke", "3 EL|Erdnussbutter", "3 EL|Sojasauce", "1 EL|Ahornsirup",
   "1|Limette", "1 TL|Sambal Oelek", "1|Karotte", "1|rote Paprika", "3|Frühlingszwiebeln", "50 g|geröstete Erdnüsse", "2 EL|Öl"],
  ["Tofu trocken tupfen, würfeln und in Stärke wenden. In Öl rundum knusprig braten. @10",
   "Reisnudeln nach Packung garen, abgießen und kalt abschrecken. @6",
   "Erdnussbutter, Sojasauce, Ahornsirup, Limettensaft, Sambal und 5 EL warmes Wasser glatt rühren.",
   "Karotte und Paprika in feine Streifen schneiden, Frühlingszwiebeln in Ringe.",
   "Nudeln mit Sauce und Gemüse mischen, Tofu und gehackte Erdnüsse darauf verteilen."], cat="Hauptgericht", level="einfach")

R("fischtacos-mango", "Fischtacos mit Mango-Salsa", "🌮", "Mexikanisch", 4, "ca. 30 Min.",
  ["500 g|Kabeljaufilet", "1 TL|Paprikapulver", "1 TL|Kreuzkümmel", "8|kleine Weizentortillas", "1|Mango", "1|rote Zwiebel",
   "1|Limette", "½ Bund|Koriander", "150 g|Rotkohl", "150 g|saure Sahne", "2 EL|Öl"],
  ["Mango und Zwiebel fein würfeln, mit Koriander, der Hälfte des Limettensafts und Salz zur Salsa mischen.",
   "Rotkohl sehr fein hobeln und mit etwas Salz und Limettensaft kneten.",
   "Fisch in Stücke schneiden, mit Paprika, Kreuzkümmel und Salz würzen und in Öl braten. @6",
   "Tortillas in einer trockenen Pfanne kurz erwärmen. @2",
   "Tortillas mit Kohl, Fisch, Salsa und saurer Sahne füllen."], cat="Hauptgericht", level="einfach")

R("couscous-pfanne-aprikosen", "Couscous-Pfanne mit Hähnchen und Aprikosen", "🍑", "Orientalisch", 4, "ca. 30 Min.",
  ["500 g|Hähnchenbrustfilet", "250 g|Couscous", "350 ml|Gemüsebrühe", "80 g|getrocknete Aprikosen", "1|Zucchini", "1|Zwiebel",
   "1 TL|Ras el-Hanout", "1 TL|Zimt", "40 g|Mandeln", "½ Bund|Minze", "2 EL|Olivenöl"],
  ["Hähnchen würfeln, mit Ras el-Hanout und Salz würzen und in Öl anbraten. @6",
   "Zwiebel und Zucchini würfeln, zugeben und mitbraten. @4",
   "Aprikosen klein schneiden, mit Zimt und Brühe zugeben und aufkochen.",
   "Couscous einrühren, Pfanne vom Herd nehmen und zugedeckt quellen lassen. @5",
   "Mit Gabel auflockern, geröstete Mandeln und Minze darüberstreuen."], cat="Hauptgericht", level="einfach")

R("gebratene-nudeln-ei", "Gebratene Nudeln mit Ei und Gemüse", "🍜", "Chinesisch", 2, "ca. 20 Min.",
  ["200 g|Mie-Nudeln", "2|Eier", "1|Karotte", "100 g|Weißkohl", "3|Frühlingszwiebeln", "1|Knoblauchzehe", "3 EL|Sojasauce",
   "1 EL|Austernsauce", "1 TL|Sesamöl", "2 EL|Öl"],
  ["Nudeln nach Packung garen und abtropfen lassen. @4",
   "Karotte und Kohl in feine Streifen schneiden, Frühlingszwiebeln in Ringe.",
   "Eier im Wok in Öl stocken lassen, zerteilen und herausnehmen. @2",
   "Gemüse und Knoblauch im Wok bei großer Hitze anbraten. @3",
   "Nudeln, Saucen und Ei zugeben und alles zusammen kräftig durchbraten, mit Sesamöl beträufeln. @3"], cat="Hauptgericht", level="einfach")

R("krautkrapfen", "Allgäuer Krautkrapfen", "🥨", "Bayerisch", 4, "ca. 1 Std. 30 Min.",
  ["400 g|Mehl", "4|Eier", "100 ml|Wasser", "500 g|Sauerkraut", "150 g|Speckwürfel", "1|Zwiebel", "250 ml|Gemüsebrühe",
   "2 EL|Butterschmalz"],
  ["Mehl, Eier, Wasser und Salz zu einem glatten Nudelteig kneten und ruhen lassen. @30",
   "Zwiebel würfeln, mit Speck anbraten, Sauerkraut zugeben und kurz mitdünsten. @8",
   "Teig dünn ausrollen, mit Kraut belegen, aufrollen und in 4 cm breite Schnecken schneiden.",
   "Schnecken in Butterschmalz in einer großen Pfanne von unten anbraten. @5",
   "Brühe angießen und zugedeckt garen, bis die Flüssigkeit fast verkocht ist und der Boden knusprig wird. @25"],
  cat="Hauptgericht", level="anspruchsvoll")

R("chili-cheese-suesskartoffel", "Chili-Cheese-Süßkartoffeln aus dem Airfryer", "🍠", "Amerikanisch", 2, "ca. 35 Min.",
  ["2|große Süßkartoffeln", "1 Dose|Kidneybohnen", "100 g|Mais", "1 TL|Chilipulver", "1 TL|Kreuzkümmel", "80 g|Cheddar",
   "2 EL|saure Sahne", "2|Frühlingszwiebeln", "1 EL|Öl"],
  ["Süßkartoffeln waschen, mehrmals einstechen, mit Öl einreiben und im Airfryer bei 200 °C garen. @25",
   "Bohnen abspülen, mit Mais, Chili, Kreuzkümmel und Salz in einem Topf erwärmen. @5",
   "Süßkartoffeln längs aufschneiden, Bohnen einfüllen und mit Cheddar bestreuen.",
   "Noch einmal in den Airfryer geben, bis der Käse schmilzt. @3",
   "Mit saurer Sahne und Frühlingszwiebeln servieren."], airfryer=True, cat="Hauptgericht", level="einfach")

# ---------- Suppen ----------
R("avgolemono", "Avgolemono (griechische Zitronen-Hühnersuppe)", "🍋", "Griechisch", 4, "ca. 40 Min.",
  ["1,2 l|Hühnerbrühe", "300 g|Hähnchenbrustfilet", "100 g|Langkornreis", "2|Eier", "2|Zitronen", "½ Bund|Dill"],
  ["Hähnchen in der Brühe gar ziehen lassen, herausnehmen und zerzupfen. @15",
   "Reis in der Brühe weich kochen. @15",
   "Eier mit Zitronensaft schaumig schlagen, dann nach und nach eine Kelle heiße Brühe einrühren.",
   "Eier-Mischung bei kleiner Hitze in die Suppe rühren, nicht mehr kochen lassen, bis sie leicht bindet. @3",
   "Hähnchen zugeben, salzen und mit Dill servieren."], cat="Suppe", level="mittel")

R("erbsen-minz-suppe", "Erbsen-Minz-Suppe", "🟢", "Britisch", 4, "ca. 20 Min.",
  ["600 g|TK-Erbsen", "1|Zwiebel", "1|Kartoffel", "800 ml|Gemüsebrühe", "½ Bund|Minze", "100 ml|Sahne", "1 EL|Butter"],
  ["Zwiebel und Kartoffel würfeln und in Butter andünsten. @4",
   "Brühe zugeben und köcheln, bis die Kartoffel weich ist. @10",
   "Erbsen zugeben und nur kurz mitkochen, damit sie grün bleiben. @3",
   "Minze zugeben, alles fein pürieren, Sahne einrühren und abschmecken."], cat="Suppe", level="einfach")

R("rote-bete-suppe-meerrettich", "Rote-Bete-Suppe mit Meerrettich", "🟣", "Osteuropäisch", 4, "ca. 40 Min.",
  ["600 g|Rote Bete (roh)", "1|Zwiebel", "1|Apfel", "1 l|Gemüsebrühe", "2 EL|Meerrettich (Glas)", "150 g|Schmand", "1 EL|Öl", "1 EL|Apfelessig"],
  ["Rote Bete schälen (Handschuhe!), Rote Bete, Zwiebel und Apfel würfeln.",
   "Zwiebel in Öl andünsten, Rote Bete und Apfel kurz mitdünsten. @4",
   "Brühe zugeben und köcheln, bis die Rote Bete weich ist. @25",
   "Fein pürieren, mit Essig, Salz und Pfeffer abschmecken.",
   "Schmand mit Meerrettich verrühren und auf die Suppe geben."], cat="Suppe", level="einfach")

# ---------- Salate und Beilagen ----------
R("smashed-cucumber", "Smashed Cucumber (chinesischer Gurkensalat)", "🥒", "Chinesisch", 2, "ca. 15 Min.",
  ["1|Salatgurke", "1|Knoblauchzehe", "2 EL|Sojasauce", "1 EL|Reisessig", "1 TL|Zucker", "1 TL|Sesamöl", "1 TL|Chiliöl", "1 EL|Sesam"],
  ["Gurke mit der flachen Messerseite andrücken, bis sie aufplatzt, dann in mundgerechte Stücke brechen.",
   "Mit etwas Salz mischen und Wasser ziehen lassen, dann abgießen. @10",
   "Knoblauch fein hacken und mit Sojasauce, Essig, Zucker, Sesamöl und Chiliöl verrühren.",
   "Gurke mit dem Dressing mischen und mit Sesam bestreuen."], cat="Salat", level="einfach")

R("brokkolisalat-cranberry", "Brokkolisalat mit Cranberrys und Kernen", "🥦", "Amerikanisch", 4, "ca. 20 Min.",
  ["1|Brokkoli", "50 g|getrocknete Cranberrys", "40 g|Sonnenblumenkerne", "1|kleine rote Zwiebel", "150 g|Naturjoghurt",
   "1 EL|Mayonnaise", "1 TL|Senf", "1 TL|Honig", "1 EL|Zitronensaft"],
  ["Brokkoli in sehr kleine Röschen schneiden, den Strunk schälen und fein würfeln.",
   "Kerne in einer trockenen Pfanne rösten. @3",
   "Joghurt, Mayonnaise, Senf, Honig und Zitronensaft zum Dressing verrühren, salzen und pfeffern.",
   "Brokkoli, fein gewürfelte Zwiebel und Cranberrys mit dem Dressing mischen und kurz durchziehen lassen. @10",
   "Kerne erst vor dem Servieren darüberstreuen."], cat="Salat", level="einfach")

R("honig-moehren-ofen", "Honig-Möhren aus dem Ofen mit Thymian", "🥕", "Deutsch", 4, "ca. 35 Min.",
  ["800 g|Karotten", "2 EL|Olivenöl", "1 EL|Honig", "3 Zweige|Thymian", "30 g|Walnüsse"],
  ["Ofen auf 200 °C Umluft vorheizen. Karotten schälen und längs halbieren.",
   "Mit Öl, Honig, Thymian, Salz und Pfeffer auf dem Blech mischen.",
   "Im Ofen rösten, bis sie weich und an den Rändern leicht gebräunt sind, einmal wenden. @25",
   "Mit gehackten Walnüssen bestreuen."], cat="Beilage", level="einfach")

R("mandel-pilaw", "Pilaw-Reis mit Mandeln und Rosinen", "🍚", "Orientalisch", 4, "ca. 30 Min.",
  ["250 g|Basmatireis", "1|Zwiebel", "30 g|Butter", "1|Zimtstange", "3|Kardamomkapseln", "450 ml|Gemüsebrühe", "40 g|Mandelstifte", "30 g|Rosinen"],
  ["Reis waschen, bis das Wasser klar ist, abtropfen lassen.",
   "Zwiebel fein würfeln und in Butter mit Zimt und Kardamom goldgelb dünsten. @5",
   "Reis zugeben und kurz glasig rühren. @2",
   "Brühe und Rosinen zugeben, aufkochen und zugedeckt bei kleinster Hitze garen. @15",
   "Mandeln rösten und unter den aufgelockerten Reis heben."], cat="Beilage", level="einfach")

# ---------- Snacks ----------
R("bruschetta", "Bruschetta mit Tomaten und Basilikum", "🍅", "Italienisch", 4, "ca. 15 Min.",
  ["1|Ciabatta", "4|reife Tomaten", "1|Knoblauchzehe", "½ Bund|Basilikum", "3 EL|Olivenöl", "1 TL|Balsamico"],
  ["Tomaten entkernen und fein würfeln, mit Basilikum, 2 EL Öl, Balsamico, Salz und Pfeffer mischen.",
   "Ciabatta in Scheiben schneiden, mit restlichem Öl beträufeln und im Ofen oder in der Pfanne rösten. @5",
   "Brote mit der halbierten Knoblauchzehe einreiben.",
   "Tomaten erst kurz vor dem Servieren daraufgeben, damit das Brot knusprig bleibt."], cat="Snack", level="einfach")

R("af-kichererbsen", "Knusprige Kichererbsen aus dem Airfryer", "🫘", "Orientalisch", 2, "ca. 20 Min.",
  ["1 Dose|Kichererbsen", "1 EL|Olivenöl", "1 TL|geräuchertes Paprikapulver", "½ TL|Kreuzkümmel", "½ TL|Knoblauchpulver"],
  ["Kichererbsen abspülen und sehr gut trocken tupfen, lose Häutchen entfernen.",
   "Mit Öl, Gewürzen und Salz mischen.",
   "Im Airfryer bei 200 °C knusprig rösten, zwischendurch schütteln. @15",
   "Kurz abkühlen lassen – sie werden dabei noch knuspriger."], airfryer=True, cat="Snack", level="einfach")

# ---------- Frühstück ----------
R("chia-pudding-mango", "Chia-Pudding mit Mango", "🥭", "International", 2, "ca. 10 Min. (+ über Nacht)",
  ["4 EL|Chiasamen", "250 ml|Hafermilch", "1 TL|Ahornsirup", "1|Mango", "2 EL|Kokosraspel"],
  ["Chiasamen mit Hafermilch und Ahornsirup verrühren, nach 5 Minuten noch einmal umrühren. @5",
   "Abgedeckt im Kühlschrank quellen lassen, am besten über Nacht.",
   "Mango würfeln oder pürieren.",
   "Pudding in Gläser füllen, Mango darauf geben und mit Kokosraspeln bestreuen."], cat="Frühstück", level="einfach")

R("herzhafte-fruehstuecksmuffins", "Herzhafte Frühstücksmuffins mit Ei und Spinat", "🧁", "Amerikanisch", 4, "ca. 30 Min.",
  ["8|Eier", "100 g|Babyspinat", "1|rote Paprika", "80 g|Feta", "2|Frühlingszwiebeln", "50 ml|Milch"],
  ["Ofen auf 180 °C vorheizen, ein Muffinblech einfetten.",
   "Spinat grob hacken, Paprika fein würfeln, Frühlingszwiebeln in Ringe schneiden.",
   "Eier mit Milch, Salz und Pfeffer verquirlen.",
   "Gemüse und zerbröselten Feta in die Mulden verteilen und mit der Eiermasse auffüllen.",
   "Backen, bis die Muffins gestockt und leicht gebräunt sind. @20"], cat="Frühstück", level="einfach")

# ---------- Süßes und Backen ----------
R("lebkuchen-tiramisu", "Lebkuchen-Tiramisu", "🎄", "Deutsch", 6, "ca. 25 Min. (+ 3 Std. kühlen)",
  ["250 g|Mascarpone", "250 g|Magerquark", "200 ml|Schlagsahne", "60 g|Zucker", "1 Pck.|Vanillezucker", "250 g|Lebkuchen (ohne Schokolade)",
   "200 ml|Kaffee (abgekühlt)", "2 EL|Kakaopulver", "1 TL|Zimt"],
  ["Mascarpone, Quark, Zucker und Vanillezucker glatt rühren, Sahne steif schlagen und unterheben.",
   "Lebkuchen kurz in Kaffee tauchen und eine Form damit auslegen.",
   "Die Hälfte der Creme darauf streichen, wieder Lebkuchen, dann die restliche Creme schichten.",
   "Abgedeckt im Kühlschrank durchziehen lassen. @180",
   "Kakao mit Zimt mischen und vor dem Servieren darübersieben."], cat="Dessert", level="einfach")

R("nicecream", "Schoko-Bananen-Nicecream", "🍌", "International", 2, "ca. 5 Min. (+ Gefrierzeit)",
  ["3|reife Bananen (gefroren)", "1 EL|Kakaopulver", "2 EL|Haferdrink", "1 EL|Erdnussbutter"],
  ["Bananen in Scheiben schneiden und mindestens 4 Stunden einfrieren.",
   "Gefrorene Bananen mit Kakao und Haferdrink im Mixer cremig pürieren, zwischendurch abschaben.",
   "Erdnussbutter kurz unterziehen und sofort essen oder 30 Minuten nachfrieren. @30"], cat="Dessert", level="einfach")

R("kuerbisbrot", "Saftiges Kürbisbrot", "🎃", "Deutsch", 12, "ca. 1 Std. 15 Min.",
  ["300 g|Hokkaido-Kürbis", "500 g|Dinkelmehl", "1 Würfel|frische Hefe", "200 ml|lauwarmes Wasser", "1 TL|Zucker", "2 TL|Salz",
   "2 EL|Olivenöl", "40 g|Kürbiskerne"],
  ["Kürbis würfeln, weich dämpfen und fein pürieren, abkühlen lassen. @12",
   "Hefe mit Zucker im Wasser auflösen, mit Mehl, Salz, Öl und Kürbispüree zu einem glatten Teig kneten.",
   "Zugedeckt an einem warmen Ort gehen lassen, bis er sich verdoppelt hat. @45",
   "Zu einem Laib formen, in Kürbiskernen wälzen und noch einmal gehen lassen. @15",
   "Bei 210 °C backen, bis das Brot beim Klopfen hohl klingt. @35"], cat="Backen", level="mittel")

# ---------- Getränke ----------
R("heisse-zitrone-ingwer", "Heiße Zitrone mit Ingwer und Honig", "🍋", "International", 2, "ca. 10 Min.",
  ["1|Bio-Zitrone", "20 g|Ingwer", "2 TL|Honig", "500 ml|Wasser"],
  ["Ingwer in dünne Scheiben schneiden und im Wasser kurz aufkochen, dann ziehen lassen. @5",
   "Zitrone auspressen, ein paar Scheiben Schale mitziehen lassen.",
   "Etwas abkühlen lassen und erst dann den Honig einrühren."], cat="Getränk", level="einfach")
