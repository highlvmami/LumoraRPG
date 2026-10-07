// Karakter tasarlama ekranı. Seçenek satırları appearance.options listesinden otomatik üretilir.
(function (L) {
  const $ = (id) => document.getElementById(id);

  L.creator = {
    app: null,
    onDone: null,
    raf: 0,

    open(initial, onDone, { editing = false } = {}) {
      this.app = Object.assign(L.appearance.defaults(), initial || {});
      this.onDone = onDone;
      $('creator').classList.remove('hidden');
      $('game').classList.add('hidden');
      $('startBtn').textContent = editing ? 'Kaydet ✔' : 'Maceraya Başla ▶';
      $('creatorTitle').textContent = editing ? 'Karakterini Düzenle' : 'Kahramanını Yarat';
      $('charName').value = this.app.name;
      this.build();
      const loop = (ts) => { this.drawPreview(ts / 1000); this.raf = requestAnimationFrame(loop); };
      cancelAnimationFrame(this.raf);
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

    build() {
      const box = $('creatorOptions');
      box.innerHTML = '';
      for (const opt of L.appearance.options) {
        const row = document.createElement('div');
        row.className = 'opt-row';
        const label = document.createElement('div');
        label.className = 'opt-label';
        label.textContent = opt.label;
        row.appendChild(label);

        if (opt.type === 'color') {
          const sw = document.createElement('div');
          sw.className = 'swatches';
          for (const c of opt.values) {
            const b = document.createElement('button');
            b.className = 'swatch' + (this.app[opt.key] === c ? ' active' : '');
            b.style.background = c;
            b.title = c;
            b.addEventListener('click', () => { this.app[opt.key] = c; this.build(); });
            sw.appendChild(b);
          }
          row.appendChild(sw);
        } else {
          const cyc = document.createElement('div');
          cyc.className = 'cycler';
          const idx = Math.max(0, opt.values.findIndex((v) => v.id === this.app[opt.key]));
          const step = (dir) => {
            const n = opt.values.length;
            this.app[opt.key] = opt.values[(idx + dir + n) % n].id;
            this.build();
          };
          const prev = document.createElement('button');
          prev.className = 'btn btn-sq'; prev.textContent = '◀'; prev.onclick = () => step(-1);
          const name = document.createElement('span');
          name.textContent = opt.values[idx].name;
          const next = document.createElement('button');
          next.className = 'btn btn-sq'; next.textContent = '▶'; next.onclick = () => step(1);
          cyc.append(prev, name, next);
          row.appendChild(cyc);
        }
        box.appendChild(row);
      }
    },

    drawPreview(t) {
      const c = $('previewCanvas'), ctx = c.getContext('2d');
      ctx.imageSmoothingEnabled = false;
      ctx.clearRect(0, 0, c.width, c.height);
      // zemin
      ctx.fillStyle = '#2b2f45';
      ctx.fillRect(16, 236, 160, 8);
      ctx.fillStyle = '#3b4163';
      ctx.fillRect(24, 232, 144, 4);
      const bob = Math.sin(t * 3) > 0 ? 0 : 6;
      ctx.drawImage(L.pixel.character(this.app, 6), 48, 236 - 168 + bob);
    },
  };
})(window.Lumora);
