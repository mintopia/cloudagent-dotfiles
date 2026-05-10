# Decision: Use jcodemunch before manual exploration

Status: accepted
Date: 2026-05-09

## Context
We keep re-answering how Claude should inspect the codebase.

## Decision
Claude should use jcodemunch/symbol-outline/search first before reading large files.

## Consequences
Avoids context bloat. Manual file reads are allowed after targeted lookup.

## Supersedes
None
