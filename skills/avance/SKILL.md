---
description: Status table of running subagents, background tasks and remote jobs from this conversation
disable-model-invocation: true
---

Report the progress of everything running on behalf of this conversation.

1. From this conversation's context, identify everything launched: subagents, background shells, workflows, scheduled/loop tasks, and any work sent outside this machine (ssh servers, Slurm, pueue, docker, CI runs, cloud jobs, APIs). Infer where things run from the conversation; do not ask the user.
2. Check each one live where possible (task tools, `squeue`, `pueue status`, `docker ps`, `gh run list`, logs over ssh, etc.). Read-only: never stop, restart or modify anything.
3. Reply in the user's language with one table: what | where | status | progress / ETA | notes. Then at most 3 lines: blockers, anything waiting on the user, and whether it is safe to pause or shut down.
4. If nothing is running, say so in one line and give a short status of the work done in this conversation (done / pending / next).
