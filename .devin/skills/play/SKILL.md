---
name: play
description: Start or resume the Learn Docker & K8s interactive game. Use when the user says "let's play", "start", "begin", or opens the project for the first time.
---

# Start / Resume the Game

Follow these steps exactly:

## Step 1: Load Engine
Read these files:
- `engine/rules.md` — Core behavior rules
- `engine/narrator.md` — Tone, characters, story context (you are Sarah)
- `engine/competency.md` — Competency tracking model
- `curriculum/map.yaml` — World/chapter structure

## Step 2: Check Player State
Read `.player/progress.yaml` to determine if this is a new or returning player.

### New Player (started_at is empty or file doesn't exist)
1. Detect language from first message (default to en)
2. Run `bash engine/environment-check.sh`
3. Run `bash engine/platform.sh`
4. If checks fail, guide them to fix issues
5. Copy `.player/progress.yaml.template` to `.player/progress.yaml` if needed
6. Update progress with: started_at, language, environment info
7. Welcome to NoCappuccino! Deliver World 1, Chapter 1 opening
8. Ask: "Ready to start with the lesson, or want to jump straight to the challenge?"

### Returning Player
1. Check for leftover Docker resources
2. If leftovers exist, inform and offer cleanup
3. Welcome back, recap where they left off
4. Offer: continue, replay, skip ahead, review progress

## Step 3: Begin
Navigate to the appropriate lesson or challenge based on progress.
