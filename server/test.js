// Checks rooms, invites and the relay with real WebSocket clients.
process.env.PORT = process.env.PORT || "18080";
const assert = require("assert");
const WebSocket = require("ws");
const { server, wss, ready } = require("./index.js");
const { weekKey } = require("./guilds.js");

function client() {
  return new Promise((resolve) => {
    const ws = new WebSocket("ws://localhost:" + process.env.PORT);
    const inbox = [];
    const waiters = [];
    ws.on("message", (data) => {
      const msg = JSON.parse(data.toString());
      const w = waiters.findIndex((x) => x.t === msg.t);
      if (w >= 0) waiters.splice(w, 1)[0].resolve(msg);
      else inbox.push(msg);
    });
    const c = {
      send: (m) => ws.send(JSON.stringify(m)),
      next: (t) =>
        new Promise((res) => {
          const i = inbox.findIndex((m) => m.t === t);
          if (i >= 0) return res(inbox.splice(i, 1)[0]);
          waiters.push({ t, resolve: res });
        }),
      close: () => ws.close(),
    };
    ws.on("open", () => resolve(c));
  });
}

(async () => {
  await ready;
  const a = await client();
  const b = await client();
  const wa = await a.next("welcome");
  const wb = await b.next("welcome");

  // Accounts: nothing works before signing in.
  a.send({ t: "create" });
  assert.match((await a.next("error")).msg, /giriş/);
  a.send({ t: "login", name: "mami", pw: "gizli1" });
  assert.strictEqual((await a.next("auth")).code, "no_account");
  a.send({ t: "register", name: "mami", pw: "gizli1", profile: { gold: 5 }, at: 10 });
  const reg = await a.next("auth");
  assert.ok(reg.ok && reg.token && reg.profile.gold === 5);
  b.send({ t: "register", name: "MAMI", pw: "baska" });
  assert.strictEqual((await b.next("auth")).code, "taken");
  b.send({ t: "register", name: "a b", pw: "baska" });
  assert.strictEqual((await b.next("auth")).code, "bad_name");
  b.send({ t: "login", name: "Mami", pw: "yanlis" });
  assert.strictEqual((await b.next("auth")).code, "wrong_password");
  b.send({ t: "resume", name: "mami", token: "uydurma" });
  assert.strictEqual((await b.next("auth")).code, "token");
  b.send({ t: "exists", name: "MAMİ" });
  b.send({ t: "register", name: "Ece", pw: "sifre2" });
  assert.ok((await b.next("auth")).ok);

  // Saves: newer replaces older; a login on another device gets it back.
  a.send({ t: "save", profile: { gold: 99 }, at: 20 });
  assert.strictEqual((await a.next("saved")).at, 20);
  a.send({ t: "save", profile: { gold: 1 }, at: 15 });
  const c3 = await client();
  await c3.next("welcome");
  c3.send({ t: "resume", name: "mami", token: reg.token });
  const back = await c3.next("auth");
  assert.ok(back.ok && back.profile.gold === 99 && back.savedAt === 20, "older save must not win");
  c3.send({ t: "online_list" });
  assert.deepStrictEqual((await c3.next("online_list")).names.sort(), ["Ece", "mami"]);
  c3.send({ t: "password", new: "yeni12" });
  const pw = await c3.next("password");
  assert.ok(pw.ok && pw.token);
  c3.send({ t: "login", name: "mami", pw: "yeni12" });
  assert.ok((await c3.next("auth")).ok);
  c3.close();

  a.send({ t: "who", names: ["ece", "nobody"] });
  assert.deepStrictEqual((await a.next("who")).online, ["ece"]);

  // Leaderboards and levels come from the saved games.
  a.send({ t: "save", profile: { accountLevel: 7, totalKills: 50, stats: { bossKills: 3 } }, at: 30 });
  await a.next("saved");
  b.send({ t: "save", profile: { accountLevel: 3, totalKills: 120, stats: { bossKills: "çok" } }, at: 5 });
  await b.next("saved");
  a.send({ t: "who", names: ["ece", "MAMİ", "nobody"] });
  assert.deepStrictEqual((await a.next("who")).levels, { Ece: 3, mami: 7 });
  a.send({ t: "leaderboard", cat: "level" });
  const lvBoard = await a.next("leaderboard");
  assert.deepStrictEqual(lvBoard.rows.map((r) => [r.name, r.value]), [["mami", 7], ["Ece", 3]]);
  assert.deepStrictEqual(lvBoard.me, { rank: 1, value: 7 });
  b.send({ t: "leaderboard", cat: "kills" });
  const killBoard = await b.next("leaderboard");
  assert.strictEqual(killBoard.rows[0].name, "Ece");
  assert.strictEqual(killBoard.rows[0].level, 3);
  b.send({ t: "leaderboard", cat: "bosses" });
  const bossBoard = await b.next("leaderboard");
  assert.deepStrictEqual(bossBoard.me, { rank: 2, value: 0 }, "a value that isn't a number counts as 0");
  b.send({ t: "leaderboard", cat: "nope" });
  assert.match((await b.next("error")).msg, /sıralama/);

  a.send({ t: "create", look: { class: "mage", tunic: "#123456" } });
  const room = await a.next("room");
  assert.strictEqual(room.members[0].look.class, "mage");
  assert.strictEqual(room.host, wa.id);
  assert.strictEqual(room.code.length, 5);

  a.send({ t: "invite", to: "ECE" });
  const inv = await b.next("invited");
  assert.strictEqual(inv.from, "mami");
  assert.strictEqual(inv.code, room.code);
  await a.next("invite_sent");
  a.send({ t: "invite", to: "nobody" });
  assert.match((await a.next("error")).msg, /çevrimiçi değil/);

  b.send({ t: "join", code: inv.code.toLowerCase(), look: { class: "warrior", junk: "x".repeat(5000) } });
  assert.strictEqual((await b.next("exists")).found, true);
  const joined = await b.next("room");
  assert.strictEqual(joined.members.length, 2);
  assert.strictEqual(joined.members[1].look, null, "a too big look is ignored");
  assert.strictEqual(joined.you, wb.id);
  await a.next("room");
  b.send({ t: "look", look: { class: "archer" } });
  assert.strictEqual((await a.next("room")).members[1].look.class, "archer");
  await b.next("room");

  a.send({ t: "game", d: { k: "snap", n: 1 } });
  const g = await b.next("game");
  assert.strictEqual(g.from, wa.id);
  assert.strictEqual(g.d.n, 1);
  b.send({ t: "game", d: { k: "me" }, to: wa.id });
  assert.strictEqual((await a.next("game")).d.k, "me");

  b.send({ t: "join", code: "ZZZZZ" });
  assert.match((await b.next("error")).msg, /oda yok/);

  a.send({ t: "leave" });
  assert.match((await b.next("room_closed")).reason, /Ev sahibi/);

  // The hub tavern: both sit down, chat reaches everyone in it.
  a.send({ t: "hub_join", look: { class: "mage" } });
  const hubA = await a.next("hub");
  assert.strictEqual(hubA.members.length, 1);
  assert.strictEqual(hubA.members[0].seat, 0);
  assert.strictEqual(hubA.members[0].look.class, "mage");
  b.send({ t: "hub_join" });
  const hubB = await b.next("hub");
  assert.strictEqual(hubB.members.length, 2);
  assert.strictEqual(hubB.you, wb.id);
  assert.notStrictEqual(hubB.members[0].seat, hubB.members[1].seat, "everyone gets their own seat");
  assert.ok(hubB.members.every((m) => m.level >= 1), "hub members come with their account level");
  assert.strictEqual((await a.next("hub")).members.length, 2);
  // Movement: numbers only, known actions only, passed to the others but not back.
  b.send({ t: "hub_state", d: { p: [1.234, 0, -2], f: 1.5, s: 4, a: "sit", o: 7, junk: "x" } });
  const st = await a.next("hub_state");
  assert.strictEqual(st.id, wb.id);
  assert.deepStrictEqual(st.d, { p: [1.23, 0, -2], f: 1.5, s: 4, a: "sit", o: 7 });
  await new Promise((r) => setTimeout(r, 50));
  b.send({ t: "hub_state", d: { p: ["x", null, 1e999], f: "no", a: "fly", o: -5 } });
  const bad = await a.next("hub_state");
  assert.deepStrictEqual(bad.d, { p: [0, 0, 0], f: 0, s: 0, a: "", o: -1 }, "bad movement data is cleaned");
  b.send({ t: "chat", text: "  merhaba\nherkese  " });
  const line = await a.next("hub_chat");
  assert.strictEqual(line.text, "merhaba herkese");
  assert.strictEqual(line.id, wb.id);
  await b.next("hub_chat");
  b.send({ t: "chat", text: "çok hızlı" });
  b.send({ t: "chat", text: "x".repeat(500) });
  await new Promise((r) => setTimeout(r, 700));
  b.send({ t: "chat", text: "x".repeat(500) });
  const long = await a.next("hub_chat");
  assert.strictEqual(long.text.length, 200, "chat lines are cut short");
  await b.next("hub_chat");
  b.send({ t: "hub_leave" });
  const afterLeave = await a.next("hub");
  assert.strictEqual(afterLeave.members.length, 1);
  b.send({ t: "hub_join" });
  const hubBack = await b.next("hub");
  assert.ok(hubBack.chat.some((c) => c.text === "merhaba herkese"), "the last chat lines are shown when you come in");
  await a.next("hub");
  await new Promise((r) => setTimeout(r, 700));
  b.send({ t: "chat", text: "son söz" });
  a.send({ t: "hub_leave" });
  await b.next("hub_chat");
  await b.next("hub");

  // Guilds: create, list, join, chat, kick, leave; the tag shows in the hub.
  a.send({ t: "guild" });
  assert.strictEqual((await a.next("guild")).guild, null);
  a.send({ t: "guild_create", name: "x", tag: "AB" });
  assert.match((await a.next("error")).msg, /Lonca adı/);
  a.send({ t: "guild_create", name: "Gece Kurtları", tag: "gk" });
  const made = (await a.next("guild")).guild;
  assert.ok(made.name === "Gece Kurtları" && made.tag === "GK" && made.leader === "mami" && made.members.length === 1);
  b.send({ t: "guild_create", name: "Başka", tag: "GK" });
  assert.match((await b.next("error")).msg, /etiket/);
  b.send({ t: "guild_list" });
  const list = (await b.next("guild_list")).guilds;
  assert.ok(list.length === 1 && list[0].members === 1);
  b.send({ t: "guild_join", name: "gece kurtları" });
  const gJoined = (await b.next("guild")).guild;
  assert.strictEqual(gJoined.members.length, 2);
  assert.ok(gJoined.members.every((m) => m.online), "members show who is online");
  assert.strictEqual((await a.next("guild")).guild.members.length, 2);
  let tagged = false;
  for (let i = 0; i < 4 && !tagged; i++) tagged = (await b.next("hub")).members.some((m) => m.guild === "GK");
  assert.ok(tagged, "the guild tag shows in the hub");
  b.send({ t: "guild_chat", text: "selam lonca" });
  assert.strictEqual((await a.next("guild_chat")).text, "selam lonca");
  await b.next("guild_chat");
  // Weekly goal: the goal needs enough kills; helpers take the reward once.
  a.send({ t: "guild_kills", n: 100 });
  const q1 = (await a.next("guild")).guild.quest;
  await b.next("guild");
  assert.strictEqual(q1.goal, 1800, "the goal grows with the members");
  assert.strictEqual(q1.progress, 100);
  b.send({ t: "guild_claim" });
  assert.match((await b.next("error")).msg, /hedef/);
  a.send({ t: "guild_kills", n: 99999 });
  const q2 = (await a.next("guild")).guild.quest;
  await b.next("guild");
  assert.ok(q2.progress >= q2.goal && q2.progress <= 2600, "one report can only add so much");
  b.send({ t: "guild_claim" });
  assert.match((await b.next("error")).msg, /katkı/);
  a.send({ t: "guild_claim" });
  assert.strictEqual((await a.next("guild_reward")).gold, 400);
  assert.deepStrictEqual((await a.next("guild")).guild.quest.claimed, ["mami"]);
  await b.next("guild");
  a.send({ t: "guild_claim" });
  assert.match((await a.next("error")).msg, /zaten/);
  assert.strictEqual(weekKey(Date.UTC(2026, 9, 10)), "2026-W41");
  assert.notStrictEqual(weekKey(Date.UTC(2026, 9, 10)), weekKey(Date.UTC(2026, 9, 12)));
  // Treasury and upgrades: members donate, only the leader buys.
  b.send({ t: "guild_donate", gold: 0 });
  assert.match((await b.next("error")).msg, /Bağış/);
  b.send({ t: "guild_donate", gold: 500 });
  assert.strictEqual((await b.next("guild_donated")).gold, 500);
  const gd = (await a.next("guild")).guild;
  assert.strictEqual(gd.upgrades.treasury, 500);
  assert.strictEqual(gd.upgrades.donors[0].name, "Ece");
  await b.next("guild");
  b.send({ t: "guild_upgrade", id: "gold" });
  assert.match((await b.next("error")).msg, /lider/);
  a.send({ t: "guild_upgrade", id: "gold" });
  assert.match((await a.next("error")).msg, /yeterli/);
  a.send({ t: "guild_donate", gold: 700 });
  await a.next("guild_donated");
  await a.next("guild");
  await b.next("guild");
  a.send({ t: "guild_upgrade", id: "gold" });
  const up = (await a.next("guild")).guild.upgrades;
  await b.next("guild");
  assert.strictEqual(up.levels.gold, 1);
  assert.strictEqual(up.treasury, 600, "the treasury pays for the upgrade");
  assert.ok(Math.abs(up.bonuses.goldGain - 0.02) < 1e-9);
  assert.strictEqual(up.costs.gold, 1200, "the next level costs more");
  a.send({ t: "guild_upgrade", id: "nope" });
  assert.match((await a.next("error")).msg, /Böyle/);
  b.send({ t: "guild_kick", name: "mami" });
  assert.match((await b.next("error")).msg, /lider/);
  a.send({ t: "guild_kick", name: "Ece" });
  assert.strictEqual((await b.next("guild")).guild, null, "a kicked member is out");
  assert.strictEqual((await a.next("guild")).guild.members.length, 1);
  a.send({ t: "guild_leave" });
  assert.strictEqual((await a.next("guild")).guild, null);
  b.send({ t: "guild_list" });
  assert.strictEqual((await b.next("guild_list")).guilds.length, 0, "the last one leaving closes the guild");

  // Duels: a challenge, an answer, and one replay for both sides.
  const strong = { cls: "warrior", hp: 500, dmg: 40, aps: 2, crit: 0.1, critDmg: 1.5, defense: 0.1 };
  const weak = { cls: "mage", hp: 60, dmg: 4, aps: 1, crit: 0, critDmg: 1.5, defense: 0 };
  assert.match((await b.next("error")).msg, /çıkarıldın/);
  a.send({ t: "duel_challenge", to: "mami", fighter: strong });
  assert.match((await a.next("error")).msg, /Kendinle/);
  a.send({ t: "duel_challenge", to: "nobody", fighter: strong });
  assert.match((await a.next("error")).msg, /çevrimiçi değil/);
  a.send({ t: "duel_challenge", to: "Ece", fighter: strong });
  assert.strictEqual((await a.next("duel_sent")).to, "Ece");
  const inbox = await b.next("duel_inbox");
  assert.strictEqual(inbox.invites[0].from, "mami");
  b.send({ t: "duel_answer", from: "mami", accept: true, fighter: weak });
  await b.next("duel_inbox");
  const duel = await b.next("duel_result");
  const duelA = await a.next("duel_result");
  assert.strictEqual(duel.winner, 0, "the stronger fighter wins");
  assert.deepStrictEqual(duel.frames, duelA.frames, "both sides see the same replay");
  assert.ok(duel.frames.length >= 2 && (duel.frames.at(-1)[1] === 0 || duel.frames.at(-1)[2] === 0));
  b.send({ t: "duel_answer", from: "mami", accept: true, fighter: weak });
  assert.match((await b.next("error")).msg, /geçerli değil/);
  a.send({ t: "duel_challenge", to: "Ece", fighter: { hp: 1e12, dmg: -5, aps: "x" } });
  await a.next("duel_sent");
  await b.next("duel_inbox");
  b.send({ t: "duel_answer", from: "mami", accept: false });
  await b.next("duel_inbox");
  assert.strictEqual((await a.next("duel_declined")).by, "Ece");

  // Trades: offer, decline, cancel, accept; offers go away when the seller leaves.
  a.send({ t: "trade_offer", to: "nobody", item: { uid: 1 }, price: 5 });
  assert.match((await a.next("error")).msg, /çevrimiçi değil/);
  a.send({ t: "trade_offer", to: "ece", item: { uid: 1 }, price: -3 });
  assert.match((await a.next("error")).msg, /Fiyat/);
  a.send({ t: "trade_offer", to: "ece", item: { uid: 7, rarity: 2, slot: "ring" }, price: 40 });
  assert.strictEqual((await a.next("trades")).offers.length, 1);
  const offered = (await b.next("trades")).offers;
  assert.ok(offered.length === 1 && offered[0].from === "mami" && offered[0].price === 40 && offered[0].item.uid === 7);
  a.send({ t: "trade_offer", to: "ece", item: { uid: 7 }, price: 1 });
  assert.match((await a.next("error")).msg, /zaten/);
  b.send({ t: "trade_answer", id: offered[0].id, accept: false });
  assert.match((await a.next("trade_closed")).reason, /reddetti/);
  await b.next("trade_closed");
  assert.strictEqual((await a.next("trades")).offers.length, 0);
  await b.next("trades");
  a.send({ t: "trade_offer", to: "ece", item: { uid: 7 }, price: 10 });
  await a.next("trades");
  const again = (await b.next("trades")).offers[0];
  a.send({ t: "trade_cancel", id: again.id });
  assert.match((await b.next("trade_closed")).reason, /geri aldı/);
  await a.next("trade_closed");
  await a.next("trades");
  await b.next("trades");
  a.send({ t: "trade_offer", to: "ece", item: { uid: 8, rarity: 4 }, price: 25 });
  await a.next("trades");
  const third = (await b.next("trades")).offers[0];
  b.send({ t: "trade_answer", id: third.id, accept: true });
  const doneA = await a.next("trade_done");
  const doneB = await b.next("trade_done");
  assert.ok(doneA.from === "mami" && doneA.to === "Ece" && doneA.price === 25 && doneB.item.uid === 8);
  b.send({ t: "trade_answer", id: third.id, accept: true });
  let twice = "";
  for (let i = 0; i < 4 && !/artık yok/.test(twice); i++) twice = (await b.next("error")).msg;
  assert.match(twice, /artık yok/, "a trade cannot be taken twice");
  await a.next("trades");
  await b.next("trades");
  a.send({ t: "trade_offer", to: "ece", item: { uid: 9 }, price: 1 });
  await b.next("trades");
  a.close();
  assert.match((await b.next("trade_closed")).reason, /çevrimdışı/, "offers end when the seller goes offline");

  // Parkour: times are sane-checked, the best counts, gold only for real finishes.
  b.send({ t: "pk_finish", ms: 3000, falls: 0 });
  assert.match((await b.next("error")).msg, /geçerli değil/, "an impossible time is refused");
  b.send({ t: "pk_finish", ms: 90000, falls: 2 });
  const pk1 = await b.next("pk_result");
  assert.ok(pk1.first && pk1.record && pk1.gold === 340, "the first finish pays a bonus");
  const pkb1 = await b.next("pk_board");
  assert.ok(pkb1.mine.best === 90000 && pkb1.mine.rank === 1 && pkb1.top.length === 1 && pkb1.total === 1);
  b.send({ t: "pk_finish", ms: 120000, falls: 1 });
  const pk2 = await b.next("pk_result");
  assert.ok(!pk2.first && !pk2.record && pk2.gold === 40, "a slower run pays little and keeps the best");
  const pkb2 = await b.next("pk_board");
  assert.ok(pkb2.mine.best === 90000 && pkb2.mine.runs === 2 && pkb2.mine.falls === 3 && pkb2.mine.last === 120000);
  b.send({ t: "pk_finish", ms: 80000, falls: 0 });
  assert.ok((await b.next("pk_result")).record, "a faster run is a new record");
  await b.next("pk_board");

  // World boss: shared health, capped fights, a share of gold once it is down.
  
  b.send({ t: "wb_info" });
  const wb0 = await b.next("wb_state");
  assert.ok(wb0.hp === wb0.max && wb0.name && !wb0.dead);
  b.send({ t: "wb_hit", dmg: 999999 });
  const wb1 = await b.next("wb_state");
  assert.ok(wb1.mine === 40000 && wb1.hp === wb0.max - 40000 && wb1.rank === 1, "a fight is capped");
  b.send({ t: "wb_hit", dmg: 100 });
  await b.next("error");
  b.send({ t: "wb_claim" });
  assert.match((await b.next("error")).msg, /henüz yenilmedi/);
  const { WorldBoss, MAX_HP } = require("./worldboss.js");
  const boss = new WorldBoss(null);
  const t0 = Date.now();
  for (let i = 0; i < 10; i++) await boss.hit("x", 40000, t0 + i * 60000);
  assert.ok(boss.view("x", t0 + 600000).dead && boss.view("x", t0 + 600000).hp === 0, "ten big fights bring it down (" + MAX_HP + ")");
  const first = await boss.claim("x", t0 + 600000);
  assert.ok(first.ok && first.gold > 300);
  assert.ok(!(await boss.claim("x", t0 + 600000)).ok, "the reward is claimed once");

  // Tavern games: bets are checked, the server rolls once both agree.
  b.send({ t: "game_challenge", to: "nobody", kind: "dice", bet: 100 });
  assert.match((await b.next("error")).msg, /çevrimiçi değil/);
  const { Games } = require("./games.js");
  const tg = new Games();
  assert.ok(tg.challenge("ayse", "mehmet", "cards", 250).ok);
  assert.ok(tg.inbox("Mehmet").length === 1 && tg.inbox("Mehmet")[0].bet === 250);
  const played = tg.answer("Mehmet", "ayse", true);
  assert.ok(played.ok && (played.winner === 0 || played.winner === 1) && played.a.total !== undefined && played.bet === 250, "a game has a winner");
  assert.ok(!tg.answer("Mehmet", "ayse", true).ok, "an invite is used once");
  assert.ok(!tg.challenge("ayse", "ayse", "dice", 50).ok, "no game against yourself");

  b.close();
  wss.close();
  server.close();
  console.log("server test passed");
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
