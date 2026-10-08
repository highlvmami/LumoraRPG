// Checks rooms, invites and the relay with real WebSocket clients.
process.env.PORT = process.env.PORT || "18080";
const assert = require("assert");
const WebSocket = require("ws");
const { server, wss } = require("./index.js");

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
  const a = await client();
  const b = await client();
  a.send({ t: "hello", name: "mami" });
  b.send({ t: "hello", name: "Ece" });
  const wa = await a.next("welcome");
  const wb = await b.next("welcome");

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
