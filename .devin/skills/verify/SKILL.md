---
name: verify
description: Verify if the current challenge is completed. Runs verification and reports results. Use when the user says "check", "verify", "did I do it right", or "test my solution".
---

# Verify Challenge Completion

## Step 1: Determine Current Challenge
Read `.player/progress.yaml` to find current world, chapter, and challenge.

## Step 2: Run Verification
Find the verify.sh for the current chapter:
```bash
ls curriculum/world-*/ch*/challenges/verify.sh
```
Run it. If no verify.sh exists, check success criteria from the challenge file.

## Step 3: Report Results

### All Passed
1. Celebrate with Sarah's voice
2. Deliver post-mission debrief (what, why, real-world, interview, pro tip, quality notes)
3. Update progress.yaml: add challenge to completed list
4. Update competency levels based on performance
5. Check if chapter/world is complete; if so, deliver story beat and tease next

### Some Failed
1. Show pass/fail breakdown
2. Give a gentle hint without the answer
3. Remind about /hint if stuck

Read `engine/validation.md` for verification patterns.
