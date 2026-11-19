# Rezepte speziell für den Airfryer
# Faustregeln: Korb nicht überfüllen (Luft muss zirkulieren), nach der Hälfte schütteln/wenden,
# wenig Öl reicht (1–2 EL), Temperaturen ca. 20 °C unter Backofen-Angaben.
from gen import R

def A(*a):
    R(*a, airfryer=True)

A("af-pommes", "Knusprige Pommes", "🍟", "Deutsch", 2, "ca. 45 Min.",
  ["600 g|festkochende Kartoffeln", "1 EL|Speisestärke", "1 EL|Öl", "1 TL|Salz", "1 TL|Paprika edelsüß (optional)"],
  ["Kartoffeln in 1 cm dicke Stifte schneiden.",
   "In kaltem Wasser einweichen. Warum: Das spült Stärke aus, die Pommes werden knuspriger statt klebrig. @20",
   "Gründlich trocken tupfen, mit Stärke bestäuben und mit Öl mischen.",
   "Bei 180 °C garen, alle 5 Minuten den Korb schütteln. @20",
   "Auf 200 °C erhöhen und goldbraun knuspern lassen. @5",
   "Sofort salzen (und mit Paprika würzen)."])

A("af-chicken-wings", "Buffalo Chicken Wings", "🍗", "Amerikanisch", 2, "ca. 35 Min.",
  ["800 g|Hähnchenflügel, geteilt", "1 TL|Backpulver", "1 TL|Salz", "1 TL|Paprika geräuchert", "½ TL|Knoblauchpulver",
   "#Sauce", "40 g|Butter", "4 EL|scharfe Chilisauce (z. B. Frank's)", "1 TL|Honig",
   "#Dip", "100 g|saure Sahne", "30 g|Blauschimmelkäse oder Feta", "2|Stangen Sellerie"],
  ["Flügel trocken tupfen und mit Backpulver, Salz und Gewürzen mischen. Warum Backpulver: Es macht die Haut extra knusprig.",
   "In einer Lage in den Korb legen und bei 180 °C garen, nach der Hälfte wenden. @20",
   "Auf 200 °C erhöhen und knusprig fertig garen. @6",
   "Butter schmelzen, Chilisauce und Honig einrühren.",
   "Wings in der Sauce schwenken.",
   "Saure Sahne mit zerdrücktem Käse verrühren und mit Selleriesticks dazu servieren."])

A("af-falafel", "Falafel aus dem Airfryer", "🧆", "Orientalisch", 3, "ca. 40 Min. (plus Einweichen)",
  ["200 g|getrocknete Kichererbsen", "½|Zwiebel", "2|Knoblauchzehen", "1 Bund|Petersilie", "½ Bund|Koriander",
   "2 TL|Kreuzkümmel", "1 TL|Salz", "½ TL|Natron", "1 EL|Mehl", "2 EL|Öl",
   "#Dazu", "3|Fladenbrote", "Tahinsauce, Salat, Tomaten|zum Füllen"],
  ["Kichererbsen über Nacht einweichen (nicht kochen). @720",
   "Abtropfen lassen und mit Zwiebel, Knoblauch, Kräutern und Gewürzen im Mixer fein, aber nicht breiig zerkleinern.",
   "Natron und Mehl unterrühren und kühl ruhen lassen. @20",
   "Zu kleinen, etwas flacheren Bällchen formen. Warum flacher: Sie garen im Airfryer gleichmäßiger durch.",
   "Rundum mit Öl bepinseln und bei 190 °C garen, nach der Hälfte wenden. @14",
   "Im Fladenbrot mit Salat, Tomaten und Tahinsauce servieren."])

A("af-katsu", "Hähnchen-Katsu aus dem Airfryer", "🍱", "Japanisch", 2, "ca. 30 Min.",
  ["2|Hähnchenbrustfilets", "3 EL|Mehl", "1|Ei", "70 g|Panko", "1 EL|Öl", "#Katsu-Sauce", "3 EL|Ketchup",
   "2 EL|Worcestersauce", "1 TL|Sojasauce", "1 TL|Zucker", "#Dazu", "150 g|Reis", "150 g|Weißkohl, fein gehobelt"],
  ["Reis kochen. @15",
   "Panko mit dem Öl in einer Pfanne goldbraun rösten. Warum vorrösten: Im Airfryer wird Panko ohne Fett sonst nur blass.",
   "Hähnchen flach klopfen, salzen, in Mehl, verquirltem Ei und dem gerösteten Panko wenden.",
   "Bei 190 °C garen, nach der Hälfte wenden. @12",
   "Sauce verrühren.",
   "Schnitzel in Streifen schneiden und mit Reis, Kohl und Sauce servieren."])

A("af-suesskartoffel", "Süßkartoffel-Wedges mit Dip", "🍠", "Amerikanisch", 2, "ca. 35 Min.",
  ["2|Süßkartoffeln (ca. 600 g)", "1 EL|Speisestärke", "1 EL|Olivenöl", "1 TL|Paprika geräuchert", "½ TL|Salz",
   "#Dip", "150 g|griechischer Joghurt", "1|Knoblauchzehe", "½|Limette", "1 EL|Schnittlauch"],
  ["Süßkartoffeln waschen und mit Schale in Spalten schneiden.",
   "Mit Stärke, Öl, Paprika und Salz mischen.",
   "In einer Lage bei 190 °C garen, nach der Hälfte schütteln. Bei Bedarf in zwei Durchgängen. @20",
   "Joghurt mit gepresstem Knoblauch, Limettensaft, Schnittlauch und Salz verrühren und dazu servieren."])

A("af-honig-senf-lachs", "Honig-Senf-Lachs mit Brokkoli", "🐟", "International", 2, "ca. 20 Min.",
  ["2|Lachsfilets (je 150 g)", "300 g|Brokkoli, in Röschen", "1 EL|Olivenöl", "#Glasur", "1 EL|Honig",
   "1 EL|Dijonsenf", "1 EL|Sojasauce", "1|Knoblauchzehe, gepresst", "#Dazu", "150 g|Reis oder Couscous"],
  ["Reis kochen. @15",
   "Brokkoli mit Öl und Salz mischen und bei 190 °C vorgaren. @5",
   "Glasur verrühren, Lachs damit bestreichen.",
   "Lachs zum Brokkoli in den Korb legen und bei 190 °C garen, bis er innen gerade glasig ist. @9",
   "Mit Reis servieren."])

A("af-gyoza", "Knusprige Gyoza", "🥟", "Japanisch", 2, "ca. 20 Min.",
  ["20|TK-Gyoza", "1 EL|Öl", "#Dip", "2 EL|Sojasauce", "1 EL|Reisessig", "1 TL|Chiliöl", "1|Frühlingszwiebel"],
  ["Gyoza gefroren in eine Schüssel geben und rundum mit Öl benetzen. Warum: Ohne Öl wird der Teig im Airfryer hart statt knusprig.",
   "In einer Lage in den Korb legen und bei 190 °C garen, nach der Hälfte wenden. @12",
   "Dip verrühren, Frühlingszwiebel hineinschneiden und dazu servieren."])

A("af-fruehlingsrollen", "Gemüse-Frühlingsrollen", "🌯", "Chinesisch", 3, "ca. 45 Min.",
  ["12|Frühlingsrollenblätter (TK, aufgetaut)", "150 g|Weißkohl", "1|Karotte", "100 g|Sojasprossen", "3|Shiitake",
   "2|Frühlingszwiebeln", "50 g|Glasnudeln", "2 EL|Sojasauce", "1 TL|Sesamöl", "1 EL|Speisestärke + 2 EL Wasser",
   "2 EL|Öl", "Süß-scharfe Chilisauce|zum Dippen"],
  ["Glasnudeln einweichen, abtropfen und kürzen. @10",
   "Gemüse fein schneiden, in einer Pfanne kurz anbraten und mit Sojasauce und Sesamöl würzen. Abkühlen lassen. @10",
   "Glasnudeln untermischen.",
   "Je 2 EL Füllung auf ein Blatt geben, Seiten einschlagen, straff aufrollen und mit Stärkewasser verkleben.",
   "Rollen rundum mit Öl bepinseln.",
   "Bei 190 °C goldbraun garen, nach der Hälfte wenden. @12"])

A("af-baked-potato", "Baked Potato mit Kräuterquark", "🥔", "Deutsch", 2, "ca. 50 Min.",
  ["2|große mehligkochende Kartoffeln (je ca. 300 g)", "1 TL|Öl", "1 TL|grobes Salz", "#Kräuterquark", "250 g|Quark",
   "2 EL|Milch", "1|Knoblauchzehe", "1 Bund|Schnittlauch", "½ Bund|Petersilie", "#Topping (optional)",
   "50 g|Speckwürfel", "2 EL|Röstzwiebeln"],
  ["Kartoffeln waschen, trocknen, mehrmals mit einer Gabel einstechen und mit Öl und Salz einreiben.",
   "Bei 200 °C garen, nach der Hälfte wenden, bis ein Messer leicht hineingleitet. @40",
   "Quark mit Milch, Knoblauch, gehackten Kräutern, Salz und Pfeffer cremig rühren.",
   "Speck in den letzten 5 Minuten in einer kleinen Form mit in den Airfryer stellen.",
   "Kartoffeln kreuzweise einschneiden, etwas aufdrücken, mit Quark, Speck und Röstzwiebeln füllen."])

A("af-gefuellte-paprika", "Gefüllte Paprika mit Feta", "🫑", "Mediterran", 2, "ca. 40 Min.",
  ["2|große Paprika", "150 g|Couscous oder gekochter Reis", "200 g|Rinderhack oder 1 Dose Kichererbsen", "½|Zwiebel",
   "1|Knoblauchzehe", "200 g|stückige Tomaten", "1 TL|Oregano", "100 g|Feta"],
  ["Couscous mit gleicher Menge kochender Brühe übergießen und quellen lassen. @5",
   "Zwiebel, Knoblauch und Hack anbraten, Tomaten und Oregano zugeben und 5 Minuten köcheln. @5",
   "Mit Couscous und der Hälfte des Fetas mischen.",
   "Paprika halbieren, entkernen und füllen, restlichen Feta darüberbröseln.",
   "Bei 180 °C garen, bis die Paprika weich und der Feta gebräunt ist. @15"])

A("af-halloumi-gemuese", "Halloumi mit Ofengemüse", "🧀", "Mediterran", 2, "ca. 30 Min.",
  ["250 g|Halloumi, in dicken Scheiben", "1|Zucchini", "1|rote Paprika", "1|rote Zwiebel", "200 g|Cherrytomaten",
   "2 EL|Olivenöl", "1 TL|Kräuter der Provence", "1|Zitrone", "1 EL|Honig"],
  ["Gemüse in mundgerechte Stücke schneiden, mit Öl, Kräutern, Salz und Pfeffer mischen.",
   "Bei 200 °C garen, nach der Hälfte schütteln. @12",
   "Halloumi auf das Gemüse legen und weitergaren, bis er goldbraun ist. @6",
   "Mit Honig und Zitronensaft beträufeln."])

A("af-tandoori", "Tandoori-Hähnchen", "🍗", "Indisch", 2, "ca. 40 Min. (plus Marinieren)",
  ["4|Hähnchenunterschenkel oder 400 g Schenkelfilet", "150 g|Joghurt", "1 EL|Zitronensaft", "1 EL|Ingwer-Knoblauch-Paste",
   "2 TL|Tandoori-Masala", "1 TL|Kaschmiri-Chili oder Paprika", "½ TL|Salz", "#Dazu", "150 g|Basmatireis",
   "1|rote Zwiebel, in Ringen", "1|Zitrone", "1 Bund|Koriander"],
  ["Fleisch mehrmals einschneiden. Warum: Die Marinade zieht so tiefer ein.",
   "Mit allen Marinadezutaten mischen und kühl ziehen lassen (gern über Nacht). @60",
   "Reis kochen. @15",
   "Überschüssige Marinade abstreifen und bei 200 °C garen, nach der Hälfte wenden, bis die Ränder dunkel werden. @20",
   "Mit Zwiebelringen, Zitrone und Koriander servieren."])

A("af-samosa", "Samosas mit Filoteig", "🥟", "Indisch", 3, "ca. 50 Min.",
  ["300 g|Kartoffeln", "100 g|Erbsen (TK)", "½|Zwiebel", "1 TL|Ingwer, gerieben", "1|grüne Chili", "1 TL|Garam Masala",
   "½ TL|Kreuzkümmel", "½ TL|Kurkuma", "1 Bund|Koriander", "6|Blätter Filoteig", "30 g|Butter, geschmolzen",
   "Mango-Chutney|zum Dippen"],
  ["Kartoffeln würfeln und weich kochen. @12",
   "Zwiebel, Ingwer, Chili und Gewürze kurz anbraten, Kartoffeln und Erbsen zugeben, grob zerdrücken, mit Koriander und Salz würzen. Abkühlen lassen.",
   "Filoblätter längs dritteln, jeden Streifen mit Butter bestreichen.",
   "1 EL Füllung an ein Ende setzen und zu Dreiecken falten.",
   "Mit Butter bestreichen und bei 180 °C goldbraun backen, nach der Hälfte wenden. @10"])

A("af-siu-yuk", "Knuspriger Schweinebauch (Siu Yuk)", "🥓", "Chinesisch", 3, "ca. 1 Std. 30 Min. (plus Trocknen)",
  ["700 g|Schweinebauch mit Schwarte, am Stück", "1 TL|Fünf-Gewürze-Pulver", "1 TL|Zucker", "1 TL|Salz",
   "1 EL|Shaoxing-Wein", "1 EL|Reisessig", "2 EL|grobes Salz", "#Dazu", "Senf oder Hoisinsauce|zum Dippen", "300 g|Reis"],
  ["Fleisch kurz in kochendes Wasser legen, dann die Schwarte mit einer Gabel dicht einstechen. @3",
   "Fleischseite (nicht die Schwarte) mit Wein, Fünf-Gewürze-Pulver, Zucker und Salz einreiben.",
   "Unabgedeckt im Kühlschrank trocknen lassen, am besten über Nacht. Warum: Eine trockene Schwarte wird knusprig. @240",
   "Schwarte mit Essig bestreichen und dick mit grobem Salz bedecken.",
   "Bei 160 °C garen. @35",
   "Salzkruste abklopfen, auf 200 °C erhöhen und garen, bis die Schwarte aufpoppt. @20",
   "Ruhen lassen, in Würfel schneiden und mit Reis und Dip servieren. @10"])

A("af-koefte", "Köfte mit Joghurtsauce", "🍢", "Orientalisch", 2, "ca. 35 Min.",
  ["400 g|Lamm- oder Rinderhack", "½|Zwiebel, fein gerieben", "1|Knoblauchzehe", "1 Bund|Petersilie", "1 TL|Kreuzkümmel",
   "1 TL|Paprika edelsüß", "½ TL|Zimt", "1 TL|Salz", "#Sauce", "150 g|Joghurt", "1 TL|Minze, getrocknet", "1|Knoblauchzehe",
   "#Dazu", "2|Fladenbrote", "1|Tomate", "½|Gurke"],
  ["Hack mit Zwiebel, Knoblauch, gehackter Petersilie und Gewürzen kräftig verkneten. Warum lange kneten: Die Köfte halten dann besser zusammen.",
   "Zu 8 länglichen Röllchen formen.",
   "Bei 200 °C garen, nach der Hälfte wenden. @12",
   "Joghurt mit Minze, Knoblauch und Salz verrühren.",
   "Mit Fladenbrot, Tomate, Gurke und Sauce servieren."])

A("af-gochujang-blumenkohl", "Gochujang-Blumenkohl", "🥦", "Koreanisch", 2, "ca. 35 Min.",
  ["1|kleiner Blumenkohl", "3 EL|Speisestärke", "1 EL|Öl", "#Glasur", "2 EL|Gochujang", "1 EL|Sojasauce", "1 EL|Honig",
   "1 TL|Reisessig", "1 TL|Sesamöl", "1|Knoblauchzehe", "#Dazu", "1 TL|Sesam", "2|Frühlingszwiebeln", "150 g|Reis"],
  ["Reis kochen. @15",
   "Blumenkohl in kleine Röschen teilen, mit Öl mischen und mit Stärke bestäuben.",
   "Bei 200 °C garen, nach der Hälfte schütteln. @15",
   "Glasur in einer Pfanne aufkochen, bis sie leicht eindickt. @2",
   "Blumenkohl darin schwenken, mit Sesam und Frühlingszwiebeln bestreuen."])

A("af-tortilla-pizza", "Tortilla-Pizza in 10 Minuten", "🍕", "Italienisch", 2, "ca. 15 Min.",
  ["2|Weizentortillas", "4 EL|Tomatensauce oder passierte Tomaten", "½ TL|Oregano", "125 g|Mozzarella",
   "Belag nach Wahl (Salami, Pilze, Paprika)|nach Geschmack", "Basilikum|zum Servieren"],
  ["Tomatensauce mit Oregano und Salz würzen.",
   "Eine Tortilla mit Sauce bestreichen, mit Mozzarella und Belag belegen.",
   "Bei 190 °C backen, bis der Käse blubbert und der Rand knusprig ist. @6",
   "Mit Basilikum servieren, zweite Pizza genauso."])

A("af-gnocchi", "Knusprige Gnocchi mit Tomaten", "🍅", "Italienisch", 2, "ca. 20 Min.",
  ["500 g|Gnocchi (Kühlregal)", "250 g|Cherrytomaten", "1|rote Zwiebel", "2|Knoblauchzehen", "2 EL|Olivenöl",
   "1 TL|Oregano", "125 g|Mozzarella oder 50 g Parmesan", "1 Handvoll|Basilikum"],
  ["Gnocchi, Tomaten, Zwiebelspalten und Knoblauch mit Öl, Oregano, Salz und Pfeffer mischen. Warum ungekocht: Die Gnocchi werden im Airfryer außen knusprig und innen weich.",
   "Bei 200 °C garen, alle 5 Minuten schütteln. @15",
   "Mozzarella darüberzupfen und schmelzen lassen. @2",
   "Mit Basilikum servieren."])

A("af-bratwurst", "Bratwurst mit Kartoffelspalten", "🌭", "Deutsch", 2, "ca. 40 Min.",
  ["4|grobe Bratwürste", "600 g|festkochende Kartoffeln", "1 EL|Öl", "1 TL|Rosmarin", "½ TL|Paprika edelsüß",
   "#Dazu", "Senf|nach Geschmack", "250 g|Sauerkraut"],
  ["Kartoffeln in Spalten schneiden, mit Öl, Rosmarin, Paprika und Salz mischen.",
   "Bei 190 °C garen, nach der Hälfte schütteln. @15",
   "Bratwürste auf die Kartoffeln legen und weitergaren, nach der Hälfte wenden. @12",
   "Sauerkraut im Topf erwärmen. @5",
   "Mit Senf servieren."])

A("af-apfeltaschen", "Apfeltaschen mit Zimt", "🥐", "Deutsch", 4, "ca. 35 Min.",
  ["1 Rolle|Blätterteig (Kühlregal)", "2|Äpfel", "2 EL|Zucker", "1 TL|Zimt", "1 EL|Zitronensaft", "30 g|Rosinen (optional)",
   "1|Eigelb", "2 EL|Milch", "1 EL|Puderzucker"],
  ["Äpfel schälen, klein würfeln und mit Zucker, Zimt, Zitronensaft und Rosinen mischen.",
   "Blätterteig in 8 Quadrate schneiden.",
   "Füllung auf je eine Hälfte geben, zu Dreiecken falten und die Ränder mit einer Gabel fest andrücken.",
   "Eigelb mit Milch verquirlen, Taschen damit bestreichen und oben einritzen.",
   "Auf Backpapier in den Korb legen und bei 170 °C goldbraun backen. Nicht stapeln. @12",
   "Etwas abkühlen lassen und mit Puderzucker bestäuben."])
