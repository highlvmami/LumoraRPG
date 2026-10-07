// Karakter tasarlama ekranı: sekmeler (Görünüm / Kıyafet / Şapka), renk kutucukları ve kıyafet kartları.
// Kartlardaki küçük resimler, karakterin o kıyafeti giymiş halinden kırpılır.
(function (L) {
  const $ = (id) => document.getElementById(id);
  const TABS = [
    { id: 'look', name: 'Görünüm', keys: ['skin', 'hairStyle', 'hairColor', 'eye'] },
    { id: 'outfit', name: 'Kıyafet', keys: ['top', 'bottom', 'shoes'] },
    { id: 'hat', name: 'Şapka', keys: ['hat'] },
  ];

  L.creator = {
    app: null,
    onDone: null,
    onBack: null,
    tab: 'look',
    raf: 0,

    open(initial, onDone, { editing = false, onBack = null } = {}) {
      this.app = L.appearance.normalize(initial || L.appearance.defaults());
      this.onDone = onDone;
      this.onBack = onBack;
      document.querySelectorAll('.screen').forEach((s) => s.classList.add('hidden'));
      $('creator').classList.remove('hidden');
      L.forest.start();
      $('startBtn').textContent = editing ? 'Kaydet ✔' : 'Maceraya Başla ▶';
      $('creatorTitle').textContent = editing ? 'Karakterini Düzenle' : 'Kahramanını Yarat';
      $('creatorBack').classList.toggle('hidden', !onBack);
      $('charName').value = this.app.name;
      this.buildTabs();
      this.build();
      cancelAnimationFrame(this.raf);
      const loop = (ts) => { this.drawPreview(ts / 1000); this.raf = requestAnimationFrame(loop); };
      this.raf = requestAnimationFrame(loop);
    },

    close() {
      cancelAnimationFrame(this.raf);
      $('creator').classList.add('hidden');
    },

    bind() {
      $('charName').addEventListener('input', (e) => { this.app.name = e.target.value.trim(); });
      $('randomBtn').addEventListener('click', () => {
        const name = this.app.name;
        this.app = Object.assign(L.appearance.random(), { name });
        this.build();
      });
      $('creatorBack').addEventListener('click', () => { this.close(); this.onBack && this.onBack(); });
      $('startBtn').addEventListener('click', () => {
        if (!this.app.name) {
          $('charName').classList.add('shake');
          $('charName').focus();
          setTimeout(() => $('charName').classList.remove('shake'), 400);
          return;
        }
        this.close();
        this.onDone && this.onDone({ ...this.app });
      });
    },

    buildTabs() {
      const box = $('creatorTabs');
      box.innerHTML = '';
      for (const t of TABS) {
        const b = document.createElement('button');
        b.className = 'tab' + (t.id === this.tab ? ' active' : '');
        b.textContent = t.name;
        b.onclick = () => { this.tab = t.id; this.buildTabs(); this.build(); };
        box.appendChild(b);
      }
    },

    build() {
      const box = $('creatorOptions');
      box.innerHTML = '';
      const tab = TABS.find((t) => t.id === this.tab);
      for (const key of tab.keys) {
        const opt = L.appearance.options.find((o) => o.key === key);
        const sec = document.createElement('div');
        sec.className = 'opt-section';
        const label = document.createElement('div');
        label.className = 'opt-label';
        label.textContent = opt.label;
        sec.appendChild(label);
        sec.appendChild(opt.type === 'color' ? this.swatches(opt) : this.cards(opt));
        box.appendChild(sec);
      }
    },

    swatches(opt) {
      const wrap = document.createElement('div');
      wrap.className = 'swatches';
      for (const c of opt.values) {
        const b = document.createElement('button');
        b.className = 'swatch' + (this.app[opt.key] === c ? ' active' : '');
        b.style.background = c;
        b.onclick = () => { this.app[opt.key] = c; this.build(); };
        wrap.appendChild(b);
      }
      return wrap;
    },

    cards(opt) {
      const wrap = document.createElement('div');
      wrap.className = 'cards';
      const [cx, cy, cw, ch] = opt.crop;
      for (const v of opt.values) {
        const b = document.createElement('button');
        b.className = 'card' + (this.app[opt.key] === v.id ? ' active' : '');
        b.title = v.name;
        const cv = document.createElement('canvas');
        const S = 3;
        cv.width = cw * S; cv.height = ch * S;
        // saç kartlarında şapka saçı kapatmasın
        const look = { ...this.app, [opt.key]: v.id };
        if (opt.key === 'hairStyle') look.hat = 'none';
        const spr = L.pixel.character(look, S);
        cv.getContext('2d').drawImage(spr, cx * S, cy * S, cw * S, ch * S, 0, 0, cw * S, ch * S);
        const name = document.createElement('span');
        name.textContent = v.name;
        b.append(cv, name);
        b.onclick = () => { this.app[opt.key] = v.id; this.build(); };
        wrap.appendChild(b);
      }
      return wrap;
    },

    drawPreview(t) {
      const c = $('previewCanvas'), ctx = c.getContext('2d');
      ctx.imageSmoothingEnabled = false;
      ctx.clearRect(0, 0, c.width, c.height);
      // sahne ışığı + gölge
      const g = ctx.createRadialGradient(128, 300, 10, 128, 300, 120);
      g.addColorStop(0, 'rgba(255,200,120,0.25)');
      g.addColorStop(1, 'rgba(255,200,120,0)');
      ctx.fillStyle = g; ctx.fillRect(0, 150, 256, 202);
      ctx.fillStyle = 'rgba(0,0,0,0.35)';
      ctx.fillRect(68, 340, 120, 7); ctx.fillRect(84, 337, 88, 13);
      const bob = Math.sin(t * 3) > 0 ? 0 : 7;
      ctx.drawImage(L.pixel.character(this.app, 7), 16, 8 + bob);
    },
  };
})(window.Lumora);
