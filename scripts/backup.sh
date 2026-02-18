#!/bin/bash
# Homelab Observability Stack — Daily Backup
# Backs up Grafana DB, Uptime Kuma DB, Alertmanager data, and config files
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

# 1. Grafana SQLite DB (use docker cp — file is owned by UID 472)
if docker cp grafana:/var/lib/grafana/grafana.db "${BACKUP_PATH}/grafana.db" 2>/dev/null; then
    echo "  ✓ Grafana DB"
else
    echo "  ⚠ Grafana DB skipped (container not running?)"
fi

# 2. Uptime Kuma SQLite DB (use docker cp — file is owned by root)
if docker cp uptime-kuma:/app/data/kuma.db "${BACKUP_PATH}/kuma.db" 2>/dev/null; then
    echo "  ✓ Uptime Kuma DB"
else
    echo "  ⚠ Uptime Kuma DB skipped (container not running?)"
fi

# 3. Alertmanager data (use docker cp)
if docker cp alertmanager:/alertmanager "${BACKUP_PATH}/alertmanager-data" 2>/dev/null; then
    tar -czf "${BACKUP_PATH}/alertmanager-data.tar.gz" -C "${BACKUP_PATH}" alertmanager-data/ 2>/dev/null
    rm -rf "${BACKUP_PATH}/alertmanager-data"
    echo "  ✓ Alertmanager data"
else
    echo "  ⚠ Alertmanager data skipped"
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

# 5. Calculate backup size
BACKUP_SIZE=$(du -sh "${BACKUP_PATH}" | cut -f1)
echo "  Backup size: ${BACKUP_SIZE}"

# 6. Clean up old backups (keep last N days)
find "${BACKUP_DIR}" -maxdepth 1 -type d -mtime +${RETENTION_DAYS} -not -path "${BACKUP_DIR}" -exec rm -rf {} \;
REMAINING=$(find "${BACKUP_DIR}" -maxdepth 1 -type d -not -path "${BACKUP_DIR}" | wc -l)
echo "  Retained backups: ${REMAINING}"

echo "[$(date)] Backup complete"
