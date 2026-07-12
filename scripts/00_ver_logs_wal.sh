#!/bin/bash
# ================================================================
#  Práctica 13 – Ver logs WAL del Maestro en tiempo real
#  Ejecutar en una terminal separada ANTES de los otros scripts
# ================================================================

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  PRÁCTICA 13 – Monitor de Logs WAL en Tiempo Real            ║"
echo "║  Presiona Ctrl+C para detener                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Escuchando logs de: pg-master | pg-replica1 | pg-replica2"
echo ""

docker compose logs -f --no-log-prefix \
  pg-master pg-replica1 pg-replica2 2>/dev/null \
  | grep --line-buffered -E "MAESTRO|REPLICA|WAL|replication|promote|recovery|checkpoint|LOG|FATAL|ERROR|standby"
