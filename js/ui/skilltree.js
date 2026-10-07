// Yetenek ağacı paneli: 3 dal (sütun), her dalda 3 kademe. Düğüme tıklayınca alttaki
// bilgi kutusunda detay ve "Öğren" butonu çıkar.
(function (L) {
  const $ = (id) => document.getElementById(id);

  L.skilltree = {
    selected: 'sharp',

    bind() {
      $('resetSkillsBtn').onclick = () => {
        const spent = Object.values(L.save.data.player.skills).reduce((a, b) => a + b, 0);
        if (!spent) return;
        if (!confirm(`${spent} yetenek puanı geri alınsın mı?`)) return;
        L.player.resetSkills();
      };
      L.events.on('skillchange', () => { this.render(); L.save.write(); });
      L.events.on('levelup', () => this.render());
    },

    state(sk) {
      const r = L.player.skill(sk.id);
      if (r >= sk.max) return 'maxed';
      if (sk.requires && L.player.skill(sk.requires) <= 0) return 'locked';
      return L.save.data.player.skillPoints > 0 ? 'available' : 'open';
    },

    render() {
      if (!L.save.data) return;
      const p = L.save.data.player;
      $('skillPointsBadge').textContent = p.skillPoints;
      $('skillPointsBadge').classList.toggle('glow', p.skillPoints > 0);

      const tree = $('skillTree');
      tree.innerHTML = '';
      for (const br of L.skills.branches) {
        const col = document.createElement('div');
        col.className = 'skill-branch';
        col.style.setProperty('--branch', br.color);
        const head = document.createElement('div');
        head.className = 'branch-head';
        head.textContent = br.name;
        col.appendChild(head);
        const nodes = L.skills.list.filter((s) => s.branch === br.id).sort((a, b) => a.tier - b.tier);
        nodes.forEach((sk, i) => {
          if (i > 0) {
            const link = document.createElement('div');
            link.className = 'skill-link' + (L.player.skill(nodes[i - 1].id) > 0 ? ' on' : '');
            col.appendChild(link);
          }
          const r = L.player.skill(sk.id);
          const b = document.createElement('button');
          b.className = `skill-node ${this.state(sk)}` + (this.selected === sk.id ? ' selected' : '');
          b.title = sk.name;
          b.innerHTML = `<span class="skill-icon">${sk.icon}</span><span class="skill-rank">${r}/${sk.max}</span>`;
          b.onclick = () => { this.selected = sk.id; this.render(); };
          b.ondblclick = () => L.player.learn(sk.id);
          col.appendChild(b);
        });
        tree.appendChild(col);
      }
      this.renderInfo();
    },

    renderInfo() {
      const sk = L.skills.get(this.selected);
      const box = $('skillInfo');
      if (!sk) { box.innerHTML = ''; return; }
      const r = L.player.skill(sk.id);
      const br = L.skills.branches.find((b) => b.id === sk.branch);
      const req = sk.requires ? L.skills.get(sk.requires) : null;
      const lockedMsg = req && L.player.skill(req.id) <= 0 ? `<div class="si-req">🔒 Önce: ${req.name}</div>` : '';
      box.innerHTML = `
        <div class="si-head"><span class="si-icon">${sk.icon}</span>
          <div><div class="si-name" style="color:${br.color}">${sk.name}</div>
          <div class="small">${br.name} · Kademe ${sk.tier} · ${r}/${sk.max}</div></div></div>
        <div class="si-now">${r > 0 ? 'Şu an: <b>' + sk.desc(r) + '</b>' : 'Henüz öğrenilmedi'}</div>
        ${r < sk.max ? `<div class="si-next">Sonraki seviye: ${sk.next}</div>` : '<div class="si-next max">✦ Maksimum seviye</div>'}
        ${lockedMsg}`;
      if (r < sk.max) {
        const btn = document.createElement('button');
        btn.className = 'gbtn gbtn-gold gbtn-sm';
        btn.textContent = 'Öğren (1 puan)';
        btn.disabled = !L.player.canLearn(sk.id);
        btn.onclick = () => L.player.learn(sk.id);
        box.appendChild(btn);
      }
    },
  };
})(window.Lumora);
