# 🖥️ Homelab Observability Stack

A production-ready, self-contained monitoring and alerting stack for homelabs.

Powered by **Prometheus**, **Grafana**, **Alertmanager**, **Node Exporter**, and **cAdvisor**.

Deployed on Ubuntu Docker-enabled host server.

---

## 🚀 Features

### Monitoring
- **Prometheus** - metrics collection and storage with configurable retention
- **Grafana** - beautiful dashboard visualization
- **Node Exporter** - host-level metrics (CPU, memory, disk, network)
- **cAdvisor** - container metrics for Docker monitoring

### Alerting
- **Alertmanager** - intelligent alert routing and grouping
- **Discord notifications** - instant alerts via Discord webhooks
- **Pre-configured alerts** - comprehensive alert rules for common issues
- **Smart routing** - critical alerts sent immediately, warnings grouped

### Infrastructure
- **Persistent storage** - all data saved to local volumes
- **Health checks** - automatic container health monitoring
- **Environment-based config** - easy customization via `.env` file
- **Non-conflicting ports** - uses ports that won't clash with dev projects

---

## 📦 Quick Start

### 1. Prerequisites
- Docker & Docker Compose installed
- At least 2 GB RAM and a few GB free disk space
- Discord account (for alert notifications)

### 2. Clone & Configure
```bash
git clone https://github.com/GavMason/homelab-observability.git
cd homelab-observability

# Copy and configure environment file
cp .env.example .env
nano .env  # Set your Discord webhook and Grafana password
```

### 3. Set Up Discord Webhook
See [docs/DISCORD_SETUP.md](docs/DISCORD_SETUP.md) for detailed instructions, or quick version:
1. Go to Discord Server Settings → Integrations → Webhooks
2. Create a webhook for your alerts channel
3. Copy the webhook URL
4. Paste it into `.env` as `DISCORD_WEBHOOK_URL`

### 4. Start the Stack
```bash
docker compose up -d
```

### 5. Access Your Services
- **Grafana**: http://localhost:3333 (default: admin/changeme)
- **Prometheus**: http://localhost:9191
- **Alertmanager**: http://localhost:9393
- **cAdvisor**: http://localhost:8181

---

## 🔧 Configuration

### Port Configuration
The stack uses non-standard ports to avoid conflicts with development projects:

| Service | Port | Standard Port | Why Changed |
|---------|------|---------------|-------------|
| Grafana | 3333 | 3000 | Avoids React/Node.js dev servers |
| Prometheus | 9191 | 9090 | Similar but unique |
| cAdvisor | 8181 | 8080 | Avoids Tomcat/Jenkins/HTTP servers |
| Alertmanager | 9393 | 9093 | Similar but unique |

You can customize any port in the `.env` file.

### Data Retention
Default Prometheus retention (configurable in `.env`):
- **Time**: 15 days
- **Size**: 10 GB

### Alert Rules
Pre-configured alerts in `prometheus/alerts/homelab_alerts.yaml`:

**Host Alerts:**
- Host down
- High/Critical CPU usage (>80%, >95%)
- High/Critical memory usage (>80%, >95%)
- Disk space warnings (<20%, <10%)
- High disk I/O

**Container Alerts:**
- Container monitoring down
- High container CPU/memory usage

**Monitoring Stack Alerts:**
- Prometheus/Alertmanager down
- Failed scrapes
- TSDB compaction issues

---

## 📊 Setting Up Dashboards

After logging into Grafana:

1. **Add Prometheus Data Source:**
   - Go to Configuration → Data Sources → Add data source
   - Select Prometheus
   - URL: `http://prometheus:9090`
   - Click "Save & Test"

2. **Import Dashboards:**
   Popular dashboard IDs from grafana.com:
   - **Node Exporter Full**: 1860
   - **Docker Container & Host Metrics**: 179
   - **Prometheus Stats**: 2

   Go to Dashboards → Import → Enter dashboard ID

---

## 🚨 Testing Alerts

### Test Alert Delivery
```bash
# Stop a service to trigger alert
docker stop node-exporter

# Wait 1 minute - check Discord for "HostDown" alert
# Restart to get "resolved" notification
docker start node-exporter
```

### Send Manual Test Alert
```bash
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

## 🛠️ Maintenance

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f prometheus
docker compose logs -f alertmanager
docker compose logs -f grafana
```

### Restart Services
```bash
# Restart all
docker compose restart

# Restart specific service
docker compose restart prometheus
```

### Update Images
```bash
docker compose pull
docker compose up -d
```

### Backup Grafana Dashboards
```bash
# Backup Grafana data
tar -czf grafana-backup-$(date +%Y%m%d).tar.gz grafana/
```

### Clean Up Data
```bash
# Stop services
docker compose down

# Remove old data (WARNING: deletes all metrics and dashboards)
rm -rf data/ grafana/

# Restart
docker compose up -d
```

---

## 📁 Project Structure

```
.
├── alertmanager/
│   └── alertmanager.yaml          # Alertmanager configuration
├── prometheus/
│   ├── prometheus.yaml            # Prometheus configuration
│   └── alerts/
│       └── homelab_alerts.yaml    # Alert rules
├── docs/
│   └── DISCORD_SETUP.md          # Discord setup guide
├── data/                          # Persistent data (gitignored)
│   ├── prometheus/               # Metrics database
│   └── alertmanager/             # Alert state
├── grafana/                       # Grafana data (gitignored)
├── docker-compose.yaml            # Service definitions
├── .env.example                   # Environment template
└── README.md                      # This file
```

---

## 🔒 Security Notes

- Change default Grafana password immediately
- Keep Discord webhook URL private (treat it like a password)
- All services run on localhost by default (not exposed to internet)
- Consider using a reverse proxy (nginx/Traefik) for HTTPS if exposing externally
- Grafana user sign-up is disabled by default

---

## 🐛 Troubleshooting

### Services Won't Start
```bash
# Check if ports are already in use
netstat -tulpn | grep -E '3333|9191|8181|9393'

# View service status
docker compose ps

# Check logs for errors
docker compose logs
```

### Not Receiving Discord Alerts
1. Verify webhook URL in `.env`
2. Test webhook directly:
   ```bash
   curl -X POST "YOUR_WEBHOOK_URL" \
     -H "Content-Type: application/json" \
     -d '{"content": "Test message"}'
   ```
3. Check alertmanager-discord logs:
   ```bash
   docker compose logs alertmanager-discord
   ```

### Grafana Shows "No Data"
1. Verify Prometheus data source is configured correctly
2. Check Prometheus is scraping targets: http://localhost:9191/targets
3. Verify time range in Grafana dashboard

### Permission Errors on Grafana
```bash
# Fix Grafana directory permissions
sudo chown -R 472:472 grafana/
```

---

## 📚 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Discord Webhook Setup](docs/DISCORD_SETUP.md)
- [PromQL Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)

---

## 🤝 Contributing

Feel free to open issues or submit pull requests for improvements!

---

## 📝 License

MIT License - see LICENSE file for details