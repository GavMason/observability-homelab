#!/bin/bash
# Homelab Observability Stack — Daily Backup
# Backs up Grafana DB, Uptime Kuma DB, Prometheus data, and config files
# Run via cron: 0 3 * * * /opt/observability/scripts/backup.sh >> ~/backups/observability/backup.log 2>&1

set -euo pipefail

BACKUP_DIR="${HOME}/backups/observability"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"
COMPOSE_DIR="/opt/observability"
RETENTION_DAYS=7

# Create backup directory
mkdir -p "${BACKUP_PATH}"

echo "[$(date)] Starting backup to ${BACKUP_PATH}"

# 1. Grafana SQLite DB (copy while running — SQLite handles this safely)
if [ -f "${COMPOSE_DIR}/grafana/grafana.db" ]; then
    cp "${COMPOSE_DIR}/grafana/grafana.db" "${BACKUP_PATH}/grafana.db"
    echo "  ✓ Grafana DB"
fi

# 2. Uptime Kuma SQLite DB
if [ -f "${COMPOSE_DIR}/data/uptime-kuma/kuma.db" ]; then
    cp "${COMPOSE_DIR}/data/uptime-kuma/kuma.db" "${BACKUP_PATH}/kuma.db"
    echo "  ✓ Uptime Kuma DB"
fi

# 3. Alertmanager data
if [ -d "${COMPOSE_DIR}/data/alertmanager" ]; then
    tar -czf "${BACKUP_PATH}/alertmanager-data.tar.gz" -C "${COMPOSE_DIR}/data" alertmanager/ 2>/dev/null || true
    echo "  ✓ Alertmanager data"
fi

# 4. All config files (everything tracked in git + .env)
tar -czf "${BACKUP_PATH}/config.tar.gz" \
    -C "${COMPOSE_DIR}" \
    docker-compose.yaml \
    .env \
    prometheus/ \
    alertmanager/ \
    caddy/ \
    homepage/ \
    loki/ \
    promtail/ \
    grafana/provisioning/ \
    scripts/ \
    2>/dev/null || true
echo "  ✓ Config files"

# 5. Prometheus snapshot via API (non-disruptive)
SNAPSHOT_RESULT=$(curl -s -XPOST "http://localhost:9191/api/v1/admin/tsdb/snapshot" 2>/dev/null || echo '{"status":"error"}')
if echo "${SNAPSHOT_RESULT}" | grep -q '"success"'; then
    SNAP_NAME=$(echo "${SNAPSHOT_RESULT}" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
    if [ -n "${SNAP_NAME}" ]; then
        mv "${COMPOSE_DIR}/data/prometheus/snapshots/${SNAP_NAME}" "${BACKUP_PATH}/prometheus-snapshot" 2>/dev/null || true
        echo "  ✓ Prometheus snapshot"
    fi
else
    echo "  ⚠ Prometheus snapshot skipped (API not available)"
fi

# 6. Calculate backup size
BACKUP_SIZE=$(du -sh "${BACKUP_PATH}" | cut -f1)
echo "  Backup size: ${BACKUP_SIZE}"

# 7. Clean up old backups (keep last N days)
find "${BACKUP_DIR}" -maxdepth 1 -type d -mtime +${RETENTION_DAYS} -not -path "${BACKUP_DIR}" -exec rm -rf {} \;
REMAINING=$(find "${BACKUP_DIR}" -maxdepth 1 -type d -not -path "${BACKUP_DIR}" | wc -l)
echo "  Retained backups: ${REMAINING}"

echo "[$(date)] Backup complete"
