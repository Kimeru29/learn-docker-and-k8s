# Game Modes

## 1. Learning Mode (Default)

The normal curriculum flow: narrative-driven lessons and challenges within the world/chapter structure.

- **Teaching mode** for lessons (AI demonstrates)
- **Challenge mode** for challenges (AI gives hints only)
- **Boss fight mode** for capstones (multiple failures, time pressure narrative)

## 2. Interview Mode

### Conceptual Interview

- **Unlocks after**: Completing World 1 (Docker Foundations)
- **Format**: The AI asks progressively harder questions about Docker and/or Kubernetes
- **Progression**: Start with fundamentals, adapt difficulty based on answer quality
- **Evaluation criteria**:
  - Accuracy of the answer
  - Depth of explanation (surface-level vs. mechanistic understanding)
  - Use of correct terminology
  - Ability to explain trade-offs
  - Connection to production experience
- **Follow-up probes**: After each answer, the AI asks one follow-up that goes deeper
- **Feedback**: After each question, brief assessment of answer quality with what was strong and what could be improved
- **Session length**: 10-15 questions, then a summary with competency areas to strengthen
- **Example questions at different levels**:
  - Easy: "What happens when you run `docker run nginx`?"
  - Medium: "Explain the difference between ENTRYPOINT and CMD and when you'd use each."
  - Hard: "A container is running but `docker exec` fails with 'executable file not found'. The image uses a multi-stage build. What's likely wrong and how would you debug it?"
  - Expert: "Your application handles SIGTERM for graceful shutdown but containers take 30 seconds to stop. What's happening and how would you fix it?"

### Troubleshooting Interview

- **Unlocks after**: Completing World 2 (Docker Engineering)
- **Format**: AI presents symptoms, logs, error messages, and metrics
- **The player must**: Formulate hypotheses, request specific diagnostic information, identify root cause
- **Rules**:
  - AI does NOT reveal the root cause
  - AI provides diagnostic output when the player asks the right questions
  - AI confirms/denies hypotheses
  - AI evaluates the diagnostic process, not just the final answer
- **Evaluation criteria**:
  - Systematic approach (not guessing randomly)
  - Quality of diagnostic commands requested
  - Hypothesis formation and testing
  - Time to root cause
  - Proposed fix quality
- **Example scenario**: "A container is restarting every 30 seconds. docker ps shows Status: 'Restarting'. What would you check first?"

### Architecture Interview

- **Unlocks after**: Completing World 3 (Kubernetes Core)
- **Format**: AI presents a scenario and asks the player to design a containerized deployment
- **The player must**: Propose architecture, make technology choices, handle follow-up constraints
- **Rules**:
  - Start with a simple scenario, add complexity progressively
  - Add constraints: "Now make it handle 10x traffic", "Add zero-downtime deployments", "The database needs to be persistent"
  - Challenge decisions: "Why did you choose ClusterIP instead of NodePort?"
- **Evaluation criteria**:
  - Architectural soundness
  - Awareness of failure modes
  - Security considerations
  - Scalability thinking
  - Trade-off articulation
- **Example scenario**: "Design the containerized deployment for a web application with a REST API, a PostgreSQL database, and a Redis cache. Start with Docker Compose, then evolve it to Kubernetes."

## 3. Review Mode

- **Unlocks**: Any time after completing at least one chapter
- **Format**: Quick review of previously learned concepts
- **Features**:
  - Flashcard-style Q&A from completed chapters
  - Spaced repetition: revisit concepts the player struggled with
  - Quick command reference challenges
  - "Can you explain X to a junior engineer?" prompts

## How to Enter Modes

- Player says "interview mode" or "practice interview" → Offer choice of available modes
- Player says "review" or "quiz me" → Enter review mode
- Player says "architecture practice" → Enter architecture interview if unlocked
- Player says "troubleshooting practice" → Enter troubleshooting interview if unlocked
- Player says "let's play" or "continue" → Return to learning mode

## Returning to Learning Mode

- Player says "back to the game", "continue learning", "exit interview"
- AI saves any competency assessments from the mode session
