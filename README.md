# Homelab Observability Stack

A self-contained monitoring, logging, alerting, and dashboard stack for homelabs. Includes a reverse proxy, uptime monitoring, centralized logging, and a service dashboard — all managed through Docker Compose.

Deployed on an Ubuntu Docker-enabled host server (Dell OptiPlex 5050).

---

## Features

### Monitoring & Alerting
- **Prometheus** — metrics collection and storage with configurable retention
- **Grafana** — dashboard visualization with provisioned datasources and dashboards
- **Node Exporter** — host-level metrics (CPU, memory, disk, network)
- **cAdvisor** — container metrics for Docker monitoring
- **Alertmanager** — alert routing and grouping
- **Discord notifications** — instant alerts via webhooks
- **Uptime Kuma** — uptime monitoring with status pages

### Logging
- **Loki** — log aggregation and querying
- **Promtail** — log collection from all Docker containers via service discovery

### Infrastructure
- **Caddy** — reverse proxy with `*.homelab.internal` subdomains and basic auth
- **Homepage** — service dashboard with live status indicators
- **Portainer** — container management UI (standalone)

### Quality of Life
- All Docker images pinned to specific versions
- Resource limits (memory) on every container
- Log rotation (json-file driver) on every container
- Health checks on every container
- Provisioned Grafana datasources and dashboards (as code)
- Automated daily backups with 7-day retention
- Automated dependency updates via Renovate
- Basic auth on sensitive endpoints (Prometheus, Alertmanager, cAdvisor, Loki)
- Environment-based configuration via `.env`
- Non-conflicting port mappings
- Wildcard DNS via dnsmasq (`*.homelab.internal`)

---

## Quick Start

### 1. Prerequisites
- Docker & Docker Compose V2
- At least 4 GB RAM recommended
- Discord account (for alert notifications)

### 2. Clone & Configure
```bash
git clone https://github.com/GavMason/homelab-observability.git
cd homelab-observability

cp .env.example .env
nano .env  # Set your Discord webhook, Grafana password, and Caddy basic auth hash
```

### 3. Generate Caddy Basic Auth Hash
```bash
docker run --rm caddy:2 caddy hash-password --plaintext 'your_password'
```
Copy the output into `CADDY_BASIC_AUTH_HASH` in `.env`, escaping every `$` as `$$` (required by Docker Compose).

### 4. Set Up Discord Webhook
See [docs/DISCORD_SETUP.md](docs/DISCORD_SETUP.md) for detailed instructions.

### 5. Create Data Directories & Fix Permissions
```bash
mkdir -p data/{prometheus,alertmanager,uptime-kuma,caddy,loki}

# Set correct ownership for containers
sudo chown -R 65534:65534 data/prometheus/
sudo chown -R 10001:10001 data/loki/
sudo chown -R 472:472 grafana/
```

### 6. Start the Stack
```bash
docker compose up -d
```

### 7. DNS Setup (optional)
Install dnsmasq for wildcard `*.homelab.internal` resolution so all devices on the network can access services by name:

```bash
sudo apt install -y dnsmasq
echo "address=/.homelab.internal/YOUR_SERVER_IP" | sudo tee /etc/dnsmasq.d/homelab.conf

# If systemd-resolved conflicts on port 53:
sudo mkdir -p /etc/systemd/resolved.conf.d
echo -e "[Resolve]\nDNSStubListener=no" | sudo tee /etc/systemd/resolved.conf.d/no-stub.conf
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
sudo systemctl restart systemd-resolved
sudo systemctl restart dnsmasq
```

---

## Access Services

### Via Reverse Proxy (with dnsmasq)
| Service | URL | Auth |
|---------|-----|------|
| Homepage (Dashboard) | http://homelab.internal | — |
| Grafana | http://grafana.homelab.internal | Grafana login |
| Prometheus | http://prometheus.homelab.internal | Basic auth |
| Alertmanager | http://alertmanager.homelab.internal | Basic auth |
| Uptime Kuma | http://uptime-kuma.homelab.internal | — |
| cAdvisor | http://cadvisor.homelab.internal | Basic auth |
| Loki | http://loki.homelab.internal | Basic auth |
| Portainer | http://portainer.homelab.internal | Portainer login |

### Via Direct Ports
| Service | Port | Default Credentials |
|---------|------|---------------------|
| Grafana | 3333 | admin / (set in .env) |
| Prometheus | 9191 | — |
| Alertmanager | 9393 | — |
| cAdvisor | 8181 | — |
| Loki | 3100 | — |
| Homepage | 3001 | — |
| Uptime Kuma | 3002 | (created on first visit) |
| Caddy | 80 | — |

---

## Configuration

### Port Mapping
Non-standard external ports avoid conflicts with development projects:

| Service | External Port | Internal Port |
|---------|--------------|---------------|
| Grafana | 3333 | 3000 |
| Prometheus | 9191 | 9090 |
| cAdvisor | 8181 | 8080 |
| Alertmanager | 9393 | 9093 |
| Loki | 3100 | 3100 |
| Homepage | 3001 | 3000 |
| Uptime Kuma | 3002 | 3001 |
| Caddy | 80 | 80 |

All ports are customizable in `.env`.

### Data Retention
Default retention (configurable in `.env`):
- **Prometheus**: 15 days / 10 GB
- **Loki**: 7 days

### Grafana Dashboards
Dashboards are provisioned automatically from `grafana/provisioning/dashboards/`:

- **Node Exporter Full** — host metrics (CPU, memory, disk, network)
- **Docker Containers** — per-container resource usage
- **Caddy Exporter** — reverse proxy request metrics

Datasources (Prometheus and Loki) are also provisioned automatically — no manual setup needed.

### Alert Rules
Pre-configured alerts in `prometheus/alerts/homelab_alerts.yaml`:

**Host Alerts:** Host down, high CPU (>80%, >95%), high memory (>80%, >95%), disk space warnings (<20%, <10%), high disk I/O, high network errors

**Container Alerts:** Container down (per-container), container restarting, high container CPU/memory usage

**Service Alerts:** Target down (catch-all), Prometheus/Alertmanager down, failed scrapes, TSDB compaction issues

---

## Backups

Daily automated backups run at 3am via cron, stored in `~/backups/observability/` with 7-day retention.

**What's backed up:**
- Grafana SQLite DB (via `docker cp`)
- Uptime Kuma SQLite DB (via `docker cp`)
- Alertmanager data
- All config files (docker-compose, .env, prometheus, alertmanager, caddy, homepage, loki, promtail, grafana provisioning, scripts)

**Setup:**
```bash
# Add to crontab
crontab -e
# Add this line:
0 3 * * * /opt/observability/scripts/backup.sh >> ~/backups/observability/backup.log 2>&1
```

**Manual backup:**
```bash
./scripts/backup.sh
```

---

## Testing Alerts

```bash
# Stop a service to trigger alert
docker stop node-exporter

# Wait 1 minute - check Discord for "HostDown" alert
# Restart to get "resolved" notification
docker start node-exporter
```

```bash
# Send a manual test alert
curl -X POST http://localhost:9393/api/v1/alerts -d '[{
  "labels": {
    "alertname": "TestAlert",
    "severity": "warning"
  },
  "annotations": {
    "description": "Test alert from homelab!"
  }
}]'
```

---

## Maintenance

```bash
# View logs
docker compose logs -f
docker compose logs -f prometheus

# Query logs in Loki (via curl)
curl -s -G 'http://localhost:3100/loki/api/v1/label/container/values'

# Restart services
docker compose restart
docker compose restart prometheus

# Update images (Renovate handles this via PRs)
docker compose pull
docker compose up -d
```

---

## Project Structure

```
.
├── alertmanager/
│   └── alertmanager.yaml              # Alertmanager config
├── caddy/
│   └── Caddyfile                      # Reverse proxy routes + basic auth
├── grafana/
│   └── provisioning/
│       ├── datasources/
│       │   └── prometheus.yaml        # Prometheus + Loki datasources
│       └── dashboards/
│           ├── dashboards.yaml        # Dashboard provisioning config
│           ├── node-exporter-full.json # Host metrics dashboard
│           ├── docker-containers.json  # Container metrics dashboard
│           └── caddy.json             # Caddy metrics dashboard
├── homepage/
│   ├── services.yaml                  # Dashboard service definitions
│   ├── settings.yaml                  # Dashboard appearance
│   ├── widgets.yaml                   # Dashboard widgets
│   ├── docker.yaml                    # Docker socket config
│   └── bookmarks.yaml                # Bookmarks (optional)
├── loki/
│   └── loki-config.yaml              # Loki log aggregation config
├── promtail/
│   └── promtail-config.yaml          # Promtail log collection config
├── prometheus/
│   ├── prometheus.yaml                # Prometheus config
│   └── alerts/
│       └── homelab_alerts.yaml        # Alert rules
├── scripts/
│   └── backup.sh                     # Daily backup script
├── data/                              # Persistent data (gitignored)
│   ├── prometheus/                    # Metrics TSDB
│   ├── alertmanager/                  # Alert state
│   ├── uptime-kuma/                   # Uptime Kuma SQLite DB
│   ├── caddy/                         # Caddy state
│   └── loki/                          # Loki chunks + index
├── docker-compose.yaml                # Service definitions
├── renovate.json                      # Automated dependency updates
├── .env.example                       # Environment template
└── README.md
```

---

## Security Notes

- All Docker images pinned to specific versions (no `latest` tags)
- Basic auth on Prometheus, Alertmanager, cAdvisor, and Loki via Caddy
- Grafana user sign-up is disabled
- Docker socket mounted read-only for Homepage and Promtail
- All services are LAN-only by default (not exposed to the internet)
- Resource limits prevent any single container from consuming all RAM
- Log rotation prevents disk exhaustion
- Keep Discord webhook URL and `.env` file private
- Change default Grafana password immediately

---

## Troubleshooting

### Services Won't Start
```bash
# Check if ports are in use
ss -tlnp | grep -E '80|3333|9191|8181|9393|3001|3002|3100'

# View status and logs
docker compose ps
docker compose logs
```

### Permission Errors (Grafana / Prometheus / Loki)
```bash
sudo chown -R 472:472 grafana/
sudo chown -R 65534:65534 data/prometheus/
sudo chown -R 10001:10001 data/loki/
```

### Not Receiving Discord Alerts
1. Verify webhook URL in `.env`
2. Check logs: `docker compose logs alertmanager-discord`

### DNS Not Resolving (*.homelab.internal)
1. Verify dnsmasq is running: `systemctl status dnsmasq`
2. Check config: `cat /etc/dnsmasq.d/homelab.conf`
3. Test: `dig homelab.internal @localhost`

### Loki Not Receiving Logs
1. Check Promtail: `docker compose logs promtail`
2. Verify labels: `curl -s http://localhost:3100/loki/api/v1/label/container/values`
3. Check Loki readiness: `curl -s http://localhost:3100/ready`

---

## Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Homepage Documentation](https://gethomepage.dev/)
- [Uptime Kuma Documentation](https://github.com/louislam/uptime-kuma/wiki)

---

## License

MIT License — see LICENSE file for details
