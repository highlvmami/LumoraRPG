// Geliştirici hile menüsü.
// Açmak için: adrese ?dev ekle (örn. index.html?dev). Bir kere açınca bu tarayıcıda hatırlanır.
// Kapatmak için: ?dev=0. Menü açıkken ` (backtick) tuşu veya 🛠️ butonu paneli açar/kapar.
(function (L) {
  const KEY = 'lumora_dev';
  const U = L.utils;

  // Oyunun diğer kısımlarının okuduğu hile bayrakları
  L.dev = { enabled: false, god: false, oneShot: false, speed: 1 };

  function readFlag() {
    const params = new URLSearchParams(location.search);
    try {
      if (params.has('dev')) localStorage.setItem(KEY, params.get('dev') === '0' ? '0' : '1');
      return localStorage.getItem(KEY) === '1';
    } catch (e) {
      return params.has('dev') && params.get('dev') !== '0';
    }
  }

  function el(tag, attrs = {}, children = []) {
    const e = document.createElement(tag);
    Object.assign(e, attrs);
    children.forEach((c) => e.append(c));
    return e;
  }

  function btn(label, fn) {
    return el('button', { className: 'btn dev-btn', textContent: label, onclick: () => { fn(); refresh(); } });
  }

  function toggle(label, key) {
    const input = el('input', { type: 'checkbox', checked: L.dev[key], onchange: (e) => { L.dev[key] = e.target.checked; } });
    return el('label', { className: 'dev-toggle' }, [input, ' ' + label]);
  }

  function section(title, items) {
    return el('div', { className: 'dev-section' }, [el('div', { className: 'dev-title', textContent: title }), el('div', { className: 'dev-row' }, items)]);
  }

  const data = () => L.save.data;
  const B = () => L.battle;

  function refresh() {
    L.hud.buildStats();
    L.hud.update();
    L.save.write();
  }

  function addLevels(n) {
    for (let i = 0; i < n; i++) L.player.addExp(L.player.expNeeded() - data().player.exp);
  }

  function jumpTo(label) {
    const m = String(label).trim().match(/^(\d+)\s*-\s*(\d+)$/);
    const n = L.balance.stagesPerWorld;
    if (!m || +m[2] < 1 || +m[2] > n) { alert(`Bölümü "dünya-bölüm" şeklinde yaz (örn. 2-5, bölüm 1-${n} arası).`); return; }
    const i = (+m[1] - 1) * n + (+m[2] - 1);
    const p = data().progress;
    if (i > p.maxStage) { p.maxStage = i; p.kills = 0; }
    B().goToStage(i);
    B().log(`🛠️ ${L.worlds.label(i)} bölümüne ışınlandın.`, 'boss');
  }

  function build() {
    const stageInput = el('input', { className: 'dev-input', placeholder: 'örn. 2-5' });
    const speedSel = el('select', { className: 'dev-input', onchange: (e) => { L.dev.speed = +e.target.value; } },
      [1, 2, 5, 10].map((v) => el('option', { value: v, textContent: `${v}x`, selected: L.dev.speed === v })));

    const panel = el('div', { id: 'devPanel', className: 'panel dev-panel hidden' }, [
      el('h3', { textContent: '🛠️ Geliştirici Menüsü' }),
      section('Altın', [
        btn('+1K', () => L.player.addGold(1e3)),
        btn('+100K', () => L.player.addGold(1e5)),
        btn('+10M', () => L.player.addGold(1e7)),
      ]),
      section('Level / Puan', [
        btn('+1 Level', () => addLevels(1)),
        btn('+10 Level', () => addLevels(10)),
        btn('+10 Puan', () => { data().player.points += 10; }),
        btn('Puanları geri al', () => {
          const p = data().player;
          for (const k in p.stats) { p.points += p.stats[k] - 1; p.stats[k] = 1; }
        }),
      ]),
      section('Savaş', [
        btn('Canavarı öldür', () => { const M = B().monster; if (M && M.hp > 0 && M.dying <= 0 && !B().player.dead) { M.hp = 0; B().kill(L.player.derived()); } }),
        btn('Mobları doldur', () => { const p = data().progress; B().goToStage(p.maxStage); p.kills = L.balance.killsForBoss; }),
        btn('Boss çağır', () => {
          const p = data().progress;
          if (p.stage !== p.maxStage) B().goToStage(p.maxStage);
          p.kills = Math.max(p.kills, L.balance.killsForBoss);
          B().summonBoss();
        }),
        btn('Canı doldur', () => { B().player.hp = L.player.derived().maxHp; }),
      ]),
      section('Hileler', [toggle('Ölümsüzlük', 'god'), toggle('Tek vuruş', 'oneShot'),
        el('label', { className: 'dev-toggle' }, ['Oyun hızı ', speedSel])]),
      section('Bölüme git', [stageInput, btn('Git', () => jumpTo(stageInput.value))]),
    ]);

    const fab = el('button', { className: 'btn dev-fab', textContent: '🛠️', title: 'Geliştirici menüsü (`)', onclick: togglePanel });
    document.body.append(panel, fab);
  }

  function togglePanel() {
    document.getElementById('devPanel').classList.toggle('hidden');
  }

  L.devmenu = {
    init() {
      L.dev.enabled = readFlag();
      if (!L.dev.enabled) return;
      build();
      document.addEventListener('keydown', (e) => {
        if (e.key === '`' && document.activeElement.tagName !== 'INPUT') togglePanel();
      });
    },
  };
})(window.Lumora);
