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

Girişte bir kullanıcı adı yaz (yeni ad = yeni hesap; hesap bu cihazda saklanır). Ana menüde hesap seviyeni görürsün; **Oyna**, **Karakterler**, **Ekipman**, **Çanta**, **Market**, **Profil** ve **Arkadaşlar** bölümleri vardır.

Hesapta en fazla 3 karakter açılır, her biri bir sınıftır: **Savaşçı** (kılıçla önündeki düşmanları biçer, canı yüksek), **Okçu** (uzaktan ok atar) ve **Büyücü** (büyü küresi fırlatır, kritikleri güçlü). Karakterler ekranında her karakterin üstündeki eşyalar görünür.

**Çanta tüm karakterlerin ortak çantasıdır.** Canavarlar bazen eşya düşürür, her boss bir **kasa** bırakır. Eşyaların 6 nadirliği vardır: Sıradan, Nadir, Çok Nadir, Epik, Efsanevi, Tanrısal. Nadirlik arttıkça eşyanın bonusları güçlenir ve çoğalır, silahlar daha detaylı görünür (karakterin elindeki silah da değişir). Her karakterin 6 ekipman yuvası vardır: silah, kask, zırh, eldiven, çizme, yüzük; silahlar sınıfa özeldir. Kasalar (Sıradan, Nadir, Epik, Efsanevi) Çanta'dan açılır: çark döner, yavaşlar ve kazandığın eşyada durur. Market'ten kasa da alınabilir.

Oyunda canavarlar etrafında doğar, karakterin menzil çemberine giren en yakın canavara otomatik ok atar. Her ölen canavar EXP ve altın verir: **karakter seviyesi** her oyunda 1'den başlar ve seni güçlendirir, **hesap seviyesi** kalıcıdır. Altınla Market'ten kasa ve **kalıcı geliştirmeler** alırsın: 10 çeşit geliştirme (hasar, can, saldırı hızı, hareket hızı, kritik, menzil, can yenileme, EXP ve altın kazancı) seviye seviye alınır, her seviye küçük bir bonus verir (ör. +%1 hasar) ve fiyatı artar. Eski tek seferlik market eşyalarının altını iade edilir.

Her seviye atlayışta oyun **durmaz**: ekranın altında 3 kart açılır, oynamaya devam ederken istediğin an tıklayarak ya da 1 · 2 · 3 tuşlarıyla seçersin (art arda seviye atlarsan seçimler sıraya girer). Kartlarda güçlendirmeler (hasar, saldırı hızı, saldırı alanı, kritik şansı, kritik hasarı, can, hız, can yenileme) ve sınıfına özel bir güçlendirme vardır: Okçu **Çift Ok** (şansla aynı anda 2 ok), Savaşçı **Çifte Savuruş**, Büyücü **Büyü Yankısı**. Boostlar o oyun boyunca geçerlidir. Alt ortadaki panel canını, EXP'ni, altınını ve tüm istatistiklerini gösterir.

Düşmanlar zamanla çeşitlenir ve güçlenir: balçık (başta), hızlı **kurt** (30 sn), uzaktan taş atan **goblin** (1 dk) ve canı/hasarı yüksek **dev örümcek** (1.5 dk). Ölen düşmanlar mavi EXP ve sarı altın topları saçar.

Seviye kartlarında yeni **silahlar** da çıkar (sınıf silahının yanında 5 silaha kadar, yani tüm silahlar alınabilir; her biri 5 seviye): **Dönen Kılıçlar**, **Ateş Topu**, **Yıldırım**, **Kutsal Alan** ve sınıfa özel skill: Okçu **Ok Yağmuru** (gökten ok yağar), Büyücü **Meteor** (gökten dev ateş topu), Savaşçı **Kalkan Darbesi** (etraftaki düşmanları vurup uzağa iter). Her 5 dakikada bir boss gelir: önce dev **Orman Devi**, sonra **Örümcek Kraliçe** (sırayla). Boss gelince diğer canavarlar çekilir ve boss tek başına savaşır; ekranın üstünde can barı görünür. Boss'lar saldırmadan önce vuracakları yeri yerde **kırmızı alanla** gösterir, alan dolunca vurur: Orman Devi yere vurur, ileri atılır ve gökten kaya yağdırır; Örümcek Kraliçe üstüne sıçrar, ağ fırlatır, gökten yumurta yağdırır ve atılır. Alandan zamanında çıkan hasar almaz.

**Başarımlar** menüsünde 17 hedef vardır (canavar kesme, boss yenme, seviye, hayatta kalma süresi, altın, eşya, kasa, geliştirme, arkadaş); her biri tamamlanınca altın ödülü verir. **Arkadaşlar** bölümünde bu cihazda oynayan diğer oyuncular (ortak arkadaşı olanlar önce) arkadaş olarak önerilir.

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
