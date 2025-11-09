# 🖥️ Homelab Observability Stack

A lightweight, self-contained monitoring stack for my homelab.

Powered by **Prometheus**, **Grafana**, **Node Exporter**, and **cAdvisor**.

Deployed on Ubuntu Docker-enabled host server.

---

## 🚀 Features
- **Prometheus** - metrics collection and storage
- **Grafana** - dashboard visualization
- **Node Exporter** - host-level metrics (CPU, memory, disk, network)
- **cAdvisor** - container metrics
- **Persistent storage** - all data saved to local volumes
- **Simple config** - one `docker-compose` away

---

## 📦 Setup

### 1. Prerequisites
- Docker & Docker Compose installed
- At least 2 GB RAM and a few GB free disk space
- Network access to ports `3000`, `9090`, and `8080`

### 2. Clone & Run
```bash
git clone https://github.com/GavMason/homelab-observability.git
cd homelab-observability
docker compose up -d
