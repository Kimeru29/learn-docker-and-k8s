---
name: verify
description: Verify if the current challenge is completed in Learn Docker & K8s. Runs the verification script and reports results. Use when the user says "check", "verify", "did I do it right", "am I done", or "test my solution".
---

# Verify Challenge Completion

## Step 1: Determine Current Challenge

Read `.player/progress.yaml` to find the current world, chapter, and challenge number.

## Step 2: Run Verification

Find the verify.sh for the current chapter:

```bash
# Example: for ch01-containers in world-1
ls curriculum/world-*/ch*/challenges/verify.sh
```

If it exists, run it:
```bash
bash curriculum/world-X-*/chXX-*/challenges/verify.sh
```

If it doesn't exist, read the challenge file and check the success criteria manually using Docker/kubectl commands.

## Step 3: Report Results

### All Checks Passed

1. Celebrate! Use Sarah's voice: "Nailed it!"
2. Deliver the **post-mission debrief**:
   - **What you did:** Brief summary
   - **Why it works:** The underlying concept
   - **Real-world connection:** When you'd see this at work
   - **Interview angle:** How this comes up in interviews
   - **Pro tip:** Advanced insight
   - **Solution quality:** Note what's good and what could be better (valid, production-safe, efficient, portable, secure, maintainable)
3. Update `.player/progress.yaml`: add challenge to completed list
4. Update competency levels based on performance (hints used, first attempt, quality)
5. Check if all challenges in the chapter are done:
   - If yes and boss fight exists: introduce the boss fight
   - If yes and it's the last chapter in a world: mark world complete, deliver world-end story
   - If no: offer to move to the next challenge

### Some Checks Failed

1. Show which checks passed and which failed
2. Give a gentle hint about the failing check WITHOUT giving the answer
3. Encourage them: "Almost there — one thing is off."
4. Remind them they can use `/hint` if stuck

### No Challenges Started

If they haven't started any challenge yet, let them know: "Nothing to verify yet! Want to start a challenge?"

## Important

- Read `engine/validation.md` for the verification patterns and philosophy
- Always run the actual check — don't assume success
- Be specific about what failed without revealing the fix
- Record hint usage and attempt count for competency tracking
