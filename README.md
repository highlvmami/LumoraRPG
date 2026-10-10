<div align="center">

# LumoraRPG

**Megabonk tarzı 3D pixel-art roguelike survivor: dalga dalga gelen canavarlar, kendiliğinden saldıran silahlar, boss'lar, petler, yetenek ağacı ve arkadaşlarınla canlı co-op.**

**[Tarayıcıda oyna →](https://highlvmami.github.io/LumoraRPG/)** · **[Windows için indir](https://github.com/highlvmami/LumoraRPG/releases/download/latest/LumoraRPG-windows.zip)**

Türkçe · [English](README.en.md)

<p>
  <img src="https://img.shields.io/badge/Godot-4.5-478CBF?logo=godotengine&logoColor=white" alt="Godot 4.5">
  <img src="https://img.shields.io/badge/GDScript-355570?logo=godotengine&logoColor=white" alt="GDScript">
  <img src="https://img.shields.io/badge/Node.js-20%2B-339933?logo=nodedotjs&logoColor=white" alt="Node.js">
  <img src="https://img.shields.io/badge/WebSocket-010101?logo=socketdotio&logoColor=white" alt="WebSocket">
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white" alt="PostgreSQL">
  <img src="https://img.shields.io/badge/Render-46E3B7?logo=render&logoColor=black" alt="Render">
  <img src="https://img.shields.io/badge/GitHub%20Actions-2088FF?logo=githubactions&logoColor=white" alt="GitHub Actions">
</p>

</div>

Bir karakter seçip açık bir haritaya iniyorsun; canavarlar her yönden gelir, silahların menzile gireni kendiliğinden vurur, sen de hareket edip hayatta kalmaya çalışırsın. Her seviyede üç karttan birini seçip o oyunluk güçlenirsin, her beş dakikada bir boss gelir. Oyun bitince kazandığın EXP, altın, eşya ve kasalar hesabında kalır: ekipman, petler ve yetenek ağacıyla bir sonraki oyuna daha güçlü başlarsın. Oyun Godot 4.5 ile yazıldı; tarayıcıda ve Windows'ta çalışır, çevrimiçi hesaplar ve co-op küçük bir Node.js sunucusundan geçer.

> Çevrimiçi sunucu Render'ın ücretsiz planında çalışıyor. Bir süre kimse bağlanmazsa uykuya geçer; sonraki ilk bağlantı bir dakika kadar sürebilir. Sunucuya ulaşılamazsa oyun bu cihazdaki hesapla çevrimdışı açılır.

## Ekran görüntüleri

<p align="center">
  <img src="docs/screenshots/sehir.jpg" alt="Ana menü: binalarıyla pikselli şehir" width="100%">
</p>

<p align="center">
  <img src="docs/screenshots/suru.jpg" alt="Karlı Dağlar'da oyuncuyu halka halinde kuşatan kurt sürüsü" width="49%">
  <img src="docs/screenshots/oyun.jpg" alt="Oyun içi: büyücü, dönen kılıçlar ve seviye kartları" width="49%">
</p>

<p align="center">
  <img src="docs/screenshots/taverna-bahce.jpg" alt="Gök Tulpar'la taverna bahçesi" width="49%">
  <img src="docs/screenshots/taverna-ic.jpg" alt="Gezilebilir taverna içi" width="49%">
</p>

<p align="center">
  <img src="docs/screenshots/yetenek-agaci.jpg" alt="Dört dallı yetenek ağacı" width="49%">
  <img src="docs/screenshots/ekipman.jpg" alt="Ekipman ve karakter önizlemesi" width="49%">
</p>

<p align="center">
  <img src="docs/screenshots/canta.jpg" alt="Çanta ve kasalar" width="32%">
  <img src="docs/screenshots/petler.jpg" alt="Pet slotları" width="32%">
  <img src="docs/screenshots/siralama.jpg" alt="Sıralama" width="32%">
</p>

<p align="center"><sub>Şehir menüsü · Sürü halkası ve seviye kartları · Taverna bahçesi ve içi · Yetenek ağacı · Ekipman · Çanta · Petler · Sıralama. Görüntüler örnek verilerle çekildi.</sub></p>

## Özellikler

### Oynanış
- **5 harita:** Sakin Orman, Sahil Kasabası, Karlı Dağlar, Yakıcı Çöl ve Ölümcül Zindan; her oyun rastgele birinde başlar. Karlı Dağlar ve Yakıcı Çöl'ün kendi canavarları ve boss'u var.
- **Kendiliğinden saldırı:** menzil çemberine giren en yakın canavar vurulur. Sınıf silahının yanında 5 silaha kadar taşınır, her biri 5 seviye.
- **Silah evrimi:** en üst seviyedeki silah, eşleşen güçlendirmeyle yeni adı ve rengiyle çok daha güçlü bir silaha dönüşür.
- **Seviye kartları:** her seviyede oyun durmadan 3 kart açılır (1 · 2 · 3 ya da tıklayarak); güçlendirmeler o oyun boyunca geçerlidir.
- **Sürüler:** canavarlar başta az ve zayıftır, zamanla 400'ü aşar. Arada tek cins dev bir sürü gelir ve oyuncunun çevresini kapalı bir halka halinde sarar.
- **Boss'lar:** her 5 dakikada bir; saldırılarını yerde kırmızı alanla gösterir, canları azaldıkça öfkelenip yeni saldırılar açar ve her hamleyi vücutlarıyla yaparlar.
- **Zindan kapıları:** tur içinde açılan mor kapıdan girip mini boss'u 60 saniyede yenersen altın ve kasa kazanırsın.
- **Gece, gündüz ve hava:** 5 dakikalık gün döngüsü; gece canavarlar daha serttir. Yağmur, fırtına ve sis gelir.
- **Kabus zorluğu:** hesap seviyesi 8, 16 ve 25'te açılan Kabus I-III; daha sert canavarlar, 2-5 kat ödül.
- **Ulti (R / Q):** her sınıfın iki ultisi var, haritadaki tüm düşmanlara vurur.

### Şehir menüsü
- Ana menü, gerçek saate göre gün doğumu ve gece yaşayan pikselli bir kasaba: halk yollarda yürür, çeşme akar, bacalar tüter, geceleri lambalar yanar.
- Her menü bir binada: Yetenek Kulesi, Pet Barınağı, Lonca Binası, Şeref Salonu, Dünya Bossu, Görev Meydanı, Taverna, Dostlar Evi, Ahır, Kuyumcu, Kahramanlar Evi, Zırh Atölyesi, Terzi, Pazar ve Savaş Kapısı.

### Karakterler, eşyalar ve kasalar
- Hesapta 5 karaktere kadar: **Savaşçı**, **Okçu**, **Büyücü**, **Gölge** ve takımını iyileştiren **Şifacı**.
- 6 nadirlik (Sıradan → Tanrısal) ve 6 ekipman yuvası; takılan eşyalar karakterin üstünde görünür.
- **Demirci:** eşyayı +5'e kadar geliştir. **Taşlar:** nadir eşyalardaki 1-3 sokete ateş, buz, zehir, fırtına ve can taşı tak.
- **Ortak çanta:** slota ve nadirliğe göre filtre; üstüne gelince özellikler takılı eşyayla karşılaştırmalı görünür.
- **Kasalar:** boss'lar kasa bırakır, Pazar'dan da alınır; çark dönüp kazandığın eşyada durur.
- **Gardırop:** sadece görünüş için giysiler ve boyalar, almadan önce üstünde denenir.

### Petler ve binekler
- Yumurtadan çıkan **9 pet**, 4 nadirlikte (Ayı'dan Anka Kuşu'na). Hesap seviyesi 10, 25 ve 50'de açılan 3 slot; slottaki petler stat verir ve oyunda seni takip eder. Pet Koleksiyonu bulunanları gösterir.
- **Ahır:** Kır At, Kurt Dostu, Kum Kaplanı ve kanatlı Gök Tulpar. Tavernada bineğinle hızlı gezersin, C ile inip binersin.

### Yetenek ağacı
- Ortada **Lumora Kalbi**, etrafında dört dal: **Saldırı**, **Savunma**, **Talih** ve oyun dışı **Hazine**. Toplam 61 yetenek, her dalın sonunda güçlü bir son yetenek.
- Her hesap seviyesi 2 puan verir; dışa doğru yetenekler daha çok puan ister. Sürükleyerek gezilir, tekerlekle yakınlaşır, istediğin zaman sıfırlanır.

### Taverna
- İçinde ve bahçesinde gezdiğin 3D bir taverna: masalara otur, salıncakta sallan, dans pistinde dans et, sohbet balonlarıyla yaz (Enter).
- Bahçede kamp ateşi, dilek kuyusu, gölet ve **balık tutma** (E); tuttuğun balığı Mutfak'ta pişirip bir sonraki tura güç olarak yersin.
- **Parkur:** kontrol noktalı bir parkur, en hızlı on süre ve altın ödülü.
- **Zar ve kart:** yakındaki oyuncuya G ile altın bahisli oyun öner; zarlar ve kartlar masaya uçar.

### Çevrimiçi
- **Hesaplar:** kullanıcı adı ve şifreyle; kaydın sunucuda saklanır, her cihazdan aynı hesapla girersin. "Beni hatırla" ile şifre sorulmaz.
- **Co-op:** oda kur, arkadaşını davet et ya da 5 harfli kodu ver (en fazla 4 kişi); ev sahibi OYNA'ya basınca herkes aynı haritada canlı oynar.
- **Düello:** sunucunun güçlere göre oynattığı Düello Arenası ve 1'e 1 gerçek zamanlı PvP.
- **Loncalar:** lonca kur ya da katıl; lonca sohbeti, haftalık ortak hedef, kasaya bağış ve 5 seviyeli lonca yükseltmeleri.
- **Haftalık dünya bossu:** tüm sunucunun ortak canlı dev boss'u; verdiğin hasar payına göre altın.
- **Ticaret, sıralamalar ve arkadaşlar:** eşyayı altına takas et; 7 kategoride sıralama; arkadaşların çevrimiçi durumu ve seviyesi.

### Diğer
- Günlük 3 görev ve 7 günlük giriş ödülü takvimi.
- 48 başarım (altın ödüllü), son 50 oyunun kayıtları, sürüm notları.
- Ses ve müzik (ayrı ayarlanır), grafik/kamera/arayüz ayarları, tam ekran (F11).
- Telefon ve tablette dokunmatik kontroller (yürüme çubuğu, kamera, ULTİ ve ZIPLA düğmeleri).
- Windows sürümü her açılışta kendini günceller (sadece küçük oyun paketini indirir).

## Kontroller

| Tuş | Eylem |
|---|---|
| WASD / ok tuşları | Yürü |
| Boşluk | Zıpla |
| Fare | Kamerayı döndür (önce oyun penceresine tıkla) |
| Fare tekerleği | Yaklaş / uzaklaş |
| 1 · 2 · 3 | Seviye kartı seç |
| R / Q | Ulti |
| Esc / P | Duraklat (devam, kalite, ana menü, boostlar) |
| F11 | Tam ekran |
| E | Tavernada otur, sallan, dans et, balık tut |
| C | Tavernada bineğinden in / bin |
| G | Tavernada zar ya da kart oyunu öner |
| Enter | Tavernada sohbet |
| F1 | Geliştirici menüsü (yalnızca Ayarlar'da gizli kod girilen hesapta) |

## Nasıl çalışır

- **Veri ile denge:** canavarlar, silahlar, eşyalar, petler, yetenekler ve başarımlar `data/` altındaki JSON dosyalarında; sayıları değiştirmek için koda dokunmaya gerek yok.
- **Pixel görünüm:** dünya düşük çözünürlüklü bir SubViewport'ta çizilip büyütülür, arayüz ise tam çözünürlükte keskin kalır. Modeller kutulardan kod ile kurulur, görsel dosya yoktur.
- **Co-op:** oyunu odayı kuran oyuncunun bilgisayarı yönetir (düşmanlar, hasar, ödüller). Sunucu sadece mesajları iletir; ev sahibi saniyede 10 kez durum gönderir, diğerleri kendi hareketlerini ve vuruşlarını yollar.
- **Hesaplar:** sunucu şifreleri yalnızca scrypt özeti, oturum anahtarlarını sha256 özeti olarak tutar. Oyun kaydı JSONB olarak saklanır ve en yeni kayıt kazanır; sıralamalar da bu kayıtlardan hesaplanır.
- **Sürekli teslim:** her PR'da GitHub Actions Godot testlerini, sunucu testini ve iki oyunlu co-op testini çalıştırır, web sürümünün Chrome'da açıldığını kontrol eder. `main`'e birleşince web sürümü GitHub Pages'e, Windows sürümü Releases'e yüklenir.

## Teknolojiler

| Parça | Teknoloji |
|---|---|
| Oyun | Godot 4.5 (GDScript) |
| Sunucu | Node.js, `ws`, `pg` |
| Veritabanı | PostgreSQL (yoksa sunucu hafızası) |
| Yayın | GitHub Pages (web), GitHub Releases (Windows), Render (sunucu) |
| Testler | Godot headless testleri, Node sunucu testi, headless Chrome |

## Proje yapısı

| Klasör | İçerik |
|---|---|
| `scripts/` | Oyun kodu: oyuncu, düşmanlar, silahlar, ilerleme, arayüz, ağ |
| `data/` | Denge ve içerik (JSON) |
| `scenes/` | Açılış (güncelleyici) ve ana sahne |
| `server/` | Çevrimiçi sunucu: hesaplar, odalar, davetler, sıralamalar, co-op aktarımı |
| `tests/` | Otomatik testler |
| `docs/` | Yol haritası ve ekran görüntüleri |

## Çalıştırma

1. [Godot 4.5](https://godotengine.org/download) (standart sürüm) indir, **Import** ile `project.godot` dosyasını aç, **F5** ile başlat.
2. Sunucuyu yerelde denemek için:

```bash
cd server
npm install
node index.js                  # ws://localhost:8080
```

Oyunu `-- --server=ws://localhost:8080` ile açınca bu sunucuya bağlanır. `DATABASE_URL` verilirse hesaplar PostgreSQL'de tutulur.

Testler:

```bash
godot --headless --path . -s res://tests/smoke_test.gd
godot --headless --path . -s res://tests/coop_test.gd    # node gerekir
(cd server && node test.js)
```

Tasarım ve yol haritası: [docs/ROADMAP.md](docs/ROADMAP.md)
