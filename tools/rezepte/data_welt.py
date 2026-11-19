# Mexikanisch, Mediterran, Orientalisch
from gen import R

# ---------------- Mexikanisch ----------------
R("chili-con-carne", "Chili con Carne", "🌶", "Mexikanisch", 4, "ca. 1 Std. 15 Min.",
  ["500 g|Rinderhack", "1|Zwiebel", "2|Knoblauchzehen", "1|rote Paprika", "2 EL|Tomatenmark", "800 g|stückige Tomaten",
   "1 Dose (400 g)|Kidneybohnen", "1 Dose (300 g)|Mais", "2 TL|Kreuzkümmel", "2 TL|Paprika edelsüß",
   "1 TL|Chilipulver", "1 TL|Oregano", "20 g|Zartbitterschokolade", "Saure Sahne und Reis|zum Servieren"],
  ["Hack in Öl krümelig und kräftig braun anbraten. @8",
   "Zwiebel, Knoblauch und Paprika zugeben und weich braten. @5",
   "Tomatenmark und Gewürze 1 Minute mitrösten.",
   "Tomaten zugeben und zugedeckt köcheln. @30",
   "Bohnen, Mais und Schokolade zugeben und weiterköcheln. Warum Schokolade: Sie macht das Chili runder und dunkler. @15",
   "Abschmecken und mit saurer Sahne und Reis servieren."])

R("tacos-al-pastor", "Tacos al Pastor", "🌮", "Mexikanisch", 4, "ca. 1 Std. (plus Marinieren)",
  ["600 g|Schweinenacken, in dünnen Scheiben", "#Marinade", "2|getrocknete Ancho-Chilis (oder 2 EL Chipotle-Paste)",
   "100 ml|Ananassaft", "2 EL|Apfelessig", "2|Knoblauchzehen", "1 TL|Kreuzkümmel", "1 TL|Oregano",
   "#Zum Servieren", "12|kleine Maistortillas", "200 g|Ananas, gewürfelt", "1|Zwiebel, fein gewürfelt",
   "1 Bund|Koriander", "2|Limetten", "Salsa|nach Geschmack"],
  ["Chilis entkernen, 10 Minuten in heißem Wasser einweichen und mit den übrigen Marinadezutaten pürieren. @10",
   "Fleisch mit der Marinade mischen und kühl ziehen lassen (gern über Nacht). @120",
   "Fleisch in einer sehr heißen Pfanne portionsweise scharf anbraten, bis die Ränder karamellisieren. @6",
   "Ananas kurz in derselben Pfanne anrösten. @3",
   "Fleisch klein schneiden, Tortillas in einer trockenen Pfanne erwärmen.",
   "Tortillas mit Fleisch, Ananas, Zwiebel, Koriander und Salsa belegen, mit Limette servieren."])

R("guacamole", "Guacamole mit Nachos", "🥑", "Mexikanisch", 4, "ca. 15 Min.",
  ["3|reife Avocados", "1|Limette", "½|rote Zwiebel, fein gewürfelt", "1|Tomate, entkernt und gewürfelt",
   "1|Jalapeño, fein gehackt", "1 Bund|Koriander", "½ TL|Salz", "200 g|Tortilla-Chips"],
  ["Avocados halbieren, Kern entfernen und das Fruchtfleisch mit einer Gabel grob zerdrücken.",
   "Sofort mit Limettensaft mischen. Warum: Die Säure verhindert, dass sie braun wird.",
   "Zwiebel, Tomate, Jalapeño und gehackten Koriander unterheben.",
   "Mit Salz abschmecken und mit Tortilla-Chips servieren."])

R("enchiladas", "Hähnchen-Enchiladas", "🌯", "Mexikanisch", 4, "ca. 1 Std.",
  ["400 g|Hähnchenbrust", "8|Weizentortillas", "1|Zwiebel", "1|Paprika", "1 Dose (400 g)|schwarze Bohnen",
   "200 g|geriebener Käse (Cheddar)", "#Sauce", "500 g|passierte Tomaten", "1 TL|Kreuzkümmel", "1 TL|Chilipulver",
   "1|Knoblauchzehe", "#Dazu", "150 g|saure Sahne", "1 Bund|Koriander"],
  ["Hähnchen in Salzwasser gar ziehen lassen und mit zwei Gabeln zerzupfen. @15",
   "Sauce aufkochen und 10 Minuten köcheln. @10",
   "Zwiebel und Paprika anbraten, mit Hähnchen, Bohnen und der Hälfte des Käses mischen. @5",
   "Etwas Sauce in eine Airfryer-geeignete Form (ca. 20 cm) geben.",
   "Tortillas füllen, aufrollen und dicht nebeneinander in die Form legen. Passen nicht alle hinein, halbieren oder in zwei Durchgängen backen.",
   "Mit Sauce und restlichem Käse bedecken und im Airfryer bei 180 °C backen, bis der Käse blubbert. @12",
   "Mit saurer Sahne und Koriander servieren."], airfryer=True)

R("quesadillas", "Quesadillas mit Bohnen und Mais", "🧀", "Mexikanisch", 2, "ca. 20 Min.",
  ["4|Weizentortillas", "150 g|geriebener Käse", "200 g|schwarze Bohnen (Dose)", "100 g|Mais", "1|Frühlingszwiebel",
   "1|Jalapeño (optional)", "½ TL|Kreuzkümmel", "Salsa und saure Sahne|zum Servieren"],
  ["Bohnen leicht zerdrücken und mit Mais, Frühlingszwiebel, Jalapeño und Kreuzkümmel mischen.",
   "Eine Tortilla in eine trockene Pfanne legen, mit Käse, Füllung und noch etwas Käse belegen, zweite Tortilla darauf.",
   "Bei mittlerer Hitze braten, bis die Unterseite knusprig ist. @3",
   "Mit Hilfe eines Tellers wenden und weiterbraten, bis der Käse geschmolzen ist. @3",
   "In Dreiecke schneiden und mit Salsa servieren."])

R("burrito-bowl", "Burrito Bowl", "🥗", "Mexikanisch", 2, "ca. 35 Min.",
  ["150 g|Reis", "1|Limette", "1 Bund|Koriander", "300 g|Hähnchenbrust", "1 TL|Kreuzkümmel", "1 TL|Paprika geräuchert",
   "200 g|schwarze Bohnen", "150 g|Mais", "1|Avocado", "150 g|Cherrytomaten", "2 EL|saure Sahne", "50 g|Käse"],
  ["Reis kochen und mit Limettensaft und gehacktem Koriander mischen. @15",
   "Hähnchen mit Gewürzen, Salz und Öl einreiben.",
   "In der Pfanne pro Seite braten, bis es durch ist, dann ruhen lassen und in Streifen schneiden. @10",
   "Bohnen und Mais erwärmen.",
   "Avocado und Tomaten würfeln.",
   "Alles nebeneinander auf dem Reis anrichten, mit saurer Sahne und Käse toppen."])

R("fajitas", "Hähnchen-Fajitas", "🫑", "Mexikanisch", 2, "ca. 30 Min.",
  ["300 g|Hähnchenbrust, in Streifen", "2|Paprika (verschiedene Farben)", "1|rote Zwiebel", "1 TL|Kreuzkümmel",
   "1 TL|Paprika geräuchert", "½ TL|Chilipulver", "1|Limette", "6|Weizentortillas",
   "Guacamole, saure Sahne, Salsa|zum Servieren"],
  ["Hähnchen mit Gewürzen, Limettensaft und 1 EL Öl marinieren. @15",
   "Paprika und Zwiebel in Streifen schneiden.",
   "Pfanne sehr heiß werden lassen, Hähnchen braten, bis es durch ist, und herausnehmen. @5",
   "Gemüse bei starker Hitze bissfest braten. @4",
   "Hähnchen zurückgeben und durchschwenken.",
   "Tortillas erwärmen und alles am Tisch selbst füllen."])

# ---------------- Mediterran ----------------
R("moussaka", "Moussaka", "🍆", "Mediterran", 4, "ca. 1 Std. 45 Min.",
  ["2|Auberginen", "400 g|Lammhack oder Rinderhack", "1|Zwiebel", "2|Knoblauchzehen", "400 g|stückige Tomaten",
   "100 ml|Rotwein", "1 TL|Zimt", "1 TL|Oregano", "#Béchamel", "40 g|Butter", "40 g|Mehl", "450 ml|Milch",
   "1|Eigelb", "50 g|Kefalotyri oder Parmesan", "1 Prise|Muskat", "#Außerdem", "1|Airfryer-geeignete Form (ca. 20 cm)"],
  ["Auberginen in 1 cm Scheiben schneiden, salzen, mit Öl bestreichen und portionsweise im Airfryer bei 200 °C garen, bis sie weich und gebräunt sind. @12",
   "Zwiebel und Knoblauch andünsten, Hack krümelig braten. @8",
   "Mit Wein ablöschen, Tomaten, Zimt und Oregano zugeben und köcheln. @25",
   "Béchamel kochen: Butter schmelzen, Mehl einrühren, Milch unterrühren, andicken lassen, vom Herd nehmen, Eigelbe, Käse und Muskat unterrühren. @8",
   "Abwechselnd Auberginen und Fleischsauce in eine Form schichten, mit Béchamel abschließen.",
   "Im Airfryer bei 160 °C backen. Wird die Oberfläche zu schnell dunkel, mit Alufolie abdecken. Warum niedriger als im Ofen: Der Airfryer bläst die Hitze direkt von oben. @30",
   "Vor dem Anschneiden ruhen lassen. @20"], airfryer=True)

R("souvlaki", "Souvlaki mit Tzatziki", "🍢", "Mediterran", 4, "ca. 45 Min. (plus Marinieren)",
  ["800 g|Schweinenacken oder Hähnchen, gewürfelt", "4 EL|Olivenöl", "1|Zitrone", "2|Knoblauchzehen", "2 TL|Oregano",
   "#Tzatziki", "500 g|griechischer Joghurt", "1|Salatgurke", "2|Knoblauchzehen", "1 EL|Olivenöl", "1 EL|Dill",
   "#Dazu", "4|Pitabrote", "1|rote Zwiebel", "2|Tomaten"],
  ["Fleisch mit Öl, Zitronensaft, Knoblauch, Oregano, Salz und Pfeffer marinieren. @60",
   "Gurke grob reiben, salzen und nach 10 Minuten kräftig ausdrücken. Warum: Sonst wird das Tzatziki wässrig. @10",
   "Gurke mit Joghurt, gepresstem Knoblauch, Öl und Dill verrühren und kühlen.",
   "Fleisch auf Spieße stecken.",
   "Spieße (kurze, die in den Korb passen) im Airfryer bei 200 °C garen, nach der Hälfte wenden. @12",
   "Pita kurz rösten und mit Spießen, Tzatziki, Zwiebeln und Tomaten servieren."], airfryer=True)

R("horiatiki", "Griechischer Bauernsalat", "🥗", "Mediterran", 2, "ca. 15 Min.",
  ["3|reife Tomaten", "1|Salatgurke", "1|grüne Paprika", "1|rote Zwiebel", "100 g|Kalamata-Oliven",
   "200 g|Feta (am Stück)", "4 EL|Olivenöl", "1 EL|Rotweinessig", "1 TL|Oregano"],
  ["Tomaten in Spalten, Gurke in dicke Halbmonde schneiden.",
   "Paprika und Zwiebel in Ringe schneiden.",
   "Alles mit Oliven in eine Schüssel geben, salzen und mit Essig mischen.",
   "Feta als Ganzes obenauf legen, mit Oregano bestreuen und Olivenöl darübergießen."])

R("spanakopita", "Spanakopita (Spinat-Feta-Pita)", "🥧", "Mediterran", 3, "ca. 1 Std.",
  ["250 g|Blattspinat (oder TK)", "3|Frühlingszwiebeln", "½ Bund|Dill", "125 g|Feta", "1|Ei",
   "1 Prise|Muskat", "125 g|Filoteig", "40 g|Butter, geschmolzen", "1|Airfryer-geeignete Form (ca. 20 cm)"],
  ["Spinat in einer Pfanne zusammenfallen lassen, gut ausdrücken und hacken. @4",
   "Mit Frühlingszwiebeln, Dill, zerbröseltem Feta, Eiern, Muskat und Pfeffer mischen.",
   "Form fetten.",
   "Die Hälfte der Teigblätter einzeln mit Butter bestreichen und in die Form legen.",
   "Füllung verteilen, mit den restlichen gebutterten Blättern bedecken.",
   "Oberfläche in Portionsstücke einritzen und im Airfryer bei 160 °C backen, bis sie goldbraun ist. @25"], airfryer=True)

R("paella", "Paella mit Hähnchen und Garnelen", "🥘", "Mediterran", 4, "ca. 1 Std.",
  ["300 g|Paella-Reis (Bomba)", "400 g|Hähnchenschenkel, gewürfelt", "200 g|Garnelen", "1|Zwiebel", "1|rote Paprika",
   "2|Knoblauchzehen", "200 g|Tomaten, gerieben", "150 g|grüne Bohnen", "1 TL|Paprika geräuchert",
   "1 Prise|Safran", "900 ml|Hühnerbrühe", "4 EL|Olivenöl", "1|Zitrone"],
  ["Hähnchen in Olivenöl in der Paellapfanne rundum anbraten. @8",
   "Zwiebel, Paprika, Bohnen und Knoblauch zugeben und weich braten. @5",
   "Tomate und Paprikapulver zugeben und einkochen lassen. @5",
   "Reis einstreuen, kurz verrühren, dann heiße Brühe mit Safran angießen. Ab jetzt nicht mehr rühren.",
   "Bei mittlerer Hitze köcheln lassen. @15",
   "Garnelen auf den Reis drücken und weitergaren, bis die Flüssigkeit aufgesogen ist und sich am Boden eine Kruste bildet. @8",
   "Mit einem Tuch abgedeckt ruhen lassen und mit Zitrone servieren. @5"])

R("gazpacho", "Gazpacho", "🍅", "Mediterran", 4, "ca. 20 Min. (plus Kühlen)",
  ["1 kg|sehr reife Tomaten", "1|Salatgurke", "1|rote Paprika", "1|Knoblauchzehe", "½|Zwiebel",
   "50 g|Weißbrot vom Vortag", "80 ml|Olivenöl", "2 EL|Sherryessig", "1 TL|Salz"],
  ["Gemüse grob schneiden, Brot kurz einweichen.",
   "Alles mit Öl, Essig und Salz im Mixer sehr fein pürieren.",
   "Durch ein Sieb streichen, damit sie samtig wird.",
   "Gut gekühlt durchziehen lassen. @60",
   "Mit fein gewürfeltem Gemüse und einem Schuss Olivenöl servieren."])

# ---------------- Orientalisch ----------------
R("hummus", "Hummus", "🫘", "Orientalisch", 4, "ca. 15 Min.",
  ["1 Dose (400 g)|Kichererbsen", "3 EL|Tahin", "1|Zitrone", "1|Knoblauchzehe", "3 EL|Eiswasser", "½ TL|Kreuzkümmel",
   "3 EL|Olivenöl", "1 TL|Paprika edelsüß", "Fladenbrot|zum Servieren"],
  ["Kichererbsen abgießen, etwas Kochflüssigkeit aufheben. Optional die Häutchen abreiben, dann wird es cremiger.",
   "Tahin mit Zitronensaft und Knoblauch im Mixer aufschlagen.",
   "Kichererbsen, Kreuzkümmel und Salz zugeben und pürieren, dabei Eiswasser zugeben, bis es sehr cremig ist. @3",
   "In eine Schale streichen, mit einer Mulde Olivenöl und Paprika garnieren.",
   "Mit warmem Fladenbrot servieren."])

R("falafel", "Falafel im Fladenbrot", "🧆", "Orientalisch", 4, "ca. 1 Std. (plus Einweichen)",
  ["250 g|getrocknete Kichererbsen", "1|Zwiebel", "3|Knoblauchzehen", "1 Bund|Petersilie", "1 Bund|Koriander",
   "2 TL|Kreuzkümmel", "1 TL|Koriander, gemahlen", "1 TL|Salz", "½ TL|Natron", "500 ml|Öl zum Frittieren",
   "#Dazu", "4|Fladenbrote", "Tahinsauce, Salat, Tomaten|zum Füllen"],
  ["Kichererbsen über Nacht in viel Wasser einweichen. Wichtig: nicht kochen, sonst zerfällt die Masse. @720",
   "Abtropfen lassen und mit Zwiebel, Knoblauch, Kräutern und Gewürzen im Mixer fein, aber nicht breiig zerkleinern.",
   "Natron unterrühren und die Masse kühl ruhen lassen. @30",
   "Walnussgroße Bällchen formen.",
   "In 175 °C heißem Öl portionsweise goldbraun frittieren. @4",
   "Mit Salat, Tomaten und Tahinsauce im Fladenbrot servieren."])

R("shakshuka", "Shakshuka", "🍳", "Orientalisch", 2, "ca. 30 Min.",
  ["1|Zwiebel", "1|rote Paprika", "2|Knoblauchzehen", "400 g|stückige Tomaten", "1 TL|Kreuzkümmel",
   "1 TL|Paprika edelsüß", "½ TL|Chiliflocken", "4|Eier", "50 g|Feta", "1 Bund|Petersilie", "2 EL|Olivenöl", "Brot|zum Servieren"],
  ["Zwiebel und Paprika in Olivenöl weich braten. @6",
   "Knoblauch und Gewürze 1 Minute mitbraten.",
   "Tomaten zugeben, salzen und einkochen lassen. @10",
   "Vier Mulden formen und je ein Ei hineinschlagen.",
   "Zugedeckt bei kleiner Hitze garen, bis das Eiweiß fest ist und das Eigelb noch flüssig. @6",
   "Mit Feta und Petersilie bestreuen und in der Pfanne mit Brot servieren."])

R("haehnchen-shawarma", "Hähnchen-Shawarma", "🥙", "Orientalisch", 4, "ca. 50 Min. (plus Marinieren)",
  ["800 g|Hähnchenschenkel ohne Knochen", "#Marinade", "100 g|Joghurt", "1|Zitrone", "3|Knoblauchzehen",
   "2 TL|Kreuzkümmel", "2 TL|Paprika", "1 TL|Kurkuma", "½ TL|Zimt", "3 EL|Olivenöl",
   "#Dazu", "4|Fladenbrote", "Knoblauchsauce, Salat, eingelegte Gurken|zum Füllen"],
  ["Marinadezutaten verrühren, Hähnchen darin mindestens 1 Stunde ziehen lassen. @60",
   "Hähnchen locker in den Airfryer-Korb legen (nicht stapeln, sonst wird es nicht knusprig) und bei 200 °C garen, nach der Hälfte wenden. Bei Bedarf in zwei Durchgängen. @15",
   "Kurz ruhen lassen und in dünne Streifen schneiden. @5",
   "In warmen Fladenbroten mit Salat, Gurken und Knoblauchsauce servieren."], airfryer=True)

R("tabouleh", "Tabouleh", "🌿", "Orientalisch", 4, "ca. 25 Min.",
  ["60 g|feiner Bulgur", "3 Bund|glatte Petersilie", "1 Bund|Minze", "3|Tomaten", "3|Frühlingszwiebeln",
   "2|Zitronen", "5 EL|Olivenöl", "½ TL|Piment oder Baharat"],
  ["Bulgur mit 80 ml kochendem Wasser übergießen und quellen lassen. @15",
   "Petersilie und Minze sehr fein hacken. Warum so viel: Echtes Tabouleh ist ein Kräutersalat, kein Bulgursalat.",
   "Tomaten fein würfeln, Frühlingszwiebeln in Ringe schneiden.",
   "Alles mit Bulgur, Zitronensaft, Öl, Gewürz und Salz mischen.",
   "Kurz durchziehen lassen und frisch servieren. @10"])

R("lamm-tajine", "Lamm-Tajine mit Aprikosen", "🍲", "Orientalisch", 4, "ca. 2 Std. 15 Min.",
  ["800 g|Lammschulter, gewürfelt", "2|Zwiebeln", "3|Knoblauchzehen", "1 EL|Ingwer", "2 TL|Ras el Hanout",
   "1|Zimtstange", "1 Prise|Safran", "500 ml|Brühe", "150 g|getrocknete Aprikosen", "1 EL|Honig",
   "40 g|Mandeln, geröstet", "1 Bund|Koriander", "250 g|Couscous"],
  ["Fleisch in Olivenöl portionsweise anbraten. @8",
   "Zwiebeln, Knoblauch und Ingwer weich braten, Gewürze 1 Minute mitrösten. @6",
   "Fleisch zurückgeben, Brühe und Safran zugeben und zugedeckt schmoren. @90",
   "Aprikosen und Honig zugeben und weiterschmoren. @20",
   "Couscous mit gleicher Menge kochender Brühe übergießen und quellen lassen, dann auflockern. @5",
   "Tajine mit Mandeln und Koriander bestreut auf dem Couscous servieren."])
