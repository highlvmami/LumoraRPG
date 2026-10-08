# LumoraRPG

Megabonk tarzı, **3D pixel-art roguelike survivor** masaüstü oyunu. Godot 4 ile yapılıyor.

Tasarım ve yol haritası: [docs/ROADMAP.md](docs/ROADMAP.md)

## Tarayıcıda oyna

https://highlvmami.github.io/LumoraRPG/ — `main` dalına her birleştirmede otomatik güncellenir.

## Windows'ta oyna (daha hızlı)

[LumoraRPG-windows.zip](https://github.com/highlvmami/LumoraRPG/releases/download/latest/LumoraRPG-windows.zip) — zip'i aç, `LumoraRPG.exe`'ye çift tıkla. Oyun her açılışta kendini otomatik günceller (sadece küçük oyun paketini indirir), zip'i bir kere indirmen yeterli. Windows "tanınmayan uygulama" uyarısı verirse **Daha fazla bilgi → Yine de çalıştır**. Masaüstü sürümünün kayıtları tarayıcıdakinden ayrıdır.

## Godot ile çalıştırma

1. [Godot 4.5](https://godotengine.org/download) (standart sürüm, .NET gerekmez) indir.
2. Godot'u aç → **Import** → bu klasördeki `project.godot` dosyasını seç.
3. **F5** (veya sağ üstteki ▶) ile oyunu başlat.

## Oynanış

Girişte **Kayıt Ol** ile kullanıcı adı ve şifreyle hesap aç, sonra **Giriş Yap** ile gir. Hesaplar çevrimiçidir: hesabın ve oyunun (karakterler, eşyalar, altın, seviyeler) sunucuda saklanır, aynı hesapla her bilgisayardan girebilirsin; şifre hiçbir yerde açık hâlde kaydedilmez. Bu bilgisayarda daha önce açılmış bir hesap ilk girişte kendiliğinden çevrimiçi olur. Sunucuya ulaşılamazsa bu bilgisayardaki hesabınla çevrimdışı oynarsın, bağlantı gelince oyunun sunucuya gönderilir. "Beni hatırla" seçiliyse oyun bu bilgisayarda bir daha şifre sormadan açılır; Ayarlar → Hesap'tan çıkış yapabilir, şifreni değiştirebilir ya da hesabı tamamen sıfırlayabilirsin. Her oyun rastgele bir haritada başlar ve haritanın adı ekranda yazar: **Sakin Orman**, **Sahil Kasabası** ya da **Ölümcül Zindan**. Fare tekerleğiyle kamerayı yaklaştırıp uzaklaştırabilirsin. Ana menüde hesap seviyeni görürsün; **Oyna**, **Karakterler**, **Ekipman**, **Çanta**, **Yetenek Ağacı**, **Market**, **Başarımlar**, **Profil**, **Arkadaşlar**, **Kayıtlar** (geçmiş oyunlar), **Sürümler** (yenilikler) ve **Ayarlar** bölümleri vardır.

Hesapta en fazla 3 karakter açılır, her biri bir sınıftır: **Savaşçı** (kılıçla önündeki düşmanları biçer, canı yüksek), **Okçu** (uzaktan ok atar) ve **Büyücü** (büyü küresi fırlatır, kritikleri güçlü). Karakterler ekranında her karakterin üstündeki eşyalar görünür.

**Çanta tüm karakterlerin ortak çantasıdır.** Canavarlar bazen eşya düşürür, her boss bir **kasa** bırakır. Eşyaların 6 nadirliği vardır: Sıradan, Nadir, Çok Nadir, Epik, Efsanevi, Tanrısal. Nadirlik arttıkça eşyanın bonusları güçlenir ve çoğalır, silahlar daha detaylı görünür (karakterin elindeki silah da değişir). Her karakterin 6 ekipman yuvası vardır: silah, kask, zırh, eldiven, çizme, yüzük; silahlar sınıfa özeldir. Kasalar (Sıradan, Nadir, Epik, Efsanevi) Çanta'dan açılır: çark döner, yavaşlar ve kazandığın eşyada durur. Market'ten kasa da alınabilir. Kasa nadirliği arttıkça kasanın şekli de değişir: sade sandık, demir kuşaklı kasa, mücevher kilitli süslü sandık ve kanatlı, taçlı altın hazine kasası. Bir eşyanın üstüne gelince özellikleri hemen görünür ve aktif karakterin o yuvada taktığı eşyayla karşılaştırılır: daha iyi olan değerler yeşil ▲, daha kötü olanlar kırmızı ▼ gösterilir.

Oyunda canavarlar etrafında doğar, karakterin menzil çemberine giren en yakın canavara otomatik ok atar. Her ölen canavar EXP ve altın verir: **karakter seviyesi** her oyunda 1'den başlar ve seni güçlendirir, **hesap seviyesi** kalıcıdır. Altınla Market'ten kasa alır, **Yetenek Ağacı**'nda kalıcı yetenekler öğrenirsin: Saldırı, Savunma ve Talih dallarında 18 yetenek (hasar, can, saldırı hızı, hareket hızı, kritik, menzil, can yenileme, EXP ve altın kazancı) seviye seviye öğrenilir, her seviye küçük bir bonus verir (ör. +%1 hasar) ve fiyatı artar. Alttaki yetenekler, üstündekiler yeterli seviyeye gelince açılır. Eski market geliştirmelerinin seviyeleri ağaca aynen taşınır.

Boss'lar canları 2/3'ün altına inince **öfkelenir**, 1/3'ün altında **çıldırır**: her evrede yeni saldırılar (yer yarığı, şok dalgası halkaları, ışın yıldızı, ağ çemberi) açılır, saldırılar karışık sırayla ve daha hızlı gelir. Aynı oyunda sonraki boss'lar daha baştan daha sert başlar. Haritada çalılar, çimenler, çiçek tarhları, mantar halkaları, devrilmiş kütükler, nilüferli göletler, kamp ateşli taş çemberler ve ateş böcekleri vardır.

Her seviye atlayışta oyun **durmaz**: ekranın altında 3 kart açılır, oynamaya devam ederken istediğin an tıklayarak ya da 1 · 2 · 3 tuşlarıyla seçersin (art arda seviye atlarsan seçimler sıraya girer). Kartlarda güçlendirmeler (hasar, saldırı hızı, saldırı alanı, kritik şansı, kritik hasarı, can, hız, can yenileme) ve sınıfına özel bir güçlendirme vardır: Okçu **Çift Ok** (şansla aynı anda 2 ok), Savaşçı **Çifte Savuruş**, Büyücü **Büyü Yankısı**. Boostlar o oyun boyunca geçerlidir. Alt ortadaki panel canını, EXP'ni, altınını ve tüm istatistiklerini gösterir.

Düşmanlar zamanla çeşitlenir ve güçlenir: balçık (başta), hızlı **kurt** (30 sn), uzaktan taş atan **goblin** (1 dk) ve canı/hasarı yüksek **dev örümcek** (1.5 dk). Ölen düşmanlar mavi EXP ve sarı altın topları saçar.

Seviye kartlarında yeni **silahlar** da çıkar (sınıf silahının yanında 5 silaha kadar, yani tüm silahlar alınabilir; her biri 5 seviye): **Dönen Kılıçlar**, **Ateş Topu**, **Yıldırım**, **Kutsal Alan** ve sınıfa özel skill: Okçu **Ok Yağmuru** (gökten ok yağar), Büyücü **Meteor** (gökten dev ateş topu), Savaşçı **Kalkan Darbesi** (etraftaki düşmanları vurup uzağa iter). Her 5 dakikada bir boss gelir: önce dev **Orman Devi**, sonra **Örümcek Kraliçe** (sırayla). Boss gelince diğer canavarlar çekilir ve boss tek başına savaşır; ekranın üstünde can barı görünür. Boss'lar saldırmadan önce vuracakları yeri yerde **kırmızı alanla** gösterir, alan dolunca vurur: Orman Devi yere vurur, ileri atılır ve gökten kaya yağdırır; Örümcek Kraliçe üstüne sıçrar, ağ fırlatır, gökten yumurta yağdırır ve atılır. Alandan zamanında çıkan hasar almaz.

**Başarımlar** menüsünde 17 hedef vardır (canavar kesme, boss yenme, seviye, hayatta kalma süresi, altın, eşya, kasa, geliştirme, arkadaş); her biri tamamlanınca altın ödülü verir. **Arkadaşlar** bölümünde bu cihazda oynayan diğer oyuncular (ortak arkadaşı olanlar önce) arkadaş olarak önerilir.

**Birlikte oyna:** Arkadaşlar bölümündeki **Birlikte Oyna** kutusunda oda kur, çevrimiçi arkadaşına **Odaya davet et** de ya da ona 5 harfli oda kodunu ver (en fazla 4 kişi). Davet gelen oyuncuya "Katıl" diye sorulur. Arkadaşlar sayfasındaki **Şu an çevrimiçi** listesinden oyuncuları ekleyebilir ya da davet edebilirsin. Ev sahibi **OYNA**'ya basınca odadaki herkes aynı haritada canlı birlikte oynar (sol ortada partinin karakter adları ve can barları görünür): düşmanlar en yakın oyuncuya saldırır, kesilen canavarların EXP ve altını herkese gider, kalabalık odada daha çok düşman gelir. Oyunu ev sahibinin bilgisayarı yönetir; ev sahibi çıkarsa oyun herkes için biter. Bağlantı `server/` klasöründeki küçük Node.js sunucusundan geçer (Render'da `lumora-online` servisi; hesaplar `DATABASE_URL` ile bağlanan `lumora-accounts` Postgres veritabanında, o yoksa sunucu hafızasında tutulur). Ücretsiz sunucu kimse oynamazken uyur; ilk bağlantı bir dakika kadar sürebilir. Yerelde denemek için: `cd server && npm install && node index.js`, oyunu `-- --server=ws://localhost:8080` ile aç.

## Kontroller

| Tuş | Eylem |
|---|---|
| WASD / ok tuşları | Yürü |
| Boşluk | Zıpla |
| Fare | Kamerayı döndür (önce oyun penceresine tıkla) |
| Esc / P | Oyunu duraklat (devam, kalite, ana menü, boostlar) |
| F1 | Geliştirici hile menüsü (sağ kenardaki HİLE düğmesi de açar): istatistikler, EXP/altın çarpanı, boss çağırma, eşya ve kasa |
| Boşluk / Enter | Kasa çarkını hızlıca durdur |

## Klasörler

- `scripts/` oyun kodu (GDScript)
- `data/` ayar ve denge değerleri (JSON) — sayıları değiştirmek için kodu açmaya gerek yok
- `tests/` otomatik testler; her PR'da GitHub Actions üzerinde Godot ile çalışır

Testi yerelde çalıştırmak için:

```
godot --headless --path . -s res://tests/smoke_test.gd
```
