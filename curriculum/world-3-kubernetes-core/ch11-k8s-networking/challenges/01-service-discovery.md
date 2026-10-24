# Challenge 1: Service Discovery

## Briefing

NoCappuccino's app has a frontend and a backend. In Docker Compose, they found each other by service name on a shared network. In Kubernetes, the mechanism is different — but the idea is the same.

Pods can't rely on IPs (they change), so we use Services. A Service gives the backend a stable DNS name that the frontend can always reach, regardless of how many backend Pods are running.

Your mission: deploy both frontend and backend as Deployments, create a ClusterIP Service for the backend, and prove that the frontend can reach the backend by Service name.

---

## Objective

Deploy a frontend and backend as separate Deployments in the `learn-ch11` namespace. Create a ClusterIP Service for the backend. Verify that a frontend Pod can successfully reach the backend using the Service name.

---

## Starting Point

**`backend-deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-backend
  namespace: learn-ch11
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch11
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        world: w03
        chapter: ch11
    spec:
      containers:
        - name: backend
          image: hashicorp/http-echo:latest
          args:
            - "-text=Hello from NoCappuccino backend!"
            - "-listen=:5678"
          ports:
            - containerPort: 5678
          resources:
            requests:
              memory: "16Mi"
              cpu: "25m"
            limits:
              memory: "32Mi"
              cpu: "50m"
```

**`backend-service.yaml`**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: learn-backend-svc
  namespace: learn-ch11
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch11
spec:
  type: ClusterIP
  selector:
    # TODO: Which label should this selector match?
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5678
```

**`frontend-deployment.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-frontend
  namespace: learn-ch11
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch11
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        world: w03
        chapter: ch11
    spec:
      containers:
        - name: frontend
          image: curlimages/curl:latest
          command: ["sleep", "3600"]
          resources:
            requests:
              memory: "16Mi"
              cpu: "25m"
            limits:
              memory: "32Mi"
              cpu: "50m"
```

---

## Your Tasks

1. Fix the `backend-service.yaml` — the selector needs to match the backend Pod labels
2. Apply all three manifests
3. Wait for all Pods to be `Running`
4. Check the Service's Endpoints to confirm it has backend Pod IPs
5. Exec into the frontend Pod and `curl` the backend using the Service name
6. You should see the response: `Hello from NoCappuccino backend!`

---

## Success Criteria

The `challenges/verify.sh` script will check:

- [ ] Deployment `learn-backend` exists with at least 1 ready replica
- [ ] Service `learn-backend-svc` exists in `learn-ch11`
- [ ] Service `learn-backend-svc` has at least one Endpoint
- [ ] In-cluster curl to `http://learn-backend-svc` succeeds

---

## Hints

<details>
<summary>Hint 1 — General direction</summary>

The Service's `selector` field tells it which Pods to route traffic to. Look at the labels defined in the backend Deployment's `spec.template.metadata.labels` — the Service selector needs to match at least one of those key-value pairs. Mismatched labels are the most common reason a Service has no Endpoints.
</details>

<details>
<summary>Hint 2 — Verifying the Service is working</summary>

Before testing with curl, check if the Service has Endpoints. If empty (`<none>`), the labels don't match. Use `kubectl get endpoints learn-backend-svc -n learn-ch11` to check.
</details>

<details>
<summary>Hint 3 — Exec and curl</summary>

To test from the frontend: `kubectl exec -it <frontend-pod-name> -n learn-ch11 -- curl http://learn-backend-svc`. The short DNS name works because both resources are in the same namespace.
</details>

---

## Post-Mission Debrief

*(Read this after you've solved the challenge.)*

**What you did:** Created two Deployments and a ClusterIP Service. The Service uses a label selector to route traffic to backend Pods. The frontend connects to the backend using just the Service name.

**Why it works:** CoreDNS resolves `learn-backend-svc` to the Service's ClusterIP. kube-proxy's iptables rules DNAT the traffic to one of the backend Pod IPs. The frontend never knows which Pod it hits.

**Real-world connection:** This is exactly how microservices communicate in production Kubernetes. `http://user-service`, `http://payment-service`, `http://catalog-service` — stable names that survive restarts, scaling, and rolling updates.

**Interview angle:** "How does service discovery work in Kubernetes?" — Services, ClusterIPs, label selectors, CoreDNS, and search domain configuration. Bonus: mention Endpoints objects.

**Pro tip:** The DNS name `learn-backend-svc` only works from the same namespace. Cross-namespace calls need `learn-backend-svc.learn-ch11` or the full FQDN.
