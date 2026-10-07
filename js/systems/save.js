// Kayıt sistemi: şimdilik tarayıcının localStorage'ı. Hesap sistemi geldiğinde
// sadece load/save fonksiyonlarının bir sunucuya gitmesi yeterli olacak.
(function (L) {
  const KEY = 'lumora_rpg_save_v1';

  L.save = {
    data: null,

    newGame(character) {
      this.data = {
        version: 1,
        character,
        player: {
          level: 1, exp: 0, gold: 0, points: 0,
          stats: { str: 1, vit: 1, agi: 1, luck: 1 },
        },
        progress: { stage: 0, maxStage: 0, kills: 0, autoBoss: false },
        records: { totalKills: 0, bossKills: 0 },
        createdAt: Date.now(),
      };
      this.write();
      return this.data;
    },

    load() {
      try {
        const raw = localStorage.getItem(KEY);
        if (!raw) return null;
        const d = JSON.parse(raw);
        if (!d || d.version !== 1 || !d.character) return null;
        this.data = d;
        return d;
      } catch (e) {
        return null;
      }
    },

    write() {
      if (!this.data) return;
      this.data.savedAt = Date.now();
      try { localStorage.setItem(KEY, JSON.stringify(this.data)); } catch (e) { /* gizli mod vb. */ }
    },

    reset() {
      try { localStorage.removeItem(KEY); } catch (e) { /* yok say */ }
      this.data = null;
    },
  };
})(window.Lumora);
