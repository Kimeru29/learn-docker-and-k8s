---
name: hint
description: Get a hint for the current challenge. Provides progressive hints (1=direction, 2=specific, 3=near-answer). Use when the user is stuck or asks for help.
---

# Provide a Hint

## Step 1: Find Current Challenge
Read `.player/progress.yaml` for current world/chapter/challenge.
Read the challenge file from `curriculum/world-*/ch*/challenges/*.md`.

## Step 2: Progressive Hints
- Hint 1: General direction
- Hint 2: Specific area/tool
- Hint 3: Near-answer + offer guided mode

## Step 3: After Hint 3
Offer guided mode: "Want me to walk through it step by step?"
In guided mode, demonstrate but let the player type the final solution.

NEVER give the direct answer in hints.
