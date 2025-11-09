# Discord Alert Setup Guide

This guide will help you set up Discord notifications for your homelab alerts.

## Why Discord?

- **Instant mobile notifications** - Get alerts on your phone
- **Free** - No costs for homelab use
- **Better than email** - Won't get lost in spam
- **Rich formatting** - Color-coded alerts with emojis
- **Alert history** - All alerts saved in a searchable channel

## Setup Steps

### 1. Create a Discord Server (if you don't have one)

1. Open Discord
2. Click the `+` button on the left sidebar
3. Select "Create My Own"
4. Choose "For me and my friends"
5. Name it (e.g., "Homelab")

### 2. Create an Alerts Channel

1. Right-click on your server name
2. Select "Create Channel"
3. Choose "Text Channel"
4. Name it `homelab-alerts` or similar
5. Click "Create Channel"

### 3. Create a Webhook

1. Click the gear icon ⚙️ next to your channel name
2. Go to "Integrations" in the left sidebar
3. Click "Webhooks" or "Create Webhook"
4. Click "New Webhook"
5. Configure the webhook:
   - **Name:** Alertmanager (or any name you prefer)
   - **Channel:** #homelab-alerts
   - **Avatar:** Optional - upload an icon
6. Click "Copy Webhook URL"

The URL will look like:
```
https://discord.com/api/webhooks/1234567890/abcdefghijklmnopqrstuvwxyz
```

### 4. Add Webhook to Your .env File

1. Copy `.env.example` to `.env` if you haven't already:
   ```bash
   cp .env.example .env
   ```

2. Open `.env` and paste your webhook URL:
   ```bash
   DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/YOUR_ACTUAL_WEBHOOK_URL_HERE
   ```

3. Save the file

### 5. Start Your Stack

```bash
docker compose up -d
```

### 6. Test Your Alerts

**Option 1: Stop a service to trigger an alert**
```bash
docker stop node-exporter
# Wait 1 minute - you should get a "HostDown" alert in Discord
docker start node-exporter
# You should get a "resolved" notification
```

**Option 2: Use Alertmanager API to send a test alert**
```bash
curl -X POST http://localhost:9093/api/v1/alerts -d '[{
  "labels": {
    "alertname": "TestAlert",
    "severity": "warning",
    "instance": "test"
  },
  "annotations": {
    "description": "This is a test alert from your homelab monitoring stack!"
  }
}]'
```

## What Alerts Look Like in Discord

### Critical Alert (Red)
```
🚨 [FIRING] HighCPUUsage

Alert: HighCPUUsage
Severity: critical
Instance: localhost:9100
Description: CPU usage is above 95% (current value: 97.3%)
Started: 2025-01-15 14:23:45 UTC
```

### Resolved Alert (Green)
```
✅ [RESOLVED] HighCPUUsage

Alert: HighCPUUsage
Severity: critical
Instance: localhost:9100
Description: CPU usage is above 95% (current value: 97.3%)
Started: 2025-01-15 14:23:45 UTC
Ended: 2025-01-15 14:28:12 UTC
```

## Customizing Alert Behavior

### Change Alert Frequency

Edit `alertmanager/alertmanager.yaml`:

```yaml
route:
  repeat_interval: 12h  # Change to 1h, 6h, 24h, etc.
```

### Critical Alerts More Frequently

Already configured! Critical alerts repeat every 5 minutes, warnings every 1 hour.

### Silence Specific Alerts

1. Go to http://localhost:9093
2. Click on the alert
3. Click "Silence"
4. Set duration and reason
5. Click "Create"

## Troubleshooting

### Not receiving alerts?

1. **Check webhook URL is correct:**
   ```bash
   grep DISCORD_WEBHOOK_URL .env
   ```

2. **Test webhook directly:**
   ```bash
   curl -X POST "YOUR_WEBHOOK_URL" \
     -H "Content-Type: application/json" \
     -d '{"content": "Test message from curl"}'
   ```

3. **Check alertmanager-discord container:**
   ```bash
   docker logs alertmanager-discord
   ```

4. **Check alertmanager logs:**
   ```bash
   docker logs alertmanager
   ```

5. **Verify services are healthy:**
   ```bash
   docker ps --format "table {{.Names}}\t{{.Status}}"
   ```

### Webhook giving 404 error?

- Your webhook URL might be incorrect or deleted
- Recreate the webhook in Discord and update `.env`
- Restart the stack: `docker compose restart`

### Getting too many alerts?

1. Adjust thresholds in `prometheus/alerts/homelab_alerts.yaml`
2. Increase `repeat_interval` in `alertmanager/alertmanager.yaml`
3. Use silences for non-critical alerts

## Advanced: Multiple Notification Channels

You can send different severity alerts to different Discord channels:

1. Create multiple webhooks in Discord
2. Update `alertmanager/alertmanager.yaml`:

```yaml
receivers:
  - name: 'critical-alerts'
    webhook_configs:
      - url: 'http://alertmanager-discord:9094'
        # Use different webhook for critical

  - name: 'warning-alerts'
    webhook_configs:
      - url: 'http://alertmanager-discord:9094'
        # Use different webhook for warnings

route:
  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'

    - match:
        severity: warning
      receiver: 'warning-alerts'
```

Note: You'll need to run multiple alertmanager-discord containers or modify the bridge to support multiple webhooks.

## Need Help?

- Check the [main README](../README.md)
- Review [Alertmanager documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- Review [Alert rules](../prometheus/alerts/homelab_alerts.yaml)
