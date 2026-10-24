# Chapter 18 Quiz: Incident Response

> **Sarah:** "Five questions. These are the things that separate a good on-call engineer from someone who makes incidents worse."

---

## Question 1

It's 2 AM. The pager fires: "Error rate above 5%." You open the dashboard and see elevated errors. You also notice a deployment happened 10 minutes ago.

**What should you do FIRST?**

A) Start reading the code changes in the deployment to understand what might be wrong.

B) Roll back the deployment immediately — errors started after the deploy.

C) Acknowledge the alert, assess impact and blast radius, classify severity, then decide on mitigation.

D) Wake up the person who made the deployment so they can investigate their code.

<details>
<summary>Answer</summary>

**C.**

The first step is always triage: acknowledge, assess, classify. You don't know yet if the deployment is the cause — correlation isn't causation. Maybe the deployment is fine and an external dependency failed at the same time.

Triage takes 2–3 minutes. It tells you: what's the impact, how bad is it, who's affected, and is it getting worse. Then you can make an informed mitigation decision (which may well be a rollback).

Option A is Phase 2 (investigation) — don't skip Phase 1 (triage/mitigation). Option B might be the right mitigation, but you should triage first to understand if rollback is the right action. Option D is blame-first, not process-first.

</details>

---

## Question 2

During an active SEV1 incident, you discover the root cause: a race condition in the new authentication middleware. You know exactly how to fix it — it's a two-line code change.

**What should you do?**

A) Write the fix, push it, and deploy immediately to production.

B) Roll back to the previous version to stop user impact, then write and test the fix properly, and deploy it through the normal pipeline.

C) Write the fix but deploy it only to staging first, then production after staging looks good.

D) Document the root cause and schedule the fix for the next sprint.

<details>
<summary>Answer</summary>

**B.**

Mitigate first. A rollback stops user impact in minutes. Then you have time to write the fix properly, test it, and deploy through the normal pipeline — without the pressure of an active incident.

Option A is tempting ("I know the fix!") but deploying a code change during an active incident without testing is how you turn one incident into two. Option C is better than A but still has users impacted while you wait for staging. Option D leaves users suffering until the next sprint.

The rule: if you can roll back, roll back. Fix later. If you can't roll back (data migration, schema change), then option C is your next best choice.

</details>

---

## Question 3

A database failure causes the API to time out, which causes the frontend to show errors. All three services appear broken.

**Where should you focus your investigation first?**

A) The frontend — that's where user impact is visible.

B) The API — it has the most logs and is the middle of the chain.

C) The database — it's the root of the dependency chain and likely the source.

D) All three simultaneously — assign a person to each.

<details>
<summary>Answer</summary>

**C.**

In a cascading failure, always start at the bottom of the dependency chain. The database is the source; the API and frontend are victims. Fixing the database will likely fix the cascade. Fixing the frontend without fixing the database changes nothing.

Option A wastes time on a symptom. Option B is closer but still a victim service. Option D is reasonable in a large team but with limited responders, prioritize the root source.

The pattern: `Frontend → API → Database`. Start investigation at the rightmost (deepest) service.

</details>

---

## Question 4

You're writing a postmortem. Which action item is the most effective at preventing recurrence?

A) "Engineers should be more careful when deploying."

B) "Add a CI pipeline step that validates the container image exists in the registry before deploying to production."

C) "Review all deployments manually before they go to production."

D) "Send a Slack reminder to test before deploying."

<details>
<summary>Answer</summary>

**B.**

Option B is a **systemic fix** — it changes the system so the failure mode is impossible regardless of who deploys. An automated check in the CI pipeline runs every time and doesn't depend on human diligence.

Option A is not actionable — "be more careful" doesn't change anything. Option C creates a bottleneck and doesn't scale. Option D relies on human memory, which is unreliable at 2 AM.

Good action items change the system. Bad action items ask humans to be perfect. Humans are not perfect — systems should compensate for that.

</details>

---

## Question 5

Your team's postmortem for a recent incident contains this line:

> "The incident was caused by Dave's failure to test the authentication changes before deploying to production."

**What is wrong with this statement, and how should it be rewritten?**

A) Nothing is wrong — Dave should have tested. Accountability matters.

B) It's blameful. Rewrite as: "The deployment pipeline did not include a test step for authentication changes, allowing an untested change to reach production."

C) It's too specific. Rewrite as: "Someone deployed without testing."

D) It should include Dave's title and years of experience for context.

<details>
<summary>Answer</summary>

**B.**

The original statement blames an individual. A blameless rewrite focuses on the system: why was it possible to deploy untested code? The answer leads to a systemic fix (add a test step to the pipeline), not a punishment (lecture Dave).

Option A perpetuates blame culture, which causes people to hide mistakes. Option C removes the individual blame but also removes useful detail. Option D is actively harmful.

Blameless doesn't mean no one is responsible. It means we focus on fixing the system so the failure mode is eliminated, rather than hoping the individual "learns their lesson."

</details>

---

> **Sarah:** "Five for five? Good. You now know how to triage, mitigate, investigate, and document. The next time the pager goes off, you won't freeze. You'll follow the process. And when it's over, you'll write the postmortem that saves the next person three hours of their life at 2 AM."
