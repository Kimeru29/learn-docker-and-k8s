---
name: env-check
description: Check if the system is ready for the game. Verifies Docker, Compose, kubectl, kind, and platform.
---

# Environment Check

Run both checks:
```bash
bash engine/environment-check.sh
bash engine/platform.sh
```

Report results in a friendly way. Guide fixes for failures. Be encouraging about optional tools.
