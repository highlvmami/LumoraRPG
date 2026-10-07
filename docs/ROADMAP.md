# LumoraRPG — MVP Tasarımı ve Yol Haritası

> Durum: taslak v1 · 2026-10-07
> Amaç: Oyunun **en temel oynanabilir halini (MVP)** çıkarmak. Item düşmesi, mini bosslar, özel zindanlar ve lonca sistemi MVP'ye **dahil değil**, ama mimari bunlara yer bırakacak şekilde kuruluyor.

---

## 1. Oyun Özeti

LumoraRPG, **3D pixel-art** görünümlü, **canlı (gerçek zamanlı) otomatik savaşlı** bir RPG.

- Oyuncu hesabına giriş yapar, **karakter slotlarından** birini seçer ya da yeni karakter tasarlar.
- Karakter küçük bir **3D pixel ormanda** doğar; sahnede **rastgele doğan 10 moba** otomatik saldırır.
- Mob kestikçe **EXP** ve **altın** kazanılır; bunlarla seviye atlanır ve **yükseltme** alınır.
- Aşamalar `1-1 → 1-2 → … → 1-10` şeklinde ilerler. `1-10`'da **boss çağrılır**, boss yenilince `2-1` açılır ve **bölge (arka plan) değişir**.

## 2. Teknik Seçim

**Seçim: Tarayıcı tabanlı — TypeScript + Three.js + Vite, hesaplar ve kayıtlar için Supabase.**
Neden: önceki sürüm zaten web'deydi, kurulum gerektirmeden linkle oynanır, her şey kodla yazıldığı için hızlı geliştirip test edebiliriz; ileride Capacitor/Tauri ile mobil ve masaüstüne paketlenebilir.

| Katman | Araç | Not |
|---|---|---|
| Dil / derleme | TypeScript + Vite | Hızlı geliştirme sunucusu, tek komutla build |
| 3D motor | Three.js | Düşük çözünürlüklü render + piksel büyütme ile "3D pixel" görünüm |
| Arayüz (menüler, HUD) | HTML/CSS katmanı (gerekirse Preact) | Oyun canvas'ının üstünde |
| Hesap + veritabanı | Supabase (Auth + Postgres) | E-posta/şifre girişi, Row Level Security ile herkes sadece kendi verisini görür |
| Barındırma | GitHub Pages veya Render static site | Ücretsiz statik yayın |
| Modeller | MagicaVoxel / Blender → glTF | MVP'de basit voxel/low-poly yer tutucular yeterli |

### "3D pixel" görünümü nasıl elde edilecek
1. Sahne gerçek 3D (low-poly/voxel modeller, sabit açılı izometrik-ortografik kamera).
2. Sahne **düşük çözünürlüklü bir render hedefine** çizilir (ör. 320×180 veya 480×270).
3. Bu görüntü ekrana **en yakın komşu (nearest)** filtresiyle büyütülür → keskin pikseller.
4. Kısıtlı renk paleti + basit ton gölgelendirme (toon) + kontur shader'ı ile pixel art hissi güçlendirilir.

## 3. MVP Kapsamı

### Dahil
- Hesap oluşturma / giriş / çıkış
- Hesap başına **3 karakter slotu**: oluştur, seç, sil
- Karakter tasarımı: isim, sınıf, görünüm (ten rengi, saç modeli, saç rengi, kıyafet rengi)
- **3 sınıf**: Savaşçı, Okçu, Büyücü
- Küçük orman sahnesi, rastgele 10 mob doğması, gerçek zamanlı otomatik savaş
- EXP, seviye, altın
- Altınla alınan temel yükseltmeler (Saldırı, Savunma, Can, Saldırı Hızı)
- Aşama sistemi `X-1 … X-10`, `X-10`'da boss çağırma, sonraki bölgeye geçiş
- **2 bölge** (bölge değişiminin çalıştığını göstermek için): Bölge 1 *Yeşil Orman*, Bölge 2 *Alacakaranlık Ormanı*
- Otomatik kayıt (sunucuya), oyuna dönünce kaldığı yerden devam
- Temel HUD ve ses efektleri

### Dahil değil (MVP sonrası)
Item düşmesi ve envanter, ekipman, mini bosslar, özel zindanlar, lonca sistemi, yetenek ağacı, sohbet, sıralama tablosu, mağaza/ödeme, çevrimdışı kazanç, mobil paketleme.

## 4. Temel Oyun Döngüsü

```
Giriş → Karakter Seç/Oluştur → Sahneye gir (ör. 1-3)
   ↓
10 mob doğar → karakter otomatik en yakın moba yürür ve saldırır
   ↓
Her ölen mob: +EXP, +altın  (seviye atlarsa statlar artar)
   ↓
10 mob da öldü → aşama temizlendi → sonraki aşama (1-4)
   ↓
1-10 temizlenince "Boss Çağır" butonu → boss savaşı
   ↓
Boss yenildi → 2-1 açılır, arka plan/bölge değişir
Boss kaybedildi → 1-10'da kalınır, yükseltme alıp tekrar denenir
```

Oyuncu savaşa doğrudan müdahale etmez (MVP'de); kararları **yükseltme almak**, **boss'u ne zaman çağıracağına karar vermek** ve **ilerlemek / geri dönüp kasmak** üzerinedir.

## 5. Sistem Tasarımları

### 5.1 Hesap ve Karakter Slotları
- Supabase Auth ile e-posta + şifre.
- Hesap başına 3 slot (ileride satın alınabilir/açılabilir slot için `max_slots` alanı tutulur).
- Slot ekranı: her slotta karakterin küçük 3D önizlemesi, isim, sınıf, seviye, en yüksek aşama. Boş slotta "Yeni Karakter".
- Karakter silme onay ister (isim yazdırarak).

### 5.2 Karakter Tasarımı
- İsim (3–16 karakter, benzersiz), sınıf seçimi (sınıf statlarının özeti gösterilir).
- Görünüm seçenekleri palet değişimiyle yapılır (aynı model, farklı renkler) → az içerikle çok çeşit.
  - Ten rengi: 4 seçenek · Saç modeli: 3 · Saç rengi: 6 · Kıyafet rengi: 6
- Ekranda dönen 3D önizleme.

### 5.3 Sınıflar (başlangıç değerleri — denge testinde değişecek)

| Sınıf | Can | Saldırı | Savunma | Saldırı Hızı (vuruş/sn) | Menzil | Özellik |
|---|---|---|---|---|---|---|
| Savaşçı | 140 | 10 | 8 | 1.0 | Yakın (1.5) | Orta saldırı / orta-yüksek savunma, dayanıklı |
| Okçu | 90 | 14 | 3 | 1.3 | Uzak (7) | Yüksek saldırı / düşük savunma, uzaktan vurur |
| Büyücü | 80 | 12 | 3 | 0.8 | Orta (5) | Hedefin etrafına küçük **alan hasarı** verir |

Seviye başına artış sınıfa göre farklıdır (ör. Savaşçı: +12 Can, +1.5 Saldırı, +1 Savunma).
Tüm sayılar `data/classes.json` içinde tutulur; kod sabit sayı içermez.

### 5.4 Sahne ve Bölge Yapısı
- **Aşama kimliği:** `bölge-aşama` (ör. `1-7`). Her bölgede 10 aşama.
- Her bölgenin kendi **ortam teması** var: zemin dokusu, ağaç modelleri/renkleri, gökyüzü rengi, sis, ışık. Bölge değişince bu tema yüklenir → "arka plan değişiyor" hissi.
- Sahne küçük ve sınırlı: yaklaşık 20×20 birimlik bir orman açıklığı, kenarlarda ağaçlar.
- Aşama zorluğu formülle büyür:
  `mobCan = tabanCan × 1.18^(aşamaSırası)` · `mobSaldırı = tabanSaldırı × 1.15^(aşamaSırası)`
  (`aşamaSırası` = (bölge−1)×10 + aşama)

### 5.5 Mob Doğma
- Aşama başında sahnede **10 mob** rastgele noktalarda doğar (karakterin çok yakınına değil, birbirinin içine değil).
- MVP'de bölge başına 2 mob türü (ör. Bölge 1: Slime, Mantar; Bölge 2: Kurt, Örümcek).
- Moblar karakteri fark edince ona yürür ve saldırır.

### 5.6 Gerçek Zamanlı Otomatik Savaş
- Sıra tabanlı değil; her şey sabit zaman adımlı (ör. saniyede 20 tick) simülasyonda akar.
- Karakter yapay zekâsı: **en yakın canlı mobu hedefle → menzile kadar yürü → saldırı bekleme süresi dolunca vur**.
- Hasar formülü: `hasar = Saldırı × 100 / (100 + Savunma × 5)` (± %10 rastgelelik, en az 1).
- Kritik vuruş MVP'de yok (yükseltme olarak sonra eklenebilir).
- Karakter ölürse: kısa bekleme → aynı aşama baştan başlar (ceza yok, MVP'de).
- Görsel geri bildirim: hasar sayıları, vurulunca beyaz yanıp sönme, ölüm efekti, can barları.

### 5.7 Boss
- `X-10`'un 10 mobu temizlenince **"Boss Çağır"** butonu çıkar (oyuncu hazır olunca basar).
- Boss: büyük model, yüksek can, 1 özel saldırı (ör. alan vuruşu, öncesinde yerde uyarı dairesi).
- Süre limiti: 60 sn. Süre biterse veya karakter ölürse boss başarısız → `X-10`'a dönülür.
- Boss yenilince: büyük EXP/altın ödülü, `(X+1)-1` açılır, bölge teması değişir.

### 5.8 EXP, Seviye, Altın
- Gereken EXP: `sonrakiSeviye = 50 × seviye^1.6`
- Mob ödülü aşamayla büyür; boss ödülü normal mobun ~15 katı.
- Seviye tavanı MVP'de 50.

### 5.9 Yükseltmeler (altınla)
| Yükseltme | Etki / seviye | Maliyet |
|---|---|---|
| Saldırı | +%5 saldırı | `20 × 1.15^seviye` |
| Savunma | +%5 savunma | `20 × 1.15^seviye` |
| Can | +%6 can | `25 × 1.15^seviye` |
| Saldırı Hızı | +%2 saldırı hızı (tavan %100) | `40 × 1.18^seviye` |

Yükseltmeler karaktere özeldir. Tanımlar `data/upgrades.json` içindedir; yeni yükseltme eklemek kod değiştirmeyi gerektirmez.

### 5.10 Arayüz (HUD)
- Üst: aşama göstergesi (`1-7`), aşamada kalan mob sayısı (`4/10`).
- Sol üst: karakter adı, seviye, can barı, EXP barı.
- Sağ üst: altın.
- Alt: yükseltme paneli (açılır/kapanır), "Boss Çağır" butonu (sadece X-10'da).
- Menü: ayarlar (ses), karakter seçimine dön, çıkış.

## 6. Veri Modeli (Supabase)

```
profiles      id (=auth user id), kullanıcı_adı, max_slots(3), created_at
characters    id, user_id → profiles, slot(1..3), name (unique), class,
              appearance (jsonb), level, exp, gold,
              current_stage ("1-7"), highest_stage, upgrades (jsonb),
              save_version, updated_at, created_at
```

- **RLS:** her kullanıcı yalnızca `user_id = auth.uid()` olan satırları okur/yazar.
- **Kayıt:** her 15 sn'de bir, aşama geçişinde ve sayfa kapanırken otomatik.
- `save_version` sayesinde ileride kayıt formatı değişince eski kayıtlar dönüştürülebilir.
- **Bilinen risk:** MVP'de savaş tarayıcıda hesaplanır, yani hileye açıktır. Lonca/sıralama gibi rekabetçi sistemlerden önce sunucu tarafı doğrulama eklenecek (bkz. Bölüm 9).
- MVP sonrası için ayrılan tablolar: `items`, `inventory`, `guilds`, `guild_members`, `dungeons_progress`.

## 7. Ekran Akışı

```
[Açılış] → [Giriş / Kayıt] → [Karakter Slotları] ─→ [Karakter Tasarımı]
                                   │                       │
                                   └──────→ [Oyun Sahnesi] ←┘
                                               ├─ Yükseltme paneli
                                               ├─ Boss savaşı
                                               └─ Menü (ayarlar, karakter seçimine dön, çıkış)
```

## 8. Proje Yapısı (öneri)

```
src/
  main.ts                 giriş noktası, ekran yöneticisi
  core/                   oyun döngüsü, zaman adımı, olay sistemi, rastgele sayı
  render/                 pixel render hattı, kamera, shader'lar, model yükleme
  world/                  sahne/bölge kurulumu, mob doğma, tema yükleme
  entities/               karakter, mob, boss (veri + davranış)
  systems/                savaş, hareket/hedefleme, ilerleme (exp/altın/aşama), yükseltmeler
  ui/                     ekranlar (giriş, slotlar, tasarım, HUD, menüler)
  net/                    Supabase istemcisi, auth, kayıt/yükleme
data/                     classes.json, mobs.json, regions.json, upgrades.json, balance.json
assets/                   modeller (glTF), dokular, sesler
docs/                     tasarım dokümanları
```

Kural: **oyun mantığı (systems) render'dan ayrı** tutulur. Böylece savaş simülasyonu test edilebilir ve ileride sunucuda da çalıştırılabilir.

## 9. Yol Haritası (Kilometre Taşları)

Her adım bir öncekinin üstüne kurulur; her adımın sonunda tarayıcıda oynanabilir bir sürüm olur.

### M0 — Kurulum
- Vite + TypeScript + Three.js projesi, lint/format, otomatik yayın (GitHub Pages veya Render).
- Pixel render hattı: düşük çözünürlüklü hedef + nearest büyütme + ortografik kamera.
- **Bitti sayılır:** yayın linkinde dönen bir pixel küp ve basit orman zemini görünüyor.

### M1 — Sahne ve Savaş Çekirdeği (hesapsız)
- Orman sahnesi (zemin, ağaçlar, ışık), yer tutucu karakter modeli.
- 10 mobun rastgele doğması, hedefleme + yürüme, gerçek zamanlı otomatik saldırı, hasar sayıları, ölüm.
- Karakter ölünce aşamayı yeniden başlatma.
- **Bitti sayılır:** karakter 10 mobu kendi kendine kesiyor, can barları ve hasar sayıları görünüyor.

### M2 — İlerleme
- EXP/seviye/altın, aşama sayacı, `1-1 … 1-10` geçişleri, zorluk ölçeklemesi.
- Boss çağırma, boss savaşı, süre limiti, kazan/kaybet akışı.
- Bölge 2 teması ve `2-1`'e geçişte arka plan değişimi.
- Geçici yerel kayıt (localStorage) — kayıt katmanı soyut yazılır, M4'te Supabase'e takılır.
- **Bitti sayılır:** 1-1'den 2-1'e kadar baştan sona oynanabiliyor.

### M3 — Sınıflar ve Yükseltmeler
- Savaşçı (yakın), Okçu (uzak, ok mermisi), Büyücü (alan hasarı) davranışları ve statları.
- Yükseltme paneli ve 4 temel yükseltme.
- İlk denge geçişi (hedef: 1-10 boss'u ilk denemede çoğunlukla kaybedilip birkaç yükseltmeden sonra geçilsin).
- **Bitti sayılır:** üç sınıf da farklı hissettiriyor ve 2-1'e ulaşabiliyor.

### M4 — Hesaplar, Slotlar ve Karakter Tasarımı
- Supabase projesi, tablolar, RLS kuralları.
- Giriş/kayıt ekranı, 3 slotlu karakter seçim ekranı, karakter tasarım ekranı (renk/saç seçimi + 3D önizleme).
- Kaydın sunucuya taşınması, oyuna dönünce kaldığı yerden devam.
- **Bitti sayılır:** iki farklı cihazdan aynı hesaba girince aynı karakterler ve ilerleme görünüyor.

### M5 — Cilalama ve MVP Yayını
- Gerçek voxel/pixel modeller (karakter ×3 sınıf, 4 mob, 2 boss), bölge temaları.
- Ses efektleri ve basit müzik, ayarlar menüsü.
- Hata ayıklama/geliştirici menüsü (aşama atlama, altın ekleme — sadece geliştirme modunda).
- Performans: düşük güçlü dizüstünde 60 FPS hedefi.
- **Bitti sayılır:** linki paylaşılan biri hesap açıp karakter yaratarak 2-1'e kadar sorunsuz oynayabiliyor. → **MVP v0.1**

## 10. MVP Sonrası (sıralama önerisi)

1. **Item düşmesi + envanter + ekipman** — moblardan nadirlikli item düşer; `items` tablosu ve item veri dosyası.
2. **Daha fazla bölge** — her bölge = yeni tema + mob türleri + boss (veri dosyası ile eklenir).
3. **Yetenekler / yetenek ağacı** — sınıfa özel aktif/pasif yetenekler.
4. **Mini bosslar** — aşamalarda nadir çıkan veya belli seviyede açılan özel düşmanlar.
5. **Özel zindanlar** — giriş hakkı/anahtar ile girilen, özel ödüllü ayrı sahneler.
6. **Sunucu tarafı doğrulama** — ödüllerin sunucuda kontrolü (rekabetçi sistemlerden önce şart).
7. **Lonca sistemi** — lonca kurma/katılma, lonca sohbeti, lonca görevleri/bossları.
8. Sıralama tabloları, çevrimdışı kazanç, mobil paketleme.

Bu sistemlerin hepsi şimdiden şu kararlarla kolaylaşıyor: veri odaklı tanımlar (`data/*.json`), render'dan bağımsız oyun mantığı, sürümlü kayıt formatı ve Supabase'te ayrılmış tablo isimleri.

## 11. Varsayımlar (değiştirilebilir)

- Karakter MVP'de tamamen otomatik hareket eder; oyuncu sadece yükseltme alır ve boss'u çağırır. (İstenirse ileride WASD/dokunmatik ile manuel hareket eklenebilir.)
- Ölüm cezası yok; sadece aşama baştan başlar.
- Hesap başına 3 slot; karakter isimleri sunucu genelinde benzersiz.
- MVP'de 2 bölge (20 aşama + 2 boss).
- Dil: Türkçe arayüz, metinler ileride çeviri için tek dosyada tutulur.
