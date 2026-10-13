'use strict';
// Grill UI server: serves structured Rounds and records Submissions.
// Runs beside the vendored upstream server.cjs, which stays unmodified (ADR-0014).
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execFile } = require('child_process');

const SESSION_DIR = process.env.BRAINSTORM_DIR || '/tmp/grill';
const STATE_DIR = path.join(SESSION_DIR, 'state');
const HOST = process.env.BRAINSTORM_HOST || '127.0.0.1';
const URL_HOST = process.env.BRAINSTORM_URL_HOST || (HOST === '127.0.0.1' ? 'localhost' : HOST);
const PORT_FILE = process.env.BRAINSTORM_PORT_FILE || null;
const TOKEN_FILE = process.env.BRAINSTORM_TOKEN_FILE || null;
const IDLE_MS = Number(process.env.BRAINSTORM_IDLE_TIMEOUT_MS) || 4 * 60 * 60 * 1000;
const MAX_BODY = 1024 * 1024;

fs.mkdirSync(STATE_DIR, { recursive: true });

function readFile(file) {
  try { return fs.readFileSync(file, 'utf-8').trim(); } catch (e) { return ''; }
}

function writePrivate(file, data) {
  fs.writeFileSync(file, data, { mode: 0o600 });
  try { fs.chmodSync(file, 0o600); } catch (e) { /* best effort */ }
}

function loadToken() {
  if (process.env.BRAINSTORM_TOKEN) return process.env.BRAINSTORM_TOKEN;
  const saved = TOKEN_FILE && readFile(TOKEN_FILE);
  if (saved && /^[0-9a-f]{32,}$/i.test(saved)) return saved;
  return crypto.randomBytes(32).toString('hex');
}
const TOKEN = loadToken();
let cookieName = 'grill-key';

function safeEqual(a, b) {
  const x = Buffer.from(String(a)), y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

function cookies(req) {
  const out = {};
  for (const part of (req.headers.cookie || '').split(';')) {
    const i = part.indexOf('=');
    if (i > 0) out[part.slice(0, i).trim()] = part.slice(i + 1).trim();
  }
  return out;
}

function authorized(req, params) {
  const key = params.get('key') || req.headers['x-grill-key'] || cookies(req)[cookieName];
  return Boolean(key) && safeEqual(key, TOKEN);
}

const pad = n => String(n).padStart(3, '0');
const roundFile = n => path.join(SESSION_DIR, `round-${pad(n)}.json`);
const answersFile = n => path.join(SESSION_DIR, `answers-${pad(n)}.json`);

function roundNumbers() {
  return fs.readdirSync(SESSION_DIR)
    .map(f => /^round-(\d+)\.json$/.exec(f))
    .filter(Boolean)
    .map(m => Number(m[1]))
    .sort((a, b) => a - b);
}

function readJson(file) {
  try { return JSON.parse(fs.readFileSync(file, 'utf-8')); } catch (e) { return null; }
}

function snapshot() {
  const rounds = roundNumbers().map(n => ({ round: readJson(roundFile(n)), answers: readJson(answersFile(n)) }))
    .filter(r => r.round);
  const latest = rounds[rounds.length - 1];
  const status = !latest ? 'waiting-for-agent' : latest.answers ? 'agent-working' : 'round-ready';
  const finished = readJson(path.join(SESSION_DIR, 'finished.json'));
  const docs = readJson(path.join(SESSION_DIR, 'docs-changed.json'));
  return {
    status: finished ? 'finished' : status, rounds, decisions: readFile(path.join(SESSION_DIR, 'decisions.md')),
    docs: Array.isArray(docs) ? docs.filter(d => typeof d === 'string' && d) : [],
    done: readJson(path.join(SESSION_DIR, 'done.json'))
  };
}

const ANSWER_KINDS = ['accept', 'option', 'skip', 'text'];
const END_ACTIONS = ['to-spec', 'to-tickets', 'keep-grilling', 'end'];

function validateSharedUnderstanding(sub) {
  if (!END_ACTIONS.includes(sub.action)) return 'unknown end action';
  if (sub.note !== undefined && typeof sub.note !== 'string') return 'note must be a string';
  if (sub.action === 'keep-grilling' && !(sub.note || '').trim()) return 'keep-grilling needs a note';
  return null;
}

function validateSubmission(sub, round) {
  if (round.type === 'shared-understanding') return sub && typeof sub === 'object' ? validateSharedUnderstanding(sub) : 'invalid submission';
  if (!sub || typeof sub !== 'object' || !Array.isArray(sub.answers)) return 'answers must be an array';
  const ids = new Set((round.questions || []).map(q => q.id));
  for (const a of sub.answers) {
    if (!a || !ids.has(a.id)) return 'unknown question id';
    if (!ANSWER_KINDS.includes(a.kind)) return 'invalid answer kind';
    if (a.kind === 'option' && typeof a.option !== 'string') return 'option answers need an option';
    if (a.text !== undefined && typeof a.text !== 'string') return 'text must be a string';
  }
  const answered = new Set(sub.answers.map(a => a.id));
  for (const id of ids) if (!answered.has(id)) return `question ${id} has no answer`;
  return null;
}

function send(res, status, type, body, extra) {
  res.writeHead(status, Object.assign({ 'Content-Type': type, 'Cache-Control': 'no-store' }, extra));
  res.end(body);
}
const sendJson = (res, status, obj) => send(res, status, 'application/json', JSON.stringify(obj));

const FORBIDDEN = '<!DOCTYPE html><meta charset="utf-8"><title>Key required</title>' +
  '<h1>Session key required</h1><p>Open the full URL including <code>?key=…</code>.</p>';

const NOTIFIED_FILE = path.join(STATE_DIR, 'notified');

function notifiedRounds() {
  return new Set(readFile(NOTIFIED_FILE).split('\n').filter(Boolean).map(Number));
}

function notifyNewRounds() {
  const seen = notifiedRounds();
  for (const n of roundNumbers()) {
    if (seen.has(n)) continue;
    const round = readJson(roundFile(n));
    if (!round) continue;
    seen.add(n);
    fs.appendFileSync(NOTIFIED_FILE, n + '\n');
    const count = (round.questions || []).length;
    execFile('cloudagent', ['notify', '--title', `Grill round ${n} ready`,
      '--body', `${count} question${count === 1 ? '' : 's'} waiting for you`], () => {});
  }
}

let lastActivity = Date.now();

const server = http.createServer((req, res) => {
  lastActivity = Date.now();
  const url = new URL(req.url, 'http://localhost');
  if (!authorized(req, url.searchParams)) return send(res, 403, 'text/html', FORBIDDEN);

  const cookie = `${cookieName}=${TOKEN}; Path=/; HttpOnly; SameSite=Strict; Max-Age=2592000`;
  if (req.method === 'GET' && url.pathname === '/') {
    return send(res, 200, 'text/html', PAGE, { 'Set-Cookie': cookie });
  }
  if (req.method === 'GET' && url.pathname === '/state') return sendJson(res, 200, snapshot());
  if (req.method === 'POST' && url.pathname === '/submit') return handleSubmit(req, res);
  send(res, 404, 'text/plain', 'Not found');
});

function handleSubmit(req, res) {
  let body = '';
  let tooBig = false;
  req.on('data', c => {
    body += c;
    if (body.length > MAX_BODY) { tooBig = true; req.destroy(); }
  });
  req.on('end', () => {
    if (tooBig) return;
    let sub;
    try { sub = JSON.parse(body); } catch (e) { return sendJson(res, 400, { error: 'invalid JSON' }); }
    const n = Number(sub && sub.round);
    const round = Number.isInteger(n) && n > 0 && readJson(roundFile(n));
    if (!round) return sendJson(res, 404, { error: 'unknown round' });
    const problem = validateSubmission(sub, round);
    if (problem) return sendJson(res, 400, { error: problem });
    const shared = round.type === 'shared-understanding';
    const record = {
      round: n,
      answers: shared ? [] : sub.answers.map(a => {
        const out = { id: a.id, kind: a.kind };
        if (a.kind === 'option') out.option = a.option;
        if (a.text) out.text = a.text;
        return out;
      }),
      comment: typeof sub.comment === 'string' ? sub.comment : '',
      source: 'browser',
      submitted_at: new Date().toISOString()
    };
    if (shared) {
      record.action = sub.action;
      record.note = (sub.note || '').trim();
    }
    try {
      // 'wx' makes a double-submit a conflict instead of clobbering the first.
      fs.writeFileSync(answersFile(n), JSON.stringify(record, null, 2) + '\n', { flag: 'wx' });
    } catch (e) {
      if (e.code === 'EEXIST') return sendJson(res, 409, { error: 'round already submitted' });
      return sendJson(res, 500, { error: 'could not save submission' });
    }
    sendJson(res, 200, { ok: true, round: n });
  });
}

function pickPort(cb) {
  const saved = Number(PORT_FILE && readFile(PORT_FILE));
  const preferred = saved || Number(process.env.BRAINSTORM_PORT) || 49152 + Math.floor(Math.random() * 16383);
  const tryPort = (port, retry) => {
    const onError = err => {
      if (err.code === 'EADDRINUSE' && retry) tryPort(0, false);
      else { console.error('grill server failed to bind: ' + err.message); process.exit(1); }
    };
    server.once('error', onError);
    server.listen(port, HOST, () => { server.removeListener('error', onError); cb(server.address().port); });
  };
  tryPort(preferred, true);
}

pickPort(port => {
  if (PORT_FILE) writePrivate(PORT_FILE, String(port));
  if (TOKEN_FILE) writePrivate(TOKEN_FILE, TOKEN);
  cookieName = 'grill-key-' + port;
  const info = {
    type: 'server-started',
    mode: 'grill',
    port,
    host: HOST,
    url: `http://${URL_HOST}:${port}/?key=${TOKEN}`,
    resumed: process.env.BRAINSTORM_RESUMED === 'true',
    session_dir: SESSION_DIR,
    decision_log: path.join(SESSION_DIR, 'decisions.md'),
    state_dir: STATE_DIR,
    round_pattern: path.join(SESSION_DIR, 'round-NNN.json'),
    answers_pattern: path.join(SESSION_DIR, 'answers-NNN.json')
  };
  notifyNewRounds();
  setInterval(notifyNewRounds, 1000).unref();
  writePrivate(path.join(STATE_DIR, 'server-info'), JSON.stringify(info) + '\n');
  try { fs.unlinkSync(path.join(STATE_DIR, 'server-stopped')); } catch (e) { /* none */ }
  console.log(JSON.stringify(info));
});

setInterval(() => {
  if (Date.now() - lastActivity > IDLE_MS) {
    writePrivate(path.join(STATE_DIR, 'server-stopped'), JSON.stringify({ reason: 'idle-timeout', timestamp: Date.now() }) + '\n');
    try { fs.unlinkSync(path.join(STATE_DIR, 'server-info')); } catch (e) { /* none */ }
    process.exit(0);
  }
}, 60000).unref();

const PAGE = `<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Grill</title>
<style>
:root{--bg:#fff;--fg:#1d1d1f;--bg2:#fff;--bg3:#e5e5e7;--border:#d0d0d5;--muted:#6e6e73;--accent:#0071e3;--rec:#eef6ff;--ok:#34c759;--err:#ff3b30;--code:#f5f5f7}
@media (prefers-color-scheme:dark){:root{--bg:#161618;--fg:#eee;--bg2:#2d2d2f;--bg3:#3d3d3f;--border:#444;--muted:#a1a1a6;--accent:#0a84ff;--rec:#1c2a3a;--ok:#30d158;--err:#ff453a;--code:#0d1117}}
*{box-sizing:border-box}
body{font:16px/1.5 system-ui,sans-serif;max-width:1040px;margin:0 auto;padding:1rem;background:var(--bg);color:var(--fg);overflow-wrap:anywhere}
#layout{display:grid;grid-template-columns:minmax(0,1fr) 270px;gap:1.5rem;align-items:start}
#panel{position:sticky;top:1rem;border:1px solid var(--border);border-radius:8px;padding:.75rem 1rem;font-size:.9rem;background:var(--bg)}
#panel h2{font-size:1rem;margin:0 0 .5rem}#panel ul{margin:.25rem 0;padding-left:1.1rem}
.counts{display:flex;flex-wrap:wrap;gap:.25rem .75rem;margin:.25rem 0}.counts b{font-variant-numeric:tabular-nums}
.log{margin-top:.75rem}.log li{margin:.25rem 0}
.q.settled{border-color:var(--ok)}.q.skipped{opacity:.75}
.bar{display:flex;flex-wrap:wrap;gap:.5rem;align-items:center;margin:1rem 0}
.q{border:1px solid var(--border);border-radius:8px;padding:1rem;margin:1rem 0;scroll-margin-top:6rem}
.q h3{margin:0 0 .5rem}.rec{background:var(--rec);border-radius:6px;padding:.5rem .75rem;margin:.5rem 0}
.notes{border-left:3px solid var(--accent);padding:.1rem .9rem;margin:1rem 0;background:var(--rec);border-radius:0 6px 6px 0}
.opts label{display:block;margin:.25rem 0}textarea{width:100%;min-height:3.5rem;margin-top:.5rem;background:var(--bg2);color:var(--fg);border:1px solid var(--border);border-radius:6px}
.status{color:var(--muted);font-size:.9rem}.past{opacity:.8;margin:.5rem 0}.past ul{margin:.25rem 0}button{font:inherit;padding:.5rem 1.25rem}
pre{background:var(--code);border:1px solid var(--border);border-radius:6px;padding:.75rem;overflow-x:auto}
pre code.hljs{padding:0;background:transparent}
:not(pre)>code{background:var(--code);border-radius:4px;padding:.1rem .3rem}
table{border-collapse:collapse}th,td{border:1px solid var(--border);padding:.25rem .6rem}
.mermaid{text-align:center;margin:1rem 0}
.mockup{background:var(--bg2);border:1px solid var(--border);border-radius:12px;overflow:hidden;margin:1rem 0}
.mockup-header{background:var(--bg3);padding:.5rem 1rem;font-size:.75rem;color:var(--muted);border-bottom:1px solid var(--border)}
.mockup-body{padding:1.5rem}
.split{display:grid;grid-template-columns:1fr 1fr;gap:1.5rem}
@media (max-width:700px){.split,.pros-cons{grid-template-columns:1fr}}
.pros-cons{display:grid;grid-template-columns:1fr 1fr;gap:1rem;margin:1rem 0}
.pros,.cons{background:var(--bg2);border-radius:8px;padding:1rem}
.pros h4{color:var(--ok);font-size:.85rem;margin-bottom:.5rem}.cons h4{color:var(--err);font-size:.85rem;margin-bottom:.5rem}
.placeholder{background:var(--bg3);border:2px dashed var(--border);border-radius:8px;padding:2rem;text-align:center;color:var(--muted)}
.mock-nav{background:var(--accent);color:#fff;padding:.75rem 1rem;display:flex;gap:1.5rem;font-size:.9rem}
.mock-sidebar{background:var(--bg3);padding:1rem;min-width:180px}.mock-content{padding:1.5rem;flex:1}
.mock-button{background:var(--accent);color:#fff;border:none;padding:.5rem 1rem;border-radius:6px;font-size:.85rem}
.mock-input{background:var(--bg);color:var(--fg);border:1px solid var(--border);border-radius:6px;padding:.5rem;width:100%}
@media (max-width:640px){
body{padding:0 .75rem 1rem}
#layout{display:block}
#panel{position:sticky;top:0;z-index:5;margin:0 -.75rem;border-radius:0;border-width:0 0 1px;padding:.4rem .75rem}
#panel h2{display:inline;margin:0 .5rem 0 0}#panel .counts{display:inline-flex;margin:0}
#panel details{margin:.25rem 0}
}
</style>
<link rel="stylesheet" media="(prefers-color-scheme: light)" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/styles/github.min.css">
<link rel="stylesheet" media="(prefers-color-scheme: dark)" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/styles/github-dark.min.css">
</head><body>
<h1>Grill</h1><div class="status" id="status">Loading…</div>
<div id="layout"><main><div id="history"></div><details id="decisions" hidden><summary>Decision log</summary><div id="decisions-body"></div></details><div id="current"></div></main>
<aside id="panel"><div id="progress"></div><div id="log" class="log"></div><details id="docs" hidden open><summary>Docs changed</summary><ul id="docs-list"></ul></details></aside></div>
<script src="https://cdn.jsdelivr.net/npm/marked@12.0.2/marked.min.js"></script>
<script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/highlight.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/mermaid@10.9.1/dist/mermaid.min.js"></script>
<script>
var md = function (s) { return window.marked ? window.marked.parse(String(s || '')) : '<pre>' + String(s || '').replace(/</g, '&lt;') + '</pre>'; };
var esc = function (s) { return String(s).replace(/[&<>"]/g, function (c) { return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]; }); };
var shown = null, picks = {}, current = null, rounds = [], lastHistory = null, lastDecisions = null;
var dark = window.matchMedia('(prefers-color-scheme: dark)');
function initMermaid() { if (window.mermaid) window.mermaid.initialize({ startOnLoad: false, theme: dark.matches ? 'dark' : 'default', securityLevel: 'strict' }); }
function enhance(root) {
  root.querySelectorAll('pre > code').forEach(function (code) {
    var pre = code.parentNode;
    if (/language-mermaid/.test(code.className)) {
      var d = document.createElement('div');
      d.className = 'mermaid'; d.setAttribute('data-src', code.textContent); d.textContent = code.textContent;
      pre.parentNode.replaceChild(d, pre);
    } else if (window.hljs) window.hljs.highlightElement(code);
  });
  renderMermaid(root);
}
function renderMermaid(root) {
  if (!window.mermaid) return;
  var nodes = root.querySelectorAll('.mermaid');
  nodes.forEach(function (n) { n.removeAttribute('data-processed'); n.textContent = n.getAttribute('data-src'); });
  if (nodes.length) window.mermaid.run({ nodes: nodes }).catch(function () {});
}
initMermaid();
dark.addEventListener('change', function () { initMermaid(); renderMermaid(document); });
var LABEL = { 'waiting-for-agent': 'Agent working: no Round yet…', 'agent-working': 'Answered. Agent working…', 'round-ready': 'Waiting for you: Round ready', 'finished': 'Session finished' };

function questionHtml(q) {
  var h = '<div class="q" id="q-' + esc(q.id) + '" data-q="' + esc(q.id) + '"><h3>' + esc(q.title) + '</h3><div>' + md(q.body) + '</div>';
  if (q.visual) h += '<div class="mockup"><div class="mockup-header">Visual</div><div class="mockup-body">' + q.visual + '</div></div>';
  if (q.recommendation) h += '<div class="rec"><strong>Recommended:</strong> ' + md(q.recommendation) + '</div>';
  h += '<div class="opts">';
  (q.options || []).forEach(function (o) {
    h += '<label><input type="radio" name="o-' + esc(q.id) + '" value="' + esc(o.id || o) + '"> ' + esc(o.label || o) + '</label>';
  });
  h += '</div><textarea placeholder="Add a note (optional)"></textarea>';
  h += '<div><button data-act="accept">Accept recommendation</button> <button data-act="skip">Skip</button> <span class="picked"></span></div></div>';
  return h;
}

function qEl(id) {
  var all = document.querySelectorAll('#current .q');
  for (var i = 0; i < all.length; i++) if (all[i].getAttribute('data-q') === id) return all[i];
  return null;
}
function textOf(id) {
  var t = qEl(id) && qEl(id).querySelector('textarea');
  return t ? t.value.trim() : '';
}
function stateOf(q) {
  if (picks[q.id]) return picks[q.id] === 'skip' ? 'skip' : 'answered';
  return textOf(q.id) ? 'answered' : 'open';
}

function optionLabel(q, id) {
  var found = (q.options || []).filter(function (o) { return (o.id || o) === id; })[0];
  return found ? (found.label || found.id || found) : id;
}
function describe(q, a) {
  var s;
  if (a.kind === 'option') s = optionLabel(q, a.option);
  else if (a.kind === 'accept') s = 'Accepted: ' + (q.recommendation || 'recommendation');
  else if (a.kind === 'skip') return 'Skipped';
  else s = '';
  if (a.text) s = s ? s + ' (' + a.text + ')' : a.text;
  return s || '(no answer)';
}

function renderPicked(q) {
  var el = qEl(q.id), p = picks[q.id], label = '';
  if (p === 'accept') label = 'Accepted';
  else if (p === 'skip') label = 'Skipped';
  else if (p === 'option') label = 'Picked ' + optionLabel(q, el.querySelector('input:checked').value);
  el.querySelector('.picked').textContent = label;
  el.className = 'q' + (p === 'skip' ? ' skipped' : p ? ' settled' : '');
}

var END_LABEL = { 'to-spec': 'To spec', 'to-tickets': 'To tickets', 'keep-grilling': 'Keep grilling', 'end': 'End session' };

function renderShared(r) {
  var el = document.getElementById('current');
  var h = '<h2>Shared understanding' + (r.title ? ': ' + esc(r.title) : '') + '</h2>';
  if (r.notes) h += '<div class="notes">' + md(r.notes) + '</div>';
  h += '<div>' + md(r.summary) + '</div><div class="bar" id="end-actions">';
  Object.keys(END_LABEL).forEach(function (k) { h += '<button data-end="' + k + '">' + END_LABEL[k] + '</button>'; });
  h += '</div><div id="keep" hidden><textarea id="keep-note" placeholder="What should the next Round dig into?"></textarea>' +
    '<p><button id="keep-send" disabled>Send and keep grilling</button></p></div>';
  el.innerHTML = h;
  enhance(el);
  current = null;
  var note = document.getElementById('keep-note'), send = document.getElementById('keep-send');
  note.oninput = function () { send.disabled = !note.value.trim(); };
  send.onclick = function () { sendEnd(r, 'keep-grilling', note.value); };
  document.getElementById('end-actions').onclick = function (e) {
    var act = e.target.getAttribute && e.target.getAttribute('data-end');
    if (!act) return;
    if (act === 'keep-grilling') { document.getElementById('keep').hidden = false; note.focus(); return; }
    sendEnd(r, act, '');
  };
  renderProgress();
}

function sendEnd(r, action, note) {
  post({ round: r.round, action: action, note: note });
}

function renderDone(d) {
  var el = document.getElementById('current');
  var link = d.spec_url ? '<p><a href="' + esc(d.spec_url) + '">' + esc(d.title || d.spec_url) + '</a></p>' : '';
  var key = JSON.stringify(d);
  if (el.getAttribute('data-done') === key) return;
  el.setAttribute('data-done', key);
  el.innerHTML = '<h2>Done</h2><p>The spec is published.</p>' + link;
}

function renderCurrent(r) {
  if (r.type === 'shared-understanding') return renderShared(r);
  var el = document.getElementById('current');
  var h = '<h2>Round ' + r.round + (r.title ? ': ' + esc(r.title) : '') + '</h2>';
  if (r.notes) h += '<div class="notes">' + md(r.notes) + '</div>';
  h += '<div class="bar"><button id="accept-all">Accept all recommendations</button></div>';
  (r.questions || []).forEach(function (q) { h += questionHtml(q); });
  h += '<textarea id="comment" placeholder="Round comment (optional)"></textarea>';
  h += '<p><button id="submit" disabled>Submit</button> <span class="status" id="submit-hint"></span></p>';
  el.innerHTML = h;
  enhance(el);
  picks = {};
  current = r;
  el.onclick = function (e) {
    var act = e.target.getAttribute && e.target.getAttribute('data-act');
    if (!act) return;
    var id = e.target.closest('.q').getAttribute('data-q');
    picks[id] = act;
    var checked = qEl(id).querySelector('input:checked');
    if (checked) checked.checked = false;
    renderPicked(questionById(id));
    refresh();
  };
  el.oninput = refresh;
  el.onchange = function (e) {
    if (e.target.type !== 'radio') return;
    var id = e.target.closest('.q').getAttribute('data-q');
    picks[id] = 'option';
    renderPicked(questionById(id));
    refresh();
  };
  document.getElementById('accept-all').onclick = function () {
    (r.questions || []).forEach(function (q) {
      if (q.recommendation && stateOf(q) === 'open') { picks[q.id] = 'accept'; renderPicked(q); }
    });
    refresh();
  };
  document.getElementById('submit').onclick = function () { submit(r); };
  refresh();
}

function questionById(id) {
  return (current.questions || []).filter(function (q) { return q.id === id; })[0];
}

function counts() {
  var c = { answered: 0, skipped: 0, remaining: [] };
  (current.questions || []).forEach(function (q) {
    var s = stateOf(q);
    if (s === 'answered') c.answered++; else if (s === 'skip') c.skipped++; else c.remaining.push(q);
  });
  return c;
}

function renderProgress() {
  var el = document.getElementById('progress');
  if (!current) { el.innerHTML = '<h2>Progress</h2><div>No open Round.</div>'; return; }
  var c = counts();
  var h = '<h2>Round ' + current.round + '</h2><div class="counts"><span><b>' + c.answered + '</b> answered</span><span><b>' +
    c.skipped + '</b> skipped</span><span><b>' + c.remaining.length + '</b> remaining</span></div>';
  if (c.remaining.length) {
    h += '<details open><summary>Unanswered</summary><ul>' + c.remaining.map(function (q) {
      return '<li><a href="#q-' + esc(q.id) + '">' + esc(q.title) + '</a></li>';
    }).join('') + '</ul></details>';
  }
  el.innerHTML = h;
}

function renderLog() {
  var items = [];
  rounds.forEach(function (r) {
    if (!r.answers) return;
    var byId = {};
    (r.round.questions || []).forEach(function (q) { byId[q.id] = q; });
    (r.answers.answers || []).forEach(function (a) {
      if (a.kind === 'skip' || !byId[a.id]) return;
      items.push('<li>R' + r.round.round + ' · <strong>' + esc(byId[a.id].title) + '</strong>: ' + esc(describe(byId[a.id], a)) + '</li>');
    });
  });
  document.getElementById('log').innerHTML = '<details' + (items.length ? ' open' : '') + '><summary>Decisions so far (' + items.length + ')</summary>' +
    (items.length ? '<ul>' + items.join('') + '</ul>' : '<div>None yet.</div>') + '</details>';
}

function renderHistory() {
  var hist = rounds.filter(function (r) { return r.answers; }).map(function (r) {
    var byId = {};
    (r.round.questions || []).forEach(function (q) { byId[q.id] = q; });
    var src = r.answers.source === 'terminal' ? ' in the terminal' : '';
    var h = '<details class="past"><summary>Round ' + r.round.round + (r.round.title ? ': ' + esc(r.round.title) : '') + ' (answered' + src + ')</summary>';
    if (r.round.notes) h += '<div class="notes">' + md(r.round.notes) + '</div>';
    h += '<ul>';
    (r.answers.answers || []).forEach(function (a) {
      var q = byId[a.id] || { title: a.id };
      h += '<li><strong>' + esc(q.title) + '</strong>: ' + esc(describe(q, a)) + '</li>';
    });
    h += '</ul>';
    if (r.answers.comment) h += '<p><em>Comment:</em> ' + esc(r.answers.comment) + '</p>';
    return h + '</details>';
  }).join('');
  if (hist === lastHistory) return;
  lastHistory = hist;
  var hEl = document.getElementById('history');
  hEl.innerHTML = hist;
  enhance(hEl);
}

function refresh() {
  if (!current) return;
  var c = counts();
  var sub = document.getElementById('submit');
  if (sub) sub.disabled = c.remaining.length > 0;
  var hint = document.getElementById('submit-hint');
  if (hint) hint.textContent = c.remaining.length ? 'Answer or skip ' + c.remaining.length + ' more to submit' : '';
  renderProgress();
}

function submit(r) {
  var answers = r.questions.map(function (q) {
    var kind = picks[q.id] || 'text', a = { id: q.id, kind: kind };
    if (kind === 'option') a.option = qEl(q.id).querySelector('input:checked').value;
    var t = textOf(q.id); if (t) a.text = t;
    return a;
  });
  post({ round: r.round, answers: answers, comment: document.getElementById('comment').value });
}

function post(payload) {
  fetch('/submit', { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload) })
    .then(function (res) { if (!res.ok) throw new Error(res.status); poll(); })
    .catch(function (e) { document.getElementById('status').textContent = 'Submit failed: ' + e.message; });
}

function poll() {
  fetch('/state', { credentials: 'same-origin' }).then(function (r) { return r.json(); }).then(function (s) {
    document.getElementById('status').textContent = LABEL[s.status] || s.status;
    rounds = s.rounds;
    var last = rounds[rounds.length - 1];
    renderHistory();
    renderLog();
    var docs = s.docs || [];
    document.getElementById('docs').hidden = !docs.length;
    document.getElementById('docs-list').innerHTML = docs.map(function (d) { return '<li><code>' + esc(d) + '</code></li>'; }).join('');
    var dec = (s.decisions || '').replace(/^# Decision log\\s*/, '');
    if (dec !== lastDecisions) {
      lastDecisions = dec;
      document.getElementById('decisions').hidden = !dec;
      var dEl = document.getElementById('decisions-body');
      dEl.innerHTML = md(dec);
      enhance(dEl);
    }
    if (last && !last.answers && shown !== last.round.round) { shown = last.round.round; renderCurrent(last.round); }
    if (s.done) { renderDone(s.done); shown = null; current = null; renderProgress(); return; }
    if (!last || last.answers) { document.getElementById('current').innerHTML = ''; shown = null; current = null; renderProgress(); }
  }).catch(function () { document.getElementById('status').textContent = 'Connection lost. Retrying…'; });
}
poll(); setInterval(poll, 2000);
</script></body></html>`;
