```
  ___ _    ___    ___
 / __| |_ | __|  / __|___ _ __  _ __  ___ ___ ___
| (__| ' \|__ \ | (__/ _ \ '  \| '_ \/ _ (_-</ -_)
 \___|_||_|___/  \___\___/_|_|_| .__/\___/__/\___|
                               |_|

 🎼 "The Symphony of Steam"

    BEFORE: 15 commands 😵       AFTER: 1 command 🎉

    $ docker run frontend...      $ docker compose up
    $ docker run backend...
    $ docker run redis...           .-- frontend  ✅
    $ docker run postgres...        |-- backend   ✅
    $ docker network create...      |-- redis     ✅
    $ docker network connect...     '-- postgres  ✅
    ... (╯°□°)╯
                                    All running!

    (^_^) Sarah: "One command to rule them all." ☕
```

# Chapter 5: The Symphony of Steam

> "I am *tired* of writing setup docs. This is the fourth new hire this month."
> — Sarah, 9:47 AM, third coffee of the day

## The Story So Far

You did it. The investor demo was a hit. NoCappuccino's custom networks are holding, the data is persisting, and Marcus finally stopped asking about the staging server. For about two weeks, everything was quiet.

Then the hiring started.

Dave decided that post-demo momentum meant it was time to scale the *team*. Which is great! Except that every new developer who joins spends their first three days doing nothing but setting up their local environment. Three days of Slack messages like "hey which version of Node?", "what's the Redis port again?", and "wait, do I need to run the mail service locally?"

Sarah's unofficial onboarding doc has grown to 47 steps. She printed it out. It was four pages long.

The stack right now is:

- **Frontend** — Nginx serving static files on port 8080
- **Backend** — Node.js API on port 3000
- **Redis** — Cache layer for session data and recommendations
- **Postgres** — Primary database

That's four `docker run` commands, in a specific order, with specific flags, on a specific network, with specific environment variables. If you forget to start Redis before the backend, the backend crashes. If you forget to create the network first, nothing can talk to anything.

Dave's solution: "Can't we just write a shell script?"

Sarah's solution: Docker Compose.

---

## What Is Docker Compose?

Docker Compose is a tool for defining and running multi-container applications. Instead of 15 terminal commands, you write one YAML file that describes your entire stack — every service, every network, every volume — and then bring it all up with a single command.

It's the "on" button Dave always wanted.

---

## Chapter Objectives

By the end of this chapter, you will be able to:

1. Write a `docker-compose.yml` file to define a multi-service application stack
2. Use `docker compose up`, `docker compose down`, and related commands to manage the stack lifecycle
3. Configure service dependencies so containers start in the right order
4. Implement health checks to solve the startup race condition problem
5. Manage environment variables and secrets using `.env` files and best practices
6. Use Compose profiles to support different environments (dev, test, prod)
7. Configure override files, resource limits, logging, and scaling for production readiness

---

## Lessons

| # | Lesson | Concepts |
|---|--------|----------|
| 01 | [Compose Basics](lessons/01-compose-basics.md) | YAML structure, services/networks/volumes, core commands |
| 02 | [Service Dependencies](lessons/02-service-dependencies.md) | depends_on, health checks, startup order |
| 03 | [Environment and Secrets](lessons/03-environment-and-secrets.md) | env vars, .env files, profiles, secret management |
| 04 | [Advanced Compose](lessons/04-advanced-compose.md) | Override files, resource limits, logging, scaling, profiles for prod |

## Challenges

| # | Challenge | Focus |
|---|-----------|-------|
| 01 | [Full Stack](challenges/01-full-stack.md) | Write the complete NoCappuccino Compose file |
| 02 | [Health Checks](challenges/02-health-checks.md) | Fix the startup race condition |
| 03 | [Secrets and Profiles](challenges/03-secrets-and-profiles.md) | Secure secrets, add dev/test profiles |
| 04 | [Production Compose](challenges/04-production-compose.md) | Resource limits, logging, network isolation, override files |

---

## Post-Chapter Debrief

Once you complete all four challenges and `verify.sh` passes:

**What you built:** A complete, production-grade Docker Compose setup for a four-service application — with proper networking, health checks, secret management, resource limits, and environment-specific configurations.

**Why it matters:** This is exactly how real engineering teams manage local development environments. The `docker-compose.yml` file becomes a living document of your architecture. New developers clone the repo and run one command. That's it.

**Real-world connection:** At companies of all sizes, Compose is the de facto standard for local development stacks. Many teams also use it for integration testing in CI pipelines — spin up the full stack, run tests, tear it down. Override files let you maintain a single base config with environment-specific tweaks.

**Interview angle:** If someone asks "how do you handle service startup order in Docker Compose?", the wrong answer is "I use `sleep 5`". The right answer involves `depends_on` with `condition: service_healthy` and proper health checks — exactly what you just built. Bonus points for mentioning override files and resource limits.

**Pro tip:** Docker Compose files are also a great entry point to understanding Kubernetes manifests. The concepts of services, networks, volumes, environment variables, and health checks all map directly to K8s constructs. You're already thinking in the right abstractions.

---

## The Cliffhanger

The Compose stack is humming. New developers join, run `docker compose up`, and are productive within minutes. Sarah sleeps soundly. Dave is so impressed he added `docker compose up` to the README in 48pt font.

Then things start getting... weird.

On Wednesday, a container takes 10 seconds to stop. On Thursday, `docker top` shows mysterious processes that nobody started. On Friday, the worker service won't shut down gracefully — the deployment pipeline hangs for 30 seconds every time.

Sarah sighs. "We need to talk about PID 1."

*Chapter 6: The Zombie Barista — coming up.*
