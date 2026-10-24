```
  _                        ___          _             __       _  _____
 | |   ___ __ _ _ _ _ _   |   \ ___  __| |_____ _ _  / _|___  | |/ ( _ )___
 | |__/ -_) _` | '_| ' \  | |) / _ \/ _| / / -_) '_| > _|_ _| | ' </ _ (_-<
 |____\___\__,_|_| |_||_| |___/\___/\__|_\_\___|_|   \_____|  |_|\_\___/__/

                 an interactive AI-driven learning game
```

> *No web app. No video courses.*
> *Just you, your AI editor, a terminal, and mass amounts of coffee.*

An open-source, interactive learning game where your AI becomes a friendly mentor
and walks you through real-world DevOps scenarios — from "what's a container?"
all the way to operating a production platform with observability and incident response.

---

## How It Works

```
  You                     AI Editor                  Your Terminal
  ---                     ---------                  -------------

  "let's play"  ------>   reads game files   -----> checks Docker
                          becomes Sarah              is installed
                          (your mentor)
                                |
                                v
                          "Welcome to NoCappuccino!
                           Dave broke staging
                           again. Let's fix it
                           with containers..."
                                |
                                v
                          lessons --> challenges --> verify --> boss fight --> next world
```

1. Clone this repo
2. Open it in any AI editor ([Claude Code](https://claude.ai/code), [Cursor](https://cursor.com), [Windsurf](https://windsurf.com), [Copilot](https://github.com/features/copilot), [Cline](https://cline.bot), [Codex](https://openai.com/index/codex-cli), [Gemini CLI](https://github.com/google-gemini/gemini-cli), [Devin](https://devin.ai), etc.)
3. Type **"let's play"**
4. Learn by doing

---

## The Cast

```
  .-----------------------------------------------------------.
  |                                                           |
  |  (^_^) Sarah       (@_@;) Dave       (-_-) Marcus         |
  |  Senior DevOps     CTO               Product Mgr          |
  |  Your mentor       "Just restart it"  "Demo is at 3"      |
  |                                                           |
  |               NoCappuccino Inc.                           |
  |            "Coffee, code, containers"                     |
  |                                                           |
  '-----------------------------------------------------------'
```

You just joined **NoCappuccino**, a fast-growing coffee subscription startup where
things are... a bit chaotic. Sarah, your senior DevOps engineer, will guide you
through the mess. Dave (the CTO) keeps breaking things. Marcus (the PM) keeps
setting deadlines. The coffee machine breaks as often as production.

---

## The Journey — 5 Worlds

```
  WORLD 1: Docker Foundations          WORLD 2: Docker Engineering
  .-------.-------.-------.-------.    .-------.-------.-------.-------.
  | Ch01  | Ch02  | Ch03  | Ch04  |    | Ch05  | Ch06  | Ch07  | Ch08  |
  | Box   | Image | Store | Net   |    | Stack | Proc  | Debug | Audit |
  '-------'-------'-------'-------'    '-------'-------'-------'-------'
            [BOSS: Morning From Hell]            [BOSS: Full Stack Meltdown]
                      |                                    |
                      v                                    v
  WORLD 3: Kubernetes Core             WORLD 4: K8s Production
  .-------.-------.-------.-------.    .-------.-------.-------.
  | Ch09  | Ch10  | Ch11  | Ch12  |    | Ch13  | Ch14  | Ch15  |
  | Arch  | Work  | Net   | Store |    | Health| Sched | SecK8s|
  '-------'-------'-------'-------'    '-------'-------'-------'
            [BOSS: Cluster Crisis]             [BOSS: Great Latte Leak]
                      |                                    |
                      '------------------------------------'
                                       |
                                       v
                      WORLD 5: Platform Engineering
                      .-------.-------.-------.
                      | Ch16  | Ch17  | Ch18  |
                      | Obs   | Deliv | Incid |
                      '-------'-------'-------'
                       [BOSS: The Full Platform]

                      DEEP DIVES (optional, any time)
                      .-------.-------.-------.-------.
                      |Linux  |NetAdv |SecAdv |Multi- |
                      |Intern |       |       | Arch  |
                      '-------'-------'-------'-------'
```

### World 1: Docker Foundations (Beginner)

| Ch | Title | Scenario | You'll Learn |
|----|-------|----------|-------------|
| 01 | **It Works on My Machine** | Dave's API crashes on staging | containers, images, port mapping |
| 02 | **The 2GB Espresso** | Image is 2GB, deploys take forever | multi-stage builds, BuildKit, caching |
| 03 | **The Vanishing Beans** | Customer data gone after restart | volumes, bind mounts, OverlayFS |
| 04 | **The Silent Grinder** | Demo in 2 hrs, services can't talk | DNS, bridge networks, troubleshooting |

### World 2: Docker Engineering (Intermediate)

| Ch | Title | Scenario | You'll Learn |
|----|-------|----------|-------------|
| 05 | **The Symphony of Steam** | 15 commands to start the stack | Compose, health checks, profiles, secrets |
| 06 | **The Zombie Barista** | Containers won't stop gracefully | PID 1, signals, ENTRYPOINT/CMD, init |
| 07 | **The Debugging Grind** | Mysterious failures at 3 AM | exit codes, docker stats, systematic debugging |
| 08 | **The Audit** | Security auditor found everything | non-root, capabilities, secret leakage |

### World 3: Kubernetes Core (Intermediate)

| Ch | Title | Scenario | You'll Learn |
|----|-------|----------|-------------|
| 09 | **The Giant Roaster** | 50K users melted the server | K8s architecture, Pods, Deployments, kind |
| 10 | **The Fleet** | Not everything is a Deployment | StatefulSets, Jobs, CronJobs, DaemonSets |
| 11 | **The Service Mesh** | Pod IPs keep changing | Services, DNS, Ingress, NetworkPolicies |
| 12 | **The Persistent Roast** | K8s database lost its data | PV, PVC, StorageClasses, dynamic provisioning |

### World 4: Kubernetes Production (Advanced)

| Ch | Title | Scenario | You'll Learn |
|----|-------|----------|-------------|
| 13 | **The Resilient Brew** | Pods "Running" but app is dead | probes, rolling updates, graceful shutdown |
| 14 | **The Resource Budget** | OOMKilled, hot nodes, HPA fails | requests/limits, QoS, scheduling, autoscaling |
| 15 | **The Lockdown** | Anyone can exec into any pod | RBAC, security contexts, Pod Security Standards |

### World 5: Platform Engineering (Advanced)

| Ch | Title | Scenario | You'll Learn |
|----|-------|----------|-------------|
| 16 | **The Glass Roaster** | Dashboard green, customers complain | Prometheus, Grafana, metrics, alerting |
| 17 | **The Pipeline** | Dave deployed "latest" from his laptop | Helm, tagging, registries, GitOps |
| 18 | **The On-Call Shift** | First on-call. 2 AM page. | triage, mitigation, postmortems, runbooks |

### Deep Dives (Optional)

| Track | Title | Topics |
|-------|-------|--------|
| Linux Internals | **Under the Hood** | namespaces, cgroups, OverlayFS, /proc |
| Advanced Networking | **The Wire** | iptables, veth pairs, CNI, kube-proxy |
| Container Security | **The Vault** | rootless Docker, seccomp, supply chain |
| Multi-Architecture | **The Universal Bean** | buildx, ARM64, manifest lists |

Along the way you'll naturally pick up **Linux fundamentals** (namespaces, cgroups, filesystem mounts) and **networking concepts** (DNS, NAT, subnets, iptables) — without ever sitting through a networking lecture.

---

## Getting Started

### Prerequisites

```
  .---------------------------------------------------.
  |  Required               Optional (Worlds 3-5)     |
  |  --------               ----------------------    |
  |  [x] Docker             [ ] kubectl               |
  |  [x] Docker Compose v2  [ ] kind                  |
  |  [x] AI editor          [ ] helm                  |
  |      (any of the above)                            |
  '---------------------------------------------------'
```

### Quick Start

```bash
git clone https://github.com/ericboy0224/learn-docker-and-k8s.git
cd learn-docker-and-k8s
```

Then open it in your AI editor and type: **"let's play"**

That's it. The AI handles everything else.

---

## Commands

```
  .---------------------------------------------------.
  |                                                    |
  |  /play            start or resume the game         |
  |  /env-check       verify your setup                |
  |  /progress        see your progress & competencies |
  |  /hint            get a nudge (3 levels)           |
  |  /verify          check your challenge solution    |
  |  /next            move to next lesson/challenge    |
  |  /skip-to 4       jump ahead (with quiz)           |
  |  /cleanup         remove game Docker resources     |
  |                                                    |
  |  ...or just talk naturally:                        |
  |  "I'm stuck"  "check my work"  "what's next"      |
  |  "interview mode"  "deep dive"  "review"           |
  |                                                    |
  '---------------------------------------------------'
```

---

## What Makes This Different

```
  Traditional Course            This Project
  ------------------            ------------

  Watch a video                 Play a game
  Follow step-by-step           Investigate & fix broken systems
  Passive consumption            Active problem-solving
  Classroom setting              Simulated real job
  Isolated concepts              Everything connects
  Generic examples               Coffee startup story
  7 chapters                     5 worlds + boss fights + deep dives
  One difficulty                 Adaptive to your skill level
  Learn tools                    Build competence
```

- **AI as game engine** — The prompt files ARE the game code. No server needed.
- **Story-driven** — Characters, stakes, humor. Dave will break things.
- **Real environments** — Actual Docker & K8s on your machine.
- **Challenge mode** — The AI won't give answers, only progressive hints.
- **Boss fights** — Multi-failure capstones that test everything you've learned.
- **Competency tracking** — The AI adapts to your strengths and weaknesses.
- **Interview prep** — Practice modes for technical interviews.
- **Cross-learning** — Docker teaches you Linux & networking for free.
- **Safe sandbox** — All resources use `learn-` prefix. Easy cleanup. No host damage.
- **Platform-aware** — Detects your OS, arch, and Docker variant. No ARM64 surprises.

---

## Project Structure

```
  .
  |-- AGENTS.md                <-- AI reads this first (universal)
  |-- CLAUDE.md                <-- Claude Code entry point + skills
  |-- .cursorrules             <-- Cursor entry point
  |-- .windsurfrules           <-- Windsurf entry point
  |
  |-- engine/                  <-- game engine
  |   |-- rules.md                 teaching, challenge, interview modes
  |   |-- narrator.md              story, characters, tone per world
  |   |-- competency.md            competency tracking model
  |   |-- modes.md                 interview & review modes
  |   |-- validation.md            how to verify challenges
  |   |-- environment-check.sh     pre-flight check
  |   |-- platform.sh              OS/arch/Docker detection
  |   '-- cleanup.sh               remove all learn-* resources
  |
  |-- curriculum/              <-- the learning content
  |   |-- map.yaml                 world/chapter structure & competencies
  |   |-- world-1-docker-foundations/
  |   |-- world-2-docker-engineering/
  |   |-- world-3-kubernetes-core/
  |   |-- world-4-kubernetes-production/
  |   |-- world-5-platform-engineering/
  |   '-- deep-dives/
  |
  |-- tests/                   <-- curriculum self-testing
  |   '-- test-curriculum.sh       validate curriculum integrity
  |
  |-- .player/
  |   |-- progress.yaml            your save file (AI-managed)
  |   '-- workspace/               your working directory
  |
  '-- learn-devops/            <-- research materials
```

---

## Contributing

This is an open-source project. Contributions welcome!

```
  Ways to contribute:

  New challenges     Add challenges to existing chapters
  New chapters       Add chapters to existing worlds
  New deep dives     Create optional advanced content
  Translations       Translate content (keep technical terms in English)
  Bug fixes          Fix verify.sh scripts or instructions
  Platform support   Add entry points for other AI editors
  Self-tests         Add curriculum integrity tests
```

---

## Author

Created by [**Eric**](https://github.com/ericboy0224) — built with curiosity, coffee, and Claude.

If this project helped you learn something, give it a star and share it with someone starting their DevOps journey.

## License

MIT

---

```
  _  _      ___                           _
 | \| |___ / __|__ _ _ __ _ __ _  _ __ __(_)_ _  ___
 | .` / _ \ (__/ _` | '_ \ '_ \ || / _/ _| | ' \/ _ \
 |_|\_\___/\___\__,_| .__/ .__/\_,_\__\__|_|_||_\___/
                     |_|  |_|

              Keep calm and containerize.
                  Happy learning! - Sarah
```
