"""Nährwerte für die Rezepte in Hubert – Richtwerte, aus den Zutaten berechnet.

Werte je 100 g (roh, essbarer Anteil), gerundet nach gängigen Nährwerttabellen
(Bundeslebensmittelschlüssel / USDA). Für ein Rezept reicht das: die App zeigt „ca.“.

  N("stichwort,stichwort2", kcal, eiweiß, kohlenhydrate, davon_zucker, fett, ballaststoffe, …)

Stichwörter: das längste passende gewinnt („tomatenmark“ schlägt „tomate“).
Ein „=“ vorne heißt: nur als ganzes Wort (+ Mehrzahl), damit „ei“ nicht in „Reis“ steckt.
Gewichte: st = 1 Stück, el / tl = Löffel, bund, hand (Handvoll), scheibe, dose, pck, wuerfel, stange, blatt.
cat: veg (Gemüse), herb (Kräuter), spice (Gewürz), fruit (Obst) – für „Gemüse würfeln“ in den Schritten.

Aufruf:  python3 tools/rezepte/naehrwerte.py   → prüft alle Rezepte (Treffer, Ausreißer)
"""
import re

FOODS = []


def N(keys, kcal, p, kh, z, f, bs, cat=None, st=None, el=None, tl=None, bund=None, hand=None, scheibe=None,
      dose=None, pck=None, wuerfel=None, stange=None, blatt=None, dichte=1.0):
    FOODS.append(dict(keys=[k.strip() for k in keys.split(",")], v=(kcal, p, kh, z, f, bs), cat=cat, st=st, el=el, tl=tl,
                      bund=bund, hand=hand, scheibe=scheibe, dose=dose, pck=pck, wuerfel=wuerfel, stange=stange,
                      blatt=blatt, dichte=dichte))


# ---------- Gemüse ----------
N("zwiebel,=zwiebeln,perlzwiebel,silberzwiebel", 40, 1.2, 9, 4.5, 0.1, 1.7, "veg", st=80)
N("schalotte", 72, 2.5, 17, 8, 0.1, 3, "veg", st=30)
N("frühlingszwiebel,lauchzwiebel", 32, 1.8, 7, 2.3, 0.2, 2.6, "veg", st=15, bund=120)
N("lauch,porree,lauchstange", 31, 1.6, 7, 2, 0.3, 2, "veg", st=200, stange=200)
N("knoblauch,knoblauchzehe", 149, 6.4, 33, 1, 0.5, 2.1, "veg", st=4, el=10, tl=4)
N("ingwer,galgant", 80, 1.8, 18, 1.7, 0.8, 2, "veg", st=15, el=6, tl=2)
N("karotte,möhre,möhrchen", 41, 0.9, 10, 4.7, 0.2, 2.8, "veg", st=80)
N("=paprika,paprikaschote,spitzpaprika,rote paprika,gelbe paprika,grüne paprika,große paprika", 31, 1, 6, 4.2, 0.3, 2.1, "veg", st=160)
N("=tomate,=tomaten,reife tomaten,fleischtomate,strauchtomate", 18, 0.9, 3.9, 2.6, 0.2, 1.2, "veg", st=120)
N("kirschtomate,cherrytomate,datteltomate,thai-aubergine", 18, 0.9, 3.9, 2.6, 0.2, 1.2, "veg", st=15)
N("stückige tomaten,passierte tomaten,geschälte tomaten,san-marzano,tomatensauce,dosentomaten", 24, 1.2, 4.5, 3.5, 0.2, 1.2, dose=400)
N("tomatenmark", 82, 4.3, 19, 12, 0.5, 4, el=16, tl=5)
N("paprikamark", 70, 2.5, 12, 8, 1, 3, el=16, tl=5)
N("getrocknete tomaten", 210, 5, 13, 10, 14, 6, st=8)
N("gurke,salatgurke", 15, 0.6, 3.6, 1.7, 0.1, 0.5, "veg", st=400)
N("gewürzgurke,essiggurke,cornichon,eingelegte gurke", 20, 0.5, 3, 2.5, 0.2, 1, st=40)
N("gurkenwasser,kimchi-saft,kimchisaft", 8, 0.2, 1.5, 1.2, 0, 0, el=15)
N("zucchini", 17, 1.2, 3.1, 2.5, 0.3, 1, "veg", st=250)
N("aubergine", 25, 1, 6, 3.5, 0.2, 3, "veg", st=300)
N("brokkoli", 34, 2.8, 7, 1.7, 0.4, 2.6, "veg", st=450)
N("blumenkohl", 25, 1.9, 5, 1.9, 0.3, 2, "veg", st=800)
N("spinat,babyspinat,blattspinat", 23, 2.9, 3.6, 0.4, 0.4, 2.2, "veg", hand=25)
N("rucola", 25, 2.6, 3.7, 2, 0.7, 1.6, "veg", hand=20, bund=60)
N("=salat,kopfsalat,romanasalat,eisbergsalat,blattsalat,kopf salat,kopf romanasalat", 15, 1.4, 2.9, 1.2, 0.2, 1.3, "veg", st=300, hand=30)
N("feldsalat", 21, 1.8, 3.6, 0.5, 0.4, 1.5, "veg", hand=20)
N("weißkohl,spitzkohl,rotkohl,wirsing,chinakohl,schwarzkohl,blaukraut", 25, 1.3, 6, 3.2, 0.1, 2.5, "veg", st=900)
N("grünkohl", 49, 4.3, 9, 2, 0.9, 4, "veg")
N("rosenkohl", 43, 3.4, 9, 2.2, 0.3, 3.8, "veg")
N("pak choi", 13, 1.5, 2.2, 1, 0.2, 1, "veg", st=250)
N("sauerkraut", 19, 0.9, 4.3, 1.8, 0.1, 2.9, dose=500)
N("kimchi", 15, 1.1, 2.4, 1.1, 0.5, 1.6)
N("champignon,pilze,steinpilz,austernpilz,shiitake,kräuterseitling,pfifferling,braune champignons", 22, 3.1, 3.3, 2, 0.3, 1, "veg", st=20)
N("getrocknete shiitake,getrocknete steinpilze,getrocknete pilze", 296, 9.6, 75, 2.2, 1, 11, st=3)
N("maiskolben", 86, 3.3, 19, 3, 1.4, 2.7, "veg", st=150)
N("=mais,maiskörner", 86, 3.3, 19, 3, 1.4, 2.7, "veg", dose=285)
N("=erbsen,tk-erbsen", 81, 5.4, 14, 5.7, 0.4, 5.1, "veg")
N("grüne bohnen,brechbohnen,prinzessbohnen", 31, 1.8, 7, 3.3, 0.2, 2.7, "veg")
N("zuckerschote", 42, 2.8, 7.6, 4, 0.2, 2.6, "veg")
N("edamame", 121, 12, 9, 2, 5, 5, "veg")
N("sojasprossen,mungobohnensprossen", 30, 3, 6, 4, 0.2, 1.8, "veg")
N("bambussprossen", 27, 2.6, 5, 3, 0.3, 2.2, "veg")
N("kidneybohnen,schwarze bohnen,weiße bohnen,borlotti,cannellini,=bohnen", 110, 7.5, 15, 0.5, 0.5, 6, dose=250)
N("kichererbsen", 120, 7, 16, 0.5, 2, 5, dose=250)
N("getrocknete kichererbsen", 364, 19, 61, 10, 6, 17)
N("=linsen,rote linsen,gelbe linsen,tellerlinsen,belugalinsen,braune linsen,schwarze linsen,berglinsen", 350, 25, 55, 2, 1.5, 11)
N("schälerbsen,getrocknete grüne schälerbsen", 340, 23, 60, 8, 1.2, 17)
N("kartoffel,pellkartoffel,drillinge", 77, 2, 17, 0.8, 0.1, 2.2, st=150)
N("gekochte kartoffel,gekochte mehlige kartoffel", 72, 1.9, 16, 0.8, 0.1, 2, st=150)
N("süßkartoffel", 86, 1.6, 20, 4.2, 0.1, 3, "veg", st=300)
N("=pommes,tk-pommes", 150, 2.5, 23, 0.3, 5, 2.5)
N("kartoffelklöße,kartoffelknödel", 110, 2.3, 24, 0.5, 0.3, 1.5, st=90)
N("kartoffelsalat", 140, 2, 14, 3, 8, 1.5)
N("kürbis,hokkaido,butternut", 26, 1, 6.5, 2.8, 0.1, 1, "veg", st=1000)
N("knollensellerie,sellerieknolle,=sellerie", 42, 1.5, 9, 1.6, 0.3, 1.8, "veg", st=600)
N("staudensellerie,stangen sellerie,stange sellerie,selleriestange", 16, 0.7, 3, 1.3, 0.2, 1.6, "veg", st=50, stange=50)
N("pastinake,petersilienwurzel", 75, 1.2, 18, 4.8, 0.3, 4.9, "veg", st=150)
N("rote bete,rote-bete", 43, 1.6, 10, 7, 0.2, 2.8, "veg", st=200)
N("rettich,radieschen,eingelegter rettich", 16, 0.7, 3.4, 1.9, 0.1, 1.6, "veg", st=20, bund=150)
N("=rettich", 16, 0.7, 3.4, 1.9, 0.1, 1.6, "veg", st=300)
N("spargel,spargelspitzen", 20, 2.2, 3.9, 1.9, 0.1, 2.1, "veg", st=25)
N("fenchel", 31, 1.2, 7, 4, 0.2, 3.1, "veg", st=250)
N("avocado", 160, 2, 9, 0.7, 15, 7, "veg", st=160)
N("chipotle,chili,chilischote,jalapeño,thai-chili,grüne chili,rote chili,peperoni", 40, 1.9, 9, 5, 0.4, 1.5, "veg", st=10)
N("getrocknete chili,ancho-chili,peperoncini,getrocknete chilischote", 300, 12, 50, 10, 6, 28, "spice", st=1)
N("oliven,kalamata", 145, 1, 4, 0.5, 15, 3.3, st=4)
N("kapern", 23, 2.4, 5, 0.4, 0.9, 3.2, el=9, tl=3)
N("suppengrün", 30, 1.3, 6, 3, 0.2, 2.5, "veg", bund=400)
N("gemischtes gemüse,tk-gemüse,wokgemüse", 50, 2.5, 8, 3, 0.4, 3, "veg")
N("meerrettich", 70, 1.2, 11, 8, 0.7, 3.3, el=15, tl=5)
N("weinblätter", 93, 5.6, 17, 1, 2, 11, st=3, blatt=3)
N("grüne papaya,papaya", 39, 0.6, 10, 6, 0.1, 1.7, "veg", st=500)
N("rhabarber", 21, 0.9, 4.5, 1, 0.2, 1.8, stange=100)
N("maronen,esskastanien", 190, 2.8, 40, 10, 1.4, 6)
N("okra", 33, 1.9, 7, 1.5, 0.2, 3.2, "veg")
N("kresse", 32, 4.2, 5.5, 4.4, 0.7, 1.1, "herb", hand=10, st=10)
N("nori,aonori,wakame,nori-blatt", 35, 6, 5, 0.5, 0.3, 3, st=3, blatt=3, el=3, tl=1)

# ---------- Obst ----------
N("=apfel,=äpfel,säuerliche äpfel,säuerlicher apfel", 52, 0.3, 14, 10, 0.2, 2.4, "fruit", st=180)
N("birne", 57, 0.4, 15, 10, 0.1, 3, "fruit", st=180)
N("banane", 89, 1.1, 23, 12, 0.3, 2.6, "fruit", st=120)
N("zitrone,bio-zitrone", 22, 0.4, 6.9, 2.5, 0.2, 0.3, "fruit", st=45)
N("limette", 22, 0.4, 6.9, 2.5, 0.2, 0.3, "fruit", st=30)
N("zitronensaft,limettensaft", 22, 0.4, 6.9, 2.5, 0.2, 0.3, el=15, tl=5)
N("orange,bio-orange", 47, 0.9, 12, 9, 0.1, 2.4, "fruit", st=200)
N("maracuja,passionsfrucht", 97, 2.2, 23, 11, 0.7, 10, "fruit", st=20)
N("mango", 60, 0.8, 15, 14, 0.4, 1.6, "fruit", st=300)
N("ananas", 50, 0.5, 13, 10, 0.1, 1.4, "fruit", st=900, dose=340)
N("beeren,heidelbeeren,himbeeren,erdbeeren,brombeeren,johannisbeeren,preiselbeeren,rote beeren", 45, 0.8, 10, 7, 0.4, 4, "fruit", hand=50)
N("weintrauben,trauben", 69, 0.7, 18, 16, 0.2, 0.9, "fruit")
N("pflaume,zwetschge", 47, 0.7, 11, 10, 0.3, 1.6, "fruit", st=35)
N("sauerkirschen,kirschen", 50, 1, 12, 8, 0.3, 1.6, "fruit")
N("granatapfel,granatapfelkerne", 83, 1.7, 19, 14, 1.2, 4, "fruit", st=250)
N("getrocknete aprikosen", 241, 3.4, 63, 53, 0.5, 7, st=8)
N("rosinen", 299, 3, 79, 59, 0.5, 3.7, el=10)
N("cranberrys,cranberries", 308, 0.1, 82, 65, 1.4, 5.7, el=10)
N("backpflaumen,trockenpflaumen", 240, 2.2, 64, 38, 0.4, 7, st=8)
N("datteln", 280, 2.5, 75, 63, 0.4, 8, st=8)
N("apfelmus", 76, 0.2, 20, 17, 0.1, 1.2, el=20)
N("zwetschgenröster", 150, 0.7, 35, 32, 0.3, 2, el=20)
N("powidl,pflaumenmus", 210, 1, 50, 45, 0.3, 3, el=20, tl=7)

# ---------- Kräuter (frisch) ----------
for k, kc in [("petersilie,glatte petersilie,kerbel", 36), ("koriander,korianderblätter,koriandergrün", 23),
              ("schnittlauch", 30), ("dill", 43), ("minze", 44), ("basilikum,thai-basilikum,basilikumblätter", 23),
              ("salbei,salbeiblätter", 50), ("rosmarin", 131), ("thymian", 101), ("majoran", 60), ("oregano", 66),
              ("estragon", 50), ("liebstöckel", 40), ("zitronengras,stängel zitronengras", 99),
              ("kaffirlimettenblätter,curryblätter", 60), ("=kräuter,gehackte kräuter,gemischte kräuter", 40)]:
    N(k, kc, 3, 6, 1, 0.7, 3, "herb", bund=25, hand=15, st=2, el=3, tl=1)
# Getrocknete Kräuter und Kräutermischungen
N("getrockneter oregano,getrockneter thymian,getrocknete kräuter,italienische kräuter,kräuter der provence,"
  "getrocknete bockshornkleeblätter,kasuri methi,beifuß", 280, 10, 60, 5, 5, 35, "spice", el=3, tl=1)
N("lorbeerblatt,lorbeerblätter", 313, 7.6, 75, 0, 8, 26, "spice", st=0.2, blatt=0.2)

# ---------- Gewürze ----------
N("kreuzkümmel,kreuzkümmelsamen,=kümmel,kurkuma,muskat,muskatnuss,zimt,garam masala,currypulver,=curry,chiliflocken,"
  "chilipulver,cayennepfeffer,pul biber,gochugaru,sichuanpfeffer,paprika edelsüß,paprika geräuchert,paprika scharf,"
  "paprikapulver,edelsüßes paprikapulver,geräuchertes paprikapulver,scharfes paprikapulver,ras el hanout,ras el-hanout,"
  "lebkuchengewürz,spekulatiusgewürz,fünf-gewürze-pulver,gyrosgewürz,tandoori-masala,tikka-masala-gewürz,"
  "knoblauchpulver,ingwerpulver,senfpulver,senfsamen,fenchelsamen,koriandersamen,gemahlener koriander,sumach,"
  "kardamom,kaschmiri,kashmiri,baharat,biryani,piment,pimentkörner,=pfeffer,schwarzer pfeffer,weißer pfeffer,"
  "pfefferkörner,schwarze pfefferkörner,safran,=nelke,nelken,gewürznelken,wacholderbeeren,sternanis,=anis,"
  "kardamomkapseln,zimtstange,matcha,berbere", 330, 12, 50, 3, 10, 30, "spice", el=7, tl=2.5, st=1, stange=3)
N("salz,grobes salz,meersalz,grobes meersalz", 0, 0, 0, 0, 0, 0, el=18, tl=6)
N("vanilleschote", 290, 4, 13, 13, 11, 0, st=3)
N("vanilleextrakt", 288, 0, 13, 13, 0, 0, el=13, tl=4)
N("vanillezucker", 400, 0, 100, 100, 0, 0, pck=8, tl=4)

# ---------- Backen & Süßes ----------
N("=zucker,weißer zucker,brauner zucker,rohrzucker,hagelzucker,gelierzucker", 400, 0, 100, 100, 0, 0, el=15, tl=5)
N("puderzucker", 400, 0, 100, 100, 0, 0, el=10, tl=3)
N("palmzucker", 380, 0.5, 95, 90, 0, 0, el=15, tl=5)
N("honig", 304, 0.3, 82, 82, 0, 0.2, el=21, tl=7, dichte=1.4)
N("ahornsirup,zuckerrübensirup,agavendicksaft,granatapfelsirup", 260, 0, 67, 60, 0.1, 0, el=20, tl=7, dichte=1.3)
N("=mehl,weizenmehl,pizzamehl,weichweizengrieß,=grieß,hartweizengrieß", 340, 10, 71, 0.7, 1, 4, el=10, tl=3)
N("dinkelmehl", 340, 11, 70, 1, 1.8, 4, el=10, tl=3)
N("dinkelvollkornmehl,vollkornmehl", 330, 14, 60, 1, 2.5, 9, el=10, tl=3)
N("speisestärke,kartoffelstärke,maisstärke,tapiokastärke", 350, 0.3, 86, 0, 0.1, 0.9, el=10, tl=3)
N("backpulver,natron", 100, 0, 25, 0, 0, 0, pck=15, tl=4, el=10)
N("frische hefe,=hefe", 100, 12, 8, 0, 1.2, 7, wuerfel=42, st=42)
N("trockenhefe", 325, 40, 40, 0, 7, 26, pck=7, tl=3)
N("gelatine", 340, 85, 0, 0, 0, 0, blatt=1.7)
N("kakao,kakaopulver,backkakao", 350, 20, 11, 1, 21, 33, el=7, tl=2.5)
N("zartbitterschokolade,zartbitterkuvertüre,kuvertüre,schokolade,schokoladendrops,schokodrops,schokoraspel", 540, 6, 46, 40, 35, 8)
N("mandel,gemahlene mandeln,gehackte mandeln,mandelstifte,mandelblättchen", 600, 21, 6, 4.4, 53, 12, el=7, hand=30)
N("haselnüsse,gemahlene haselnüsse,gehackte haselnüsse", 650, 15, 10, 4, 61, 8, el=7, hand=30)
N("walnüsse,walnusskerne,gehackte walnüsse", 690, 15, 11, 2.6, 65, 6.7, el=7, hand=30)
N("erdnüsse,geröstete erdnüsse", 600, 25, 13, 4, 49, 8, el=9, hand=30)
N("cashew,cashewkerne", 580, 18, 30, 6, 44, 3, el=9, hand=30)
N("pinienkerne", 670, 14, 13, 3.6, 68, 3.7, el=9)
N("sonnenblumenkerne,kürbiskerne,geröstete kürbiskerne", 570, 25, 12, 1.5, 49, 7, el=9)
N("=sesam,sesamsamen,geröstete sesamsamen", 570, 18, 23, 0.3, 50, 12, el=9, tl=3)
N("leinsamen", 530, 18, 29, 1.6, 42, 27, el=10, tl=3)
N("chiasamen", 486, 17, 42, 0, 31, 34, el=10, tl=3)
N("kokosraspel,kokosflocken", 650, 7, 24, 7, 62, 16, el=6)
N("=mohn,gemahlener mohn", 525, 18, 28, 3, 42, 20, el=9)
N("=nüsse,gemischte nüsse", 620, 16, 12, 4, 57, 8, el=8, hand=30)
N("orangeat,zitronat", 320, 0.5, 80, 75, 0.3, 2)
N("marmelade,konfitüre,gelee,johannisbeergelee,aprikosenmarmelade,marillenmarmelade,johannisbeermarmelade,"
  "aprikosenkonfitüre,nutella", 250, 0.3, 60, 58, 0.1, 1, el=20, tl=7)
N("vanillesaucenpulver,vanillepuddingpulver,puddingpulver", 350, 0, 86, 0, 0, 0, pck=37)
N("löffelbiskuit", 390, 8, 80, 50, 4, 1, st=6)
N("lebkuchen,printen", 350, 5, 70, 40, 6, 3, st=25)
N("cornflakes", 380, 7, 84, 8, 0.9, 3)
N("granola,müsli", 450, 9, 62, 22, 18, 7)
N("haferflocken,zarte haferflocken", 370, 13.5, 59, 0.7, 7, 10, el=8)
N("streusel,bunte streusel", 400, 2, 90, 80, 3, 0, el=10, tl=3)
N("backoblaten,back-oblaten", 350, 10, 80, 0, 1, 2, st=1)
N("blätterteig", 400, 6, 35, 2, 26, 1.5, pck=275, st=275)
N("mürbeteig", 450, 6, 55, 20, 23, 2, pck=275, st=275)
N("filoteig,strudelteig,yufka", 300, 9, 60, 1, 3, 2, blatt=20, pck=250)
N("flammkuchenteig,pizzateig", 300, 7, 50, 2, 7, 2, pck=260, st=260)
N("gyoza-teigblätter,wan-tan-blätter,frühlingsrollenblätter", 290, 8, 60, 1, 1.5, 2, st=8, pck=250)
N("reispapier,reispapierblätter", 330, 0.7, 80, 0, 0.3, 1, st=8, blatt=8)
N("weizentortilla,tortillas,große weizentortillas,kleine weizentortillas", 310, 8.5, 50, 3, 8, 3, st=60)
N("maistortilla,kleine maistortillas", 220, 5.7, 45, 1, 2.9, 6, st=30)
N("tortilla-chips", 490, 7, 63, 1, 24, 5)
N("vanilleeis", 200, 3.5, 24, 21, 10, 0, st=60)

# ---------- Reis, Nudeln, Getreide (trocken) ----------
N("=reis,basmatireis,jasminreis,langkornreis,rundkornreis,sushireis,klebreis,risottoreis,paella-reis,milchreis,"
  "reis zum servieren,wildreis,vollkornreis,parboiled", 350, 7, 78, 0.2, 0.6, 1.3)
N("gekochter reis,gekochter reis vom vortag", 130, 2.7, 28, 0, 0.3, 0.4)
N("couscous", 360, 12, 72, 1, 1.5, 5)
N("bulgur,feiner bulgur", 340, 12, 69, 0.4, 1.3, 12)
N("quinoa", 368, 14, 64, 0, 6, 7)
N("maismehl", 365, 9, 76, 1, 4, 7)
N("reismehl", 366, 6, 80, 0, 1.4, 2.4, el=10)
N("polenta,maisgrieß", 360, 8, 77, 1, 1.2, 4)
N("=nudeln,spaghetti,tonnarelli,penne,tagliatelle,rigatoni,makkaroni,maccheroni,orecchiette,orzo,linguine,"
  "fettuccine,bandnudeln,spirelli,fusilli,farfalle,cannelloni,lasagneplatten,lasagneblätter,suppennudeln,"
  "fadennudeln,kleine nudeln,kurze nudeln,trofie,weizennudeln,mie-nudeln,ramen-nudeln,yakisoba,eiernudeln,"
  "hörnchennudeln,pappardelle", 355, 12.5, 71, 3, 1.5, 3, st=17)
N("reisnudeln,reisbandnudeln,breite reisnudeln,glasnudeln,süßkartoffel-glasnudeln", 360, 6, 80, 0, 0.5, 1.6)
N("udon,udon-nudeln,vorgekochte ramen", 130, 3.5, 27, 0.5, 0.5, 1.2, pck=200)
N("gnocchi", 150, 3.6, 32, 0.5, 0.4, 1.5)
N("spätzle", 160, 6, 29, 0.5, 2.5, 1.5)
N("schupfnudeln", 160, 3.5, 33, 0.5, 1.2, 2)
N("maultaschen", 220, 9, 25, 2, 9, 2, st=60)
N("tortellini,ravioli", 300, 12, 47, 3, 7, 2.5)
N("semmelknödel", 200, 7, 33, 3, 4, 2, st=100)
N("reiskuchen,tteok", 230, 4, 50, 0, 0.5, 0.5)

# ---------- Brot ----------
N("=brot,sauerteigbrot,weißbrot,bauernbrot,altbackenes brot,weißbrot vom vortag", 250, 8.5, 48, 3, 1.5, 4, scheibe=40, st=500)
N("brötchen,semmel,altbackenes brötchen,baguettebrötchen,burgerbrötchen", 270, 9, 52, 4, 3, 3, st=60)
N("baguette,baguette vom vortag,scheiben baguette,ciabatta,ciabatta vom vortag", 260, 8.5, 52, 3, 1.5, 3, st=250, scheibe=15)
N("toastbrot,toast,brioche", 290, 8, 50, 5, 5, 3, st=25, scheibe=25)
N("fladenbrot,fladenbrote", 260, 9, 52, 2, 1.5, 2.5, st=120)
N("pitabrot,pita,naan", 270, 9, 53, 2, 2, 2.5, st=60)
N("brezn,laugenbrezel,breze", 270, 8, 55, 1, 2, 2, st=80)
N("knödelbrot", 270, 9, 52, 4, 2, 3)
N("semmelbrösel,paniermehl,panko", 360, 11, 73, 3, 2, 4, el=8)

# ---------- Milch, Käse, Eier ----------
N("=butter,weiche butter,kalte butter,geschmolzene butter,flüssige butter", 740, 0.7, 0.6, 0.6, 82, 0, el=15, tl=5)
N("ghee,butterschmalz", 900, 0, 0, 0, 99.5, 0, el=13, tl=4)
N("schmalz,schweineschmalz", 900, 0, 0, 0, 99.7, 0, el=13, tl=4)
N("=milch,vollmilch,lauwarme milch,kalte milch,warme milch", 64, 3.3, 4.8, 4.8, 3.5, 0, el=15, tl=5)
N("buttermilch", 37, 3.5, 4, 4, 0.5, 0, el=15)
N("sahne,schlagsahne,kochsahne", 300, 2.4, 3.2, 3.2, 30, 0, el=15, tl=5, pck=200)
N("saure sahne", 115, 3, 4, 4, 10, 0, el=15, pck=200)
N("schmand", 240, 2.5, 3.5, 3.5, 24, 0, el=15, pck=200)
N("crème fraîche,creme fraiche", 290, 2.4, 2.6, 2.6, 30, 0, el=15, pck=150)
N("joghurt,naturjoghurt", 65, 3.8, 4.7, 4.7, 3.5, 0, el=15, tl=5)
N("griechischer joghurt", 120, 5, 4, 4, 10, 0, el=15)
N("magerquark", 67, 12, 4, 4, 0.3, 0, el=15, pck=250)
N("=quark,speisequark", 110, 12, 3.5, 3.5, 5, 0, el=15, pck=250)
N("frischkäse", 250, 6, 3.5, 3.5, 23, 0, el=15, pck=200)
N("ziegenfrischkäse", 220, 12, 2, 2, 18, 0, el=15)
N("mascarpone", 450, 4.5, 3.5, 3.5, 47, 0, el=15, pck=250)
N("ricotta", 150, 9, 3, 3, 11, 0, el=15, pck=250)
N("mozzarella", 250, 18, 1, 1, 19.5, 0, st=125, pck=125)
N("büffelmozzarella,burrata", 270, 16, 0.5, 0.5, 23, 0, st=125, pck=125)
N("=feta,schafskäse,hirtenkäse", 270, 17, 0.5, 0.5, 22, 0, pck=200)
N("halloumi", 320, 21, 2, 2, 26, 0, pck=225)
N("paneer", 300, 19, 4, 3, 23, 0)
N("parmesan,pecorino,grana,kefalotyri,ricotta salata,parmesanrinde,geriebener parmesan", 400, 33, 0, 0, 29, 0, el=6, tl=2, st=20)
N("bergkäse,gruyère,greyerzer,emmentaler,gouda,cheddar,raclettekäse,vacherin,=käse,geriebener käse,"
  "geriebener cheddar,appenzeller,allgäuer", 390, 27, 0, 0, 31, 0, scheibe=25, hand=30, el=7)
N("camembert,brie", 300, 20, 0, 0, 24, 0, st=250)
N("gorgonzola,blauschimmelkäse", 350, 19, 0, 0, 30, 0)
N("=ei,=eier,sehr frische eier,ganzes ei,kleine eier,gekochte eier", 145, 12.5, 0.7, 0.7, 10, 0, st=58)
N("eigelb", 330, 16, 0.3, 0.3, 29, 0, st=18)
N("eiweiß,eiklar", 48, 11, 0.7, 0.7, 0.2, 0, st=33)
N("hafermilch,haferdrink,mandeldrink,sojadrink", 45, 0.5, 6.5, 3.5, 1.5, 0.8, el=15)
N("kokosmilch,kokossahne", 180, 2, 3, 2, 18, 0, el=15, dose=400)
N("kokoswasser", 19, 0.7, 3.7, 2.6, 0.2, 1)
N("kondensmilch", 130, 6.5, 10, 10, 7.5, 0, el=15)

# ---------- Fleisch ----------
N("hähnchenbrust,hähnchenbrustfilet,hähnchenfilet,hühnerbrust,=hähnchen,hähnchenfleisch,hühnchen,=huhn", 110, 23, 0, 0, 1.5, 0, st=180)
# Mit Knochen: Werte je 100 g Einkaufsgewicht (gut ein Viertel ist Knochen)
N("hähnchenschenkel,hähnchenkeule,hähnchenteile", 135, 13, 0, 0, 9, 0, st=250)
N("hähnchenunterschenkel", 135, 13, 0, 0, 9, 0, st=120)
N("schenkelfilet", 160, 18, 0, 0, 9, 0, st=120)
N("hähnchenschenkel ohne knochen", 160, 18, 0, 0, 9, 0, st=120)
N("hähnchenflügel,chicken wings", 140, 12, 0, 0, 10, 0, st=90)
N("suppenhuhn", 180, 18, 0, 0, 12, 0, st=1500)
N("hähnchenhack", 150, 18, 0, 0, 8, 0)
N("putenbrust,putenschnitzel,putenfleisch,=pute", 105, 24, 0, 0, 1, 0, st=150)
N("rinderhack,rinderhackfleisch", 250, 18, 0, 0, 20, 0)
N("gemischtes hack,gemischtes hackfleisch,=hack,=hackfleisch", 260, 17, 0, 0, 21, 0)
N("schweinehack,mett", 270, 17, 0, 0, 22, 0)
N("lammhack", 280, 17, 0, 0, 23, 0)
N("rindfleisch,rindergulasch,rinderhüfte,rumpsteak,rindersteak,rinderfilet,rinderlende,roastbeef,rinderroulade,"
  "rinderschmorbraten,rindswade,tafelspitz,beinscheibe,rinderbraten,rindfleischstreifen,=filet,hüfte,suppenfleisch",
  150, 21, 0, 0, 7, 0, st=200)
N("rinderbrust", 250, 18, 0, 0, 20, 0)
N("kalbsschnitzel,kalbsfilet,kalbfleisch", 110, 21, 0, 0, 2.5, 0, st=130)
N("kalbshaxe", 140, 20, 0, 0, 6, 0, st=1200)
N("kalbsbrät,brät", 250, 11, 1, 0, 22, 0)
N("schweinenacken", 200, 18, 0, 0, 14, 0, st=180)
N("schweinebauch", 380, 14, 0, 0, 36, 0)
N("schweinefilet,schweineschnitzel,=schnitzel", 110, 22, 0, 0, 2, 0, st=150)
N("schweinekotelett,kotelett", 150, 21, 0, 0, 7, 0, st=200)
N("schweinegulasch,schweinefleisch,schweineschulter,schweinebraten", 180, 19, 0, 0, 12, 0)
N("schäufele,schweineschäufele", 220, 17, 0, 0, 17, 0)
N("kassler,kasseler,kasslerkotelett", 140, 20, 0.5, 0, 6, 0, st=200)
N("=lamm,lammschulter,lammfleisch,lammkeule,lammkotelett", 230, 17, 0, 0, 18, 0)
N("=reh,hirsch,hirschgulasch,wildgulasch,rehkeule", 120, 22, 0, 0, 3, 0)
N("ente,entenbrust", 240, 19, 0, 0, 18, 0, st=350)
N("gänsekeule,gans", 290, 16, 0, 0, 25, 0, st=400)
N("speck,speckwürfel,frühstücksspeck,bacon,durchwachsener speck,geräucherter speck,pancetta,guanciale,"
  "speckscheiben,scheiben speck,lardo", 400, 14, 0, 0, 38, 0, scheibe=15, st=15)
N("kochschinken,=schinken,schinkenstreifen", 110, 20, 1, 1, 3, 0, scheibe=20)
N("parmaschinken,serrano,rohschinken,prosciutto,bündnerfleisch", 250, 26, 0, 0, 16, 0, scheibe=15)
N("salami", 400, 22, 1, 1, 34, 0, scheibe=8)
N("chorizo", 450, 24, 2, 1, 38, 0)
N("wiener würstchen,würstchen,saitenwürstchen,saitenwürstle,frankfurter", 270, 13, 1, 1, 24, 0, st=50)
N("bratwurst,bratwürste,fränkische bratwürste,grobe bratwürste", 300, 14, 0.5, 0, 27, 0, st=110)
N("nürnberger rostbratwürste,nürnberger", 300, 14, 0.5, 0, 27, 0, st=25)
N("krakauer,kabanos,mettenden,pinkelwürste,pinkel", 320, 15, 1, 0, 29, 0, st=100)
N("fleischwurst,lyoner", 280, 12, 1, 1, 25, 0, st=200, scheibe=20)
N("leberkäse", 300, 12, 1, 1, 27, 0, scheibe=150)
N("merguez", 300, 15, 1, 0, 26, 0, st=60)
N("salsiccia", 300, 15, 1, 0, 26, 0, st=100)
N("corned beef", 210, 22, 0.5, 0, 13, 0, dose=340)
N("rinderknochen,markknochen,knochen", 0, 0, 0, 0, 0, 0)

# ---------- Fisch ----------
N("lachs,lachsfilet,lachs in sushiqualität", 200, 20, 0, 0, 13, 0, st=150)
N("räucherlachs", 180, 23, 0, 0, 10, 0, scheibe=15)
N("kabeljau,kabeljaufilet,seelachs,fischfilet,weißes fischfilet,festes fischfilet,dorsch,=fisch,zander,rotbarsch",
  80, 18, 0, 0, 0.8, 0, st=150)
N("forelle,forellen,küchenfertige forellen", 70, 12, 0, 0, 2.5, 0, st=300)
N("karpfen", 70, 11, 0, 0, 3, 0, st=1500)
N("thunfisch,thunfisch in öl", 190, 25, 0, 0, 10, 0, dose=150)
N("thunfischsteak", 110, 23, 0, 0, 1.5, 0, st=180)
N("garnele,shrimps,scampi", 80, 18, 0, 0, 0.8, 0, st=15)
N("miesmuscheln,muscheln", 25, 4, 1, 0, 0.6, 0)
N("matjes,matjesfilets", 260, 16, 0, 0, 22, 0, st=60)
N("rollmops,rollmöpse", 160, 14, 6, 5, 9, 0, st=70)
N("sardellen,sardellenfilets,anchovis", 210, 29, 0, 0, 10, 0, st=4)
N("surimi,surimi-sticks", 100, 8, 15, 4, 1, 0, st=17)
N("bonitoflocken", 350, 75, 0, 0, 3, 0, el=2)
N("fischfrikadellen", 180, 12, 12, 1, 9, 0.5, st=40)
N("tk-gyoza,gyoza", 200, 8, 28, 2, 6, 2, st=20)
N("falafel", 330, 13, 32, 2, 18, 5, st=20)

# ---------- Saucen, Öle, Würzpasten ----------
N("=öl,olivenöl,sesamöl,neutrales öl,rapsöl,sonnenblumenöl,kokosöl,chiliöl,kürbiskernöl,mildes olivenöl,frittieröl,"
  "pflanzenöl,erdnussöl", 884, 0, 0, 0, 100, 0, el=12, tl=4, dichte=0.92)
N("sojasauce,helle sojasauce,dunkle sojasauce,tamari", 60, 8, 6, 1, 0, 0, el=16, tl=6)
N("ketjap manis", 300, 2, 70, 60, 0, 0, el=20, tl=7)
N("hoisinsauce,=hoisin", 220, 3, 44, 27, 3.4, 2.8, el=18, tl=6)
N("austernsauce,vegetarische austernsauce", 100, 2, 22, 20, 0.3, 0, el=18, tl=6)
N("fischsauce", 35, 5, 4, 4, 0, 0, el=18, tl=6)
N("mirin", 240, 0.3, 43, 43, 0, 0, el=16, tl=5)
N("sake,shaoxing-wein,reiswein", 110, 0.5, 5, 0, 0, 0, el=15)
N("=essig,reisessig,schwarzer reisessig,weißweinessig,rotweinessig,apfelessig,sherryessig,chinkiang-essig", 20, 0, 1, 0.5, 0, 0, el=15, tl=5)
N("balsamico", 88, 0.5, 17, 15, 0, 0, el=15, tl=5)
N("=senf,mittelscharfer senf,dijonsenf,körniger senf,scharfer senf", 90, 6, 5, 2, 5, 2, el=15, tl=5)
N("süßer senf", 150, 4, 25, 20, 4, 2, el=15, tl=5)
N("mayonnaise,japanische mayonnaise,mayo", 700, 1, 1, 1, 77, 0, el=15, tl=5)
N("ketchup,tomatenketchup", 110, 1.5, 25, 23, 0.2, 0.5, el=17, tl=6)
N("bbq-sauce,barbecuesauce", 170, 1, 40, 33, 0.5, 0.5, el=17, tl=6)
N("worcestersauce,worcestershiresauce,okonomiyaki-sauce,tonkatsu-sauce", 120, 1, 28, 22, 0.1, 0, el=16, tl=5)
N("sriracha,sambal oelek,=sambal,scharfe chilisauce", 90, 2, 17, 12, 1, 2, el=16, tl=5)
N("süß-scharfe chilisauce,sweet chili", 220, 0.5, 54, 50, 0.5, 1, el=18, tl=6)
N("gochujang", 230, 5, 48, 22, 2, 2, el=20, tl=7)
N("doubanjiang,fermentierte schwarze bohnen", 180, 8, 20, 8, 7, 4, el=18, tl=6)
N("misopaste,=miso,helle misopaste", 200, 12, 26, 6, 6, 5, el=18, tl=6)
N("tahin,tahinsauce,sesampaste", 600, 18, 21, 0.5, 54, 9, el=15, tl=5)
N("erdnussbutter,erdnussmus", 600, 25, 16, 8, 50, 6, el=16, tl=5)
N("currypaste,rote currypaste,grüne currypaste,gelbe currypaste,massaman-currypaste,nam prik pao", 120, 3, 12, 5, 6, 4, el=15, tl=5)
N("harissa", 100, 3, 10, 5, 5, 4, el=15, tl=5)
N("tamarindenpaste,tamarinde", 240, 2.8, 60, 40, 0.6, 5, el=18, tl=6)
N("ajvar", 80, 1.5, 9, 7, 4, 3, el=15)
N("żur,zur", 30, 1, 5, 1, 0.5, 0.5)
N("salsa", 30, 1.5, 6, 4, 0.2, 1.5, el=15, st=300)
N("salsa verde,pesto", 450, 4, 5, 2, 45, 2, el=15)
N("guacamole", 150, 2, 8, 1, 13, 6, el=20)
N("hummus", 250, 8, 14, 0.5, 17, 6, el=20)
N("tzatziki", 120, 4, 4, 3, 10, 0.5, el=20)
N("remoulade,senf-mayonnaise,knoblauchsauce,burgersauce", 450, 1, 6, 5, 46, 0.5, el=15)
N("mango-chutney,chutney", 230, 0.6, 55, 50, 0.2, 1, el=20, tl=7)
N("ingwer-knoblauch-paste", 100, 3, 15, 1, 3, 2, el=15, tl=5)
N("eingelegter ingwer", 50, 0.3, 12, 10, 0.1, 1, el=10)
N("japanische currywürfel,currywürfel", 500, 6, 45, 5, 33, 3, wuerfel=20, st=20)
N("röstzwiebeln", 560, 6, 40, 6, 42, 5, el=5)
N("brühe,gemüsebrühe,hühnerbrühe,rinderbrühe,fleischbrühe,heiße brühe,dashi,=fond,fischfond,kalbsfond,wildfond,"
  "geflügelfond,bratenfond,gemüsefond,brühwürfel", 6, 0.6, 0.5, 0.3, 0.3, 0, el=15, wuerfel=500)
N("=wasser,lauwarmes wasser,warmes wasser,heißes wasser,kaltes wasser,eiswasser,eiswürfel", 0, 0, 0, 0, 0, 0, el=15, st=0)
N("weißwein,rotwein,trockener weißwein,trockener rotwein,kräftiger rotwein,=wein", 70, 0.1, 2.6, 1, 0, 0, el=15)
N("=bier,weißbier,dunkles bier", 43, 0.5, 3.5, 0.3, 0, 0)
N("amaretto,kirschwasser,=rum,likör,=schnaps", 250, 0, 15, 15, 0, 0, el=15)
N("espresso,kaffee,starker espresso,kalter starker kaffee,=tee,schwarzer tee,früchtetee", 2, 0.1, 0.3, 0, 0, 0, el=15)
N("apfelsaft,naturtrüber apfelsaft,orangensaft,ananassaft,kirschsaft,rote-bete-saft,traubensaft,=saft", 45, 0.3, 10.5, 10, 0.1, 0.2, el=15)

# ---------- Tofu & Co. ----------
N("tofu,fester tofu,räuchertofu", 145, 15, 2, 0.5, 8.7, 2)
N("seidentofu,weicher tofu", 55, 5, 2, 1, 3, 0.3)
N("tempeh", 190, 19, 9, 0, 11, 6)

# ---------- Kein Essen ----------
N("airfryer-geeignete form,holzspieße,backpapier,küchengarn,tarteform,springform,kuchenform,belag nach wahl,"
  "spieße,frischhaltefolie,alufolie,=form,pandanblatt", 0, 0, 0, 0, 0, 0, st=0)


# ============================================================
# Zutat → Lebensmittel

PLURAL = ("", "e", "n", "en", "s", "er", "es")


def _norm(name):
    n = name.lower()
    n = re.sub(r"\([^)]*\)", " ", n)
    n = n.split(",")[0]
    alts = [a.strip() for a in re.split(r"\s+oder\s+|\s+und\s+|\s*\+\s*", n) if a.strip()]
    # „Lamm- oder Rinderhack“: der erste Teil ist nur ein Wortanfang → den letzten nehmen
    n = alts[-1] if alts and alts[0].endswith("-") else (alts[0] if alts else n)
    return " " + re.sub(r"\s+", " ", n).strip() + " "


def _hit(text, key):
    """Passt das Stichwort? ganz = nur als Wort; sonst Wortanfang oder Ende eines zusammengesetzten Worts."""
    whole = key.startswith("=")
    k = key.lstrip("=")
    for m in re.finditer(re.escape(k), text):
        a, b = m.start(), m.end()
        before = text[a - 1] if a > 0 else " "
        rest = re.match(r"[a-zäöüß]*", text[b:]).group(0)
        if whole:
            if before == " " and rest in PLURAL:
                return True
            continue
        if before == " " or before == "-":
            return True            # Wortanfang: „tomaten“, „kartoffelstärke“ (falls kein längeres Stichwort)
        if rest in PLURAL:
            return True            # Ende eines Worts: „kirschtomaten“, „knoblauchzehen“
    return False


_CACHE = {}


def find(name):
    if name in _CACHE:
        return _CACHE[name]
    t = _norm(name)
    best, blen = None, 0
    for f in FOODS:
        for k in f["keys"]:
            L = len(k.lstrip("="))
            if L > blen and _hit(t, k):
                best, blen = f, L
    _CACHE[name] = best
    return best


# ============================================================
# Menge → Gramm

FRAC = {"½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1 / 3, "⅔": 2 / 3}


def _number(s):
    s = s.strip()
    m = re.match(r"^(?:ca\.\s*)?(\d+(?:[.,]\d+)?)?\s*([½¼¾⅓⅔])?(?:\s*[–-]\s*(\d+(?:[.,]\d+)?))?\s*(.*)$", s)
    if not m or (m.group(1) is None and m.group(2) is None):
        return None, s
    n = float(m.group(1).replace(",", ".")) if m.group(1) else 0
    n += FRAC.get(m.group(2), 0) if m.group(2) else 0
    if m.group(3):
        n = (n + float(m.group(3).replace(",", "."))) / 2
    return n, m.group(4).strip()


UNIT = [  # (Muster, Feld im Lebensmittel, Ersatzwert in g)
    (r"^kg\b", None, 1000), (r"^g\b", None, 1), (r"^l\b", "ml", 1000), (r"^ml\b", "ml", 1), (r"^cl\b", "ml", 10),
    (r"^el\b", "el", 12), (r"^tl\b", "tl", 4), (r"^prise", None, 0.4), (r"^msp", None, 0.5),
    (r"^handvoll", "hand", 30), (r"^bund", "bund", 25), (r"^scheibe", "scheibe", 25), (r"^dose", "dose", 400),
    (r"^glas", "dose", 300), (r"^(pck|päckchen|packung|beutel)", "pck", 10), (r"^würfel", "wuerfel", 10),
    (r"^zweig", None, 1.5), (r"^stängel", None, 15), (r"^stange", "stange", 60), (r"^spritzer", None, 3),
    (r"^rolle", "pck", 275), (r"^kugel", "st", 125), (r"^(blatt|blätter)", "blatt", 2), (r"^streifen", None, 5),
    (r"^paar", None, 100), (r"^(stück|stk)", "st", 100), (r"^kopf", "st", 500), (r"^knolle", None, 50),
    (r"^(zehe|zehen)", None, 4), (r"^tasse", None, 150), (r"^becher", "pck", 200),
]


def grams(amount, food):
    """Menge in Gramm – None, wenn sie sich nicht sinnvoll lesen lässt."""
    a = (amount or "").strip()
    if not a:
        return None
    n, rest = _number(a)
    if n is None:
        return None
    r = rest.lower()
    # „1 Dose (400 g)“, „2 Dosen (je 400 g)“
    m = re.search(r"\((?:je\s*)?(?:ca\.\s*)?(\d+(?:[.,]\d+)?)\s*(g|ml|kg)\)", r)
    if m:
        v = float(m.group(1).replace(",", ".")) * (1000 if m.group(2) == "kg" else 1)
        return n * v
    # „1 Stück (3 cm)“ Ingwer
    m = re.search(r"\((\d+)\s*cm\)", r)
    if m:
        return n * int(m.group(1)) * 5
    if r in ("portionen", "portion"):
        return n * 90                          # „2 Portionen Ramen-Nudeln“
    if r == "rezept":
        return None
    for pat, field, default in UNIT:
        if re.match(pat, r):
            if field == "ml":
                return n * default * (food["dichte"] if food else 1)
            v = food.get(field) if (food and field) else None
            if field == "tl" and v is None and food and food.get("el"):
                v = food["el"] / 3
            return n * (v if v is not None else default)
    # nur eine Zahl: Stück
    if r == "" or re.match(r"^(große?|kleine?|mittelgroße?)\b", r):
        st = food.get("st") if food else None
        return n * st if st is not None else None
    return None


NAME_UNIT = re.compile(r"^(bund|scheiben?|zweige?|stängel|blätter|blatt|kopf|stangen?|dosen?|handvoll|packungen?|päckchen)\s+(.*)$")


def resolve(ing):
    """Zutat → (Name zum Nachschlagen, Menge, Gramm falls schon klar).
    „8 | Scheiben Baguette“ → Menge „8 Scheiben“; „2 | Kalbsschnitzel (je 150 g)“ → 300 g;
    „2 TL Paprika“ ist Paprikapulver, nicht die Schote."""
    name, amount = ing["name"], (ing.get("amount") or "").strip()
    n, rest = _number(amount) if amount else (None, "")
    low = name.lower().strip()
    m = NAME_UNIT.match(low)
    if n is not None and rest == "" and m:
        amount, name = f"{amount} {m.group(1)}", m.group(2)
    m = re.search(r"\(je\s*(?:ca\.\s*)?(\d+)\s*(g|kg)", low)
    if n is not None and m:
        return name, amount, n * int(m.group(1)) * (1000 if m.group(2) == "kg" else 1)
    f = find(name)
    if f and "=paprika" in f["keys"] and re.match(r"^\s*[\d½¼¾,.–-]*\s*(tl|el|prise|msp)", amount.lower()):
        return "paprikapulver", amount, None
    return name, amount, None


# ============================================================
# Rezept → Nährwerte pro Portion

SERVE = re.compile(r"zum (servieren|bestreuen|bestäuben|garnieren|dippen|füllen|belegen|beträufeln|einwickeln|binden)"
                   r"|nach (geschmack|belieben)")
FRY = re.compile(r"frittier|ausbacken|ausgebacken|schwimmend|zum backen in")


def recipe(r):
    """r: Rezept-JSON (wie in apps/rezepte/data). Gibt (Werte pro Portion, Liste offener Zutaten) zurück."""
    tot = [0.0] * 6
    missing = []
    group = ""
    steps = " ".join(x["text"] for x in r["steps"]).lower()
    for ing in r["ingredients"]:
        if "group" in ing and "name" not in ing:
            group = ing["group"].lower()
            continue
        name, amount, g = resolve(ing)
        food = find(name) if name else None
        low = ing["name"].lower()
        hint = " ".join(re.findall(r"\(([^)]*)\)", low)) + " " + low
        if g is None:
            g = grams(amount, food)
        if g is None:
            if re.search(r"zum (an)?braten|zum einfetten|für die (form|pfanne)", hint) and food:
                g = 8
            elif SERVE.search(hint) or not (ing.get("amount") or "").strip():
                continue                       # zum Servieren, Salz nach Geschmack: nicht mitgerechnet
            else:
                missing.append(f"{ing.get('amount')} | {name}")
                continue
        if food is None:
            missing.append(f"{ing.get('amount')} | {name}")
            continue
        if FRY.search(hint) or FRY.search(group):
            g *= 0.06                          # Frittieröl: nur was ans Essen geht
        elif food["v"][4] >= 80 and g >= 100 and FRY.search(steps):
            g *= 0.25                          # Schwimmend ausbacken: ein Teil bleibt in der Pfanne
        for i in range(6):
            tot[i] += food["v"][i] * g / 100
    s = max(1, r.get("servings") or 2)
    kcal, p, kh, z, f, bs = (x / s for x in tot)
    out = {"kcal": int(round(kcal / 10) * 10), "p": round(p), "kh": round(kh), "z": round(z), "f": round(f), "bs": round(bs)}
    return out, missing


def export():
    """Tabelle für die App: Stichwörter, Werte je 100 g, Gewichte je Einheit, Dichte."""
    out = []
    for f in FOODS:
        w = {k: f[k] for k in ("st", "el", "tl", "bund", "hand", "scheibe", "dose", "pck", "wuerfel", "stange", "blatt")
             if f[k] is not None}
        e = {"k": f["keys"], "v": list(f["v"]), "w": w}
        if f["cat"]:
            e["c"] = f["cat"]
        if f["dichte"] != 1.0:
            e["d"] = f["dichte"]
        out.append(e)
    return {"version": 1, "foods": out}


# ============================================================
# Prüfen

if __name__ == "__main__":
    import json, glob, os, collections
    here = os.path.dirname(os.path.abspath(__file__))
    data = os.path.join(here, "..", "..", "apps", "rezepte", "data")
    rows, miss = [], collections.Counter()
    for fn in sorted(glob.glob(os.path.join(data, "*.json"))):
        if fn.endswith(("index.json", "naehrwerte.json")):
            continue
        r = json.load(open(fn, encoding="utf-8"))
        v, m = recipe(r)
        rows.append((v["kcal"], r["id"], r.get("cat"), r.get("servings"), v))
        for x in m:
            miss[x] += 1
    print("Offen:", sum(miss.values()))
    for k, n in miss.most_common(80):
        print(f"  {n}× {k}")
    rows.sort()
    print("\nNiedrigste:")
    for x in rows[:25]:
        print("  ", x)
    print("Höchste:")
    for x in rows[-25:]:
        print("  ", x)
