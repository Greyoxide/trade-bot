#!/bin/bash
set -e

# Parse cycle from bot.yml and convert to a cron expression
CYCLE=$(ruby -ryaml -e "puts YAML.load_file('config/bot.yml').dig('bot', 'cycle').to_s.strip.downcase")

case "$CYCLE" in
  *h)
    HOURS="${CYCLE%h}"
    CRON_EXPR="0 */${HOURS} * * *"
    ;;
  *m)
    MINS="${CYCLE%m}"
    CRON_EXPR="*/${MINS} * * * *"
    ;;
  *d)
    DAYS="${CYCLE%d}"
    CRON_EXPR="0 0 */${DAYS} * *"
    ;;
  "daily")
    CRON_EXPR="0 0 * * *"
    ;;
  "hourly")
    CRON_EXPR="0 * * * *"
    ;;
  *)
    echo "Unknown cycle '${CYCLE}', defaulting to daily"
    CRON_EXPR="0 0 * * *"
    ;;
esac

echo "Scheduling bot with cron: ${CRON_EXPR}"

# Write env vars into cron-safe format (cron doesn't inherit the environment)
printenv | grep -E '^(ALPACA|OPENAI)' | sed 's/^/export /' > /app/.cron_env

# Write the crontab
cat > /etc/cron.d/trade_bot <<EOF
${CRON_EXPR} root . /app/.cron_env && cd /app && bundle exec ruby run.rb >> /app/log/cron.log 2>&1
EOF

chmod 0644 /etc/cron.d/trade_bot

# Tail both log files so docker logs shows output
touch /app/log/cron.log /app/log/trade_bot.log
tail -F /app/log/cron.log /app/log/trade_bot.log &

exec cron -f
