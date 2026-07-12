#!/bin/bash
# ================================================================
#  Práctica 13 – FASE 3b: Reconectar Réplica 2 al nuevo Maestro
#  Ejecutar: bash scripts/04_reconectar_replica2.sh
# ================================================================

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  PRÁCTICA 13 – Reconexión de Réplica 2 al nuevo Maestro     ║"
echo "╚══════════════════════════════════════════════════════════════╝"

echo ""
echo "  PASO 1: Editar postgresql.auto.conf en Réplica 2"
echo "          Cambiando primary_conninfo de pg-master → pg-replica1"

docker exec pg-replica2 bash -c "
  echo '--- Configuración ACTUAL ---';
  grep 'primary_conninfo' /var/lib/postgresql/data/postgresql.auto.conf || echo '(no encontrado)';
  sed -i \"s/host=pg-master/host=pg-replica1/g\" /var/lib/postgresql/data/postgresql.auto.conf;
  echo '--- Configuración NUEVA ---';
  grep 'primary_conninfo' /var/lib/postgresql/data/postgresql.auto.conf;
"

echo ""
echo "  PASO 2: Recargar configuración en Réplica 2"
docker exec pg-replica2 su postgres -c "pg_ctl reload -D /var/lib/postgresql/data" 2>/dev/null \
  || docker restart pg-replica2

echo "  ✔ Réplica 2 redirigida al nuevo Maestro (pg-replica1)."
sleep 5

echo ""
echo "  PASO 3: Verificar estado de Réplica 2"
PGPASSWORD="postgres123" psql -h localhost -p 5434 -U postgres -d practica13 \
  -c "SELECT pg_is_in_recovery() AS es_replica, pg_last_wal_receive_lsn() AS wal_recibido;" \
  2>/dev/null || echo "  ⚠️  Réplica 2 aún no disponible, espera unos segundos."

echo ""
echo "✅ Reconexión completada."
