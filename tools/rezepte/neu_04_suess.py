# Runde 1: Frühstück, Desserts, Backen
from gen import R

F = dict(cat="Frühstück")
D = dict(cat="Dessert")
B = dict(cat="Backen")

R("pfannkuchen", "Pfannkuchen", "🥞", "Deutsch", 4, "ca. 30 Min.",
  ["250 g|Mehl", "500 ml|Milch", "3|Eier", "1 Prise|Salz", "1 EL|Zucker", "2 EL|Butter zum Braten"],
  ["Mehl, Milch, Eier, Salz und Zucker glatt rühren und ruhen lassen. Warum: Das Mehl quillt, die Pfannkuchen reißen nicht. @10",
   "Wenig Butter in einer Pfanne erhitzen, eine Kelle Teig dünn verteilen.",
   "Goldbraun backen, wenden und fertig backen. So weiter, bis der Teig aufgebraucht ist. @20",
   "Mit Apfelmus, Marmelade oder Zimt und Zucker servieren."], level="einfach", cat="Hauptgericht")

R("pancakes", "Fluffige Pancakes", "🥞", "Amerikanisch", 4, "ca. 25 Min.",
  ["250 g|Mehl", "2 TL|Backpulver", "1 EL|Zucker", "1 Prise|Salz", "300 ml|Buttermilch", "2|Eier", "40 g|geschmolzene Butter",
   "Ahornsirup|zum Servieren", "150 g|Heidelbeeren"],
  ["Mehl, Backpulver, Zucker und Salz mischen.",
   "Buttermilch, Eier und Butter verquirlen und kurz unter das Mehl rühren. Klümpchen sind gut – zu viel Rühren macht sie zäh.",
   "Pfanne bei mittlerer Hitze leicht fetten, je 3 EL Teig hineingeben.",
   "Wenden, sobald sich Bläschen bilden, und fertig backen. @15",
   "Mit Ahornsirup und Heidelbeeren servieren."], level="einfach", **F)

R("ruehrei", "Cremiges Rührei mit Schnittlauch", "🍳", "Deutsch", 2, "ca. 10 Min.",
  ["5|Eier", "2 EL|Milch oder Sahne", "1 EL|Butter", "½ Bund|Schnittlauch", "2 Scheiben|Brot"],
  ["Eier mit Milch, Salz und Pfeffer verquirlen.",
   "Butter bei kleiner Hitze schmelzen, Eier zugeben.",
   "Mit einem Pfannenwender langsam von außen nach innen schieben, bis das Ei gerade gestockt, aber noch glänzend ist. @4",
   "Mit Schnittlauch bestreuen und mit Brot servieren."], level="einfach", **F)

R("french-toast", "French Toast mit Beeren", "🍞", "Amerikanisch", 2, "ca. 15 Min.",
  ["4 Scheiben|Brioche oder Toast", "2|Eier", "150 ml|Milch", "1 TL|Zimt", "1 EL|Zucker", "1 EL|Butter",
   "150 g|gemischte Beeren", "Puderzucker|zum Bestäuben"],
  ["Eier, Milch, Zimt und Zucker verquirlen.",
   "Brotscheiben kurz darin einweichen.",
   "In Butter bei mittlerer Hitze pro Seite goldbraun braten. @6",
   "Mit Beeren und Puderzucker servieren."], level="einfach", **F)

R("overnight-oats", "Overnight Oats", "🥣", "International", 1, "ca. 5 Min. (plus Nacht im Kühlschrank)",
  ["50 g|Haferflocken", "100 ml|Milch oder Haferdrink", "100 g|Joghurt", "1 TL|Chiasamen", "1 TL|Honig",
   "100 g|Beeren", "1 EL|Nüsse"],
  ["Haferflocken, Milch, Joghurt, Chiasamen und Honig in einem Glas verrühren.",
   "Abgedeckt über Nacht in den Kühlschrank stellen.",
   "Morgens mit Beeren und Nüssen toppen."], level="einfach", **F)

R("granola", "Knuspermüsli (Granola)", "🥣", "International", 8, "ca. 35 Min.",
  ["300 g|Haferflocken", "100 g|Nüsse, grob gehackt", "50 g|Sonnenblumenkerne", "4 EL|Ahornsirup oder Honig",
   "3 EL|Kokosöl", "1 TL|Zimt", "1 Prise|Salz", "80 g|Rosinen oder Cranberries"],
  ["Ofen auf 160 °C vorheizen.",
   "Kokosöl mit Sirup schmelzen, mit Haferflocken, Nüssen, Kernen, Zimt und Salz mischen.",
   "Auf einem Blech verteilen und goldbraun backen, nach der Hälfte wenden. @25",
   "Abkühlen lassen (wird erst dann knusprig) und Trockenfrüchte untermischen. Luftdicht aufbewahren."], level="einfach", **F)

R("shakshuka-feta", "Eier im Tomaten-Paprika-Sugo mit Feta", "🍳", "Orientalisch", 2, "ca. 25 Min.",
  ["1|Zwiebel", "1|rote Paprikaschote", "1|Knoblauchzehe", "400 g|stückige Tomaten", "1 TL|Kreuzkümmel",
   "4|Eier", "80 g|Feta", "½ Bund|Petersilie", "2 EL|Olivenöl"],
  ["Zwiebel und Paprika in Streifen schneiden und in Öl weich dünsten. @6",
   "Knoblauch und Kreuzkümmel kurz mitbraten, Tomaten zugeben, salzen und einkochen. @8",
   "Vier Mulden formen, Eier hineinschlagen, zudecken und stocken lassen. @6",
   "Mit Feta und Petersilie servieren, dazu Fladenbrot."], level="einfach", **F)

R("avocado-toast", "Avocado-Toast mit Ei", "🥑", "International", 2, "ca. 15 Min.",
  ["2 Scheiben|Sauerteigbrot", "1|Avocado", "1 Spritzer|Zitronensaft", "2|Eier", "1 Prise|Chiliflocken", "Kresse|zum Garnieren"],
  ["Brot rösten.",
   "Avocado mit Zitronensaft, Salz und Pfeffer zerdrücken.",
   "Eier als Spiegeleier braten oder 7 Minuten kochen. @6",
   "Brot mit Avocado bestreichen, Ei darauflegen und mit Chili und Kresse bestreuen."], level="einfach", **F)

R("bircher-muesli", "Bircher Müsli", "🍏", "Schweizerisch", 2, "ca. 10 Min. (plus Quellen)",
  ["80 g|Haferflocken", "200 ml|Milch", "1|Apfel", "150 g|Joghurt", "1 EL|Zitronensaft", "1 EL|Honig", "2 EL|Haselnüsse"],
  ["Haferflocken mit Milch einweichen. @30",
   "Apfel mit Schale grob reiben und sofort mit Zitronensaft mischen.",
   "Apfel, Joghurt und Honig unter die Flocken rühren.",
   "Mit gehackten Haselnüssen servieren."], level="einfach", **F)

R("croque-monsieur", "Croque Monsieur", "🥪", "Französisch", 2, "ca. 20 Min.",
  ["4 Scheiben|Toastbrot", "4 Scheiben|Kochschinken", "100 g|Gruyère, gerieben", "1 EL|Butter", "1 EL|Mehl", "150 ml|Milch",
   "1 TL|Dijonsenf", "1 Prise|Muskat"],
  ["Butter schmelzen, Mehl anschwitzen, Milch einrühren und dick einkochen. Mit Muskat, Salz und der Hälfte des Käses verrühren. @4",
   "Ofengrill vorheizen. Zwei Brotscheiben mit Senf bestreichen, mit Schinken und etwas Käse belegen, zuklappen.",
   "Oben mit der Sauce bestreichen und mit restlichem Käse bestreuen.",
   "Unter dem Grill goldbraun überbacken. @6"], level="einfach", cat="Snack")

R("milchreis", "Milchreis mit Kirschen", "🍚", "Deutsch", 4, "ca. 40 Min.",
  ["250 g|Milchreis", "1 l|Milch", "50 g|Zucker", "1 Päckchen|Vanillezucker", "1 Prise|Salz", "1 Glas|Sauerkirschen",
   "1 EL|Speisestärke", "Zimt und Zucker|zum Bestreuen"],
  ["Milch mit Zucker, Vanillezucker und Salz aufkochen, Reis einrühren.",
   "Bei kleinster Hitze zugedeckt quellen lassen, gelegentlich umrühren, damit nichts ansetzt. @30",
   "Kirschen mit Saft erhitzen, mit angerührter Stärke binden. @3",
   "Milchreis mit Kirschen und Zimt-Zucker servieren."], level="einfach", **D)

R("griessbrei", "Grießbrei", "🥣", "Deutsch", 2, "ca. 10 Min.",
  ["500 ml|Milch", "50 g|Weichweizengrieß", "2 EL|Zucker", "1 Prise|Salz", "1 TL|Butter", "Zimt|zum Bestreuen"],
  ["Milch mit Zucker und Salz aufkochen.",
   "Grieß unter Rühren einrieseln lassen und unter Rühren quellen lassen, bis er andickt. @5",
   "Butter einrühren und mit Zimt oder Obst servieren."], level="einfach", **D)

R("schokopudding", "Schokoladenpudding", "🍫", "Deutsch", 4, "ca. 15 Min. (plus Kühlen)",
  ["500 ml|Milch", "100 g|Zartbitterschokolade", "40 g|Speisestärke", "60 g|Zucker", "1 EL|Kakaopulver", "1 Prise|Salz"],
  ["Stärke, Zucker, Kakao und Salz mit 100 ml Milch glatt rühren.",
   "Restliche Milch mit gehackter Schokolade aufkochen, bis sie geschmolzen ist.",
   "Angerührte Stärke einrühren und unter Rühren 1 Minute kochen lassen. @1",
   "In Schälchen füllen und kalt stellen. @120"], level="einfach", **D)

R("panna-cotta", "Panna Cotta mit Beerensauce", "🍮", "Italienisch", 4, "ca. 20 Min. (plus 4 Std. Kühlen)",
  ["500 ml|Sahne", "50 g|Zucker", "1|Vanilleschote", "3 Blatt|Gelatine", "300 g|Beeren (TK)", "2 EL|Puderzucker"],
  ["Gelatine in kaltem Wasser einweichen. @5",
   "Sahne mit Zucker und ausgekratzter Vanille aufkochen und leise köcheln. @5",
   "Vom Herd nehmen, Gelatine ausdrücken und darin auflösen.",
   "In Gläser füllen und kalt stellen. @240",
   "Beeren mit Puderzucker erwärmen, pürieren und über die Panna Cotta geben."], level="einfach", **D)

R("mousse-chocolat", "Mousse au Chocolat", "🍫", "Französisch", 6, "ca. 25 Min. (plus 4 Std. Kühlen)",
  ["200 g|Zartbitterschokolade (70 %)", "4|Eier", "40 g|Zucker", "200 ml|Sahne", "1 Prise|Salz"],
  ["Schokolade über dem Wasserbad schmelzen und etwas abkühlen lassen.",
   "Eier trennen. Eigelbe mit der Hälfte des Zuckers cremig schlagen und die Schokolade einrühren.",
   "Sahne steif schlagen und unterheben.",
   "Eiweiß mit Salz und restlichem Zucker steif schlagen und vorsichtig unterheben.",
   "In Gläser füllen und kalt stellen. @240"], level="mittel", **D)

R("rote-gruetze", "Rote Grütze mit Vanillesauce", "🍓", "Deutsch", 4, "ca. 20 Min. (plus Kühlen)",
  ["500 g|gemischte rote Beeren (TK)", "250 ml|Kirschsaft", "60 g|Zucker", "30 g|Speisestärke", "#Vanillesauce",
   "400 ml|Milch", "1|Vanilleschote", "2|Eigelb", "40 g|Zucker", "1 TL|Speisestärke"],
  ["Saft mit Zucker aufkochen, Stärke mit etwas Wasser anrühren und einrühren. Beeren zugeben und kurz aufkochen. @3",
   "Abkühlen lassen und kalt stellen. @60",
   "Milch mit Vanilleschote aufkochen. Eigelb, Zucker und Stärke verquirlen, heiße Milch langsam einrühren.",
   "Zurück in den Topf geben und unter Rühren erhitzen, bis die Sauce bindet – nicht kochen lassen. @4"], level="einfach", **D)

R("apfelstrudel", "Apfelstrudel", "🍎", "Österreichisch", 8, "ca. 1 Std. 15 Min.",
  ["1 Packung|Strudel- oder Filoteig", "1 kg|säuerliche Äpfel", "80 g|Zucker", "1 TL|Zimt", "60 g|Rosinen",
   "50 g|Semmelbrösel", "100 g|Butter", "1 EL|Zitronensaft", "Puderzucker|zum Bestäuben"],
  ["Ofen auf 190 °C vorheizen. Äpfel schälen, in dünne Scheiben schneiden, mit Zucker, Zimt, Rosinen und Zitronensaft mischen.",
   "Brösel in 30 g Butter goldbraun rösten. Restliche Butter schmelzen.",
   "Teigblätter auf einem Küchentuch überlappend auslegen und mit Butter bestreichen.",
   "Brösel auf dem unteren Drittel verteilen, Äpfel daraufgeben. Mit Hilfe des Tuchs aufrollen, Enden einschlagen.",
   "Mit Butter bestreichen und goldbraun backen. @40",
   "Lauwarm mit Puderzucker und Vanillesauce servieren."], level="mittel", **D)

R("kaiserschmarrn-apfel", "Apfelpfannkuchen", "🍎", "Deutsch", 4, "ca. 30 Min.",
  ["200 g|Mehl", "400 ml|Milch", "3|Eier", "1 Prise|Salz", "2|Äpfel", "2 EL|Butter", "2 EL|Zucker", "1 TL|Zimt"],
  ["Mehl, Milch, Eier und Salz glatt rühren.",
   "Äpfel schälen und in dünne Spalten schneiden.",
   "Butter in einer Pfanne schmelzen, Apfelspalten darin kurz anbraten.",
   "Teig darübergießen, zugedeckt stocken lassen, wenden und fertig backen. @8",
   "Mit Zimt und Zucker bestreuen."], level="einfach", cat="Hauptgericht")

R("dampfnudeln", "Dampfnudeln mit Vanillesauce", "🥟", "Deutsch", 4, "ca. 2 Std. (inkl. Gehzeit)",
  ["500 g|Mehl", "1 Würfel|frische Hefe", "250 ml|lauwarme Milch", "60 g|Zucker", "60 g|weiche Butter", "1|Ei",
   "1 Prise|Salz", "#Zum Garen", "150 ml|Milch", "30 g|Butter", "1 EL|Zucker", "#Vanillesauce", "1 Päckchen|Vanillesaucenpulver", "500 ml|Milch"],
  ["Hefe in Milch mit 1 TL Zucker auflösen. Mit Mehl, restlichem Zucker, Butter, Ei und Salz zu einem glatten Teig kneten.",
   "Abgedeckt gehen lassen, bis er doppelt so groß ist. @60",
   "8 Kugeln formen und nochmals gehen lassen. @20",
   "In einem breiten Topf mit Deckel Milch, Butter und Zucker aufkochen, Kugeln hineinsetzen.",
   "Zugedeckt bei kleiner Hitze garen, bis es knistert und unten eine Kruste entsteht. Deckel nicht öffnen! @25",
   "Vanillesauce nach Packung kochen und dazu servieren."], level="anspruchsvoll", cat="Hauptgericht")

R("marmorkuchen", "Marmorkuchen", "🍰", "Deutsch", 12, "ca. 1 Std. 20 Min.",
  ["250 g|weiche Butter", "220 g|Zucker", "1 Päckchen|Vanillezucker", "4|Eier", "375 g|Mehl", "1 Päckchen|Backpulver",
   "150 ml|Milch", "2 EL|Kakaopulver", "2 EL|Milch (für den dunklen Teig)", "Puderzucker|zum Bestäuben"],
  ["Ofen auf 175 °C Ober-/Unterhitze vorheizen. Gugelhupfform fetten und bemehlen.",
   "Butter, Zucker und Vanillezucker cremig schlagen, Eier einzeln unterrühren.",
   "Mehl und Backpulver abwechselnd mit der Milch unterrühren.",
   "Zwei Drittel des Teigs in die Form füllen. Restlichen Teig mit Kakao und 2 EL Milch verrühren und daraufgeben.",
   "Mit einer Gabel spiralförmig durchziehen und backen. Stäbchenprobe machen. @55",
   "Abkühlen lassen, stürzen und mit Puderzucker bestäuben."], level="einfach", **B)

R("kaesekuchen", "Käsekuchen", "🍰", "Deutsch", 12, "ca. 1 Std. 30 Min. (plus Abkühlen)",
  ["#Boden", "200 g|Mehl", "80 g|Zucker", "100 g|kalte Butter", "1|Ei", "#Füllung", "1 kg|Magerquark", "200 g|Zucker",
   "4|Eier", "1 Päckchen|Vanillepuddingpulver", "200 ml|Sahne", "100 g|geschmolzene Butter", "1|Bio-Zitrone (Abrieb)"],
  ["Mehl, Zucker, Butter und Ei zu einem Mürbeteig verkneten und kalt stellen. @30",
   "Ofen auf 170 °C Ober-/Unterhitze vorheizen. Teig in einer Springform (26 cm) als Boden und 3 cm hohen Rand auslegen.",
   "Quark, Zucker, Eier, Puddingpulver, Sahne, Butter und Zitronenabrieb glatt rühren.",
   "Füllung auf den Boden geben und backen. @70",
   "Im ausgeschalteten Ofen bei leicht geöffneter Tür abkühlen lassen – so reißt er nicht ein. @30"], level="mittel", **B)

R("bananenbrot", "Bananenbrot", "🍌", "Amerikanisch", 10, "ca. 1 Std. 10 Min.",
  ["3|sehr reife Bananen", "80 g|geschmolzene Butter", "120 g|brauner Zucker", "2|Eier", "1 TL|Vanilleextrakt",
   "220 g|Mehl", "1 TL|Natron", "1 Prise|Salz", "1 TL|Zimt", "60 g|Walnüsse (optional)"],
  ["Ofen auf 175 °C vorheizen. Kastenform mit Backpapier auslegen.",
   "Bananen zerdrücken, mit Butter, Zucker, Eiern und Vanille verrühren.",
   "Mehl, Natron, Salz und Zimt mischen und kurz unterrühren. Nüsse unterheben.",
   "In die Form füllen und backen. Stäbchenprobe machen. @55"], level="einfach", **B)

R("zimtschnecken", "Zimtschnecken", "🌀", "Skandinavisch", 12, "ca. 2 Std. (inkl. Gehzeit)",
  ["500 g|Mehl", "1 Würfel|frische Hefe", "250 ml|lauwarme Milch", "70 g|Zucker", "80 g|weiche Butter", "1|Ei",
   "1 Prise|Salz", "#Füllung", "100 g|weiche Butter", "100 g|brauner Zucker", "2 EL|Zimt", "#Guss", "100 g|Frischkäse",
   "60 g|Puderzucker"],
  ["Hefe in Milch auflösen, mit Mehl, Zucker, Butter, Ei und Salz zu einem glatten Teig kneten. Abgedeckt gehen lassen. @60",
   "Teig zu einem Rechteck (ca. 40 × 30 cm) ausrollen. Butter darauf verstreichen, mit Zucker und Zimt bestreuen.",
   "Von der langen Seite aufrollen und in 12 Scheiben schneiden. In eine gefettete Form setzen.",
   "Nochmals gehen lassen. Ofen auf 180 °C vorheizen. @20",
   "Goldbraun backen. @22",
   "Frischkäse mit Puderzucker verrühren und auf den warmen Schnecken verstreichen."], level="mittel", **B)

R("brownies", "Schoko-Brownies", "🍫", "Amerikanisch", 16, "ca. 45 Min.",
  ["200 g|Zartbitterschokolade", "150 g|Butter", "200 g|Zucker", "3|Eier", "100 g|Mehl", "2 EL|Kakaopulver",
   "1 Prise|Salz", "100 g|Walnüsse oder Schokodrops"],
  ["Ofen auf 180 °C vorheizen. Eine Form (20 × 20 cm) mit Backpapier auslegen.",
   "Schokolade mit Butter schmelzen.",
   "Zucker und Eier verrühren, Schokobutter einrühren.",
   "Mehl, Kakao und Salz unterheben, Nüsse zugeben.",
   "Backen, bis die Oberfläche glänzt, innen aber noch feucht ist. Warum nicht länger: Sonst werden sie trocken statt fudgy. @22"], level="einfach", **B)

R("muffins-blaubeer", "Blaubeer-Muffins", "🧁", "Amerikanisch", 12, "ca. 35 Min.",
  ["300 g|Mehl", "2 TL|Backpulver", "150 g|Zucker", "1 Prise|Salz", "2|Eier", "250 ml|Buttermilch", "100 ml|Öl",
   "200 g|Heidelbeeren"],
  ["Ofen auf 180 °C vorheizen, Muffinblech mit Förmchen auslegen.",
   "Mehl, Backpulver, Zucker und Salz mischen.",
   "Eier, Buttermilch und Öl verquirlen und kurz unter die trockenen Zutaten rühren.",
   "Heidelbeeren unterheben, Teig verteilen und backen. @22"], level="einfach", **B)

R("chocolate-chip-cookies", "Chocolate Chip Cookies", "🍪", "Amerikanisch", 20, "ca. 30 Min.",
  ["125 g|weiche Butter", "100 g|brauner Zucker", "50 g|weißer Zucker", "1|Ei", "1 TL|Vanilleextrakt", "200 g|Mehl",
   "½ TL|Natron", "1 Prise|Salz", "150 g|Schokoladendrops"],
  ["Ofen auf 180 °C vorheizen.",
   "Butter mit beiden Zuckersorten cremig rühren, Ei und Vanille unterrühren.",
   "Mehl, Natron und Salz unterrühren, Schokodrops unterheben.",
   "Walnussgroße Kugeln mit Abstand auf ein Blech setzen.",
   "Backen, bis die Ränder goldbraun sind – die Mitte bleibt weich. @11"], level="einfach", **B)

R("streuselkuchen", "Streuselkuchen vom Blech", "🍰", "Deutsch", 20, "ca. 1 Std. 30 Min. (inkl. Gehzeit)",
  ["#Hefeteig", "500 g|Mehl", "1 Würfel|frische Hefe", "250 ml|lauwarme Milch", "60 g|Zucker", "60 g|Butter", "1|Ei",
   "#Streusel", "300 g|Mehl", "200 g|Zucker", "200 g|kalte Butter", "1 TL|Zimt"],
  ["Hefe in Milch auflösen, mit Mehl, Zucker, Butter und Ei zu einem Teig kneten. Gehen lassen. @45",
   "Für die Streusel Mehl, Zucker, Butter und Zimt mit den Fingern zu Bröseln reiben.",
   "Teig auf einem gefetteten Blech ausrollen, Streusel darauf verteilen und nochmals gehen lassen. @15",
   "Bei 180 °C goldbraun backen. @25"], level="mittel", **B)

R("zwetschgendatschi", "Zwetschgendatschi", "🍑", "Deutsch", 20, "ca. 1 Std. 30 Min. (inkl. Gehzeit)",
  ["400 g|Mehl", "½ Würfel|frische Hefe", "200 ml|lauwarme Milch", "50 g|Zucker", "50 g|Butter", "1|Ei", "1 Prise|Salz",
   "2 kg|Zwetschgen", "3 EL|Zucker", "1 TL|Zimt"],
  ["Hefeteig aus Mehl, Hefe, Milch, Zucker, Butter, Ei und Salz kneten und gehen lassen. @45",
   "Zwetschgen entsteinen und längs einschneiden (nicht halbieren).",
   "Teig auf ein gefettetes Blech ausrollen und die Zwetschgen dachziegelartig dicht daraufsetzen.",
   "Bei 200 °C backen. @30",
   "Noch warm mit Zimt und Zucker bestreuen, mit Schlagsahne servieren."], level="mittel", **B)

R("rhabarberkuchen", "Rhabarberkuchen mit Baiser", "🍰", "Deutsch", 12, "ca. 1 Std. 15 Min.",
  ["125 g|weiche Butter", "125 g|Zucker", "3|Eier (getrennt)", "200 g|Mehl", "2 TL|Backpulver", "3 EL|Milch",
   "600 g|Rhabarber", "150 g|Zucker (für das Baiser)"],
  ["Ofen auf 180 °C vorheizen. Rhabarber putzen und in 2 cm Stücke schneiden.",
   "Butter und Zucker cremig rühren, Eigelbe unterrühren. Mehl, Backpulver und Milch unterrühren.",
   "Teig in eine Springform streichen, Rhabarber darauf verteilen und backen. @25",
   "Eiweiß steif schlagen, dabei den Zucker einrieseln lassen, bis die Masse glänzt.",
   "Auf den Kuchen streichen und weiterbacken, bis das Baiser goldbraun ist. @20"], level="mittel", **B)

R("waffeln", "Waffeln", "🧇", "Deutsch", 8, "ca. 30 Min.",
  ["125 g|weiche Butter", "75 g|Zucker", "1 Päckchen|Vanillezucker", "3|Eier", "250 g|Mehl", "1 TL|Backpulver",
   "250 ml|Milch", "Puderzucker|zum Bestäuben"],
  ["Butter, Zucker und Vanillezucker cremig rühren, Eier unterrühren.",
   "Mehl und Backpulver abwechselnd mit Milch unterrühren.",
   "Waffeleisen fetten und Waffeln goldbraun backen. @20",
   "Mit Puderzucker, Kirschen oder Sahne servieren."], level="einfach", **B)

R("vollkornbrot", "Schnelles Vollkornbrot", "🍞", "Deutsch", 12, "ca. 1 Std. 20 Min.",
  ["500 g|Dinkelvollkornmehl", "1 Würfel|frische Hefe", "500 ml|lauwarmes Wasser", "2 EL|Apfelessig", "2 TL|Salz",
   "100 g|Sonnenblumenkerne", "50 g|Leinsamen", "2 EL|Haferflocken"],
  ["Ofen auf 200 °C Ober-/Unterhitze vorheizen (nicht vorheizen ist auch möglich – dann 10 Minuten länger).",
   "Hefe im Wasser auflösen. Mit Mehl, Essig, Salz, Kernen und Leinsamen zu einem klebrigen Teig verrühren. Kneten ist nicht nötig.",
   "In eine gefettete Kastenform füllen, mit Haferflocken bestreuen und mit Wasser besprühen.",
   "Backen, bis das Brot beim Klopfen auf den Boden hohl klingt. @60"], level="einfach", **B)

R("laugenbrezeln", "Laugenbrezeln", "🥨", "Deutsch", 8, "ca. 1 Std. 45 Min.",
  ["500 g|Weizenmehl (Type 550)", "1 Würfel|frische Hefe", "300 ml|lauwarmes Wasser", "40 g|weiche Butter", "2 TL|Salz",
   "#Lauge", "1 l|Wasser", "4 EL|Natron", "grobes Salz|zum Bestreuen"],
  ["Hefe im Wasser auflösen, mit Mehl, Butter und Salz 10 Minuten kneten. Gehen lassen. @45",
   "In 8 Stücke teilen, zu langen Strängen (ca. 50 cm) rollen, Enden dünner. Zu Brezeln schlingen.",
   "Unabgedeckt im Kühlschrank ruhen lassen – so bekommen sie eine Haut. @20",
   "Ofen auf 220 °C vorheizen. Wasser mit Natron aufkochen (Achtung, schäumt).",
   "Brezeln einzeln 30 Sekunden in die Lauge tauchen, auf Backpapier legen, mit Salz bestreuen und dick einschneiden.",
   "Dunkelbraun backen. @18"], level="anspruchsvoll", **B)

R("pizzateig-grundrezept", "Pizzabrötchen", "🍕", "Italienisch", 12, "ca. 1 Std. 30 Min.",
  ["500 g|Mehl", "1 Päckchen|Trockenhefe", "300 ml|lauwarmes Wasser", "3 EL|Olivenöl", "2 TL|Salz",
   "100 g|Salami oder Kochschinken", "100 g|Gouda, gerieben", "1|Paprikaschote", "2 EL|Tomatenmark", "1 TL|Oregano"],
  ["Mehl, Hefe, Wasser, Öl und Salz zu einem glatten Teig kneten und gehen lassen. @45",
   "Salami, Paprika und Käse fein würfeln, mit Tomatenmark und Oregano mischen.",
   "Füllung unter den Teig kneten, 12 Brötchen formen und auf ein Blech setzen. Nochmals gehen lassen. @15",
   "Bei 200 °C goldbraun backen. @20"], level="einfach", cat="Snack")

R("eiskaffee", "Eiskaffee", "☕", "Deutsch", 2, "ca. 10 Min.",
  ["300 ml|kalter starker Kaffee", "4 Kugeln|Vanilleeis", "100 ml|Sahne", "1 EL|Schokoraspel"],
  ["Sahne steif schlagen.",
   "Je 2 Kugeln Eis in ein Glas geben, mit kaltem Kaffee auffüllen.",
   "Mit Sahne und Schokoraspeln garnieren."], level="einfach", cat="Getränk")

R("smoothie-beeren", "Beeren-Bananen-Smoothie", "🥤", "International", 2, "ca. 5 Min.",
  ["1|Banane", "200 g|Beeren (TK)", "250 ml|Milch oder Haferdrink", "100 g|Joghurt", "1 TL|Honig"],
  ["Alles im Mixer cremig pürieren.",
   "Sofort servieren."], level="einfach", cat="Getränk")

R("heisse-schokolade", "Heiße Schokolade", "☕", "International", 2, "ca. 10 Min.",
  ["500 ml|Milch", "80 g|Zartbitterschokolade", "1 EL|Zucker", "1 Prise|Zimt", "Sahne|zum Servieren"],
  ["Milch erhitzen, gehackte Schokolade darin unter Rühren schmelzen.",
   "Mit Zucker und Zimt abschmecken und aufschäumen.",
   "Mit Sahne servieren."], level="einfach", cat="Getränk")
