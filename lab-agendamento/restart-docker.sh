#!/bin/bash

LOG=/var/log/docker-restart.log

echo "$(date '+%Y-%m-%d %H:%M:%S') - Reiniciando o servico docker" >> "$LOG"
systemctl restart docker

sleep 30

for c in $(docker ps -a --format '{{.Names}}'); do
  status=$(docker inspect -f '{{.State.Status}}' "$c")
  inicio=$(docker inspect -f '{{.State.StartedAt}}' "$c")
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Container $c | status: $status | iniciado em: $inicio" >> "$LOG"
done

echo "----------------------------------------" >> "$LOG"
