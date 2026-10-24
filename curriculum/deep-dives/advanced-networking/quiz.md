# Deep Dive Quiz: The Wire — Advanced Networking

This quiz is used for **skip-level assessment**. Score 4/5 or higher to skip this deep dive.

Answer each question before looking at the answers at the bottom.

---

## Questions

**Q1.** When Docker creates a container on the default bridge, it creates a veth pair. Where does each end of the pair go?

- A) One end in the container as `eth0`, the other end in the Docker daemon process
- B) One end in the container as `eth0`, the other end on the host attached to the `docker0` bridge
- C) One end in the container as `lo`, the other end on the host as `docker0`
- D) Both ends stay on the host; the container accesses them through shared memory

---

**Q2.** You run `docker run -p 8080:80 nginx`. A packet arrives at host port 8080. What iptables operation routes it to the container?

- A) SNAT in the POSTROUTING chain rewrites the source to the container's IP
- B) MASQUERADE in the OUTPUT chain redirects local traffic
- C) DNAT in the PREROUTING chain rewrites the destination to the container's IP:80
- D) FORWARD chain accepts the packet and the bridge automatically delivers it

---

**Q3.** In Kubernetes, kube-proxy creates iptables rules for Services. How does it load-balance traffic across multiple pod endpoints?

- A) Round-robin using sequential rule matching
- B) Consistent hashing based on source IP
- C) Random probability using the iptables `statistic` module across endpoint chains
- D) The API server decides which pod receives each request

---

**Q4.** What is the primary role of a CNI (Container Network Interface) plugin in Kubernetes?

- A) Implementing the Kubernetes Service abstraction (ClusterIP, NodePort)
- B) Creating veth pairs, assigning pod IPs, and setting up routes between nodes
- C) Managing DNS resolution for pods and services
- D) Encrypting all inter-pod communication with TLS

---

**Q5.** A service mesh like Istio injects a sidecar proxy into every pod. How does the sidecar intercept all traffic without modifying the application?

- A) It modifies the application's DNS settings to point to the proxy
- B) It uses iptables rules (or eBPF) inside the pod to redirect all inbound/outbound traffic through the proxy
- C) The application must be configured to use the proxy as an HTTP proxy
- D) The CNI plugin routes all traffic to the sidecar before delivering it to the application container

---

## Answers

| # | Answer | Explanation |
|---|--------|-------------|
| Q1 | **B** | A veth pair is a virtual cable. Docker places one end (`eth0`) inside the container's network namespace and attaches the other end (`vethXXX`) to the `docker0` bridge on the host. The bridge acts as a virtual switch connecting all containers. |
| Q2 | **C** | Docker creates a DNAT rule in the nat table's PREROUTING chain (via the DOCKER chain). When a packet arrives at host:8080, the rule rewrites its destination to the container's IP and port 80. The packet is then forwarded through the bridge and veth pair to the container. |
| Q3 | **C** | kube-proxy uses the iptables `statistic` module with `--mode random --probability` to distribute traffic. For N endpoints, the first chain matches with probability 1/N, the second with 1/(N-1), and so on. This achieves approximately equal distribution. |
| Q4 | **B** | CNI plugins handle the pod networking setup: creating veth pairs, assigning IP addresses from the cluster's pod CIDR, and setting up routes so pods on different nodes can reach each other. Service routing (ClusterIP, NodePort) is handled by kube-proxy, not the CNI. DNS is handled by CoreDNS. |
| Q5 | **B** | The service mesh init container (or CNI plugin) configures iptables rules inside the pod's network namespace that redirect all inbound and outbound TCP traffic to the sidecar proxy's ports. The application sends traffic normally — it doesn't know the proxy exists. The proxy terminates the connection, applies policies, and forwards to the actual destination. |

---

## Scoring

- **5/5** — Skip approved. You can trace packets in your sleep.
- **4/5** — Skip approved. Review the explanation for your missed question.
- **3/5 or below** — Work through the lessons. Seeing the actual iptables rules and veth pairs will make this concrete.
