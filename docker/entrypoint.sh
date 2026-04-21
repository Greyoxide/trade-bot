#!/bin/bash
set -e

# Clear logs on each deploy
truncate -s 0 /app/log/trade_bot.log 2>/dev/null || true

# Health check server — required by platforms like Railway/Easypanel
PORT="${PORT:-3000}"
ruby -e "
  require 'socket'
  server = TCPServer.new(${PORT})
  loop { c = server.accept; c.print \"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK\"; c.close }
" &

echo "Health check listening on port ${PORT}"

exec bundle exec ruby run.rb
