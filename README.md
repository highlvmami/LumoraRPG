# LumoraRPG

Megabonk tarzı, **3D pixel-art roguelike survivor** masaüstü oyunu. Godot 4 ile yapılıyor.

Tasarım ve yol haritası: [docs/ROADMAP.md](docs/ROADMAP.md)

## Tarayıcıda oyna

https://highlvmami.github.io/LumoraRPG/ — `main` dalına her birleştirmede otomatik güncellenir.

## Godot ile çalıştırma

1. [Godot 4.5](https://godotengine.org/download) (standart sürüm, .NET gerekmez) indir.
2. Godot'u aç → **Import** → bu klasördeki `project.godot` dosyasını seç.
3. **F5** (veya sağ üstteki ▶) ile oyunu başlat.

## Oynanış

Girişte bir kullanıcı adı yaz (yeni ad = yeni hesap; hesap bu cihazda saklanır). Ana menüde hesap seviyeni görürsün; **Oyna**, **Karakterler**, **Ekipman**, **Çanta**, **Market**, **Profil** ve **Arkadaşlar** bölümleri vardır.

Hesapta en fazla 3 karakter açılır, her biri bir sınıftır: **Savaşçı** (kılıçla önündeki düşmanları biçer, canı yüksek), **Okçu** (uzaktan ok atar) ve **Büyücü** (büyü küresi fırlatır, kritikleri güçlü). Karakterler ekranında her karakterin üstündeki eşyalar görünür.

**Çanta tüm karakterlerin ortak çantasıdır.** Canavarlar bazen eşya düşürür, her boss bir **kasa** bırakır. Eşyaların 6 nadirliği vardır: Sıradan, Nadir, Çok Nadir, Epik, Efsanevi, Tanrısal. Nadirlik arttıkça eşyanın bonusları güçlenir ve çoğalır, silahlar daha detaylı görünür (karakterin elindeki silah da değişir). Her karakterin 6 ekipman yuvası vardır: silah, kask, zırh, eldiven, çizme, yüzük; silahlar sınıfa özeldir. Kasalar (Sıradan, Nadir, Epik, Efsanevi) Çanta'dan açılır: çark döner, yavaşlar ve kazandığın eşyada durur. Market'ten kasa da alınabilir.

Oyunda canavarlar etrafında doğar, karakterin menzil çemberine giren en yakın canavara otomatik ok atar. Her ölen canavar EXP ve altın verir: **karakter seviyesi** her oyunda 1'den başlar ve seni güçlendirir, **hesap seviyesi** kalıcıdır. Altınla Market'ten eşya alırsın; çantandaki eşyalar her oyunda bonus verir.

Her seviye atlayışta oyun durur ve 3 rastgele güçlendirmeden (boost) birini seçersin: hasar, saldırı hızı, saldırı alanı, kritik şansı, kritik hasarı, can, hız veya can yenileme. Boostlar o oyun boyunca geçerlidir. Alt ortadaki panel canını, EXP'ni, altınını ve tüm istatistiklerini gösterir.

Düşmanlar zamanla çeşitlenir ve güçlenir: balçık (başta), hızlı **kurt** (30 sn), uzaktan taş atan **goblin** (1 dk) ve canı/hasarı yüksek **dev örümcek** (1.5 dk). Ölen düşmanlar mavi EXP ve sarı altın topları saçar.

Seviye kartlarında yeni **silahlar** da çıkar (sınıf silahının yanında en fazla 3 silah, her biri 5 seviye): **Dönen Kılıçlar**, **Ateş Topu**, **Yıldırım** ve **Kutsal Alan**. 5. ve 10. dakikada boss **Orman Devi** gelir; ekranın üstünde can barı görünür, her yöne taş saçar.

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
