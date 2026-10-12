# Decision: Install the `cache-tax` mod

Status: accepted
Date: 2026-10-12

## Context

Long Cloud Agent sessions routinely sit idle past the one-hour prompt-cache
TTL. The next message, however small, then re-writes the whole context at the
cache-write rate — dollars per turn on a 200k+ token session. Nothing in the
stack warned about this or prevented it.

[cache-tax](https://github.com/karanb192/cache-tax) is a Claude Code mod
(Claude Code 2.1.287+) that does both: `/keepwarm` pings the cache with a
tool-less fork after 50 idle minutes inside a bounded window, and a guard drops
a cold send once (for contexts of 50k+ tokens) with the estimated rewrite cost.
A hook-only version also exists, but it does not include warming.

## Decision

Install `cache-tax@claude-code-mods` from the `karanb192/claude-code-mods`
marketplace via the existing `add_marketplace` / `install_plugin` helpers in
`install.sh`, under a new "Mods" section. It is the first mod in these
dotfiles. Use the mod, not the hook version — running both double-guards every
cold send.

## Consequences

- Cold sends are refused once by default (`/cache-tax guard warn` switches to
  warn-only); a resend always goes through.
- Keepwarm pings cost tokens (a cache read plus a short reply) and only work
  with a one-hour main cache — the subscription default. API-key sessions need
  `promptCacheTtl: "1h"`.
- Requires Claude Code 2.1.287+; older versions install it but do not load it.
- Retiring it later is a one-line addition to `DEPRECATED_PLUGINS` (and
  `DEPRECATED_MARKETPLACES` if no other mod uses the marketplace).
