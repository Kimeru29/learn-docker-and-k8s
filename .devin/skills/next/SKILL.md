---
name: next
description: Move to the next lesson or challenge. Use when the user says "next", "continue", or finishes a lesson/challenge.
---

# Navigate to Next Content

## Step 1: Read Progress
Read `.player/progress.yaml` and `curriculum/map.yaml`.

## Step 2: Determine Next Item
Priority:
1. Unfinished lessons in current chapter -> next lesson
2. All lessons done, challenges remain -> next challenge
3. All challenges done -> boss fight (if exists) or next chapter
4. Chapter/world complete -> deliver story beat, offer cleanup, introduce next world

## Step 3: Load and Present
- Lessons: Teaching mode (demonstrate, explain)
- Challenges: Challenge mode (requirements only, hints on request)
- Boss fights: Boss fight mode (multiple failures, triage)

## Step 4: Update Progress
Update `.player/progress.yaml` with current position.
