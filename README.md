# Lumora RPG

Web için pixel art idle RPG. Bağımlılık yok: `index.html`'i tarayıcıda açman yeterli.

## Klasör yapısı
- `js/core/utils.js` – yardımcılar ve olay sistemi (`Lumora.events`)
- `js/data/` – oyunun **verisi**: denge sayıları (`balance.js`), karakter seçenekleri (`appearance.js`),
  piksel çizimleri (`sprites.js`), canavarlar (`monsters.js`), dünyalar (`worlds.js`)
- `js/systems/` – kurallar: kayıt (`save.js`, localStorage), oyuncu/level (`player.js`), savaş/boss (`battle.js`)
- `js/render/` – çizim: piksel motoru, arka planlar, savaş sahnesi
- `js/ui/` – karakter tasarlama ekranı ve oyun arayüzü
- `js/main.js` – başlangıç ve oyun döngüsü

## Sık yapılacaklar
- Zorluk ayarı: `js/data/balance.js`
- Yeni canavar: `sprites.js`'e çizim (veya mevcut çizimi başka renkle kullan) → `monsters.js` → `worlds.js` listesine ekle
- Yeni dünya: `worlds.js`'e ekle, `backgrounds.js`'e arka plan çizimi ekle
- Yeni saç/şapka: `sprites.js` → `appearance.js`
