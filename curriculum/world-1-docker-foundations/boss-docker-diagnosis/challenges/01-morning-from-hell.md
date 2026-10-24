# Boss Fight: The Morning From Hell

> **Difficulty:** Intermediate (combines all four chapters)
> **Estimated time:** 45-60 minutes
> **Partial credit:** Yes -- each problem is verified independently

---

## Situation

It's 7:45 AM. Marcus is at the airport. Dave is in Colombia. Four Docker problems are happening simultaneously. Customers are affected. You're on your own.

Take a breath. Then triage.

---

## Setup: Create the Broken Environment

Run these commands to set up all four broken scenarios:

### Problem 1: The Bloated Image

Create the bloated Dockerfile and app:

```bash
mkdir -p /tmp/learn-boss-app

cat > /tmp/learn-boss-app/main.go << 'EOF'
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "NoCappuccino Bean-Tracker v2.0")
		fmt.Fprintln(w, "Status: All systems nominal.")
	})

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "ok")
	})

	log.Printf("Bean-Tracker listening on :%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}
EOF

cat > /tmp/learn-boss-app/go.mod << 'EOF'
module github.com/nocappuccino/bean-tracker
go 1.21
EOF

cat > /tmp/learn-boss-app/Dockerfile.bloated << 'EOF'
FROM ubuntu:22.04

RUN apt-get update
RUN apt-get install -y curl wget git build-essential

ARG TARGETARCH
RUN wget https://go.dev/dl/go1.21.0.linux-${TARGETARCH}.tar.gz
RUN tar -C /usr/local -xzf go1.21.0.linux-${TARGETARCH}.tar.gz
RUN rm go1.21.0.linux-${TARGETARCH}.tar.gz

ENV PATH=$PATH:/usr/local/go/bin

COPY . /app
WORKDIR /app

RUN go mod download
RUN go build -o bean-tracker .

EXPOSE 8080
CMD ["/app/bean-tracker"]
EOF
```

### Problem 2: The Vanishing Database

```bash
# Run MySQL WITHOUT a volume (data will be lost on rm)
docker run -d \
  --name learn-boss-db \
  --label app=learn-docker-k8s \
  --label world=w01 \
  --label chapter=boss \
  -e MYSQL_ROOT_PASSWORD=bosspassword \
  -e MYSQL_DATABASE=preferences \
  mysql:8.0
```

Wait for MySQL to initialize (~15 seconds), then add data:

```bash
# Wait for MySQL to be ready
sleep 20

# Insert some customer data
docker exec learn-boss-db mysql -u root -pbosspassword -e "
  USE preferences;
  CREATE TABLE IF NOT EXISTS customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    favorite_roast VARCHAR(50)
  );
  INSERT INTO customers (name, favorite_roast) VALUES
    ('Alice', 'Ethiopian Light'),
    ('Bob', 'Colombian Dark'),
    ('Charlie', 'Brazilian Medium');
"
```

Now simulate Dave's cron job (the destructive restart):

```bash
# This is what Dave's cron job does -- destroys the container
docker stop learn-boss-db
docker rm learn-boss-db
```

The data is now gone. Your job: bring the database back with a volume so this never happens again.

### Problem 3: The Silent Services

```bash
# Start backend on the DEFAULT bridge (no DNS resolution)
docker run -d \
  --name learn-boss-backend \
  --label app=learn-docker-k8s \
  --label world=w01 \
  --label chapter=boss \
  nginx:alpine

# Start frontend on the DEFAULT bridge
docker run -d \
  --name learn-boss-frontend-probe \
  --label app=learn-docker-k8s \
  --label world=w01 \
  --label chapter=boss \
  alpine sleep 3600
```

Verify they can't find each other:

```bash
docker exec learn-boss-frontend-probe ping -c 1 learn-boss-backend
# ping: bad address 'learn-boss-backend'
```

### Problem 4: The Port Collision

```bash
# Start a rogue container on port 8080
docker run -d \
  --name learn-boss-rogue \
  --label app=learn-docker-k8s \
  --label world=w01 \
  --label chapter=boss \
  -p 8080:80 \
  nginx:alpine
```

Now the frontend can't use port 8080. The rogue container needs to be stopped and the frontend needs to serve on port 8080.

---

## Your Mission

Fix all four problems. The order is up to you -- triage based on customer impact.

### Requirement 1: Optimized Image

- Create a proper `Dockerfile` at `/tmp/learn-boss-app/Dockerfile` (or wherever you prefer)
- Build it as `learn-boss-app:optimized`
- The image MUST be under **100MB**
- The image must respond on port 8080 with the Bean-Tracker response
- Use multi-stage builds -- no compilers in the final image

### Requirement 2: Persistent Database

- Create a named volume called `learn-boss-db-data` with labels `app=learn-docker-k8s` and `world=w01` and `chapter=boss`
- Run a MySQL 8.0 container named `learn-boss-db` with:
  - The volume mounted at `/var/lib/mysql`
  - Environment: `MYSQL_ROOT_PASSWORD=bosspassword`, `MYSQL_DATABASE=preferences`
  - Labels: `app=learn-docker-k8s`, `world=w01`, `chapter=boss`
- Create the `customers` table and insert at least one row
- The data must survive `docker stop` + `docker rm` + `docker run` with the same volume

### Requirement 3: Service Discovery

- Create a user-defined network named `learn-boss-app-net` with labels `app=learn-docker-k8s` and `world=w01` and `chapter=boss`
- Connect `learn-boss-backend` and `learn-boss-frontend-probe` to this network
- `learn-boss-frontend-probe` must be able to resolve and reach `learn-boss-backend` by name

### Requirement 4: Frontend on Port 8080

- Stop and remove the rogue container (`learn-boss-rogue`)
- Run or use a container named `learn-boss-frontend` that:
  - Is accessible at `http://localhost:8080`
  - Has labels: `app=learn-docker-k8s`, `world=w01`, `chapter=boss`
  - Serves content (nginx welcome page or custom content)

---

## Hints

This is a boss fight -- hints are more limited than regular challenges.

<details>
<summary>Triage Hint -- What to fix first</summary>

Think about customer impact:
1. **Port collision** -- the entire frontend is down. Fix this first to get something visible.
2. **Service discovery** -- the frontend can't reach the backend. Users see errors.
3. **Database** -- preferences are gone. Users notice but can survive temporarily.
4. **Image size** -- this is an operational concern, not a customer-facing outage. Fix last.

But your order may differ. There's no single correct sequence.

</details>

<details>
<summary>Problem 1 Hint -- The Bloated Image</summary>

Review Chapter 2. You need a multi-stage Dockerfile: one stage with `golang:1.21-alpine` to compile, one stage with `alpine:3.21` for the runtime. The key line is `COPY --from=builder`. Set `CGO_ENABLED=0` for a static binary.

</details>

<details>
<summary>Problem 2 Hint -- The Vanishing Database</summary>

Review Chapter 3. Create a named volume first, then run MySQL with `-v learn-boss-db-data:/var/lib/mysql`. The volume must exist before or be created implicitly by the `-v` flag. After inserting data, test persistence: stop, rm, run again, verify data is still there.

</details>

<details>
<summary>Problem 3 Hint -- Silent Services</summary>

Review Chapter 4. The default bridge doesn't support DNS. Create a user-defined network and connect both containers to it. You can connect running containers with `docker network connect`.

</details>

<details>
<summary>Problem 4 Hint -- Port Collision</summary>

Review Chapter 1. First, find and stop the rogue container that's using port 8080. Then start your frontend container with `-p 8080:80`.

</details>

---

## Verification

When you think all four problems are fixed:

```bash
bash curriculum/world-1-docker-foundations/boss-docker-diagnosis/challenges/verify.sh
```

The script checks each problem independently. You'll see PASS/FAIL for each one.

---

## Cleanup

After completing the boss fight:

```bash
bash engine/cleanup.sh
```

This removes all `learn-*` Docker resources (containers, volumes, networks, images).
