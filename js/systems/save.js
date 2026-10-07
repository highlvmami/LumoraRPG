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
          level: 1, exp: 0, gold: 0, points: 0, skillPoints: 0, skills: {},
          stats: { str: 1, vit: 1, agi: 1, luck: 1 },
        },
        progress: { stage: 0, maxStage: 0, kills: 0, autoBoss: false },
        records: { totalKills: 0, bossKills: 0 },
        createdAt: Date.now(),
      };
      this.write();
      return this.data;
    },

    hasSave() {
      try { return !!localStorage.getItem(KEY); } catch (e) { return false; }
    },

    load() {
      try {
        const raw = localStorage.getItem(KEY);
        if (!raw) return null;
        const d = JSON.parse(raw);
        if (!d || d.version !== 1 || !d.character) return null;
        // eski kayıtları yeni sürüme uyarla
        d.character = L.appearance.normalize(d.character);
        if (d.player.skillPoints === undefined) d.player.skillPoints = (d.player.level - 1) * L.balance.skillPointsPerLevel;
        if (!d.player.skills) d.player.skills = {};
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
