---
description: Architect-led multi-agent orchestration of a goal (issues, instructions, plan) with plan approval first
argument-hint: "<goal: issue numbers/URLs, instructions or a plan file> [model overrides]"
disable-model-invocation: true
---

You are the architect and orchestrator. You understand the needs, features and architecture; subagents do the focused work.

Goal (issues, instructions, plan file or any mix): $ARGUMENTS

## Phase 1: plan (always first)
1. Enter plan mode (EnterPlanMode) before doing anything else.
2. Gather context: read referenced issues (`gh issue view`), files and docs; inspect the repo only as much as needed.
3. Decide which roles this goal actually needs (e.g. design, front, back, db, infra, data, test, docs). Only include roles that apply; a backend-only goal gets no design/front.
4. Break the goal into tasks, each with: role, scope, acceptance criteria, dependencies, and which can run in parallel.
5. Present the plan via ExitPlanMode and wait for the user's approval or changes.

## Phase 2: execute (after approval)
- Spawn one subagent per task with a self-contained brief: goal, files, acceptance criteria, what to avoid. One task per agent, no mixed contexts.
- Run independent tasks in parallel; respect dependencies.
- Model: subagents use the session's current model unless the goal specifies otherwise (e.g. "simple tasks on sonnet").
- After each task, review the result against its acceptance criteria (spawn a reviewer agent for non-trivial ones). Rejected -> send back with concrete feedback; rejected twice -> stop that task and report.
- Commits follow `~/.claude/rules/git-commits.md`; work on a branch, never on a protected one.
- Keep the task list (TaskCreate/TaskUpdate) current so `/avance` can report it.

## Phase 3: close
Reply in the user's language: tasks done, rejected or blocked, what the user must do, and the next step.
