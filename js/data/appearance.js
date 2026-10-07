// Karakter tasarlama seçenekleri.
// type 'color': renk kutucukları. type 'item': kıyafet/şapka kartları (çizimleri js/render/character.js'te).
// Yeni kıyafet: character.js'teki ilgili tabloya çizim fonksiyonu ekle, buraya id + isim yaz.
(function (L) {
  L.appearance = {
    options: [
      { key: 'skin', label: 'Ten Rengi', type: 'color',
        values: ['#ffe0bd', '#f5c99b', '#e0ac69', '#c68642', '#8d5524', '#5c3a1e', '#9fd89a', '#b9c7ff'] },
      { key: 'hairStyle', label: 'Saç', type: 'item', crop: [4, 0, 24, 24],
        values: [
          { id: 'short', name: 'Kısa' }, { id: 'long', name: 'Uzun' }, { id: 'spiky', name: 'Dikenli' },
          { id: 'ponytail', name: 'At Kuyruğu' }, { id: 'bob', name: 'Küt' }, { id: 'mohawk', name: 'Mohikan' },
          { id: 'bald', name: 'Kel' },
        ] },
      { key: 'hairColor', label: 'Saç Rengi', type: 'color',
        values: ['#2b1b0e', '#6b3e1f', '#b5651d', '#e8c26a', '#e9ecef', '#c92a2a', '#3b5bdb', '#9c36b5', '#2b8a3e', '#f783ac'] },
      { key: 'eye', label: 'Göz Rengi', type: 'color',
        values: ['#3b2a1a', '#1971c2', '#2f9e44', '#862e9c', '#c92a2a', '#f59f00'] },
      { key: 'hat', label: 'Şapka', type: 'item', crop: [2, 0, 28, 28],
        values: [
          { id: 'none', name: 'Yok' }, { id: 'cap', name: 'Kep' }, { id: 'wizard', name: 'Büyücü Şapkası' },
          { id: 'helmet', name: 'Şövalye Miğferi' }, { id: 'crown', name: 'Taç' }, { id: 'bandana', name: 'Bandana' },
          { id: 'hood', name: 'Kapüşon' }, { id: 'pirateHat', name: 'Korsan Şapkası' },
        ] },
      { key: 'top', label: 'Üst', type: 'item', crop: [4, 20, 24, 24],
        values: [
          { id: 'peasant', name: 'Köylü Tişörtü' }, { id: 'vest', name: 'Deri Yelek' }, { id: 'knight', name: 'Şövalye Zırhı' },
          { id: 'wizard', name: 'Büyücü Cübbesi' }, { id: 'pirate', name: 'Korsan Gömleği' }, { id: 'ninja', name: 'Ninja Kıyafeti' },
          { id: 'hunter', name: 'Avcı Tuniği' },
        ] },
      { key: 'bottom', label: 'Alt', type: 'item', crop: [6, 32, 20, 16],
        values: [
          { id: 'jeans', name: 'Kot Pantolon' }, { id: 'leather', name: 'Deri Pantolon' }, { id: 'greaves', name: 'Zırh Dizlik' },
          { id: 'shorts', name: 'Şort' }, { id: 'cloth', name: 'Kumaş Pantolon' }, { id: 'hunterPants', name: 'Avcı Pantolonu' },
        ] },
      { key: 'shoes', label: 'Ayakkabı', type: 'item', crop: [6, 38, 20, 10],
        values: [
          { id: 'boots', name: 'Deri Çizme' }, { id: 'ironBoots', name: 'Demir Çizme' }, { id: 'sandals', name: 'Sandalet' },
          { id: 'sneakers', name: 'Spor Ayakkabı' }, { id: 'tabi', name: 'Ninja Tabisi' },
        ] },
    ],

    defaults() {
      return {
        name: '', skin: '#f5c99b', hairStyle: 'short', hairColor: '#6b3e1f', eye: '#1971c2',
        hat: 'none', top: 'peasant', bottom: 'jeans', shoes: 'boots',
      };
    },

    // Eski kayıtları ve bilinmeyen değerleri geçerli hale getirir
    normalize(app) {
      const out = this.defaults();
      out.name = (app && app.name) || '';
      for (const opt of this.options) {
        const v = app && app[opt.key];
        const ok = opt.type === 'color' ? opt.values.includes(v) || /^#[0-9a-f]{6}$/i.test(v || '') : opt.values.some((o) => o.id === v);
        if (ok) out[opt.key] = v;
      }
      return out;
    },

    random() {
      const a = this.defaults();
      for (const opt of this.options) {
        const v = L.utils.pick(opt.values);
        a[opt.key] = opt.type === 'color' ? v : v.id;
      }
      return a;
    },
  };
})(window.Lumora);
