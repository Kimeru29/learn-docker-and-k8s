---
name: progress
description: Show player's current progress and competencies. Use when the user asks "where am I", "show progress", or "status".
---

# Show Progress

Read `.player/progress.yaml` and display:

1. **Current position**: World, chapter, lesson/challenge
2. **Completed worlds**: List with completion status
3. **Chapter breakdown**: Per-world completion percentage
4. **Competency snapshot**: Top 5 strongest + weakest areas with levels
5. **Time played**: Since started_at
6. **Recommendations**: Based on competency data (weak areas to revisit, deep dives to explore, interview modes unlocked)

Use ASCII progress bars for visual clarity:
```
World 1: [========..] 80%  (3/4 chapters + boss)
World 2: [====......] 40%  (2/4 chapters)
World 3: [..........] 0%   (not started)
```
