# Runde 1: Suppen und Salate
from gen import R

S = dict(cat="Suppe")
SA = dict(cat="Salat")

R("tomatensuppe", "Tomatensuppe", "🍅", "Italienisch", 4, "ca. 35 Min.",
  ["1|Zwiebel", "2|Knoblauchzehen", "2 EL|Olivenöl", "1 EL|Tomatenmark", "800 g|geschälte Tomaten (Dose)",
   "500 ml|Gemüsebrühe", "1 TL|Zucker", "100 ml|Sahne", "1 Handvoll|Basilikum"],
  ["Zwiebel und Knoblauch würfeln und in Öl glasig dünsten. @4",
   "Tomatenmark kurz anrösten, Tomaten, Brühe und Zucker zugeben und köcheln. @20",
   "Fein pürieren, Sahne einrühren und mit Salz und Pfeffer abschmecken.",
   "Mit Basilikum servieren."], level="einfach", **S)

R("kuerbissuppe", "Kürbissuppe mit Ingwer", "🎃", "Deutsch", 4, "ca. 40 Min.",
  ["1|Hokkaido-Kürbis (ca. 1 kg)", "1|Zwiebel", "1 Stück|Ingwer (2 cm)", "2 EL|Butter", "800 ml|Gemüsebrühe",
   "200 ml|Kokosmilch", "1 Prise|Muskat", "2 EL|Kürbiskerne", "Kürbiskernöl|zum Beträufeln"],
  ["Kürbis waschen, entkernen und mit Schale würfeln. Hokkaido muss nicht geschält werden.",
   "Zwiebel und Ingwer würfeln und in Butter andünsten. @4",
   "Kürbis zugeben, mit Brühe aufgießen und weich kochen. @20",
   "Kokosmilch zugeben und fein pürieren. Mit Salz, Pfeffer und Muskat abschmecken.",
   "Kürbiskerne ohne Fett rösten und mit Kernöl über die Suppe geben."], level="einfach", **S)

R("brokkolisuppe", "Brokkoli-Cremesuppe", "🥦", "Deutsch", 4, "ca. 30 Min.",
  ["600 g|Brokkoli", "1|Kartoffel", "1|Zwiebel", "1 EL|Butter", "800 ml|Gemüsebrühe", "100 ml|Sahne", "50 g|Bergkäse"],
  ["Brokkoli in Röschen teilen, Stiel schälen und würfeln. Kartoffel und Zwiebel würfeln.",
   "Zwiebel in Butter andünsten, Gemüse und Brühe zugeben und weich kochen. @15",
   "Pürieren, Sahne und geriebenen Käse einrühren, abschmecken."], level="einfach", **S)

R("spargelcremesuppe", "Spargelcremesuppe", "🌱", "Deutsch", 4, "ca. 45 Min.",
  ["1 kg|weißer Spargel", "1 l|Wasser", "1 TL|Zucker", "40 g|Butter", "40 g|Mehl", "150 ml|Sahne", "1|Eigelb",
   "1 Spritzer|Zitronensaft", "½ Bund|Kerbel oder Petersilie"],
  ["Spargel schälen. Schalen und Enden mit Wasser, Salz und Zucker auskochen, dann absieben – das ist der Fond. @20",
   "Spargelstangen in Stücke schneiden und im Fond bissfest garen, herausnehmen. @8",
   "Butter schmelzen, Mehl anschwitzen und mit dem Fond glatt rühren. Köcheln lassen. @5",
   "Sahne mit Eigelb verquirlen, vom Herd nehmen und einrühren. Mit Salz und Zitrone abschmecken.",
   "Spargelstücke zugeben und mit Kräutern servieren."], **S)

R("hochzeitssuppe", "Hochzeitssuppe", "🍲", "Deutsch", 6, "ca. 2 Std.",
  ["1|Suppenhuhn (ca. 1,5 kg)", "2|Karotten", "¼|Sellerieknolle", "1|Lauchstange", "1|Zwiebel", "1|Lorbeerblatt",
   "#Klößchen", "250 g|Kalbsbrät", "#Eierstich", "3|Eier", "100 ml|Milch", "1 Prise|Muskat",
   "#Einlage", "200 g|Spargelspitzen (Glas)", "1 Bund|Schnittlauch"],
  ["Huhn mit Zwiebel, Lorbeer, 1 EL Salz und 3 l Wasser aufkochen, Schaum abschöpfen und leise köcheln. @90",
   "Eierstich: Eier, Milch, Salz und Muskat verquirlen, in eine gefettete Tasse füllen und im Wasserbad stocken lassen. @25",
   "Huhn herausnehmen, Brühe durch ein Sieb gießen. Gemüse fein würfeln und in der Brühe garen. @10",
   "Aus dem Brät mit zwei Teelöffeln Klößchen formen und in der Brühe gar ziehen lassen. @5",
   "Hühnerfleisch zerzupfen, Eierstich würfeln, mit Spargelspitzen in die Suppe geben und mit Schnittlauch servieren."], level="anspruchsvoll", **S)

R("huehnersuppe", "Hühnersuppe mit Nudeln", "🍜", "Deutsch", 4, "ca. 1 Std. 15 Min.",
  ["2|Hähnchenkeulen", "2|Karotten", "2 Stangen|Staudensellerie", "1|Zwiebel", "1|Lorbeerblatt", "1,5 l|Wasser",
   "100 g|Suppennudeln", "½ Bund|Petersilie"],
  ["Keulen mit halbierter Zwiebel, Lorbeer, 1 TL Salz und Wasser aufkochen, abschäumen und leise köcheln. @45",
   "Keulen herausnehmen, Fleisch von Haut und Knochen lösen und zerzupfen.",
   "Karotten und Sellerie in Scheiben in der Brühe garen. @10",
   "Nudeln zugeben und garen. @6",
   "Fleisch zurückgeben, abschmecken und mit Petersilie servieren."], level="einfach", **S)

R("gulaschsuppe", "Gulaschsuppe", "🍲", "Ungarisch", 6, "ca. 1 Std. 45 Min.",
  ["600 g|Rindergulasch", "3|Zwiebeln", "2|Paprikaschoten", "400 g|Kartoffeln", "2 EL|Schmalz oder Öl", "2 EL|Paprika edelsüß",
   "1 TL|Paprika scharf", "2 EL|Tomatenmark", "1 TL|Kümmel", "1 TL|Majoran", "1,5 l|Rinderbrühe"],
  ["Fleisch in kleine Würfel schneiden und in Schmalz portionsweise kräftig anbraten.",
   "Gewürfelte Zwiebeln zugeben und goldbraun braten. @8",
   "Tomatenmark und Paprika kurz mitrösten, sofort mit Brühe ablöschen.",
   "Kümmel und Majoran zugeben und zugedeckt köcheln. @60",
   "Kartoffeln und Paprika würfeln, zugeben und weich garen. @20",
   "Mit Salz und Pfeffer abschmecken."], **S)

R("linsensuppe-rot", "Rote Linsensuppe (Mercimek)", "🥣", "Türkisch", 4, "ca. 35 Min.",
  ["200 g|rote Linsen", "1|Zwiebel", "1|Karotte", "1 EL|Tomatenmark", "1 TL|Kreuzkümmel", "1 TL|Paprika edelsüß",
   "1,2 l|Gemüsebrühe", "3 EL|Olivenöl", "1|Zitrone", "1 TL|Pul Biber (Chiliflocken)"],
  ["Zwiebel und Karotte würfeln und in 2 EL Öl andünsten. @5",
   "Tomatenmark und Gewürze kurz mitrösten, Linsen und Brühe zugeben und weich kochen. @20",
   "Fein pürieren und mit Salz abschmecken.",
   "Restliches Öl mit Pul Biber erhitzen und über die Suppe träufeln. Mit Zitronenspalten servieren."], level="einfach", **S)

R("bohnensuppe", "Toskanische Bohnensuppe (Ribollita)", "🫘", "Italienisch", 4, "ca. 1 Std.",
  ["2 Dosen|weiße Bohnen (je 400 g)", "1|Zwiebel", "2|Karotten", "2 Stangen|Staudensellerie", "2|Knoblauchzehen",
   "300 g|Schwarzkohl oder Wirsing", "400 g|stückige Tomaten", "1 l|Gemüsebrühe", "4 Scheiben|altbackenes Brot",
   "5 EL|Olivenöl", "1 Zweig|Rosmarin"],
  ["Gemüse würfeln und in 3 EL Öl langsam andünsten. @10",
   "Tomaten, Brühe, Rosmarin und Kohlstreifen zugeben und köcheln. @20",
   "Bohnen zugeben, ein Drittel davon mit etwas Brühe pürieren und zurückgeben. @10",
   "Brot in Stücke reißen und in der Suppe weich ziehen lassen. Warum: Das Brot bindet die Suppe – typisch toskanisch. @10",
   "Mit Salz, Pfeffer und restlichem Olivenöl servieren."], **S)

R("kartoffel-lauch-suppe", "Kartoffel-Lauch-Suppe", "🥔", "Deutsch", 4, "ca. 35 Min.",
  ["600 g|mehligkochende Kartoffeln", "2|Lauchstangen", "1|Zwiebel", "2 EL|Butter", "1 l|Gemüsebrühe", "100 ml|Sahne",
   "1 Prise|Muskat", "½ Bund|Schnittlauch"],
  ["Kartoffeln schälen und würfeln, Lauch in Ringe schneiden.",
   "Zwiebel und Lauch in Butter andünsten. @5",
   "Kartoffeln und Brühe zugeben und weich kochen. @20",
   "Grob pürieren, Sahne zugeben und mit Salz, Pfeffer und Muskat abschmecken. Mit Schnittlauch servieren."], level="einfach", **S)

R("chili-sin-carne", "Chili sin Carne", "🌶️", "Mexikanisch", 4, "ca. 50 Min.",
  ["1|Zwiebel", "2|Knoblauchzehen", "1|rote Paprikaschote", "1|Süßkartoffel", "800 g|stückige Tomaten",
   "400 g|Kidneybohnen (Dose)", "400 g|schwarze Bohnen (Dose)", "200 g|Mais (Dose)", "2 TL|Kreuzkümmel",
   "1 TL|Paprika geräuchert", "1 TL|Chilipulver", "1 TL|Kakaopulver", "2 EL|Olivenöl"],
  ["Zwiebel, Knoblauch, Paprika und Süßkartoffel würfeln.",
   "Zwiebel und Knoblauch in Öl andünsten, Gewürze kurz mitrösten.",
   "Paprika, Süßkartoffel und Tomaten zugeben und köcheln. @25",
   "Bohnen und Mais abspülen, zugeben und mit Kakao weiter köcheln. Kakao rundet die Schärfe ab. @10",
   "Mit Salz abschmecken und mit Reis oder Brot servieren."], cat="Hauptgericht", level="einfach")

R("minestrone-kalt", "Gurkenkaltschale mit Dill", "🥒", "Deutsch", 4, "ca. 15 Min. (plus Kühlen)",
  ["2|Salatgurken", "500 g|Joghurt", "1|Knoblauchzehe", "1 Bund|Dill", "2 EL|Olivenöl", "1 Spritzer|Zitronensaft"],
  ["Gurken schälen, entkernen und grob schneiden.",
   "Mit Joghurt, Knoblauch, Dill (etwas zurückbehalten), Öl und Zitronensaft fein pürieren.",
   "Mit Salz und Pfeffer abschmecken und kalt stellen. @60",
   "Mit Dill und einem Schuss Olivenöl servieren."], level="einfach", **S)

R("ramen-miso", "Miso-Ramen mit Ei", "🍜", "Japanisch", 2, "ca. 30 Min.",
  ["2 Portionen|Ramen-Nudeln", "800 ml|Hühnerbrühe", "2 EL|Misopaste", "1 EL|Sojasauce", "1 TL|Sesamöl",
   "2|Eier", "100 g|Mais", "2|Frühlingszwiebeln", "1 Handvoll|Babyspinat", "1 Blatt|Nori"],
  ["Eier genau 6,5 Minuten kochen, in Eiswasser abschrecken und pellen. @7",
   "Brühe erhitzen, Miso und Sojasauce einrühren. Nicht mehr kochen lassen, sonst verliert Miso das Aroma.",
   "Nudeln nach Packung kochen und in Schalen verteilen. @4",
   "Brühe darübergießen, Spinat, Mais, halbierte Eier, Frühlingszwiebeln und Nori daraufgeben, mit Sesamöl beträufeln."], level="einfach", **S)

R("caesar-salad", "Caesar Salad mit Hähnchen", "🥗", "Amerikanisch", 2, "ca. 30 Min.",
  ["1|Romanasalat", "2|Hähnchenbrustfilets", "2 Scheiben|Toastbrot", "40 g|Parmesan", "1 EL|Öl",
   "#Dressing", "1|Eigelb", "1|Knoblauchzehe", "2|Sardellenfilets", "1 TL|Dijonsenf", "1 EL|Zitronensaft",
   "80 ml|Olivenöl"],
  ["Für das Dressing Eigelb, Knoblauch, Sardellen, Senf und Zitronensaft pürieren, Öl langsam einlaufen lassen. Die Hälfte des Parmesans unterrühren.",
   "Hähnchen salzen, pfeffern und in Öl pro Seite braten, ruhen lassen und in Streifen schneiden. @12",
   "Brot würfeln und in der Pfanne knusprig rösten. @4",
   "Salat zerzupfen, mit Dressing mischen, mit Hähnchen, Croutons und Parmesanspänen anrichten."], cat="Salat", level="mittel")

R("nudelsalat", "Klassischer Nudelsalat", "🥗", "Deutsch", 6, "ca. 30 Min. (plus Ziehen)",
  ["500 g|Spirelli", "200 g|Fleischwurst oder Kochschinken", "200 g|Erbsen (TK)", "4|Gewürzgurken", "1|rote Paprikaschote",
   "200 g|Mayonnaise", "150 g|Joghurt", "3 EL|Gurkenwasser", "1 TL|Senf"],
  ["Nudeln kochen, Erbsen die letzte Minute mitkochen. Abgießen und abkühlen lassen. @10",
   "Wurst, Gurken und Paprika würfeln.",
   "Mayonnaise, Joghurt, Gurkenwasser und Senf verrühren, salzen und pfeffern.",
   "Alles mischen und ziehen lassen. Vor dem Servieren evtl. mit Gurkenwasser nachwürzen. @60"], cat="Salat", level="einfach")

R("gurkensalat", "Gurkensalat mit Dill", "🥒", "Deutsch", 4, "ca. 15 Min.",
  ["2|Salatgurken", "150 g|saure Sahne", "2 EL|Weißweinessig", "1 TL|Zucker", "1 Bund|Dill"],
  ["Gurken in dünne Scheiben hobeln, leicht salzen und 10 Minuten ziehen lassen. Wasser abgießen. @10",
   "Saure Sahne, Essig, Zucker und gehackten Dill verrühren, pfeffern.",
   "Mit den Gurken mischen und sofort servieren."], cat="Salat", level="einfach")

R("krautsalat", "Bayerischer Krautsalat", "🥬", "Deutsch", 6, "ca. 20 Min. (plus Ziehen)",
  ["1|kleiner Weißkohl", "100 g|Speckwürfel (optional)", "4 EL|Weißweinessig", "4 EL|Öl", "1 TL|Kümmel", "1 TL|Zucker"],
  ["Kohl sehr fein hobeln, mit 1 TL Salz kräftig durchkneten, bis er weich wird.",
   "Essig mit Zucker, Kümmel und 100 ml heißem Wasser aufkochen und über den Kohl gießen.",
   "Speck knusprig braten und mit dem Öl unterheben.",
   "Ziehen lassen. @60"], cat="Salat", level="einfach")

R("caprese", "Insalata Caprese", "🍅", "Italienisch", 4, "ca. 10 Min.",
  ["4|reife Tomaten", "2 Kugeln|Büffelmozzarella", "1 Bund|Basilikum", "4 EL|Olivenöl", "1 EL|Balsamico (optional)"],
  ["Tomaten und Mozzarella in Scheiben schneiden und abwechselnd auf einer Platte anrichten.",
   "Mit Basilikum belegen, mit Salz und Pfeffer würzen und mit Olivenöl beträufeln."], cat="Salat", level="einfach")

R("couscous-salat", "Couscous-Salat mit Feta", "🥗", "Orientalisch", 4, "ca. 20 Min.",
  ["200 g|Couscous", "250 ml|Gemüsebrühe", "1|Salatgurke", "200 g|Kirschtomaten", "1|rote Zwiebel", "150 g|Feta",
   "1 Bund|Minze", "½ Bund|Petersilie", "1|Zitrone", "4 EL|Olivenöl"],
  ["Couscous mit heißer Brühe übergießen, zugedeckt quellen lassen und mit einer Gabel auflockern. @10",
   "Gemüse würfeln, Kräuter hacken.",
   "Alles mit Zitronensaft und Öl mischen, salzen, pfeffern.",
   "Feta darüberbröseln."], cat="Salat", level="einfach")

R("linsensalat", "Linsensalat mit Ziegenkäse", "🥗", "Französisch", 4, "ca. 35 Min.",
  ["200 g|Belugalinsen", "1|rote Zwiebel", "1|Karotte", "100 g|Rucola", "150 g|Ziegenfrischkäse",
   "3 EL|Rotweinessig", "1 TL|Dijonsenf", "1 TL|Honig", "4 EL|Olivenöl"],
  ["Linsen in ungesalzenem Wasser bissfest kochen. @20",
   "Zwiebel und Karotte fein würfeln.",
   "Essig, Senf, Honig und Öl verquirlen, salzen und pfeffern. Mit den warmen Linsen und dem Gemüse mischen.",
   "Mit Rucola und zerbröseltem Ziegenkäse servieren."], cat="Salat", level="einfach")

R("waldorfsalat", "Waldorfsalat", "🍏", "Amerikanisch", 4, "ca. 20 Min.",
  ["2|Äpfel", "3 Stangen|Staudensellerie", "60 g|Walnüsse", "100 g|Weintrauben", "100 g|Mayonnaise", "100 g|Joghurt",
   "1 EL|Zitronensaft"],
  ["Äpfel würfeln und sofort mit Zitronensaft mischen. Sellerie in feine Scheiben schneiden, Trauben halbieren.",
   "Mayonnaise und Joghurt verrühren, salzen und pfeffern.",
   "Alles mischen und mit grob gehackten Walnüssen bestreuen."], cat="Salat", level="einfach")

R("griechischer-nudelsalat", "Orzo-Salat mit Gemüse", "🥗", "Griechisch", 4, "ca. 25 Min.",
  ["250 g|Orzo (Kritharaki)", "1|Paprikaschote", "½|Salatgurke", "100 g|Kalamata-Oliven", "150 g|Feta",
   "1|Zitrone", "4 EL|Olivenöl", "1 TL|Oregano"],
  ["Orzo kochen, abgießen und mit 1 EL Öl mischen. @9",
   "Gemüse würfeln, Oliven halbieren.",
   "Mit Zitronensaft, restlichem Öl, Oregano, Salz und Pfeffer mischen.",
   "Feta darüberbröseln."], cat="Salat", level="einfach")

R("rote-bete-salat", "Rote-Bete-Salat mit Apfel", "🍠", "Deutsch", 4, "ca. 15 Min.",
  ["500 g|gekochte Rote Bete", "1|Apfel", "1|rote Zwiebel", "2 EL|Apfelessig", "3 EL|Öl", "1 TL|Meerrettich (Glas)",
   "½ Bund|Petersilie"],
  ["Rote Bete und Apfel würfeln, Zwiebel fein würfeln.",
   "Essig, Öl, Meerrettich, Salz und Pfeffer verrühren.",
   "Alles mischen und mit Petersilie bestreuen."], cat="Salat", level="einfach")

R("thai-rindfleischsalat", "Thai-Rindfleischsalat (Yam Nua)", "🥗", "Thailändisch", 2, "ca. 25 Min.",
  ["300 g|Rumpsteak", "1|Salatgurke", "150 g|Kirschtomaten", "1|rote Zwiebel", "1 Bund|Koriander", "1 Bund|Minze",
   "2 EL|Fischsauce", "2|Limetten", "1 TL|Zucker", "1|rote Chili"],
  ["Steak salzen und in einer heißen Pfanne pro Seite braten, ruhen lassen. @3",
   "Fischsauce, Limettensaft, Zucker und gehackte Chili verrühren.",
   "Gurke, Tomaten und Zwiebel schneiden, Kräuter zupfen.",
   "Steak dünn aufschneiden und mit Gemüse, Kräutern und Dressing mischen."], cat="Salat", level="einfach")

R("asia-glasnudelsalat", "Glasnudelsalat mit Erdnüssen", "🥗", "Vietnamesisch", 4, "ca. 20 Min.",
  ["150 g|Glasnudeln", "1|Karotte", "1|rote Paprikaschote", "½|Salatgurke", "1 Bund|Koriander", "50 g|geröstete Erdnüsse",
   "3 EL|Sojasauce", "2 EL|Limettensaft", "1 EL|Sesamöl", "1 TL|Zucker", "1|Knoblauchzehe"],
  ["Glasnudeln mit kochendem Wasser übergießen, 5 Minuten ziehen lassen, abschrecken und kürzer schneiden. @5",
   "Gemüse in feine Streifen schneiden.",
   "Sojasauce, Limettensaft, Sesamöl, Zucker und Knoblauch verrühren.",
   "Alles mischen und mit Koriander und Erdnüssen bestreuen."], cat="Salat", level="einfach")

R("panzanella", "Panzanella (Brotsalat)", "🍞", "Italienisch", 4, "ca. 25 Min.",
  ["300 g|Ciabatta vom Vortag", "500 g|reife Tomaten", "1|Salatgurke", "1|rote Zwiebel", "1 Bund|Basilikum",
   "3 EL|Rotweinessig", "6 EL|Olivenöl"],
  ["Brot in Würfel reißen und in 2 EL Öl in der Pfanne rösten. @6",
   "Tomaten grob schneiden, salzen und Saft ziehen lassen. Gurke und Zwiebel schneiden. @10",
   "Mit Brot, Essig, restlichem Öl und Basilikum mischen, ziehen lassen, bis das Brot den Saft aufgesogen hat. @10"], cat="Salat", level="einfach")

R("wurstsalat", "Schweizer Wurstsalat", "🥗", "Deutsch", 4, "ca. 15 Min. (plus Ziehen)",
  ["400 g|Fleischwurst (Lyoner)", "200 g|Emmentaler", "1|rote Zwiebel", "4|Gewürzgurken", "3 EL|Weißweinessig",
   "3 EL|Gurkenwasser", "4 EL|Öl", "1 TL|Senf", "½ Bund|Schnittlauch"],
  ["Wurst und Käse in feine Streifen schneiden, Zwiebel in Ringe, Gurken in Scheiben.",
   "Essig, Gurkenwasser, Senf, Öl, Salz und Pfeffer verrühren.",
   "Mit den Zutaten mischen und ziehen lassen. Mit Schnittlauch und Brot servieren. @20"], cat="Salat", level="einfach")

R("feldsalat-speck", "Feldsalat mit Speck und Croutons", "🥗", "Deutsch", 4, "ca. 15 Min.",
  ["200 g|Feldsalat", "100 g|Speckwürfel", "2 Scheiben|Toastbrot", "1|Schalotte", "2 EL|Balsamico", "1 TL|Senf",
   "1 TL|Honig", "4 EL|Öl"],
  ["Feldsalat waschen und trocken schleudern.",
   "Speck knusprig braten, Brotwürfel im Speckfett rösten. @6",
   "Schalotte fein würfeln, mit Balsamico, Senf, Honig und Öl verrühren, salzen und pfeffern.",
   "Salat mit Dressing mischen und mit Speck und Croutons bestreuen."], cat="Salat", level="einfach")

R("quinoa-bowl", "Quinoa-Bowl mit Ofengemüse", "🥙", "International", 2, "ca. 40 Min.",
  ["150 g|Quinoa", "1|Süßkartoffel", "200 g|Kichererbsen (Dose)", "1|Avocado", "100 g|Babyspinat", "2 EL|Olivenöl",
   "1 TL|Paprika geräuchert", "#Dressing", "2 EL|Tahin", "1|Zitrone", "1 TL|Ahornsirup"],
  ["Ofen auf 220 °C vorheizen. Süßkartoffel würfeln, mit Kichererbsen, Öl, Paprika und Salz mischen und rösten. @25",
   "Quinoa abspülen und in doppelter Menge Wasser garen. @15",
   "Tahin mit Zitronensaft, Ahornsirup, Salz und Wasser zu einem cremigen Dressing rühren.",
   "Quinoa, Spinat, Ofengemüse und Avocadoscheiben in Schalen anrichten und mit Dressing beträufeln."], level="einfach")
