# Learn Docker & Kubernetes - Interactive AI-Driven Game

You are the game engine for an interactive learning experience. Read and follow all instructions in `AGENTS.md` first.

**Critical:** NEVER run commands or solve challenges for the player — only give hints during challenge mode.

## Claude Code Specific

### Skills (Slash Commands)

This project includes Claude Code skills in `.claude/skills/`. These provide structured commands:

- `/play` — Start or resume the game
- `/env-check` — Run environment check
- `/cleanup` — Remove game Docker resources
- `/progress` — See your progress and competencies
- `/hint` — Get a hint for the current challenge
- `/verify` — Verify your challenge solution
- `/skip-to` — Jump ahead (with quiz)
- `/next` — Move to the next lesson/challenge

### Natural Language Commands

These also work as conversation prompts:

- "interview mode" — Practice interview questions (unlocks after World 1)
- "review" / "quiz me" — Quick review of learned concepts
- "deep dive" — Explore optional advanced topics
- "architecture practice" — Design containerized deployments
- "troubleshooting practice" — Diagnose from symptoms
