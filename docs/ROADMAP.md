# LumoraRPG — Megabonk Tarzı Yeni Yol Haritası

> Durum: taslak v2 · 2026-10-08
> Önceki yol haritasının (`ROADMAP.md`, aşama tabanlı idle RPG) yerine geçer. Orman teması, 3D pixel görünüm, 3 sınıf ve boss fikri korunuyor; oyunun çekirdeği **koşu (run) tabanlı roguelike survivor** oluyor.

---

## 1. Oyun Özeti

Megabonk / Vampire Survivors tarzı **3D pixel-art roguelike survivor**.

- Oyuncu karakterini **kendisi yürütür, zıplar ve kayar**; **saldırılar otomatik** yapılır.
- Ormanlık haritada her yönden **dalga dalga, gittikçe kalabalıklaşan düşmanlar** gelir (aynı anda yüzlerce).
- Ölen düşmanlar **EXP kristali** ve **altın** düşürür. Seviye atlayınca oyun durur, **3 yükseltmeden biri** seçilir (yeni silah, silah geliştirme veya pasif "tome").
- Harita üzerinde **sandıklar**, **tapınaklar (shrine)** ve **elit düşmanlar** vardır.
- Sayaç dolunca (ör. 10 dk) **boss portalı** açılır; boss yenilirse bir sonraki bölgeye (**Bölge 2**) geçilir.
- Ölünce koşu biter. Koşuda toplanan **kalıcı para** ile ana menüde **kalıcı yükseltmeler** ve **yeni karakterler** açılır (meta ilerleme).

**Önceki fikirden ne kaldı, ne değişti?**

| Önceki | Yeni |
|---|---|
| Sahnede 10 mob, karakter yerinde savaşır | Sonsuz dalga, yüzlerce düşman, oyuncu hareket eder |
| 1-1 … 1-10 aşamalar | Bölge başına tek büyük harita + sayaç; sonunda boss, sonra Bölge 2 |
| Kalıcı seviye ve altınla stat alma | Seviye her koşuda sıfırdan; kalıcı ilerleme meta mağazadan |
| Savaşçı / Okçu / Büyücü | Aynen kalıyor: her biri farklı **başlangıç silahı** ve pasif özelliği olan karakter |
| Karakter slotları | Yerine **açılabilir karakterler** + kozmetik görünüm (hesap başına tek profil) |
| Item, mini boss, zindan, lonca | Yine MVP sonrası; roguelike yapıya uyarlanmış hâlleriyle (bkz. Bölüm 10) |

## 2. Teknik Seçim

**Masaüstü oyunu, Godot 4 (GDScript) ile.** Windows / macOS / Linux için dışa aktarılır, ileride Steam'e çıkabilir. Hesaplar MVP sonrasına kaydı, MVP yerel kayıtla çalışır.
Neden: ücretsiz ve açık kaynak, hafif bir editör, 3D + fizik + animasyon hazır; yüzlerce düşman için **MultiMesh** desteği var; gerekirse aynı proje web'e de dışa aktarılabilir.

### "3D pixel" görünüm
Sahne gerçek 3D (low-poly/voxel), düşük çözünürlüğe (480×270) çizilip pencereye büyütülür (Godot'ta `stretch mode = viewport`); kısıtlı palet + toon ışık + ince kontur. Kamera **üçüncü şahıs, karakterin arkasından** (Megabonk gibi), fareyle döndürülebilir.

### Performans planı (bu türde en kritik konu)
- Düşmanlar **MultiMeshInstance3D** ile çizilir (tür başına tek çizim çağrısı).
- Düşman çarpışması ve hedef bulma için **uzaysal ızgara (spatial hash)**; düşmanlar fizik gövdesi kullanmaz (oyuncu ve arazi Godot fiziğini kullanır).
- Mermi, kristal ve hasar sayıları için **nesne havuzu (object pool)**.
- Hedef: **400 düşman + 300 mermi** ile orta seviye dizüstünde 60 FPS.

## 3. MVP Kapsamı

### Dahil
- 1 harita: **Yeşil Orman** (sınırlı alan, tepeler, ağaçlar, rampalar) + **Bölge 2: Alacakaranlık Ormanı** (aynı yerleşim, farklı tema ve daha güçlü düşmanlar)
- 3 karakter: **Savaşçı, Okçu, Büyücü** (Okçu ve Büyücü meta para ile açılır)
- Hareket: koşma, zıplama, kayma (slide); kamera kontrolü
- **6 silah** (her biri 5 seviye), **6 pasif tome**
- Seviye atlayınca 3 seçenekten 1'ini seçme (+ 1 "yeniden çek" hakkı)
- **4 düşman türü + 1 elit + 1 boss** (bölge başına)
- EXP kristalleri, mıknatıs etkisi, altın, sağlık düşürmesi
- **Sandıklar** (altınla açılır, rastgele silah/tome geliştirmesi) ve **2 tapınak türü**
- Sayaç, boss portalı, boss savaşı, Bölge 2'ye geçiş
- Koşu sonu ekranı (süre, öldürme, hasar dökümü), meta para
- Ana menü: karakter seçimi, **meta mağaza** (6 kalıcı yükseltme), ayarlar
- Yerel kayıt (`user://` klasörüne JSON)

### Dahil değil (MVP sonrası)
Hesaplar ve bulut kaydı, item/eşya sistemi, mini bosslar, özel zindanlar, lonca, sıralama tablosu, başarımlar/görevler, daha fazla harita ve karakter, çok oyunculu, mobil kontroller.

## 4. Oyun Döngüleri

**Koşu içi döngü (10–15 dk):**
```
Haritaya doğ → yürü, düşmanlar gelir → silahlar otomatik ateş eder
  → kristal topla → seviye atla → 3 seçenekten birini seç → daha güçlü ol
  → sandık aç / tapınak kullan / elit kes → sayaç dolar → boss portalı açılır
  → boss'u yen → Bölge 2 (daha zor) → ... → öl veya kazan
```

**Meta döngü (koşular arası):**
```
Koşu bitti → kazanılan meta para → mağazadan kalıcı yükseltme / yeni karakter
  → yeni koşu, biraz daha güçlü ve daha fazla seçenekle
```

## 5. Sistem Tasarımları

### 5.1 Karakterler

| Karakter | Can | Hız | Başlangıç silahı | Pasif | Açılma |
|---|---|---|---|---|---|
| Savaşçı | 120 | Orta | **Kılıç Savurma** (önünde yay biçimli alan) | +%10 zırh, düşük canda +hasar | Baştan açık |
| Okçu | 80 | Yüksek | **Ok Yağmuru** (en yakın düşmana delen ok) | +%15 kritik şansı | 300 meta para |
| Büyücü | 70 | Düşük | **Ateş Topu** (çarpınca patlayan alan hasarı) | +%20 alan büyüklüğü | 500 meta para |

Görünüm: her karakter için 3–4 renk kostümü (kozmetik, meta para ile).

### 5.2 Silahlar (MVP: 6 adet, her biri 5 seviye)

| Silah | Davranış |
|---|---|
| Kılıç Savurma | Karakterin baktığı yöne yay şeklinde alan vuruşu |
| Ok Yağmuru | En yakın düşmana delen ok; seviyeyle ok sayısı artar |
| Ateş Topu | Rastgele düşmana patlayan küre |
| Dönen Baltalar | Karakterin etrafında dönen baltalar |
| Yıldırım | Rastgele düşmanlara düşen, zincirleme şimşek |
| Zehir Bulutu | Yere bırakılan, zamanla hasar veren alan |

Karakter en fazla **4 silah** ve **4 tome** taşır.

### 5.3 Pasif Tome'lar (MVP: 6 adet)
Hasar, Saldırı Hızı, Mermi Sayısı, Alan Büyüklüğü, Hareket Hızı, Mıknatıs (toplama mesafesi).

### 5.4 Seviye Atlama Seçimi
- Gereken EXP: `10 + seviye × 8` (ilk dakikalarda hızlı, sonra yavaşlayan eğri; testte ayarlanacak).
- Atlayınca oyun durur, 3 kart çıkar: yeni silah / mevcut silah +1 / tome.
- Kart nadirliği (Sıradan / Nadir / Destansı) etkinin büyüklüğünü belirler; şans statı nadirliği artırır.
- Koşu başına 1 "yeniden çek" hakkı (meta mağazadan artırılabilir).

### 5.5 Düşmanlar ve Dalga Sistemi
- Düşmanlar oyuncunun görüş alanı dışında, çevresindeki halkada doğar.
- **Dalga tablosu** (`data/waves.json`): her dakika için hangi türden, saniyede kaç düşman doğacağı.
- Zorluk zamanla artar: `düşmanCan = taban × (1 + dakika × 0.25)`; Bölge 2'de ek ×2.5 çarpan.
- Ekrandaki düşman tavanı (ör. 400); tavan dolunca uzaktakiler oyuncuya yakın konuma taşınır.

| Bölge 1 düşmanı | Rol |
|---|---|
| Slime | Yavaş, kalabalık, zayıf |
| Mantar Adam | Orta hız, ölünce küçük zehir bırakır |
| Yaban Domuzu | Hızlı, düz çizgide hücum eder |
| Orman Ruhu | Uzaktan mermi atar |
| **Elit: Dev Ent** | Büyük, yavaş, çok canlı; ölünce sandık düşürür |
| **Boss: Kadim Ağaç** | 3 saldırı deseni, alan uyarı daireleri, çağırdığı yardımcılar |

### 5.6 Harita
- Yaklaşık 200×200 birimlik, kenarları dağ/ağaçla kapalı alan; tepeler, rampalar ve kayalar (zıplama/kayma işe yarasın diye).
- Her koşuda **sandık, tapınak ve elit konumları rastgele** dağıtılır (harita yerleşimi sabit).
- Mini harita veya ekran kenarında ok işaretleri ile sandık/tapınak gösterimi.

### 5.7 Sandıklar ve Tapınaklar
- **Sandık:** koşu içi altınla açılır, fiyatı her açışta artar. İçinden rastgele silah/tome geliştirmesi çıkar.
- **Güç Tapınağı:** yanında 10 sn durunca kalıcı (koşu boyunca) küçük stat bonusu.
- **Lanet Tapınağı:** dokununca daha çok ve daha güçlü düşman, karşılığında daha çok EXP/altın.

### 5.8 Boss ve Bölge Geçişi
- Sayaç **10 dk** (bölge başına). Dolunca harita üzerinde **boss portalı** açılır; oyuncu girdiğinde boss savaşı başlar.
- Portal açıkken düşman yoğunluğu hızla artar → oyuncuyu boss'a yönlendirir.
- Boss yenilirse: büyük ödül, **Bölge 2** yüklenir (karakter gücü korunur, düşmanlar güçlenir).
- Bölge 2'nin boss'u yenilince koşu **zaferle** biter.

### 5.9 Hasar ve Statlar
- `hasar = silahHasarı × (1 + hasarBonusu) × (kritikse 2)`; zırh gelen hasarı `100 / (100 + zırh)` oranında azaltır.
- Vurulunca 0.5 sn dokunulmazlık.
- Tüm sayılar `data/*.json` içinde; kod sabit sayı içermez.

### 5.10 Meta İlerleme
- Koşu sonunda: `metaPara = öldürme/20 + hayatta kalınan dakika × 10 + boss ödülü`.
- **Meta mağaza (MVP: 6 yükseltme, her biri 5 seviye):** Başlangıç Canı, Hasar, Hareket Hızı, Mıknatıs, Altın Kazancı, Yeniden Çek Hakkı.
- Karakter açma ve kostümler de meta para ile.

### 5.11 Arayüz
- HUD: can barı, EXP barı + seviye, sayaç, öldürme sayısı, altın, silah/tome ikonları.
- Seviye atlama kart ekranı, duraklatma menüsü, koşu sonu özeti.
- Ana menü: Oyna → Karakter Seç → Harita; Mağaza; Ayarlar (ses, hassasiyet, grafik kalitesi).

## 6. Kontroller
- **WASD** hareket, **Boşluk** zıplama, **Shift** kayma, **fare** kamera.
- Saldırı tamamen otomatik.
- Gamepad desteği M5'te; dokunmatik kontroller MVP sonrası.

## 7. Veri Modeli (yerel kayıt, ileride sunucuya taşınacak)

```
profile
  version, metaPara, açıkKarakterler[], metaYükseltmeler{ad: seviye},
  kostümler{karakter: renk}, ayarlar{}, istatistikler{enUzunKoşu, toplamÖldürme, kazanılanKoşu}
```
Kayıt formatı sürümlü (`version`), böylece M6'da Supabase'e taşırken dönüştürülebilir.

## 8. Proje Yapısı (öneri)

```
project.godot   motor ayarları (480×270 pixel görüntü)
scenes/         sahneler (.tscn)
scripts/
  core/         ayar yükleme, tuş atamaları, malzemeler, nesne havuzu
  world/        arazi, ağaç/kaya, sandık/tapınak yerleşimi, portal
  player/       oyuncu hareketi, model, kamera
  enemies/      düşmanlar, dalga sistemi, boss
  combat/       silahlar, mermiler, hasar
  progression/  seviye/kart, ganimet, meta mağaza, kayıt
  ui/           menüler, HUD, kart ekranı, koşu sonu
data/           characters, weapons, tomes, enemies, waves, shop, balance (.json)
assets/         modeller (glTF/vox), dokular, sesler
tests/          otomatik testler (CI'da Godot ile çalışır)
```

## 9. Yol Haritası (Kilometre Taşları)

Her adım sonunda Godot'ta açılıp oynanabilir bir sürüm olur.

### M0 — Kurulum ve Hareket
- Godot projesi, pixel görüntü ayarları, otomatik test (GitHub Actions).
- Test arazisi, oyuncu kontrolcüsü: koşma, zıplama, kayma, eğimli zemin, üçüncü şahıs kamera.
- **Bitti sayılır:** karakter tepeli bir alanda akıcı şekilde koşup zıplıyor ve kayıyor.

### M1 — Sürü Çekirdeği
- Düşman doğma halkası, oyuncuyu takip, MultiMesh çizim, spatial hash çarpışma.
- 1 silah (Ok Yağmuru), mermi havuzu, hasar sayıları, oyuncu canı ve ölüm.
- **Bitti sayılır:** 400 düşman ekranda 60 FPS'te koşuyor, ok atıp kesebiliyorum, ölünce koşu bitiyor.

### M2 — Koşu Döngüsü
- EXP kristalleri + mıknatıs, seviye atlama kart ekranı, 6 silah + 6 tome.
- Dalga tablosu ve sayaca bağlı zorluk, 4 düşman türü, elit.
- **Bitti sayılır:** 10 dakikalık bir koşu baştan sona oynanabiliyor ve her koşuda farklı yapı (build) çıkıyor.

### M3 — Harita ve Boss
- Yeşil Orman haritası, rastgele sandık/tapınak/elit yerleşimi, altın ve sandık açma.
- Boss portalı, Kadim Ağaç boss'u, Bölge 2 geçişi ve zafer ekranı.
- **Bitti sayılır:** iki bölge ve iki boss ile bir koşu kazanılabiliyor.

### M4 — Karakterler ve Meta İlerleme
- Savaşçı, Okçu, Büyücü (başlangıç silahı + pasif), karakter seçim ekranı.
- Meta para, mağaza, karakter açma, kostümler, yerel kayıt, koşu sonu özeti.
- **Bitti sayılır:** öl → para kazan → mağazadan al → yeni koşuda farkı hisset döngüsü çalışıyor.

### M5 — Cilalama ve MVP Yayını
- Gerçek voxel/pixel modeller ve animasyonlar, vuruş hissi (ekran sarsıntısı, kısa durma, parçacıklar), sesler ve müzik.
- Denge geçişi, ayarlar, gamepad, performans optimizasyonu, geliştirici menüsü.
- **Bitti sayılır:** indirilebilir Windows/macOS sürümünü açan biri koşuya girebiliyor, 10 dakikalık koşu akıcı ve eğlenceli. → **MVP v0.1**

### M6 — Hesaplar (MVP'den hemen sonra)
- Supabase ile giriş, profilin buluta taşınması, cihazlar arası devam.

## 10. MVP Sonrası (önerilen sıra)

1. **Daha fazla harita** (her biri yeni tema, düşmanlar, boss) ve **daha fazla karakter/silah**.
2. **Item sistemi** — sandıklardan ve elitlerden düşen, koşu boyunca kalan özel eşyalar (Megabonk'taki gibi pasif etkili eşyalar).
3. **Silah evrimleri** — belirli silah + tome ikilisi maksimum seviyede birleşerek güçlü versiyona dönüşür.
4. **Mini bosslar** — koşunun belli dakikalarında çıkan, özel ödüllü güçlü düşmanlar.
5. **Başarımlar / görevler** — yeni silah ve karakterlerin kilidini açar.
6. **Özel zindanlar / meydan okuma modları** — kurallı özel haritalar (ör. sadece tek silah).
7. **Sıralama tabloları** (sunucu tarafı doğrulama ile).
8. **Lonca sistemi** — lonca meydan okumaları, ortak hedefler, haftalık sıralama.
9. Mobil kontroller ve paketleme, çok oyunculu (co-op) denemesi.

## 11. Varsayımlar (değiştirilebilir)

- "Megabong" ile **Megabonk** (2025, 3D roguelike survivor) kastedildi.
- Oyuncu hareketi tamamen elle, saldırılar tamamen otomatik.
- Koşu süresi bölge başına 10 dk, MVP'de 2 bölge.
- Hesaplar MVP'den hemen sonra (M6); o zamana kadar ilerleme bilgisayarda saklanır.
- Motor olarak Godot 4 seçildi (masaüstü öncelikli).
