# Homelab Observability Stack

A self-contained monitoring, alerting, and dashboard stack for homelabs. Includes a reverse proxy, uptime monitoring, and a service dashboard — all managed through Docker Compose.

Deployed on an Ubuntu Docker-enabled host server (Dell OptiPlex 5050).

---

## Features

### Monitoring & Alerting
- **Prometheus** — metrics collection and storage with configurable retention
- **Grafana** — dashboard visualization
- **Node Exporter** — host-level metrics (CPU, memory, disk, network)
- **cAdvisor** — container metrics for Docker monitoring
- **Alertmanager** — alert routing and grouping
- **Discord notifications** — instant alerts via webhooks
- **Uptime Kuma** — uptime monitoring with status pages

### Infrastructure
- **Caddy** — reverse proxy with `*.homelab.internal` subdomains
- **Homepage** — service dashboard with live status indicators
- **Portainer** — container management UI

### Quality of Life
- Persistent storage for all services
- Health checks on every container
- Environment-based configuration via `.env`
- Non-conflicting port mappings
- Wildcard DNS via dnsmasq (`*.homelab.internal`)

---

## Quick Start

### 1. Prerequisites
- Docker & Docker Compose
- At least 2 GB RAM and a few GB free disk space
- Discord account (for alert notifications)

### 2. Clone & Configure
```bash
git clone https://github.com/GavMason/homelab-observability.git
cd homelab-observability

cp .env.example .env
nano .env  # Set your Discord webhook and Grafana password
```

### 3. Set Up Discord Webhook
See [docs/DISCORD_SETUP.md](docs/DISCORD_SETUP.md) for detailed instructions.

### 4. Start the Stack
```bash
docker compose up -d
```

### 5. DNS Setup (optional)
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
| Service | URL |
|---------|-----|
| Homepage (Dashboard) | http://homelab.internal |
| Grafana | http://grafana.homelab.internal |
| Prometheus | http://prometheus.homelab.internal |
| Alertmanager | http://alertmanager.homelab.internal |
| Uptime Kuma | http://uptime-kuma.homelab.internal |
| cAdvisor | http://cadvisor.homelab.internal |
| Portainer | http://portainer.homelab.internal |

### Via Direct Ports
| Service | Port | Default Credentials |
|---------|------|---------------------|
| Grafana | 3333 | admin / (set in .env) |
| Prometheus | 9191 | — |
| Alertmanager | 9393 | — |
| cAdvisor | 8181 | — |
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
| Homepage | 3001 | 3000 |
| Uptime Kuma | 3002 | 3001 |
| Caddy | 80 | 80 |

All ports are customizable in `.env`.

### Data Retention
Default Prometheus retention (configurable in `.env`):
- **Time**: 15 days
- **Size**: 10 GB

### Alert Rules
Pre-configured alerts in `prometheus/alerts/homelab_alerts.yaml`:

**Host Alerts:** Host down, high CPU (>80%, >95%), high memory (>80%, >95%), disk space warnings (<20%, <10%), high disk I/O

**Container Alerts:** Container monitoring down, high container CPU/memory usage

**Monitoring Stack Alerts:** Prometheus/Alertmanager down, failed scrapes, TSDB compaction issues

---

## Setting Up Dashboards

After logging into Grafana:

1. **Add Prometheus Data Source:**
   - Configuration > Data Sources > Add data source > Prometheus
   - URL: `http://prometheus:9090`
   - Click "Save & Test"

2. **Import Dashboards** (from grafana.com):
   - **Node Exporter Full**: 1860
   - **Docker Container & Host Metrics**: 179
   - **Prometheus Stats**: 2

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

# Restart services
docker compose restart
docker compose restart prometheus

# Update images
docker compose pull
docker compose up -d

# Backup Grafana dashboards
tar -czf grafana-backup-$(date +%Y%m%d).tar.gz grafana/

# Reload Prometheus config without restart
curl -X POST http://localhost:9191/-/reload
```

---

## Project Structure

```
.
├── alertmanager/
│   └── alertmanager.yaml           # Alertmanager config
├── caddy/
│   └── Caddyfile                   # Reverse proxy routes
├── homepage/
│   ├── services.yaml               # Dashboard service definitions
│   ├── settings.yaml               # Dashboard appearance
│   ├── widgets.yaml                # Dashboard widgets
│   ├── docker.yaml                 # Docker socket config
│   └── bookmarks.yaml              # Bookmarks (optional)
├── prometheus/
│   ├── prometheus.yaml             # Prometheus config
│   └── alerts/
│       └── homelab_alerts.yaml     # Alert rules
├── data/                           # Persistent data (gitignored)
│   ├── prometheus/                 # Metrics TSDB
│   ├── alertmanager/               # Alert state
│   ├── uptime-kuma/                # Uptime Kuma SQLite DB
│   └── caddy/                      # Caddy state & certs
├── grafana/                        # Grafana data (gitignored)
├── docs/
│   └── DISCORD_SETUP.md            # Discord setup guide
├── docker-compose.yaml             # Service definitions
├── .env.example                    # Environment template
└── README.md
```

---

## Security Notes

- Change default Grafana password immediately
- Keep Discord webhook URL private
- All services are LAN-only by default (not exposed to the internet)
- Caddy handles reverse proxying over HTTP (no HTTPS needed for `.local` domains)
- Grafana user sign-up is disabled
- Docker socket is mounted read-only for Homepage

---

## Troubleshooting

### Services Won't Start
```bash
# Check if ports are in use
ss -tlnp | grep -E '80|3333|9191|8181|9393|3001|3002'

# View status and logs
docker compose ps
docker compose logs
```

### Permission Errors (Grafana / Prometheus)
```bash
sudo chown -R 472:472 grafana/
sudo chown -R 65534:65534 data/prometheus/
```

### Not Receiving Discord Alerts
1. Verify webhook URL in `.env`
2. Check logs: `docker compose logs alertmanager-discord`

### DNS Not Resolving (*.homelab.internal)
1. Verify dnsmasq is running: `systemctl status dnsmasq`
2. Check config: `cat /etc/dnsmasq.d/homelab.conf`
3. Test: `dig homelab @localhost`

---

## Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Homepage Documentation](https://gethomepage.dev/)
- [Uptime Kuma Documentation](https://github.com/louislam/uptime-kuma/wiki)

---

## License

MIT License — see LICENSE file for details
