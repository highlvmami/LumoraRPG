// Karakter tasarlama seçenekleri. Yeni saç/şapka eklemek için:
// 1) js/data/sprites.js içine piksel haritasını ekle, 2) buradaki listeye id + isim ekle.
(function (L) {
  const clothes = ['#e03131', '#f76707', '#fab005', '#2f9e44', '#1c7ed6', '#5f3dc4',
    '#c2255c', '#f8f9fa', '#495057', '#212529', '#8d5524', '#20c997'];

  L.appearance = {
    options: [
      { key: 'skin', label: 'Ten Rengi', type: 'color',
        values: ['#ffe0bd', '#f5c99b', '#e0ac69', '#c68642', '#8d5524', '#5c3a1e', '#9fd89a', '#b9c7ff'] },
      { key: 'hairStyle', label: 'Saç Stili', type: 'cycle',
        values: [
          { id: 'short', name: 'Kısa' }, { id: 'long', name: 'Uzun' },
          { id: 'spiky', name: 'Dikenli' }, { id: 'ponytail', name: 'At Kuyruğu' },
          { id: 'bald', name: 'Kel' },
        ] },
      { key: 'hairColor', label: 'Saç Rengi', type: 'color',
        values: ['#2b1b0e', '#6b3e1f', '#b5651d', '#e8c26a', '#e9ecef', '#c92a2a', '#3b5bdb', '#9c36b5', '#2b8a3e'] },
      { key: 'eye', label: 'Göz Rengi', type: 'color',
        values: ['#1b1b24', '#1971c2', '#2f9e44', '#862e9c', '#c92a2a', '#8d5524'] },
      { key: 'hat', label: 'Şapka', type: 'cycle',
        values: [
          { id: 'none', name: 'Yok' }, { id: 'cap', name: 'Kep' },
          { id: 'wizard', name: 'Büyücü Şapkası' }, { id: 'helmet', name: 'Miğfer' },
          { id: 'crown', name: 'Taç' }, { id: 'bandana', name: 'Bandana' },
        ] },
      { key: 'hatColor', label: 'Şapka Rengi', type: 'color',
        values: ['#1c7ed6', '#e03131', '#5f3dc4', '#adb5bd', '#fab005', '#2f9e44', '#212529', '#f8f9fa'] },
      { key: 'shirt', label: 'Tişört', type: 'color', values: clothes },
      { key: 'pants', label: 'Pantolon', type: 'color', values: clothes },
      { key: 'shoes', label: 'Ayakkabı', type: 'color',
        values: ['#5c3a1e', '#212529', '#e03131', '#f8f9fa', '#1c7ed6', '#868e96'] },
    ],

    // Şapkaların sabit süs rengi (yıldız, mücevher, sorguç...)
    hatAccent: { cap: '#f8f9fa', wizard: '#ffd43b', helmet: '#e03131', crown: '#e03131', bandana: '#f8f9fa' },

    defaults() {
      return {
        name: '', skin: '#f5c99b', hairStyle: 'short', hairColor: '#6b3e1f', eye: '#1b1b24',
        hat: 'none', hatColor: '#1c7ed6', shirt: '#1c7ed6', pants: '#495057', shoes: '#5c3a1e',
      };
    },

    random() {
      const a = this.defaults();
      for (const opt of this.options) {
        const v = L.utils.pick(opt.values);
        a[opt.key] = opt.type === 'cycle' ? v.id : v;
      }
      return a;
    },
  };
})(window.Lumora);
