(function() {
  const MIN_RECONNECT_MS = 500;
  const MAX_RECONNECT_MS = 30000;
  const TOMBSTONE_AFTER_MS = 15000; // show the "paused" overlay after this long with no contact
  const POLL_MS = 2000;             // REST poll cadence (reload signal + liveness)

  // Pure: next backoff delay (doubles, capped). Exported for unit tests.
  function nextReconnectDelay(current, max) {
    return Math.min(current * 2, max);
  }
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { nextReconnectDelay, MIN_RECONNECT_MS, MAX_RECONNECT_MS, TOMBSTONE_AFTER_MS };
  }

  // Everything below is browser-only; bail out when loaded in Node (tests).
  if (typeof window === 'undefined') return;

  // The WebSocket is the fast path for live-reload and click events. REST polling
  // (/poll for reloads, POST /event for clicks) is the fallback that keeps the
  // companion working when a WebSocket can't connect — e.g. a proxy that won't
  // upgrade. Liveness (the "paused" overlay) is owned by the poll, not the socket,
  // so a blocked WebSocket alone never looks like a dead server.
  let ws = null;
  let eventQueue = [];
  let reconnectDelay = MIN_RECONNECT_MS;
  let reconnectTimer = null;
  let everLive = false;
  let tombstoneShown = false;
  let lastVersion = null;   // last screen version seen from /poll
  let lastContactAt = null; // last time /poll or the WS reached the server

  function sessionKey() {
    try {
      return window.sessionStorage && window.sessionStorage.getItem('brainstorm-session-key');
    } catch (e) {}
    return null;
  }

  function keyedPath(p) {
    const key = sessionKey();
    return key ? p + '?key=' + encodeURIComponent(key) : p;
  }

  function websocketUrl() {
    const key = sessionKey();
    // Match the WebSocket scheme to the page scheme. Behind a Cloud Agent HTTP
    // forward the page is served over https, so the browser blocks mixed-content
    // ws:// — deriving wss:// from location.protocol keeps it working both behind
    // the TLS forward (https -> wss) and on plain localhost (http -> ws).
    const scheme = window.location.protocol === 'https:' ? 'wss://' : 'ws://';
    return scheme + window.location.host + (key ? '/?key=' + encodeURIComponent(key) : '');
  }

  function reloadAfterRecovery() {
    const key = sessionKey();
    if (key) {
      window.location.replace('/?key=' + encodeURIComponent(key));
    } else {
      window.location.reload();
    }
  }

  // Reflect connection state in the frame's status pill (absent on full-doc screens).
  function setStatus(state) {
    const el = document.querySelector('.status');
    if (!el) return;
    const map = {
      connecting:   ['Connecting…',   'var(--text-tertiary)'],
      connected:    ['Connected',     'var(--success)'],
      reconnecting: ['Reconnecting…', 'var(--warning)'],
      disconnected: ['Disconnected',  'var(--error)']
    };
    const [text, color] = map[state] || map.disconnected;
    el.textContent = text;
    el.style.setProperty('--status-color', color);
  }

  // Self-styled so it works on framed and full-document screens alike.
  function showTombstone() {
    if (tombstoneShown) return;
    tombstoneShown = true;
    const el = document.createElement('div');
    el.id = 'bs-tombstone';
    el.style.cssText = 'position:fixed;inset:0;z-index:99999;display:flex;' +
      'align-items:center;justify-content:center;padding:2rem;text-align:center;' +
      'background:rgba(20,20,22,0.92);color:#f5f5f7;font-family:system-ui,sans-serif';
    el.innerHTML = '<div style="max-width:480px">' +
      '<h2 style="margin:0 0 .5rem;font-weight:600">Companion paused</h2>' +
      '<p style="margin:0;opacity:.85">The visual companion has stopped. ' +
      'Ask your coding agent to bring it back — this page reconnects automatically.</p></div>';
    if (document.body) document.body.appendChild(el);
  }

  function pollHealthy() {
    return lastContactAt !== null && Date.now() - lastContactAt < TOMBSTONE_AFTER_MS;
  }

  // ===== WebSocket fast path =====

  function connect() {
    if (reconnectTimer) { clearTimeout(reconnectTimer); reconnectTimer = null; }
    if (!pollHealthy()) setStatus(everLive ? 'reconnecting' : 'connecting');
    try {
      ws = new WebSocket(websocketUrl());
    } catch (e) {
      ws = null;
      scheduleReconnect();
      return;
    }

    ws.onopen = () => {
      const recovered = tombstoneShown;
      everLive = true;
      lastContactAt = Date.now();
      reconnectDelay = MIN_RECONNECT_MS;
      tombstoneShown = false;
      setStatus('connected');
      eventQueue.forEach(e => ws.send(JSON.stringify(e)));
      eventQueue = [];
      // Recovered from a tombstoned outage (e.g. the server restarted on the same
      // port) — reload through the keyed bootstrap so the cookie is refreshed
      // before the visible URL returns to bare /.
      if (recovered) reloadAfterRecovery();
    };

    ws.onmessage = (msg) => {
      let data;
      try { data = JSON.parse(msg.data); } catch (e) { return; }
      lastContactAt = Date.now();
      if (data.type === 'reload') window.location.reload();
    };

    ws.onclose = () => {
      ws = null;
      if (pollHealthy()) setStatus('connected');
      else setStatus(everLive ? 'reconnecting' : 'connecting');
      scheduleReconnect();
    };

    // Let onclose own reconnection so we don't schedule it twice.
    ws.onerror = () => { try { ws.close(); } catch (e) {} };
  }

  function scheduleReconnect() {
    reconnectTimer = setTimeout(connect, reconnectDelay);
    reconnectDelay = nextReconnectDelay(reconnectDelay, MAX_RECONNECT_MS);
  }

  // ===== REST fallback: poll for reloads and report liveness =====

  async function pollOnce() {
    let data;
    try {
      const res = await fetch(keyedPath('/poll'), { cache: 'no-store' });
      if (!res.ok) throw new Error('HTTP ' + res.status);
      data = await res.json();
    } catch (e) {
      if (!pollHealthy()) { setStatus('disconnected'); showTombstone(); }
      return;
    }

    const recovered = tombstoneShown;
    everLive = true;
    lastContactAt = Date.now();
    tombstoneShown = false;
    // The WS pill owns 'connected' when the socket is open; otherwise the poll does.
    if (!ws || ws.readyState !== WebSocket.OPEN) setStatus('connected');

    if (lastVersion === null) {
      lastVersion = data.version;
    } else if (data.version !== lastVersion) {
      lastVersion = data.version;
      // If the WS is open it will deliver the reload; don't navigate twice.
      if (!ws || ws.readyState !== WebSocket.OPEN) { reloadAfterRecovery(); return; }
    }
    if (recovered) reloadAfterRecovery();
  }

  // ===== Events =====

  function sendEvent(event) {
    event.timestamp = Date.now();
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(event));
      return;
    }
    fetch(keyedPath('/event'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(event),
      cache: 'no-store',
      keepalive: true
    }).catch(() => { eventQueue.push(event); });
  }

  // Capture clicks on choice elements
  document.addEventListener('click', (e) => {
    const target = e.target.closest('[data-choice]');
    if (!target) return;

    sendEvent({
      type: 'click',
      text: target.textContent.trim(),
      choice: target.dataset.choice,
      id: target.id || null
    });

  });

  // Frame UI: selection tracking
  window.selectedChoice = null;

  window.toggleSelect = function(el) {
    const container = el.closest('.options') || el.closest('.cards');
    const multi = container && container.dataset.multiselect !== undefined;
    if (container && !multi) {
      container.querySelectorAll('.option, .card').forEach(o => o.classList.remove('selected'));
    }
    if (multi) {
      el.classList.toggle('selected');
    } else {
      el.classList.add('selected');
    }
    window.selectedChoice = el.dataset.choice;
  };

  // Expose API for explicit use
  window.brainstorm = {
    send: sendEvent,
    choice: (value, metadata = {}) => sendEvent({ type: 'choice', value, ...metadata })
  };

  setStatus('connecting');
  connect();
  pollOnce();
  setInterval(pollOnce, POLL_MS);
})();
