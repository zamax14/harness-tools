---
description: Explore the current repo and summarize what it is, how it is built and its state
argument-hint: "[focus, e.g. 'the ETL' or 'auth']"
disable-model-invocation: true
context: fork
agent: Explore
---

Explore this repository and explain it to someone who is about to work on it.

Focus (may be empty): $ARGUMENTS

Read README, CLAUDE.md/AGENTS.md, docs, manifests (package.json, pyproject, Cargo.toml, compose files, CI), entry points and the directory structure. Skim code only as needed.

Reply in Spanish, concise, in the chat:
- **Propósito**: what it does and for whom (2-3 lines).
- **Stack y arquitectura**: main pieces and how they connect.
- **Estructura**: key directories, one line each.
- **Cómo se corre**: dev/test/deploy commands found.
- **Estado**: maturity, obvious gaps, TODOs, deprecated parts.
If a focus was given, go deeper on it and keep the rest brief.
