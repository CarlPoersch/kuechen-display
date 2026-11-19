# Chinesisch, Thailändisch, Japanisch
# Format: R(id, Titel, Icon, Küche, Portionen, Zeit, Zutaten, Schritte)
# Zutat "Menge|Name", Gruppe "#Name", Schritt "Text @Minuten" (Timer)
from gen import R

R("kung-pao-haehnchen", "Kung-Pao-Hähnchen", "🌶", "Chinesisch", 2, "ca. 30 Min.",
  ["#Hähnchen", "350 g|Hähnchenbrust, gewürfelt", "1 EL|Sojasauce", "1 TL|Speisestärke",
   "#Sauce", "2 EL|Sojasauce", "1 EL|schwarzer Reisessig", "1 TL|Zucker", "1 TL|Speisestärke", "50 ml|Wasser",
   "#Pfanne", "2 EL|neutrales Öl", "8|getrocknete Chilischoten", "1 TL|Sichuanpfeffer", "2|Knoblauchzehen, gehackt",
   "1 Stück (2 cm)|Ingwer, gehackt", "3|Frühlingszwiebeln, in Stücken", "60 g|geröstete Erdnüsse", "150 g|Reis zum Servieren"],
  ["Hähnchen mit Sojasauce und Stärke vermischen und kurz ziehen lassen. @10",
   "Reis nach Packungsangabe kochen. @15",
   "Alle Zutaten für die Sauce verrühren.",
   "Öl im Wok stark erhitzen, Chili und Sichuanpfeffer 30 Sekunden anrösten, ohne dass sie schwarz werden.",
   "Hähnchen zugeben und 4–5 Minuten braten, bis es fast gar ist. @5",
   "Knoblauch, Ingwer und Frühlingszwiebeln 1 Minute mitbraten.",
   "Sauce einrühren, kurz aufkochen lassen, bis sie glänzt. Erdnüsse unterheben und mit Reis servieren."])

R("mapo-tofu", "Mapo Tofu", "🥘", "Chinesisch", 2, "ca. 25 Min.",
  ["400 g|Seidentofu oder weicher Tofu", "150 g|Hackfleisch (Schwein oder Rind)", "2 EL|Doubanjiang (Chili-Bohnenpaste)",
   "1 EL|fermentierte schwarze Bohnen (optional)", "2|Knoblauchzehen, gehackt", "1 TL|Ingwer, gehackt",
   "200 ml|Brühe", "1 EL|Sojasauce", "1 TL|Speisestärke in 2 EL Wasser", "1 TL|Sichuanpfeffer, gemahlen",
   "2|Frühlingszwiebeln, in Ringen", "2 EL|neutrales Öl", "150 g|Reis zum Servieren"],
  ["Reis kochen. @15",
   "Tofu in 2 cm große Würfel schneiden und 2 Minuten in leicht gesalzenem Wasser ziehen lassen, dann abgießen. @2",
   "Öl erhitzen, Hackfleisch krümelig und knusprig braten. @4",
   "Doubanjiang, schwarze Bohnen, Knoblauch und Ingwer 1 Minute mitbraten, bis das Öl rot wird.",
   "Brühe und Sojasauce angießen, Tofu vorsichtig hineingeben und 5 Minuten köcheln. @5",
   "Mit Stärke binden, mit Sichuanpfeffer und Frühlingszwiebeln bestreuen und mit Reis servieren."])

R("gebratener-reis", "Gebratener Eierreis", "🍚", "Chinesisch", 2, "ca. 20 Min.",
  ["400 g|gekochter Reis vom Vortag", "3|Eier", "100 g|Erbsen (TK)", "1|Karotte, fein gewürfelt",
   "3|Frühlingszwiebeln, in Ringen", "2|Knoblauchzehen, gehackt", "2 EL|Sojasauce", "1 TL|Sesamöl",
   "2 EL|neutrales Öl", "1 Prise|weißer Pfeffer"],
  ["Den Reis mit den Händen lockern, damit keine Klumpen entstehen. Warum Reis vom Vortag: Er ist trockener und wird nicht matschig.",
   "1 EL Öl im Wok erhitzen, Eier verquirlen, darin stocken lassen und herausnehmen.",
   "Restliches Öl erhitzen, Karotte und Knoblauch 2 Minuten braten. @2",
   "Reis zugeben und bei starker Hitze 4–5 Minuten braten, dabei immer wieder wenden. @5",
   "Erbsen, Ei, Sojasauce und Pfeffer untermischen und 2 Minuten weiterbraten. @2",
   "Mit Sesamöl und Frühlingszwiebeln abschmecken."])

R("chow-mein", "Chow Mein mit Gemüse", "🍜", "Chinesisch", 2, "ca. 25 Min.",
  ["250 g|Mie-Nudeln", "1|Paprika, in Streifen", "1|Karotte, in Streifen", "150 g|Weißkohl oder Chinakohl, in Streifen",
   "100 g|Sojasprossen", "2|Knoblauchzehen", "#Sauce", "2 EL|Sojasauce", "1 EL|dunkle Sojasauce", "1 EL|Austernsauce",
   "1 TL|Zucker", "1 TL|Sesamöl", "#Pfanne", "2 EL|neutrales Öl"],
  ["Nudeln nach Packung kochen, abschrecken und mit etwas Öl vermischen. @4",
   "Saucenzutaten verrühren.",
   "Öl im Wok stark erhitzen, Knoblauch, Karotte und Paprika 2 Minuten braten. @2",
   "Kohl zugeben und 2 Minuten weiterbraten. @2",
   "Nudeln und Sauce zugeben und 2–3 Minuten unter Wenden braten, bis die Nudeln Farbe annehmen. @3",
   "Sojasprossen unterheben und sofort servieren."])

R("suess-sauer-schwein", "Schweinefleisch süß-sauer", "🍍", "Chinesisch", 2, "ca. 40 Min.",
  ["350 g|Schweinenacken, gewürfelt", "1|Ei", "4 EL|Speisestärke", "1|Paprika, gewürfelt", "1|Zwiebel, in Spalten",
   "150 g|Ananas, gewürfelt", "#Sauce", "4 EL|Ketchup", "3 EL|Reisessig", "3 EL|Zucker", "1 EL|Sojasauce",
   "100 ml|Ananassaft", "1 TL|Speisestärke", "#Zum Frittieren", "500 ml|neutrales Öl", "150 g|Reis zum Servieren"],
  ["Reis kochen. @15",
   "Fleisch mit Ei vermischen und in Stärke wenden.",
   "Öl in einem Topf auf ca. 170 °C erhitzen und das Fleisch portionsweise 4–5 Minuten goldbraun frittieren. Auf Küchenpapier abtropfen. @5",
   "Saucenzutaten verrühren.",
   "2 EL Öl in einer Pfanne erhitzen, Zwiebel und Paprika 2 Minuten braten. @2",
   "Ananas und Sauce zugeben und aufkochen, bis die Sauce andickt. @2",
   "Fleisch kurz in der Sauce schwenken und sofort mit Reis servieren, damit es knusprig bleibt."])

R("dan-dan-nudeln", "Dan-Dan-Nudeln", "🍜", "Chinesisch", 2, "ca. 25 Min.",
  ["200 g|Weizennudeln", "150 g|Schweinehack", "1 EL|Sojasauce", "1 TL|Shaoxing-Wein (optional)",
   "#Sauce", "2 EL|Sesampaste (Tahin)", "2 EL|Chiliöl", "2 EL|Sojasauce", "1 EL|schwarzer Reisessig",
   "1 TL|Zucker", "½ TL|Sichuanpfeffer, gemahlen", "1|Knoblauchzehe, gepresst",
   "#Dazu", "150 g|Pak Choi", "2|Frühlingszwiebeln", "2 EL|geröstete Erdnüsse, gehackt"],
  ["Saucenzutaten in zwei Schalen aufteilen und verrühren.",
   "Hack in wenig Öl krümelig braten, mit Sojasauce und Wein ablöschen, bis es knusprig ist. @6",
   "Nudeln nach Packung kochen, Pak Choi in der letzten Minute mitgaren. @5",
   "Nudeln mit etwas Kochwasser in die Schalen geben und gut mit der Sauce mischen.",
   "Hack, Pak Choi, Frühlingszwiebeln und Erdnüsse darauf verteilen."])

R("jiaozi", "Jiaozi (gefüllte Teigtaschen)", "🥟", "Chinesisch", 4, "ca. 1 Std. 15 Min.",
  ["#Teig", "300 g|Weizenmehl", "150 ml|Wasser, kalt", "#Füllung", "300 g|Schweinehack", "150 g|Chinakohl, fein gehackt",
   "1 TL|Salz", "2|Frühlingszwiebeln, fein", "1 TL|Ingwer, gerieben", "2 EL|Sojasauce", "1 TL|Sesamöl",
   "#Dip", "3 EL|schwarzer Reisessig", "1 EL|Sojasauce", "1 TL|Chiliöl"],
  ["Mehl und Wasser 8 Minuten zu einem glatten Teig kneten. @8",
   "Abgedeckt ruhen lassen. @30",
   "Chinakohl mit Salz mischen, 10 Minuten ziehen lassen und kräftig ausdrücken. @10",
   "Kohl mit allen übrigen Füllungszutaten verkneten.",
   "Teig zu einer Rolle formen, in ca. 30 Stücke teilen und jedes zu einem dünnen Kreis (ca. 8 cm) ausrollen.",
   "Je 1 TL Füllung daraufgeben, zu Halbmonden falten und den Rand fest zusammendrücken.",
   "In kochendem Wasser garen, bis sie oben schwimmen, dann noch 2 Minuten ziehen lassen. @6",
   "Dip verrühren und dazu servieren."])

R("tomaten-ei", "Tomaten mit Rührei (Fanqie Chao Dan)", "🍅", "Chinesisch", 2, "ca. 15 Min.",
  ["4|Eier", "3|Tomaten, in Spalten", "2|Frühlingszwiebeln", "1 EL|Ketchup", "1 TL|Zucker", "½ TL|Salz",
   "2 EL|neutrales Öl", "150 g|Reis zum Servieren"],
  ["Reis kochen. @15",
   "Eier mit einer Prise Salz verquirlen. In 1 EL Öl locker stocken lassen und herausnehmen.",
   "Restliches Öl erhitzen, Tomaten 3 Minuten braten, bis sie Saft ziehen. @3",
   "Ketchup, Zucker und Salz zugeben und 1 Minute köcheln.",
   "Ei zurück in die Pfanne geben, kurz durchschwenken, mit Frühlingszwiebeln bestreuen und auf Reis servieren."])

R("rind-brokkoli", "Rindfleisch mit Brokkoli", "🥦", "Chinesisch", 2, "ca. 30 Min.",
  ["300 g|Rindersteak (Hüfte), in dünnen Streifen", "1 EL|Sojasauce", "1 TL|Speisestärke", "300 g|Brokkoli, in Röschen",
   "2|Knoblauchzehen", "1 TL|Ingwer, gerieben", "#Sauce", "3 EL|Austernsauce", "1 EL|Sojasauce", "1 TL|Zucker",
   "100 ml|Wasser", "1 TL|Speisestärke", "#Pfanne", "2 EL|neutrales Öl", "150 g|Reis zum Servieren"],
  ["Rindfleisch mit Sojasauce und Stärke mischen. Warum Stärke: Sie schützt das Fleisch und hält es saftig. @10",
   "Reis kochen. @15",
   "Brokkoli 2 Minuten blanchieren und abtropfen lassen. @2",
   "Öl im Wok stark erhitzen, Fleisch 1–2 Minuten scharf anbraten und herausnehmen. @2",
   "Knoblauch und Ingwer kurz anbraten, Brokkoli zugeben.",
   "Sauce einrühren, aufkochen lassen, Fleisch zurückgeben und 1 Minute schwenken."])

R("hong-shao-rou", "Rot geschmorter Schweinebauch", "🍖", "Chinesisch", 4, "ca. 2 Std.",
  ["600 g|Schweinebauch ohne Schwarte, in 3 cm Würfeln", "2 EL|Zucker", "3 EL|helle Sojasauce", "2 EL|dunkle Sojasauce",
   "3 EL|Shaoxing-Wein", "1 Stück (3 cm)|Ingwer, in Scheiben", "3|Frühlingszwiebeln", "2|Sternanis",
   "1|Zimtstange", "500 ml|Wasser", "300 g|Reis zum Servieren"],
  ["Fleisch in kaltem Wasser aufsetzen, 3 Minuten kochen und abgießen. Warum: So werden Trübstoffe entfernt. @3",
   "Zucker in einem Topf mit 1 EL Öl hellbraun karamellisieren lassen.",
   "Fleisch zugeben und rundum im Karamell wenden.",
   "Wein, beide Sojasaucen, Gewürze, Ingwer und Wasser zugeben.",
   "Zugedeckt bei kleiner Hitze schmoren. @90",
   "Deckel abnehmen und die Sauce bei starker Hitze sirupartig einkochen. @10",
   "Mit Reis servieren."])

R("suan-la-tang", "Scharf-saure Suppe", "🥣", "Chinesisch", 4, "ca. 35 Min.",
  ["1 l|Hühnerbrühe", "150 g|Schweinefleisch, in feinen Streifen", "5|getrocknete Shiitake-Pilze",
   "200 g|fester Tofu, in Streifen", "100 g|Bambussprossen, in Streifen", "4 EL|schwarzer Reisessig",
   "3 EL|Sojasauce", "1 TL|weißer Pfeffer", "2 EL|Speisestärke in 4 EL Wasser", "1|Ei, verquirlt",
   "2|Frühlingszwiebeln", "1 TL|Chiliöl"],
  ["Pilze in heißem Wasser einweichen, dann in Streifen schneiden. @20",
   "Brühe mit Pilzen, Fleisch und Bambus aufkochen und 5 Minuten köcheln. @5",
   "Tofu, Essig, Sojasauce und Pfeffer zugeben und 2 Minuten köcheln. @2",
   "Mit der Stärke binden.",
   "Das Ei in dünnem Strahl unter Rühren einlaufen lassen.",
   "Mit Frühlingszwiebeln und Chiliöl servieren. Mit Essig und Pfeffer abschmecken: Sie soll deutlich scharf und sauer sein."])

# ---------------- Thailändisch ----------------
R("pad-thai", "Pad Thai mit Garnelen", "🍤", "Thailändisch", 2, "ca. 30 Min.",
  ["150 g|Reisbandnudeln (5 mm)", "200 g|Garnelen", "2|Eier", "100 g|Sojasprossen", "3|Frühlingszwiebeln",
   "2|Knoblauchzehen", "#Sauce", "3 EL|Tamarindenpaste", "2 EL|Fischsauce", "2 EL|brauner Zucker",
   "#Dazu", "40 g|Erdnüsse, gehackt", "1|Limette", "1 TL|Chiliflocken", "2 EL|neutrales Öl"],
  ["Nudeln in lauwarmem Wasser einweichen, bis sie biegsam sind. @25",
   "Sauce verrühren, bis der Zucker gelöst ist.",
   "Öl im Wok erhitzen, Knoblauch und Garnelen 2 Minuten braten und an den Rand schieben. @2",
   "Eier in den Wok schlagen und verrühren, bis sie fast gestockt sind.",
   "Nudeln und Sauce zugeben und 3 Minuten braten, bis die Nudeln weich sind. Bei Bedarf einen Schuss Wasser zugeben. @3",
   "Sprossen und Frühlingszwiebeln unterheben. Mit Erdnüssen, Chili und Limettenspalten servieren."])

R("gruenes-curry", "Grünes Curry mit Hähnchen", "🍛", "Thailändisch", 2, "ca. 30 Min.",
  ["300 g|Hähnchenbrust, in Streifen", "2 EL|grüne Currypaste", "400 ml|Kokosmilch", "1|Aubergine oder 150 g Thai-Auberginen",
   "100 g|Zuckerschoten", "2 EL|Fischsauce", "1 TL|Palmzucker oder brauner Zucker", "4|Kaffirlimettenblätter",
   "1 Handvoll|Thai-Basilikum", "150 g|Jasminreis"],
  ["Reis kochen. @15",
   "Den dicken Teil der Kokosmilch im Topf erhitzen, bis sich das Fett absetzt, dann die Currypaste 2 Minuten darin anrösten. @2",
   "Hähnchen zugeben und 3 Minuten mitgaren. @3",
   "Restliche Kokosmilch, Aubergine und Limettenblätter zugeben und köcheln lassen. @8",
   "Zuckerschoten, Fischsauce und Zucker zugeben und 2 Minuten köcheln. @2",
   "Basilikum unterheben und mit Reis servieren."])

R("rotes-curry", "Rotes Curry mit Kürbis", "🎃", "Thailändisch", 2, "ca. 35 Min.",
  ["400 g|Hokkaido-Kürbis, gewürfelt", "200 g|Tofu oder Hähnchen", "2 EL|rote Currypaste", "400 ml|Kokosmilch",
   "100 ml|Wasser", "1|rote Paprika", "2 EL|Fischsauce oder Sojasauce", "1 TL|Zucker", "1|Limette",
   "1 Handvoll|Thai-Basilikum", "150 g|Jasminreis"],
  ["Reis kochen. @15",
   "Etwas Kokosmilch erhitzen und die Currypaste 2 Minuten darin anrösten. @2",
   "Kürbis, restliche Kokosmilch und Wasser zugeben und köcheln, bis der Kürbis fast weich ist. @12",
   "Tofu oder Hähnchen und Paprika zugeben und gar ziehen lassen. @6",
   "Mit Fischsauce, Zucker und Limettensaft abschmecken, Basilikum unterheben."])

R("tom-kha-gai", "Tom Kha Gai (Kokossuppe)", "🥥", "Thailändisch", 2, "ca. 25 Min.",
  ["400 ml|Kokosmilch", "300 ml|Hühnerbrühe", "250 g|Hähnchenbrust, in Streifen", "1 Stück (4 cm)|Galgant, in Scheiben",
   "2|Stängel Zitronengras", "4|Kaffirlimettenblätter", "150 g|Champignons, in Scheiben", "3 EL|Fischsauce",
   "2|Limetten", "1 TL|Zucker", "2|kleine Chilis", "1 Handvoll|Koriander"],
  ["Zitronengras flach klopfen und in Stücke schneiden. Warum klopfen: So gibt es mehr Aroma ab.",
   "Brühe, Kokosmilch, Galgant, Zitronengras und Limettenblätter aufkochen und ziehen lassen. @5",
   "Hähnchen und Pilze zugeben und sanft köcheln, bis das Fleisch gar ist. @6",
   "Vom Herd nehmen, mit Fischsauce, Limettensaft und Zucker abschmecken.",
   "Mit Chili und Koriander servieren. Galgant und Zitronengras werden nicht mitgegessen."])

R("tom-yum-goong", "Tom Yum Goong", "🍲", "Thailändisch", 2, "ca. 25 Min.",
  ["700 ml|Brühe", "250 g|Garnelen", "2|Stängel Zitronengras", "1 Stück (3 cm)|Galgant", "4|Kaffirlimettenblätter",
   "150 g|Austernpilze oder Champignons", "2 EL|Nam Prik Pao (Chilipaste)", "3 EL|Fischsauce", "2|Limetten",
   "3|kleine Chilis, angedrückt", "1 Handvoll|Koriander"],
  ["Brühe mit Zitronengras, Galgant und Limettenblättern aufkochen und ziehen lassen. @5",
   "Pilze und Chilipaste zugeben und 2 Minuten köcheln. @2",
   "Garnelen zugeben und nur garen, bis sie rosa sind. @2",
   "Vom Herd nehmen, mit Fischsauce und Limettensaft abschmecken: scharf, sauer, salzig.",
   "Mit Chilis und Koriander servieren."])

R("pad-kra-pao", "Pad Kra Pao (Basilikum-Hack)", "🌿", "Thailändisch", 2, "ca. 20 Min.",
  ["300 g|Hähnchen- oder Schweinehack", "4|Knoblauchzehen", "3|rote Chilis", "1 EL|Austernsauce", "1 EL|Sojasauce",
   "1 TL|Fischsauce", "1 TL|Zucker", "2 Handvoll|Thai-Basilikum (Holy Basil)", "2|Eier", "150 g|Jasminreis",
   "3 EL|neutrales Öl"],
  ["Reis kochen. @15",
   "Knoblauch und Chilis im Mörser grob zerstoßen.",
   "1 EL Öl im Wok erhitzen, Knoblauch-Chili 30 Sekunden anbraten.",
   "Hack zugeben und krümelig braten. @4",
   "Saucen und Zucker zugeben, Basilikum unterheben, bis es zusammenfällt.",
   "Restliches Öl in einer Pfanne stark erhitzen und die Eier knusprig braten (Spiegelei mit krossem Rand). Alles auf Reis servieren."])

R("massaman-curry", "Massaman-Curry mit Rind", "🥜", "Thailändisch", 4, "ca. 2 Std.",
  ["600 g|Rindergulasch", "3 EL|Massaman-Currypaste", "800 ml|Kokosmilch", "300 ml|Wasser", "500 g|festkochende Kartoffeln",
   "1|Zwiebel, in Spalten", "60 g|Erdnüsse", "3 EL|Fischsauce", "2 EL|Tamarindenpaste", "1 EL|Palmzucker",
   "1|Zimtstange", "300 g|Jasminreis"],
  ["Etwas Kokosmilch erhitzen und die Currypaste darin 2 Minuten anrösten. @2",
   "Fleisch zugeben und rundum anbraten.",
   "Restliche Kokosmilch, Wasser und Zimtstange zugeben und zugedeckt schmoren. @75",
   "Kartoffeln, Zwiebel und Erdnüsse zugeben und weiterköcheln, bis die Kartoffeln weich sind. @25",
   "Reis kochen. @15",
   "Mit Fischsauce, Tamarinde und Zucker abschmecken: mild-süß und leicht säuerlich."])

R("som-tam", "Som Tam (Papayasalat)", "🥗", "Thailändisch", 2, "ca. 20 Min.",
  ["300 g|grüne Papaya (oder Kohlrabi)", "1|Karotte", "100 g|Cherrytomaten", "50 g|grüne Bohnen", "2|Knoblauchzehen",
   "2|kleine Chilis", "2 EL|Fischsauce", "2|Limetten", "1 EL|Palmzucker", "30 g|geröstete Erdnüsse"],
  ["Papaya und Karotte schälen und in feine Streifen hobeln.",
   "Bohnen in 3 cm Stücke schneiden, Tomaten halbieren.",
   "Knoblauch und Chilis im Mörser zerstoßen, dann Zucker, Fischsauce und Limettensaft verrühren.",
   "Bohnen und Tomaten zugeben und leicht andrücken.",
   "Papaya und Karotte unterheben und kurz mit dem Stößel durchklopfen, damit sie das Dressing aufnehmen.",
   "Mit Erdnüssen bestreut sofort servieren."])

R("larb-gai", "Larb Gai (Hähnchensalat)", "🥬", "Thailändisch", 2, "ca. 20 Min.",
  ["300 g|Hähnchenhack", "2 EL|Klebreis (roh)", "2|Schalotten, in Ringen", "3 EL|Fischsauce", "2|Limetten",
   "1 TL|Chiliflocken", "1 Handvoll|Minze", "1 Handvoll|Koriander", "1|Kopf Romanasalat"],
  ["Klebreis in einer Pfanne ohne Fett goldbraun rösten und im Mörser fein mahlen. Warum: Das gibt den typischen nussigen Biss. @5",
   "Hack mit 3 EL Wasser in der Pfanne krümelig garen, ohne es anzubraten. @5",
   "Vom Herd nehmen, mit Fischsauce, Limettensaft und Chili würzen.",
   "Schalotten, Kräuter und das Reispulver unterheben.",
   "In Salatblättern servieren."])

R("mango-sticky-rice", "Mango Sticky Rice", "🥭", "Thailändisch", 2, "ca. 1 Std. (plus Einweichen)",
  ["200 g|Klebreis", "200 ml|Kokosmilch", "50 g|Zucker", "½ TL|Salz", "2|reife Mangos", "1 EL|geröstete Sesamsamen"],
  ["Klebreis in Wasser einweichen (am besten über Nacht, mindestens 4 Stunden). @240",
   "Abgießen und im Dämpfeinsatz über kochendem Wasser garen, bis er glasig ist. @25",
   "Kokosmilch mit Zucker und Salz erwärmen, bis der Zucker gelöst ist. Nicht kochen.",
   "Zwei Drittel der Kokosmilch unter den heißen Reis mischen und abgedeckt ziehen lassen. @15",
   "Mangos schälen und in Scheiben schneiden.",
   "Reis mit Mango anrichten, restliche Kokosmilch darüber und mit Sesam bestreuen."])

# ---------------- Japanisch ----------------
R("shoyu-ramen", "Shoyu-Ramen (schnelle Variante)", "🍜", "Japanisch", 2, "ca. 45 Min.",
  ["1 l|Hühnerbrühe", "4 EL|Sojasauce", "1 EL|Mirin", "1 Stück (3 cm)|Ingwer", "2|Knoblauchzehen", "2|Eier",
   "200 g|Ramen-Nudeln", "200 g|Hähnchenbrust oder Schweinebauch", "2|Frühlingszwiebeln", "1|Nori-Blatt",
   "100 g|Spinat", "1 TL|Sesamöl"],
  ["Eier 6½ Minuten kochen, in Eiswasser abschrecken und schälen. @7",
   "Eier in einer Mischung aus 2 EL Sojasauce, Mirin und 50 ml Wasser marinieren. @30",
   "Brühe mit Ingwer und Knoblauch aufkochen und köcheln lassen. @15",
   "Fleisch in der Brühe garen, herausnehmen und in Scheiben schneiden. @12",
   "Brühe mit restlicher Sojasauce und Sesamöl abschmecken.",
   "Nudeln nach Packung kochen, Spinat kurz mitgaren. @3",
   "Nudeln in Schalen, heiße Brühe darüber, mit Fleisch, halbiertem Ei, Frühlingszwiebeln und Nori belegen."])

R("teriyaki-lachs", "Teriyaki-Lachs", "🐟", "Japanisch", 2, "ca. 25 Min.",
  ["2|Lachsfilets (je 150 g)", "#Teriyaki-Sauce", "4 EL|Sojasauce", "3 EL|Mirin", "2 EL|Sake oder Wasser", "1 EL|Zucker",
   "#Dazu", "150 g|Sushi- oder Jasminreis", "200 g|Brokkoli", "1 TL|Sesam", "1 EL|neutrales Öl"],
  ["Reis kochen. @15",
   "Saucenzutaten verrühren.",
   "Brokkoli dämpfen oder kochen. @5",
   "Lachs trocken tupfen und in Öl auf der Hautseite knusprig braten. @4",
   "Wenden und 2 Minuten weiterbraten. @2",
   "Sauce in die Pfanne gießen und einkochen, bis sie glänzt. Lachs dabei immer wieder damit überziehen. @2",
   "Mit Reis, Brokkoli und Sesam servieren."])

R("katsu-curry", "Chicken Katsu Curry", "🍛", "Japanisch", 2, "ca. 45 Min.",
  ["2|Hähnchenbrustfilets", "1|Ei", "3 EL|Mehl", "60 g|Panko", "300 ml|neutrales Öl zum Ausbacken",
   "#Curry", "1|Zwiebel", "1|Karotte", "1|Kartoffel", "400 ml|Wasser", "60 g|japanische Currywürfel",
   "150 g|Reis"],
  ["Reis kochen. @15",
   "Zwiebel, Karotte und Kartoffel würfeln, in etwas Öl 5 Minuten anbraten. @5",
   "Wasser zugeben und köcheln, bis das Gemüse weich ist. @15",
   "Vom Herd nehmen, Currywürfel einrühren, bis sie gelöst sind, dann noch 3 Minuten sanft köcheln. @3",
   "Hähnchen flach klopfen, in Mehl, verquirltem Ei und Panko wenden.",
   "Im heißen Öl (ca. 170 °C) pro Seite 3–4 Minuten goldbraun ausbacken. @7",
   "Schnitzel in Streifen schneiden und mit Reis und Currysauce servieren."])

R("gyudon", "Gyudon (Rindfleisch-Reisschale)", "🍚", "Japanisch", 2, "ca. 25 Min.",
  ["250 g|Rindfleisch, hauchdünn geschnitten", "1|Zwiebel, in Streifen", "150 ml|Dashi oder Brühe", "3 EL|Sojasauce",
   "2 EL|Mirin", "1 EL|Zucker", "150 g|Reis", "2|Frühlingszwiebeln", "eingelegter Ingwer|nach Geschmack"],
  ["Reis kochen. @15",
   "Dashi, Sojasauce, Mirin und Zucker in einer Pfanne aufkochen.",
   "Zwiebel darin weich köcheln. @5",
   "Rindfleisch zugeben und nur kurz garen, bis es nicht mehr rosa ist. @2",
   "Auf Reis verteilen, etwas Sud darübergeben, mit Frühlingszwiebeln und Ingwer servieren."])

R("okonomiyaki", "Okonomiyaki", "🥞", "Japanisch", 2, "ca. 35 Min.",
  ["150 g|Mehl", "150 ml|Dashi oder Wasser", "2|Eier", "300 g|Weißkohl, fein geschnitten", "3|Frühlingszwiebeln",
   "150 g|Schweinebauch in dünnen Scheiben (oder Speck)", "#Topping", "3 EL|Okonomiyaki-Sauce oder Worcestersauce mit Ketchup",
   "2 EL|japanische Mayonnaise", "2 EL|Bonitoflocken (optional)", "1 TL|Aonori (optional)"],
  ["Mehl, Dashi und Eier zu einem dicken Teig verrühren.",
   "Kohl und Frühlingszwiebeln unterheben.",
   "Etwas Öl in einer Pfanne erhitzen, die Hälfte des Teigs zu einem 2 cm dicken Fladen formen, Fleisch darauflegen.",
   "Bei mittlerer Hitze braten. @5",
   "Vorsichtig wenden (mit Hilfe eines Tellers) und weiterbraten, bis er durch ist. @5",
   "Mit Sauce und Mayonnaise bestreichen, mit Bonito und Aonori bestreuen. Zweiten Fladen genauso backen."])

R("miso-suppe", "Miso-Suppe", "🥣", "Japanisch", 2, "ca. 15 Min.",
  ["600 ml|Dashi (oder Wasser mit 1 TL Dashi-Pulver)", "2 EL|helle Misopaste", "150 g|Seidentofu, gewürfelt",
   "1 EL|getrockneter Wakame", "2|Frühlingszwiebeln"],
  ["Wakame 5 Minuten in Wasser einweichen und abgießen. @5",
   "Dashi erhitzen, aber nicht kochen lassen.",
   "Misopaste in einer Kelle Brühe glatt rühren und zurück in den Topf geben. Warum nicht kochen: Miso verliert sonst Aroma.",
   "Tofu und Wakame zugeben und 1 Minute erwärmen.",
   "Mit Frühlingszwiebeln servieren."])

R("yakisoba", "Yakisoba", "🍝", "Japanisch", 2, "ca. 25 Min.",
  ["300 g|Yakisoba- oder Mie-Nudeln", "150 g|Schweinebauch oder Hähnchen, in Streifen", "200 g|Weißkohl", "1|Karotte",
   "1|Zwiebel", "#Sauce", "3 EL|Worcestersauce", "1 EL|Sojasauce", "1 EL|Austernsauce", "1 EL|Ketchup", "1 TL|Zucker",
   "#Dazu", "eingelegter Ingwer|nach Geschmack", "1 TL|Aonori (optional)"],
  ["Nudeln nach Packung vorbereiten und lockern.",
   "Sauce verrühren.",
   "Fleisch in etwas Öl knusprig braten. @4",
   "Zwiebel, Karotte und Kohl zugeben und 3 Minuten braten. @3",
   "Nudeln und Sauce zugeben und 2–3 Minuten unter Wenden braten. @3",
   "Mit Ingwer und Aonori servieren."])

R("oyakodon", "Oyakodon (Hähnchen-Ei-Schale)", "🍳", "Japanisch", 2, "ca. 25 Min.",
  ["250 g|Hähnchenschenkel, gewürfelt", "1|Zwiebel, in Streifen", "3|Eier", "150 ml|Dashi", "3 EL|Sojasauce",
   "2 EL|Mirin", "1 TL|Zucker", "150 g|Reis", "2|Frühlingszwiebeln"],
  ["Reis kochen. @15",
   "Dashi, Sojasauce, Mirin und Zucker in einer kleinen Pfanne aufkochen.",
   "Zwiebel und Hähnchen darin zugedeckt garen. @7",
   "Eier nur leicht verquirlen und gleichmäßig darübergießen.",
   "Zugedeckt stocken lassen, das Ei soll noch weich sein. @1",
   "Auf Reis gleiten lassen und mit Frühlingszwiebeln bestreuen."])
