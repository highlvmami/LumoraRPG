// Checks rooms, invites and the relay with real WebSocket clients.
process.env.PORT = process.env.PORT || "18080";
const assert = require("assert");
const WebSocket = require("ws");
const { server, wss, ready } = require("./index.js");

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

  a.send({ t: "create" });
  const room = await a.next("room");
  assert.strictEqual(room.host, wa.id);
  assert.strictEqual(room.code.length, 5);

  a.send({ t: "invite", to: "ECE" });
  const inv = await b.next("invited");
  assert.strictEqual(inv.from, "mami");
  assert.strictEqual(inv.code, room.code);
  await a.next("invite_sent");
  a.send({ t: "invite", to: "nobody" });
  assert.match((await a.next("error")).msg, /çevrimiçi değil/);

  b.send({ t: "join", code: inv.code.toLowerCase() });
  assert.strictEqual((await b.next("exists")).found, true);
  const joined = await b.next("room");
  assert.strictEqual(joined.members.length, 2);
  assert.strictEqual(joined.you, wb.id);
  await a.next("room");

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

  a.close();
  b.close();
  wss.close();
  server.close();
  console.log("server test passed");
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
