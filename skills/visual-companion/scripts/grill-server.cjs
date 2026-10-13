'use strict';
// Grill UI server: serves structured Rounds and records Submissions.
// Runs beside the vendored upstream server.cjs, which stays unmodified (ADR-0014).
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

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
  return { status, rounds };
}

const ANSWER_KINDS = ['accept', 'option', 'skip', 'text'];

function validateSubmission(sub, round) {
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
    const record = {
      round: n,
      answers: sub.answers.map(a => {
        const out = { id: a.id, kind: a.kind };
        if (a.kind === 'option') out.option = a.option;
        if (a.text) out.text = a.text;
        return out;
      }),
      comment: typeof sub.comment === 'string' ? sub.comment : '',
      submitted_at: new Date().toISOString()
    };
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
    session_dir: SESSION_DIR,
    state_dir: STATE_DIR,
    round_pattern: path.join(SESSION_DIR, 'round-NNN.json'),
    answers_pattern: path.join(SESSION_DIR, 'answers-NNN.json')
  };
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
body{font:16px/1.5 system-ui,sans-serif;max-width:760px;margin:0 auto;padding:1rem;color:#1d1d1f}
.q{border:1px solid #d0d0d5;border-radius:8px;padding:1rem;margin:1rem 0}
.q h3{margin:0 0 .5rem}.rec{background:#eef6ff;border-radius:6px;padding:.5rem .75rem;margin:.5rem 0}
.opts label{display:block;margin:.25rem 0}textarea{width:100%;box-sizing:border-box;min-height:3.5rem;margin-top:.5rem}
.status{color:#666;font-size:.9rem}.past{opacity:.7}button{font:inherit;padding:.5rem 1.25rem}
@media (prefers-color-scheme:dark){body{background:#161618;color:#eee}.q{border-color:#444}.rec{background:#1c2a3a}}
</style></head><body>
<h1>Grill</h1><div class="status" id="status">Loading…</div>
<div id="history"></div><div id="current"></div>
<script src="https://cdn.jsdelivr.net/npm/marked@12.0.2/marked.min.js"></script>
<script>
var md = function (s) { return window.marked ? window.marked.parse(String(s || '')) : '<pre>' + String(s || '').replace(/</g, '&lt;') + '</pre>'; };
var esc = function (s) { return String(s).replace(/[&<>"]/g, function (c) { return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]; }); };
var shown = null, picks = {};
var LABEL = { 'waiting-for-agent': 'Waiting for the agent…', 'agent-working': 'Submitted. The agent is working…', 'round-ready': 'Round ready' };

function questionHtml(q) {
  var h = '<div class="q" data-q="' + esc(q.id) + '"><h3>' + esc(q.title) + '</h3><div>' + md(q.body) + '</div>';
  if (q.recommendation) h += '<div class="rec"><strong>Recommended:</strong> ' + md(q.recommendation) + '</div>';
  h += '<div class="opts">';
  (q.options || []).forEach(function (o) {
    h += '<label><input type="radio" name="o-' + esc(q.id) + '" value="' + esc(o.id || o) + '"> ' + esc(o.label || o) + '</label>';
  });
  h += '</div><textarea placeholder="Add a note (optional)"></textarea>';
  h += '<div><button data-act="accept">Accept recommendation</button> <button data-act="skip">Skip</button> <span class="picked"></span></div></div>';
  return h;
}

function renderCurrent(r) {
  var el = document.getElementById('current');
  var h = '<h2>Round ' + r.round + (r.title ? ': ' + esc(r.title) : '') + '</h2>';
  if (r.notes) h += '<div>' + md(r.notes) + '</div>';
  (r.questions || []).forEach(function (q) { h += questionHtml(q); });
  h += '<textarea id="comment" placeholder="Round comment (optional)"></textarea><p><button id="submit" disabled>Submit</button></p>';
  el.innerHTML = h;
  picks = {};
  el.onclick = function (e) {
    var act = e.target.getAttribute && e.target.getAttribute('data-act');
    if (!act) return;
    var qEl = e.target.closest('.q');
    picks[qEl.getAttribute('data-q')] = act;
    qEl.querySelector('.picked').textContent = act === 'accept' ? 'Accepted' : 'Skipped';
    refreshSubmit(r);
  };
  el.oninput = function () { refreshSubmit(r); };
  el.onchange = function (e) {
    if (e.target.type !== 'radio') return;
    var qEl = e.target.closest('.q');
    picks[qEl.getAttribute('data-q')] = 'option';
    qEl.querySelector('.picked').textContent = 'Picked ' + e.target.value;
    refreshSubmit(r);
  };
  document.getElementById('submit').onclick = function () { submit(r); };
}

function refreshSubmit(r) {
  var done = (r.questions || []).every(function (q) { return picks[q.id] || textOf(q.id); });
  document.getElementById('submit').disabled = !done;
}
function textOf(id) {
  var t = document.querySelector('.q[data-q="' + id + '"] textarea');
  return t ? t.value.trim() : '';
}

function submit(r) {
  var answers = r.questions.map(function (q) {
    var kind = picks[q.id] || 'text', a = { id: q.id, kind: kind };
    if (kind === 'option') a.option = document.querySelector('input[name="o-' + q.id + '"]:checked').value;
    var t = textOf(q.id); if (t) a.text = t;
    return a;
  });
  fetch('/submit', { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ round: r.round, answers: answers, comment: document.getElementById('comment').value }) })
    .then(function (res) { if (!res.ok) throw new Error(res.status); poll(); })
    .catch(function (e) { document.getElementById('status').textContent = 'Submit failed: ' + e.message; });
}

function poll() {
  fetch('/state', { credentials: 'same-origin' }).then(function (r) { return r.json(); }).then(function (s) {
    document.getElementById('status').textContent = LABEL[s.status] || s.status;
    var last = s.rounds[s.rounds.length - 1];
    document.getElementById('history').innerHTML = s.rounds.filter(function (r) { return r.answers; }).map(function (r) {
      return '<details class="past"><summary>Round ' + r.round.round + ' (answered)</summary><pre>' + esc(JSON.stringify(r.answers.answers, null, 2)) + '</pre></details>';
    }).join('');
    if (last && !last.answers && shown !== last.round.round) { shown = last.round.round; renderCurrent(last.round); }
    if (last && last.answers) { document.getElementById('current').innerHTML = ''; shown = null; }
  }).catch(function () {});
}
poll(); setInterval(poll, 2000);
</script></body></html>`;
