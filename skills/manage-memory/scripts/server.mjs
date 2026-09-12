// Deterministic memory editor server. Renders the project's memory files as an
// editable page and captures the user's edits/deletions to a changeset the agent
// applies on save. Save is a plain POST (no WebSocket), so it works behind any
// TLS-terminating proxy.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const MEMORY_DIR = process.env.MM_MEMORY_DIR;
const STATE_DIR = process.env.MM_STATE_DIR;
const PORT = Number(process.env.MM_PORT) || 0;
const HOST = process.env.MM_HOST || '127.0.0.1';

if (!MEMORY_DIR || !STATE_DIR) {
  console.error('MM_MEMORY_DIR and MM_STATE_DIR are required');
  process.exit(1);
}
fs.mkdirSync(STATE_DIR, { recursive: true });

const MAX_BODY_BYTES = 8 * 1024 * 1024;

function listMemoryFiles() {
  try {
    return fs.readdirSync(MEMORY_DIR)
      .filter(f => f.endsWith('.md') && f !== 'MEMORY.md')
      .sort();
  } catch {
    return [];
  }
}

function parseMemory(raw) {
  const m = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!m) return { name: '', description: '', type: '', body: raw };
  const fm = m[1];
  const body = m[2].replace(/^\s*\n/, '');
  const grab = re => { const x = fm.match(re); return x ? x[1].trim() : ''; };
  return {
    name: grab(/^name:\s*(.*)$/m),
    description: grab(/^description:\s*(.*)$/m),
    type: grab(/^\s*type:\s*(.*)$/m),
    body,
  };
}

function readMemories() {
  return listMemoryFiles().map(filename => {
    const raw = fs.readFileSync(path.join(MEMORY_DIR, filename), 'utf-8');
    return { filename, ...parseMemory(raw) };
  });
}

function readIndex() {
  try {
    return fs.readFileSync(path.join(MEMORY_DIR, 'MEMORY.md'), 'utf-8');
  } catch {
    return '';
  }
}

const esc = s => String(s)
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;');

function renderCard(mem, i) {
  const badge = mem.type ? `<span class="badge">${esc(mem.type)}</span>` : '';
  return `
  <section class="card" data-filename="${esc(mem.filename)}">
    <header class="card-head">
      <div class="card-title">
        <h2>${esc(mem.name || mem.filename)}</h2>
        <code>${esc(mem.filename)}</code> ${badge}
      </div>
      <label class="del"><input type="checkbox" class="delete-flag"> Delete</label>
    </header>
    <label class="field">
      <span>Description</span>
      <input type="text" class="mem-description" value="${esc(mem.description)}">
    </label>
    <label class="field">
      <span>Content</span>
      <textarea class="mem-body" rows="10">${esc(mem.body)}</textarea>
    </label>
  </section>`;
}

function renderPage() {
  const memories = readMemories();
  const cards = memories.length
    ? memories.map(renderCard).join('\n')
    : '<p class="empty">No memories found for this project.</p>';
  const index = readIndex();
  const indexBlock = index
    ? `<details class="index"><summary>Index (MEMORY.md — regenerated on save)</summary><pre>${esc(index)}</pre></details>`
    : '';
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Manage Memory</title>
<style>
  :root { color-scheme: light dark; --bg:#f7f7f5; --card:#fff; --fg:#1a1a1a; --muted:#666; --line:#e2e2df; --accent:#3b6ea5; --danger:#b4433a; }
  @media (prefers-color-scheme: dark) { :root { --bg:#16171a; --card:#1f2125; --fg:#e8e8e6; --muted:#9a9a97; --line:#33353a; --accent:#6fa8dc; --danger:#e06c66; } }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--fg); font:15px/1.5 system-ui,-apple-system,Segoe UI,sans-serif; }
  header.top { position:sticky; top:0; background:var(--bg); border-bottom:1px solid var(--line); padding:1rem 1.25rem; display:flex; align-items:center; justify-content:space-between; gap:1rem; z-index:5; }
  header.top h1 { font-size:1.1rem; margin:0; }
  main { max-width:820px; margin:0 auto; padding:1.25rem; }
  .card { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:1rem 1.25rem; margin-bottom:1.25rem; }
  .card.marked { opacity:.55; outline:2px solid var(--danger); }
  .card-head { display:flex; align-items:flex-start; justify-content:space-between; gap:1rem; margin-bottom:.75rem; }
  .card-title h2 { font-size:1rem; margin:0 0 .25rem; }
  .card-title code { color:var(--muted); font-size:.8rem; }
  .badge { display:inline-block; background:var(--accent); color:#fff; border-radius:4px; padding:.05rem .4rem; font-size:.7rem; text-transform:uppercase; letter-spacing:.03em; }
  .del { font-size:.85rem; color:var(--danger); white-space:nowrap; }
  .field { display:block; margin-bottom:.75rem; }
  .field span { display:block; font-size:.75rem; text-transform:uppercase; letter-spacing:.04em; color:var(--muted); margin-bottom:.25rem; }
  input[type=text], textarea { width:100%; background:var(--bg); color:var(--fg); border:1px solid var(--line); border-radius:6px; padding:.5rem .6rem; font:inherit; }
  textarea { resize:vertical; font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:.85rem; }
  button { background:var(--accent); color:#fff; border:0; border-radius:6px; padding:.55rem 1.1rem; font:inherit; font-weight:600; cursor:pointer; }
  button:disabled { opacity:.5; cursor:default; }
  .empty { color:var(--muted); }
  .index { margin-top:1rem; color:var(--muted); }
  .index pre { background:var(--card); border:1px solid var(--line); border-radius:8px; padding:.75rem; overflow:auto; font-size:.8rem; }
  .status { font-size:.9rem; }
  .status.ok { color:var(--accent); }
  .status.err { color:var(--danger); }
</style>
</head>
<body>
<header class="top">
  <h1>Manage Memory</h1>
  <div style="display:flex;align-items:center;gap:1rem">
    <span class="status" id="status"></span>
    <button id="save">Save changes</button>
  </div>
</header>
<main>
  ${cards}
  ${indexBlock}
</main>
<script>
  const statusEl = document.getElementById('status');
  const saveBtn = document.getElementById('save');
  document.querySelectorAll('.delete-flag').forEach(cb => {
    cb.addEventListener('change', () => cb.closest('.card').classList.toggle('marked', cb.checked));
  });
  saveBtn.addEventListener('click', async () => {
    const memories = [...document.querySelectorAll('.card')].map(card => ({
      filename: card.dataset.filename,
      description: card.querySelector('.mem-description').value,
      body: card.querySelector('.mem-body').value,
      delete: card.querySelector('.delete-flag').checked,
    }));
    saveBtn.disabled = true;
    statusEl.textContent = 'Saving…';
    statusEl.className = 'status';
    try {
      const res = await fetch('/save', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ savedAt: new Date().toISOString(), memories }),
      });
      if (!res.ok) throw new Error('HTTP ' + res.status);
      statusEl.textContent = 'Saved — return to your terminal and tell your agent you are done.';
      statusEl.className = 'status ok';
    } catch (e) {
      statusEl.textContent = 'Save failed: ' + e.message;
      statusEl.className = 'status err';
    } finally {
      saveBtn.disabled = false;
    }
  });
</script>
</body>
</html>`;
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', c => {
      size += c.length;
      if (size > MAX_BODY_BYTES) { reject(new Error('body too large')); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf-8')));
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  const url = (req.url || '/').split('?')[0];
  if (req.method === 'GET' && url === '/health') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('ok');
    return;
  }
  if (req.method === 'GET' && url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
    res.end(renderPage());
    return;
  }
  if (req.method === 'POST' && url === '/save') {
    try {
      const raw = await readBody(req);
      const data = JSON.parse(raw);
      if (!data || !Array.isArray(data.memories)) throw new Error('invalid changeset');
      fs.writeFileSync(path.join(STATE_DIR, 'changeset.json'), JSON.stringify(data, null, 2));
      fs.writeFileSync(path.join(STATE_DIR, 'saved'), (data.savedAt || new Date().toISOString()) + '\n');
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true }));
    } catch (e) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: false, error: e.message }));
    }
    return;
  }
  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not found');
});

server.listen(PORT, HOST, () => {
  const addr = server.address();
  console.log(JSON.stringify({ type: 'listening', port: addr.port, host: HOST }));
});
