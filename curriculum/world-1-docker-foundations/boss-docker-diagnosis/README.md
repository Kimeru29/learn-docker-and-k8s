```
  ____   ___  ____ ____    _____ ___ ____ _   _ _____
 | __ ) / _ \/ ___/ ___|  |  ___|_ _/ ___| | | |_   _|
 |  _ \| | | \___ \___ \  | |_   | | |  _| |_| | | |
 | |_) | |_| |___) |__) | |  _|  | | |_| |  _  | | |
 |____/ \___/|____/____/  |_|   |___\____|_| |_| |_|

  _____ _             __  __                  _
 |_   _| |__   ___   |  \/  | ___  _ __ _ __ (_)_ __   __ _
   | | | '_ \ / _ \  | |\/| |/ _ \| '__| '_ \| | '_ \ / _` |
   | | | | | |  __/  | |  | | (_) | |  | | | | | | | | (_| |
   |_| |_| |_|\___|  |_|  |_|\___/|_|  |_| |_|_|_| |_|\__, |
                                                        |___/
  _____                      _   _      _ _
 |  ___| __ ___  _ __ ___   | | | | ___| | |
 | |_ | '__/ _ \| '_ ` _ \  | |_| |/ _ \ | |
 |  _|| | | (_) | | | | | | |  _  |  __/ | |
 |_|  |_|  \___/|_| |_| |_| |_| |_|\___|_|_|
```

# Boss Fight: The Morning From Hell

> *Everything that could go wrong, did go wrong -- all at once.*

---

## The Story

It's 7:45 AM. You're the first one in the office. Coffee machine is broken (ironic, for a coffee company). You open your laptop to check Slack.

**14 unread messages.**

Marcus: "I'm at the airport. Board meeting in NYC. Can't deal with infra today."
Dave: "Heading to a coffee sourcing trip in Colombia. No Wi-Fi on the farm. Back Thursday."

Then customer support:
- "@engineering the app is showing an error page"
- "@engineering the search feature is completely broken"
- "@engineering a customer says their preferences are gone AGAIN"
- "@engineering nothing works"

You pull up the monitoring dashboard. Four separate problems. All hitting at the same time. No Marcus. No Dave. Just you and everything you've learned in the last four chapters.

Sarah's voice echoes in your head: *"This is what we trained for."*

Time to triage.

---

## The Four Problems

### Problem 1: The Bloated Build (ch02 -- Images)
Someone pushed a new version of the Bean-Tracker service last night. The image is **over 2GB**. It's eating disk space, deploys are timing out, and the staging environment is at 98% disk. The Dockerfile is a mess -- single stage, build tools in production, no `.dockerignore`.

**Your fix must produce an image under 100MB.**

### Problem 2: The Vanishing Database (ch03 -- Storage)
The preferences database container was restarted overnight by a cron job that Dave wrote. It ran `docker rm` and `docker run` without a volume. All customer preference data is gone. Again.

**Your fix must ensure data persists across container deletion and recreation.**

### Problem 3: The Silent Services (ch04 -- Networking)
The frontend and backend are running, but they can't find each other. The frontend shows `Error: getaddrinfo ENOTFOUND learn-boss-backend`. They're on Docker's default bridge -- no DNS resolution.

**Your fix must enable container-to-container communication by name.**

### Problem 4: The Port Collision (ch01 + ch04 -- Containers + Networking)
The frontend is supposed to be accessible at `http://localhost:8080`, but another container is already using that port. The frontend container won't start.

**Your fix must make the frontend accessible at `http://localhost:8080`.**

---

## Setup

None -- the challenge file walks you through creating the broken environment.

---

## Challenge

| # | Challenge | What's broken |
|---|-----------|---------------|
| 01 | [The Morning From Hell](challenges/01-morning-from-hell.md) | All four problems, your call on triage order |

---

## Verification

```bash
bash curriculum/world-1-docker-foundations/boss-docker-diagnosis/challenges/verify.sh
```

The verify script checks each problem independently -- partial credit is possible.

---

## What Makes This a Boss Fight

- **Multiple simultaneous failures** -- you must triage and decide what to fix first
- **No hand-holding** -- the challenge tells you what's broken, not how to fix it
- **Time pressure narrative** -- customers are affected, leadership is unavailable
- **Cross-chapter skills** -- you need concepts from all four chapters
- **Independent verification** -- each fix is checked separately

---

## Post-Boss Debrief

When all four checks pass, you've completed World 1. Sarah has a message for you:

> "You just handled your first real incident solo. Four problems, zero hand-holding, and you didn't panic-deploy or 'just restart everything.'
>
> Dave would have restarted every container and hoped for the best. Marcus would have escalated to a vendor. You actually *diagnosed* each problem and *fixed* it.
>
> That's the difference between knowing Docker commands and understanding Docker.
>
> Welcome to the team -- for real this time.
>
> Now... about that coffee machine."

---

## Resources Used

- Docker resource prefix: `learn-boss-`
- Labels: `--label app=learn-docker-k8s --label world=w01 --label chapter=boss`
- All resources are cleaned up by `bash engine/cleanup.sh`
