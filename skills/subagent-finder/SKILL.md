---
name: subagent-finder
description: >
  Find the right specialized subagent for a task from the awesome-claude-code-subagents
  catalog (150+ agents across 10 categories). Use this skill whenever you need to spawn
  a subagent and want to find one with the right expertise — e.g., "I need an agent that
  knows Kubernetes", "find me a security auditor", "what agents can help with database
  migrations?", or any time you're about to use the Agent tool and the task would benefit
  from a specialist. Also use when the user explicitly asks to find, list, or browse
  available subagents. Also use when the user types /subagents — this triggers the project
  assessment mode that scans the project, recommends agents, and installs them permanently.
---

# Subagent Finder

Search the [awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
catalog to find specialist agents without loading the entire collection into context.

## When to use

- You need to delegate work to a subagent and want to pick the best specialist
- The user asks to find, list, or browse available agents
- A task would benefit from deep domain expertise (security, infrastructure, data, etc.)

## How it works

1. **Search** — Run the bundled search script with keywords describing the expertise needed:

   ```bash
   bash <skill-dir>/scripts/search.sh <keyword> [keyword...]
   ```

   Examples:
   ```bash
   bash <skill-dir>/scripts/search.sh security audit
   bash <skill-dir>/scripts/search.sh kubernetes deploy
   bash <skill-dir>/scripts/search.sh react frontend components
   bash <skill-dir>/scripts/search.sh database migration schema
   ```

   The script clones and caches the repo locally (`~/.cache/awesome-claude-code-subagents`),
   then searches agent frontmatter (name + description) by keyword. Results are ranked by
   number of keyword matches.

2. **Present options** — Show the user the top 2–3 matches with their name, category,
   description, and model. Let the user pick which agent to use. Don't auto-select.

3. **Load and spawn** — Once the user picks an agent, read its full definition from the
   cached file path shown in the search results. Then spawn a subagent using the Agent tool
   with the agent definition as the system prompt. Use the model specified in the agent's
   frontmatter (`sonnet`, `opus`, `haiku`) as the `model` parameter.

## Tips

- Use 2–3 keywords that describe the domain and task, not full sentences
- If no results match, the script shows available categories — use a category name as a keyword
- If the user's task spans multiple domains, search once per domain and let them pick a combination
- The cached repo auto-updates every 24 hours; pass no special flags

## `/subagents` command — Project assessment and installation

When the user types `/subagents`, enter project assessment mode. This scans the current
project's tech stack, recommends matching agents, and installs the user's selections
permanently into the project.

### Step 1: Assess the project

Run the bundled assessment script to detect the tech stack:

```bash
bash <skill-dir>/scripts/assess.sh <project-root>
```

This outputs keyword groups (one per line) based on detected config files, languages,
frameworks, and infrastructure. Each line is a set of search keywords.

### Step 2: Search for each keyword group

For each line of output from the assessment, run the search script:

```bash
bash <skill-dir>/scripts/search.sh <keywords>
```

Collect all unique agents across all searches. Deduplicate by agent name.

### Step 3: Curate and present recommendations

The raw search results will include some noise — agents that match a keyword but aren't
relevant to the project (e.g., `wordpress-master` matching on "backend"). Before
presenting, filter out agents that clearly don't fit the detected stack. Read the
one-line description of each candidate and drop any that are irrelevant.

Show the user a table of the curated agents grouped by category, with name, model, and
a one-line description. Note which tech stack signal triggered each match. Let the user
select which agents to install — they can pick individual agents, all of them, or none.

### Step 4: Install selected agents

For each agent the user selects:

1. Read the full agent definition from the cached file path
2. Copy it to `.claude/agents/<agent-name>.md` in the project directory
3. Create the `.claude/agents/` directory if it doesn't exist

```bash
mkdir -p .claude/agents
cp <cached-agent-file> .claude/agents/<agent-name>.md
```

After installation, list what was installed and explain that these agents are now
permanently available in the project via `--agent <name>` or the Agent tool.

### Step 5: Offer to re-run

Tell the user they can run `/subagents` again any time to reassess after adding new
dependencies or infrastructure.

## What NOT to do

- Don't load every agent file into context — that's the whole point of this skill
- Don't guess agent names from memory — always search, the catalog evolves
- Don't skip the user choice step — present options and let them decide
- Don't install agents without user confirmation
