#!/usr/bin/env node
// Patch the context-mode plugin's PreToolUse routing hook so that curl/wget and
// inline-HTTP requests to loopback hosts (localhost, 127.0.0.1, ::1, 0.0.0.0)
// are allowed through instead of redirected to the ctx_* sandbox. Dev-server
// verification needs raw curl against the local app; redirecting it is pure
// friction (retro 2026-10-05).
//
// context-mode is an upstream marketplace plugin, so this runs AFTER
// `claude plugin install context-mode` and edits the installed copy in place.
// Idempotent: keyed on the MARKER, so re-running (or a version bump that
// re-copies clean source) safely re-applies without duplicating.

import { readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const MARKER = "cloudagent-dotfiles(localhost-bypass)";
const CLAUDE_DIR = process.env.CLAUDE_DIR || join(process.env.HOME, ".claude");
const BASE = join(CLAUDE_DIR, "plugins", "cache", "context-mode");

// Find every .../hooks/core/routing.mjs under the plugin cache (version dirs vary).
function findRouting(dir, depth = 0, out = []) {
  if (depth > 6) return out;
  let entries;
  try { entries = readdirSync(dir); } catch { return out; }
  for (const e of entries) {
    const p = join(dir, e);
    let s;
    try { s = statSync(p); } catch { continue; }
    if (s.isDirectory()) findRouting(p, depth + 1, out);
    else if (e === "routing.mjs" && p.includes(join("hooks", "core"))) out.push(p);
  }
  return out;
}

const LOOPBACK_GUARD =
  String.raw`if (/(?:\/\/|@|\s|=)(?:localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\]|::1)(?::\d+)?/i.test(SUBJECT) && !/https?:\/\/(?!localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\]|::1)[^\s/'"]+/i.test(SUBJECT)) return null;`;

const CURL_ANCHOR =
  String.raw`    if (/(^|\s|&&|\||\;)(curl|wget)\s/i.test(stripped)) {
      // Split on chain operators (&&, ||, ;) to evaluate each segment`;
const CURL_REPLACEMENT =
  String.raw`    if (/(^|\s|&&|\||\;)(curl|wget)\s/i.test(stripped)) {
      // ${MARKER}: loopback requests are small and
      // local — let them through so dev-server verification can use curl.
      ${LOOPBACK_GUARD.replace(/SUBJECT/g, "stripped")}
      // Split on chain operators (&&, ||, ;) to evaluate each segment`;

const HTTP_ANCHOR =
  String.raw`      /http\.(get|request)\s*\(/i.test(noHeredoc)
    ) {
      return mcpRedirect({`;
const HTTP_REPLACEMENT =
  String.raw`      /http\.(get|request)\s*\(/i.test(noHeredoc)
    ) {
      // ${MARKER}: loopback requests are small and
      // local — let them through so dev-server verification can hit 127.0.0.1.
      ${LOOPBACK_GUARD.replace(/SUBJECT/g, "noHeredoc")}
      return mcpRedirect({`;

const files = findRouting(BASE);
if (files.length === 0) {
  console.warn(`⚠ context-mode routing hook not found under ${BASE} — nothing patched`);
  process.exit(0);
}

let changed = 0;
for (const file of files) {
  let src = readFileSync(file, "utf8");
  if (src.includes(MARKER)) { console.log(`✔ already patched: ${file}`); continue; }

  let next = src;
  let applied = 0;
  if (next.includes(CURL_ANCHOR)) { next = next.replace(CURL_ANCHOR, CURL_REPLACEMENT); applied++; }
  else console.warn(`⚠ curl anchor not found in ${file} (upstream changed?)`);
  if (next.includes(HTTP_ANCHOR)) { next = next.replace(HTTP_ANCHOR, HTTP_REPLACEMENT); applied++; }
  else console.warn(`⚠ inline-HTTP anchor not found in ${file} (upstream changed?)`);

  if (applied > 0 && next !== src) { writeFileSync(file, next); changed++; console.log(`✔ patched (${applied}/2 sites): ${file}`); }
}

console.log(changed > 0 ? `context-mode localhost bypass applied to ${changed} file(s)` : "context-mode localhost bypass: no changes");
