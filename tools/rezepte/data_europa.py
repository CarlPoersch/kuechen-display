# Italienisch, Deutsch, Französisch
from gen import R

# ---------------- Italienisch ----------------
R("carbonara", "Spaghetti Carbonara", "🍝", "Italienisch", 2, "ca. 25 Min.",
  ["200 g|Spaghetti", "120 g|Guanciale oder Pancetta, gewürfelt", "3|Eigelb", "1|ganzes Ei",
   "50 g|Pecorino Romano, fein gerieben", "1 TL|schwarzer Pfeffer, frisch gemahlen"],
  ["Spaghetti in gut gesalzenem Wasser kochen. @10",
   "Guanciale in einer Pfanne ohne Öl langsam knusprig auslassen. @8",
   "Eigelbe, Ei, Pecorino und Pfeffer zu einer dicken Creme verrühren.",
   "Pfanne vom Herd nehmen. Nudeln tropfnass zum Guanciale geben.",
   "Eiercreme mit 3 EL Nudelwasser zugeben und kräftig schwenken, bis eine cremige Sauce entsteht. Warum vom Herd: Sonst wird das Ei zu Rührei.",
   "Mit Pecorino und Pfeffer servieren."])

R("ragu-bolognese", "Ragù alla Bolognese", "🍝", "Italienisch", 4, "ca. 2 Std. 30 Min.",
  ["500 g|Hackfleisch (Rind und Schwein)", "100 g|Pancetta, fein gewürfelt", "1|Zwiebel", "1|Karotte", "1|Stange Sellerie",
   "150 ml|trockener Rotwein", "400 g|passierte Tomaten", "2 EL|Tomatenmark", "150 ml|Milch", "250 ml|Brühe",
   "2 EL|Olivenöl", "400 g|Tagliatelle", "Parmesan|zum Servieren"],
  ["Zwiebel, Karotte und Sellerie sehr fein würfeln (Soffritto).",
   "Pancetta in Olivenöl auslassen, Soffritto zugeben und weich dünsten. @10",
   "Hack zugeben und krümelig braten, bis die Flüssigkeit verdampft ist. @10",
   "Tomatenmark 1 Minute mitrösten, mit Wein ablöschen und einkochen lassen.",
   "Milch zugeben und einkochen lassen. Warum Milch: Sie macht das Fleisch zart und die Sauce runder.",
   "Tomaten und Brühe zugeben und bei kleinster Hitze offen köcheln, bei Bedarf Brühe nachgießen. @120",
   "Tagliatelle kochen, mit dem Ragù mischen und mit Parmesan servieren. @8"])

R("lasagne", "Lasagne", "🧀", "Italienisch", 3, "ca. 1 Std. 30 Min.",
  ["#Fleischsauce", "250 g|Rinderhack", "½|Zwiebel", "½|Karotte", "1|Knoblauchzehe", "400 g|passierte Tomaten",
   "1 EL|Tomatenmark", "½ TL|Oregano", "#Béchamel", "25 g|Butter", "25 g|Mehl", "300 ml|Milch", "1 Prise|Muskat",
   "#Außerdem", "125 g|Lasagneplatten", "50 g|Parmesan, gerieben", "60 g|Mozzarella", "1|Airfryer-geeignete Form (ca. 20 cm)"],
  ["Zwiebel, Karotte und Knoblauch fein würfeln und in Öl andünsten. @5",
   "Hack krümelig braten, Tomatenmark mitrösten. @8",
   "Tomaten und Oregano zugeben, salzen und köcheln lassen. @30",
   "Für die Béchamel Butter schmelzen, Mehl einrühren, Milch nach und nach unterrühren und köcheln, bis sie andickt. Mit Muskat und Salz würzen. @6",
   "In die Form abwechselnd Sauce, Platten (passend gebrochen), Béchamel und Parmesan schichten. Mit Béchamel, Mozzarella und Parmesan abschließen.",
   "Mit Alufolie abgedeckt im Airfryer bei 160 °C backen. Warum abdecken: So garen die Platten durch, bevor der Käse verbrennt. @20",
   "Folie abnehmen und bei 180 °C goldbraun backen. @8",
   "Vor dem Anschneiden ruhen lassen, damit sie nicht zerfällt. @10"], airfryer=True)

R("risotto-funghi", "Risotto ai Funghi", "🍄", "Italienisch", 2, "ca. 40 Min.",
  ["160 g|Risottoreis (Arborio, Carnaroli)", "250 g|Champignons oder Steinpilze", "1|Schalotte", "1|Knoblauchzehe",
   "100 ml|trockener Weißwein", "800 ml|heiße Gemüsebrühe", "40 g|Butter", "50 g|Parmesan", "2 EL|Olivenöl",
   "1 Bund|Petersilie"],
  ["Pilze in Scheiben schneiden und in 1 EL Öl kräftig anbraten, herausnehmen. @5",
   "Schalotte und Knoblauch in restlichem Öl glasig dünsten. @3",
   "Reis zugeben und 2 Minuten anschwitzen, bis er glasig ist. @2",
   "Mit Wein ablöschen und einkochen lassen.",
   "Nach und nach Brühe zugeben und unter Rühren garen, bis der Reis cremig ist und noch Biss hat. @18",
   "Pilze untermischen, vom Herd nehmen, Butter und Parmesan einrühren und abgedeckt ruhen lassen. @2",
   "Mit Petersilie servieren."])

R("pizza-margherita", "Pizza Margherita", "🍕", "Italienisch", 2, "ca. 3 Std. (inkl. Gehzeit)",
  ["#Teig", "300 g|Pizzamehl (Tipo 00)", "190 ml|Wasser", "3 g|Trockenhefe", "7 g|Salz",
   "#Belag", "200 g|San-Marzano-Tomaten (Dose)", "1 Prise|Salz", "200 g|Mozzarella (Fior di Latte)",
   "1 Handvoll|Basilikum", "2 EL|Olivenöl"],
  ["Mehl, Wasser und Hefe vermengen, Salz zugeben und 10 Minuten kneten. @10",
   "Abgedeckt gehen lassen. @120",
   "Teig in drei Kugeln teilen und noch einmal ruhen lassen. Warum drei: Eine Pizza muss in den Airfryer-Korb passen (ca. 18 cm). @30",
   "Airfryer auf 200 °C vorheizen. @3",
   "Tomaten mit Salz zerdrücken. Mozzarella abtropfen lassen und zerzupfen.",
   "Eine Kugel auf Backpapier von innen nach außen dünn drücken (ca. 18 cm), Rand dicker lassen.",
   "Mit Tomaten bestreichen und mit dem Backpapier in den Korb legen. Backen. @5",
   "Mozzarella belegen und fertig backen. Die übrigen Pizzen genauso. @3",
   "Mit Basilikum und Olivenöl servieren."], airfryer=True)

R("pesto-genovese", "Trofie mit Pesto Genovese", "🌿", "Italienisch", 2, "ca. 20 Min.",
  ["200 g|Trofie oder Linguine", "50 g|Basilikumblätter", "30 g|Pinienkerne", "1|Knoblauchzehe", "40 g|Parmesan",
   "20 g|Pecorino", "80 ml|mildes Olivenöl", "1|kleine Kartoffel", "100 g|grüne Bohnen"],
  ["Pinienkerne ohne Fett goldbraun rösten. @3",
   "Basilikum, Knoblauch, Pinienkerne und etwas Salz im Mörser oder Mixer zerkleinern, Käse und Öl einarbeiten. Nicht zu lange mixen: Basilikum wird sonst bitter.",
   "Kartoffel würfeln, Bohnen in Stücke schneiden.",
   "Nudeln mit Kartoffel und Bohnen im selben Topf kochen. @11",
   "Abgießen, dabei etwas Nudelwasser auffangen.",
   "Mit Pesto und 2–3 EL Nudelwasser vermengen, bis alles cremig ist."])

R("aglio-olio", "Spaghetti Aglio, Olio e Peperoncino", "🧄", "Italienisch", 2, "ca. 15 Min.",
  ["200 g|Spaghetti", "4|Knoblauchzehen, in dünnen Scheiben", "1–2|getrocknete Peperoncini", "80 ml|Olivenöl",
   "1 Bund|Petersilie, gehackt"],
  ["Spaghetti in gesalzenem Wasser kochen. @9",
   "Öl mit Knoblauch und Peperoncino bei kleiner Hitze erwärmen, bis der Knoblauch hellgolden ist. Er darf nicht braun werden. @4",
   "Nudeln mit einer Kelle Nudelwasser in die Pfanne geben.",
   "Kräftig schwenken, bis eine leicht sämige Sauce entsteht.",
   "Petersilie unterheben."])

R("minestrone", "Minestrone", "🥣", "Italienisch", 4, "ca. 1 Std.",
  ["1|Zwiebel", "2|Karotten", "2|Stangen Sellerie", "1|Zucchini", "2|Kartoffeln", "150 g|grüne Bohnen",
   "400 g|stückige Tomaten", "1 Dose (400 g)|Borlotti- oder weiße Bohnen", "1,2 l|Gemüsebrühe", "80 g|kleine Nudeln (Ditalini)",
   "1|Parmesanrinde (optional)", "3 EL|Olivenöl", "Parmesan und Basilikum|zum Servieren"],
  ["Alles Gemüse in kleine Würfel schneiden.",
   "Zwiebel, Karotten und Sellerie in Olivenöl weich dünsten. @8",
   "Kartoffeln, Zucchini, grüne Bohnen, Tomaten, Brühe und Parmesanrinde zugeben und köcheln. @25",
   "Bohnen und Nudeln zugeben und weiterköcheln, bis die Nudeln gar sind. @10",
   "Rinde entfernen, mit Salz und Pfeffer abschmecken, mit Parmesan, Basilikum und einem Schuss Olivenöl servieren."])

R("tiramisu", "Tiramisu", "☕", "Italienisch", 6, "ca. 30 Min. (plus 6 Std. Kühlen)",
  ["4|sehr frische Eier", "100 g|Zucker", "500 g|Mascarpone", "300 ml|starker Espresso, abgekühlt", "2 EL|Amaretto (optional)",
   "200 g|Löffelbiskuits", "2 EL|Kakaopulver"],
  ["Eier trennen. Eigelbe mit Zucker hell und cremig aufschlagen. @5",
   "Mascarpone unterrühren.",
   "Eiweiß steif schlagen und vorsichtig unterheben.",
   "Espresso mit Amaretto mischen. Biskuits nur kurz eintauchen, damit sie nicht durchweichen.",
   "Abwechselnd Biskuits und Creme in eine Form schichten, mit Creme abschließen.",
   "Abgedeckt kühlen, am besten über Nacht. @360",
   "Vor dem Servieren mit Kakao bestäuben."])

R("saltimbocca", "Saltimbocca alla Romana", "🥩", "Italienisch", 2, "ca. 20 Min.",
  ["4|dünne Kalbsschnitzel (je ca. 80 g)", "4|Scheiben Parmaschinken", "4|Salbeiblätter", "2 EL|Mehl",
   "30 g|Butter", "1 EL|Olivenöl", "100 ml|trockener Weißwein"],
  ["Schnitzel zwischen Frischhaltefolie dünn klopfen.",
   "Jedes mit einer Scheibe Schinken und einem Salbeiblatt belegen und mit einem Zahnstocher feststecken.",
   "Auf der Unterseite leicht mehlieren.",
   "Butter und Öl erhitzen, Schnitzel zuerst auf der Schinkenseite braten, dann wenden. @3",
   "Mit Wein ablöschen, kurz einkochen und die Sauce über das Fleisch geben. @2"])

R("penne-arrabbiata", "Penne all'Arrabbiata", "🌶", "Italienisch", 2, "ca. 25 Min.",
  ["200 g|Penne", "400 g|geschälte Tomaten (Dose)", "3|Knoblauchzehen", "2|getrocknete Chilis", "3 EL|Olivenöl",
   "1 Bund|Petersilie", "Pecorino|zum Servieren"],
  ["Knoblauch in Scheiben schneiden und mit zerbröselten Chilis im Öl anschwitzen, ohne dass er braun wird. @2",
   "Tomaten zerdrücken, zugeben, salzen und köcheln lassen. @15",
   "Penne kochen. @11",
   "Penne mit etwas Nudelwasser in der Sauce schwenken.",
   "Mit Petersilie und Pecorino servieren."])

R("gnocchi-salbeibutter", "Kartoffelgnocchi in Salbeibutter", "🥔", "Italienisch", 2, "ca. 1 Std. 15 Min.",
  ["500 g|mehligkochende Kartoffeln", "150 g|Mehl", "1|Eigelb", "1 Prise|Muskat", "60 g|Butter", "8|Salbeiblätter",
   "40 g|Parmesan"],
  ["Kartoffeln mit Schale weich kochen. @25",
   "Pellen und noch heiß durch eine Presse drücken, ausdampfen lassen. @10",
   "Mit Mehl, Eigelb, Salz und Muskat rasch zu einem glatten Teig verkneten. Nicht zu lange kneten, sonst werden sie zäh.",
   "Teig zu daumendicken Rollen formen und 2 cm lange Stücke abschneiden.",
   "In siedendem Salzwasser garen, bis sie oben schwimmen, dann herausheben. @3",
   "Butter mit Salbei aufschäumen lassen, bis sie nussig duftet, Gnocchi darin schwenken. @3",
   "Mit Parmesan servieren."])

# ---------------- Deutsch ----------------
R("wiener-schnitzel", "Wiener Schnitzel mit Kartoffelsalat", "🥩", "Deutsch", 2, "ca. 1 Std.",
  ["2|Kalbsschnitzel (je 150 g)", "2 EL|Mehl", "1|Ei", "60 g|Semmelbrösel", "100 g|Butterschmalz", "1|Zitrone",
   "#Kartoffelsalat", "500 g|festkochende Kartoffeln", "1|Zwiebel", "150 ml|heiße Brühe", "3 EL|Weißweinessig",
   "1 TL|Senf", "3 EL|Öl", "1 Bund|Schnittlauch"],
  ["Kartoffeln mit Schale kochen. @20",
   "Zwiebel fein würfeln, mit Brühe, Essig, Senf, Salz und Pfeffer aufkochen.",
   "Kartoffeln pellen, warm in Scheiben schneiden und mit dem heißen Sud übergießen. Öl unterheben und ziehen lassen. @30",
   "Schnitzel dünn klopfen, salzen, in Mehl, verquirltem Ei und Bröseln wenden. Panade nicht andrücken.",
   "Butterschmalz reichlich erhitzen und die Schnitzel schwimmend ausbacken, dabei die Pfanne schwenken, damit die Panade Wellen schlägt. @4",
   "Auf Küchenpapier abtropfen lassen. Mit Zitrone und dem Salat (mit Schnittlauch) servieren."])

R("kaesespaetzle", "Allgäuer Kässpatzen", "🧀", "Deutsch", 2, "ca. 45 Min.",
  ["250 g|Mehl", "3|Eier", "100 ml|Wasser", "1 TL|Salz", "200 g|Bergkäse, gerieben", "2|Zwiebeln", "30 g|Butter",
   "1 Bund|Schnittlauch"],
  ["Mehl, Eier, Wasser und Salz zu einem zähen Teig schlagen, bis er Blasen wirft. @5",
   "Teig ruhen lassen. @15",
   "Zwiebeln in Ringe schneiden und in Butter langsam goldbraun braten. @15",
   "Teig portionsweise in kochendes Salzwasser schaben oder pressen. Sobald die Spätzle oben schwimmen, abschöpfen.",
   "Lagenweise mit Käse in eine Airfryer-geeignete Form schichten und bei 160 °C kurz überbacken, bis der Käse schmilzt. @4",
   "Mit Röstzwiebeln und Schnittlauch servieren."], airfryer=True)

R("rinderrouladen", "Rinderrouladen", "🥩", "Deutsch", 4, "ca. 2 Std. 15 Min.",
  ["4|Rinderrouladen", "2 EL|mittelscharfer Senf", "4|Scheiben Speck", "2|Gewürzgurken", "2|Zwiebeln", "1|Karotte",
   "100 g|Sellerie", "1 EL|Tomatenmark", "250 ml|Rotwein", "500 ml|Rinderbrühe", "2 EL|Öl", "1 EL|Speisestärke"],
  ["Rouladen ausbreiten, salzen, pfeffern und mit Senf bestreichen.",
   "Je eine Scheibe Speck, Gurkenstreifen und Zwiebelstreifen darauflegen, aufrollen und mit Rouladennadeln feststecken.",
   "Rouladen in Öl rundum kräftig anbraten und herausnehmen. @8",
   "Gemüse würfeln und im Bratfett anrösten, Tomatenmark mitrösten. @5",
   "Mit Wein ablöschen, Brühe zugeben, Rouladen hineinlegen und zugedeckt schmoren. @90",
   "Rouladen herausnehmen, Sauce passieren und mit Stärke binden.",
   "Dazu passen Rotkohl und Kartoffelklöße."])

R("schweinebraten", "Bayerischer Schweinebraten", "🍖", "Deutsch", 3, "ca. 2 Std.",
  ["1 kg|Schweineschulter mit Schwarte", "2|Zwiebeln", "2|Karotten", "1 TL|Kümmel", "1 TL|grobes Salz", "330 ml|dunkles Bier",
   "300 ml|Brühe", "1 EL|Speisestärke", "1|Airfryer-geeignete Form, in die der Braten passt"],
  ["Schwarte rautenförmig einschneiden, ohne ins Fleisch zu schneiden.",
   "Fleisch rundum mit Salz, Pfeffer und Kümmel einreiben.",
   "Mit der Schwarte nach unten in die Form legen, 100 ml Wasser angießen und im Airfryer bei 160 °C garen. Warum Schwarte nach unten: Sie weicht auf und poppt später besser auf. @30",
   "Wenden, die Schwarte kräftig mit grobem Salz einreiben und bei 160 °C weitergaren, bis das Fleisch innen ca. 75 °C hat. @45",
   "Währenddessen die Sauce im Topf ansetzen: Zwiebeln und Karotten grob gewürfelt anrösten, mit Bier und Brühe ablöschen und köcheln lassen. @30",
   "Für die Kruste auf 200 °C stellen, bis die Schwarte aufpoppt. Nicht aus den Augen lassen. @12",
   "Bratensaft aus der Form zur Sauce geben, abseihen und leicht binden. Braten kurz ruhen lassen. Mit Knödeln und Krautsalat servieren. @10"], airfryer=True)

R("kartoffelsuppe", "Kartoffelsuppe mit Würstchen", "🥣", "Deutsch", 4, "ca. 45 Min.",
  ["800 g|mehligkochende Kartoffeln", "1|Bund Suppengrün", "1|Zwiebel", "1 l|Gemüsebrühe", "100 ml|Sahne",
   "1 TL|Majoran", "1 Prise|Muskat", "4|Wiener Würstchen", "1 Bund|Petersilie"],
  ["Kartoffeln, Suppengrün und Zwiebel würfeln.",
   "Zwiebel in etwas Butter andünsten, Gemüse zugeben und kurz mitdünsten. @5",
   "Brühe angießen und köcheln, bis die Kartoffeln weich sind. @20",
   "Etwa die Hälfte grob pürieren, damit die Suppe sämig wird.",
   "Sahne, Majoran, Muskat, Salz und Pfeffer zugeben.",
   "Würstchen in Scheiben schneiden und in der Suppe erwärmen. @5",
   "Mit Petersilie servieren."])

R("reibekuchen", "Reibekuchen mit Apfelmus", "🥔", "Deutsch", 4, "ca. 40 Min.",
  ["1 kg|festkochende Kartoffeln", "1|Zwiebel", "2|Eier", "3 EL|Mehl", "1 TL|Salz", "100 ml|Öl zum Braten",
   "400 g|Apfelmus"],
  ["Kartoffeln schälen und mit der Zwiebel fein reiben.",
   "Masse in einem Tuch kräftig ausdrücken. Warum: Weniger Wasser = knusprigere Puffer.",
   "Mit Eiern, Mehl und Salz vermengen.",
   "Öl erhitzen, je 2 EL Masse flach drücken und pro Seite goldbraun braten. @4",
   "Auf Küchenpapier abtropfen. Vor dem Servieren alle zusammen im Airfryer bei 180 °C wieder aufknuspern. @3",
   "Mit Apfelmus servieren."], airfryer=True)

R("frikadellen", "Frikadellen mit Kartoffelpüree", "🍔", "Deutsch", 4, "ca. 50 Min.",
  ["500 g|gemischtes Hack", "1|altbackenes Brötchen", "1|Zwiebel", "1|Ei", "1 TL|Senf", "1 TL|Paprika edelsüß",
   "#Püree", "1 kg|mehligkochende Kartoffeln", "200 ml|Milch", "40 g|Butter", "1 Prise|Muskat"],
  ["Brötchen in Wasser einweichen und gut ausdrücken. @10",
   "Kartoffeln schälen und in Salzwasser weich kochen. @20",
   "Hack mit Brötchen, fein gewürfelter Zwiebel, Ei, Senf, Paprika, Salz und Pfeffer verkneten.",
   "Mit feuchten Händen 8 Frikadellen formen.",
   "In Öl bei mittlerer Hitze von beiden Seiten braten, bis sie durch sind. @12",
   "Kartoffeln abgießen, mit warmer Milch und Butter stampfen, mit Muskat und Salz würzen."])

R("rindergulasch", "Rindergulasch", "🍲", "Deutsch", 4, "ca. 2 Std. 30 Min.",
  ["1 kg|Rindergulasch (Wade oder Schulter)", "800 g|Zwiebeln", "2 EL|Tomatenmark", "2 EL|Paprika edelsüß",
   "1 TL|Paprika scharf", "1 TL|Kümmel, gemahlen", "1 TL|Majoran", "2|Knoblauchzehen", "1 EL|Essig",
   "750 ml|Rinderbrühe", "3 EL|Butterschmalz"],
  ["Zwiebeln in Streifen schneiden und im Schmalz langsam goldbraun schmoren. Warum so viele: Sie binden später die Sauce. @20",
   "Tomatenmark kurz mitrösten, Topf vom Herd nehmen und das Paprikapulver einrühren (es verbrennt sonst leicht).",
   "Mit Essig ablöschen, Fleisch, Kümmel, Majoran und Knoblauch zugeben.",
   "Brühe angießen und zugedeckt sanft schmoren, bis das Fleisch zart ist. @120",
   "Mit Salz und Pfeffer abschmecken. Dazu passen Semmelknödel oder Spätzle."])

R("linseneintopf", "Linseneintopf", "🥣", "Deutsch", 4, "ca. 1 Std.",
  ["250 g|Tellerlinsen", "1|Bund Suppengrün", "1|Zwiebel", "300 g|Kartoffeln", "100 g|Speck, gewürfelt",
   "1,2 l|Gemüsebrühe", "2|Lorbeerblätter", "4|Wiener Würstchen", "2 EL|Essig", "1 TL|Zucker"],
  ["Speck im Topf auslassen, Zwiebel und gewürfeltes Suppengrün darin andünsten. @6",
   "Linsen, Brühe und Lorbeer zugeben und köcheln. @20",
   "Kartoffeln würfeln, zugeben und weiterköcheln, bis alles weich ist. @20",
   "Würstchen in Scheiben darin erwärmen. @5",
   "Mit Essig, Zucker, Salz und Pfeffer süß-sauer abschmecken."])

R("kaiserschmarrn", "Kaiserschmarrn", "🥞", "Deutsch", 2, "ca. 30 Min.",
  ["4|Eier", "125 g|Mehl", "250 ml|Milch", "2 EL|Zucker", "1 Prise|Salz", "40 g|Rosinen (optional)", "30 g|Butter",
   "2 EL|Puderzucker", "300 g|Zwetschgenröster oder Apfelmus"],
  ["Eier trennen. Eigelbe mit Mehl, Milch und Salz glatt rühren.",
   "Eiweiß mit Zucker steif schlagen und locker unterheben.",
   "Butter in einer großen Pfanne schmelzen, Teig hineingeben, Rosinen darüberstreuen.",
   "Bei mittlerer Hitze stocken lassen, bis die Unterseite goldbraun ist. @5",
   "Vierteln, wenden und mit zwei Gabeln in Stücke reißen.",
   "Etwas Puderzucker darüberstreuen und unter Wenden karamellisieren lassen. @3",
   "Mit Puderzucker und Zwetschgenröster servieren."])

R("apfelkuchen", "Versunkener Apfelkuchen", "🍎", "Deutsch", 6, "ca. 1 Std.",
  ["65 g|weiche Butter", "65 g|Zucker", "½ Päckchen|Vanillezucker", "2|kleine Eier", "100 g|Mehl", "1 TL|Backpulver",
   "2 EL|Milch", "2|säuerliche Äpfel", "½|Zitrone", "1 EL|Puderzucker", "1|kleine Springform oder Kuchenform (16–18 cm)"],
  ["Form fetten. Warum kleiner als üblich: Sie muss in den Airfryer-Korb passen.",
   "Butter, Zucker und Vanillezucker cremig rühren, Eier einzeln unterrühren. @4",
   "Mehl mit Backpulver mischen und mit der Milch unterrühren.",
   "Äpfel schälen, vierteln, Kerngehäuse entfernen und die Rücken mehrmals einschneiden. Mit Zitronensaft beträufeln.",
   "Teig in die Form streichen, Äpfel mit der Rundung nach oben hineindrücken.",
   "Im Airfryer bei 150 °C backen. Bräunt die Oberfläche zu schnell, mit Alufolie abdecken. Fertig, wenn ein Holzstäbchen sauber herauskommt. @35",
   "Abkühlen lassen und mit Puderzucker bestäuben."], airfryer=True)

R("obatzda", "Obatzda mit Brezn", "🥨", "Deutsch", 4, "ca. 15 Min. (plus Ziehen)",
  ["200 g|reifer Camembert", "50 g|weiche Butter", "100 g|Frischkäse", "1|kleine Zwiebel, sehr fein gewürfelt",
   "1 TL|Paprika edelsüß", "½ TL|Kümmel, gemahlen", "2 EL|Weißbier (optional)", "1 Bund|Schnittlauch", "4|Brezn",
   "4|Radieschen"],
  ["Camembert mit einer Gabel klein drücken.",
   "Mit Butter, Frischkäse und Bier cremig vermengen, grobe Stücke dürfen bleiben.",
   "Zwiebel, Paprika, Kümmel, Salz und Pfeffer unterrühren.",
   "Abgedeckt kühl durchziehen lassen. @30",
   "Mit Schnittlauch, Radieschen und frischen Brezn servieren."])

# ---------------- Französisch ----------------
R("ratatouille", "Ratatouille", "🍆", "Französisch", 4, "ca. 1 Std.",
  ["1|Aubergine", "2|Zucchini", "2|Paprika (rot, gelb)", "1|Zwiebel", "3|Knoblauchzehen", "400 g|Tomaten",
   "1 TL|Kräuter der Provence", "5 EL|Olivenöl", "1 Bund|Basilikum"],
  ["Gemüse in 2 cm Würfel schneiden.",
   "Aubergine in 2 EL Öl anbraten und herausnehmen. Warum getrennt: Jedes Gemüse behält so seinen Biss. @6",
   "Zucchini und Paprika ebenfalls nacheinander anbraten. @6",
   "Zwiebel und Knoblauch im restlichen Öl andünsten, Tomaten und Kräuter zugeben. @5",
   "Alles Gemüse zurück in den Topf geben und sanft schmoren. @25",
   "Mit Salz, Pfeffer und Basilikum abschmecken."])

R("quiche-lorraine", "Quiche Lorraine", "🥧", "Französisch", 3, "ca. 1 Std. 20 Min.",
  ["#Mürbeteig", "120 g|Mehl", "60 g|kalte Butter", "1|Eigelb", "1 Prise|Salz", "#Füllung", "100 g|Speck, gewürfelt",
   "2|Eier", "120 ml|Sahne", "50 ml|Milch", "60 g|Gruyère, gerieben", "1 Prise|Muskat", "#Außerdem", "1|Tarteform (18–20 cm)"],
  ["Mehl, Butterwürfel, Ei, Salz und 1–2 EL kaltes Wasser rasch zu einem Teig verkneten und kühlen. @30",
   "Teig ausrollen, in die Form legen, mit einer Gabel einstechen und mit Backpapier und Hülsenfrüchten beschwert im Airfryer bei 170 °C blind backen. Warum beschweren: Sonst bläht sich der Boden auf. @10",
   "Speck in einer Pfanne knusprig braten. @5",
   "Eier, Sahne, Milch, Muskat und Pfeffer verquirlen.",
   "Speck und Käse auf dem Boden verteilen, Eiermasse darübergießen.",
   "Im Airfryer bei 150 °C backen, bis die Füllung gestockt und goldbraun ist. @25"], airfryer=True)

R("coq-au-vin", "Coq au Vin", "🍷", "Französisch", 4, "ca. 2 Std.",
  ["1,2 kg|Hähnchenteile (Keulen)", "150 g|Speck, gewürfelt", "200 g|Champignons", "12|Perlzwiebeln oder Schalotten",
   "2|Knoblauchzehen", "2 EL|Mehl", "500 ml|kräftiger Rotwein", "200 ml|Hühnerbrühe", "2|Lorbeerblätter",
   "3|Zweige Thymian", "30 g|Butter"],
  ["Hähnchen salzen und pfeffern. Speck im Bräter auslassen und herausnehmen. @4",
   "Hähnchen im Fett rundum goldbraun anbraten und herausnehmen. @10",
   "Zwiebeln und Pilze anbraten, Knoblauch zugeben. @5",
   "Mehl darüberstäuben, kurz anschwitzen, dann mit Wein und Brühe ablöschen.",
   "Hähnchen, Speck und Kräuter zurückgeben und zugedeckt schmoren. @75",
   "Sauce bei Bedarf einkochen und mit der Butter verfeinern. Dazu Baguette oder Kartoffeln."])

R("crepes", "Crêpes", "🥞", "Französisch", 4, "ca. 45 Min.",
  ["250 g|Mehl", "4|Eier", "500 ml|Milch", "1 EL|Zucker", "1 Prise|Salz", "50 g|geschmolzene Butter",
   "Zucker, Zitrone, Nutella oder Marmelade|zum Füllen"],
  ["Mehl, Zucker und Salz mischen, Eier und nach und nach die Milch einrühren, bis ein glatter Teig entsteht.",
   "Butter unterrühren und den Teig ruhen lassen. Warum ruhen: Das Mehl quillt, die Crêpes reißen nicht. @30",
   "Eine beschichtete Pfanne leicht fetten und heiß werden lassen.",
   "Eine kleine Kelle Teig hineingeben und durch Schwenken dünn verteilen.",
   "Backen, bis der Rand sich löst, wenden und kurz weiterbacken. @2",
   "Nach Belieben füllen und falten."])

R("zwiebelsuppe", "Französische Zwiebelsuppe", "🧅", "Französisch", 4, "ca. 1 Std. 15 Min.",
  ["1 kg|Zwiebeln", "50 g|Butter", "1 TL|Zucker", "1 EL|Mehl", "150 ml|trockener Weißwein", "1,2 l|Rinderbrühe",
   "2|Zweige Thymian", "8|Scheiben Baguette", "150 g|Gruyère, gerieben"],
  ["Zwiebeln in feine Ringe schneiden.",
   "In Butter mit dem Zucker bei mittlerer Hitze langsam tief goldbraun karamellisieren, regelmäßig rühren. @40",
   "Mehl darüberstäuben und kurz anschwitzen, mit Wein ablöschen.",
   "Brühe und Thymian zugeben und köcheln. @20",
   "Baguettescheiben mit Käse belegen und im Airfryer bei 200 °C überbacken, bis der Käse blubbert. @4",
   "Suppe in Schalen füllen und die Käsebrote darauflegen."], airfryer=True)
