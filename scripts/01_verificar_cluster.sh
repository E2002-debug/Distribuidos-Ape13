#!/bin/bash
# ================================================================
#  Práctica 13 – FASE 1: Verificar estado del clúster (Versión Sudo)
#  Ejecutar: bash scripts/01_verificar_cluster.sh
# ================================================================

set -e
MASTER_CONTAINER="pg-master"
R1_CONTAINER="pg-replica1"
R2_CONTAINER="pg-replica2"

PG_USER="postgres"
PG_DB="postgres"

run_psql_docker() {
  local label="$1"
  local container="$2"
  local query="$3"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  📍 $label  (Contenedor: $container)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Añadimos sudo para asegurar los privilegios sobre Docker
  sudo docker exec -i "$container" psql -U "$PG_USER" -d "$PG_DB" -c "$query" || echo "  ⚠️  Nodo no disponible (offline o en failover)"
}

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  PRÁCTICA 13 – Estado del Clúster PostgreSQL WAL     ║"
echo "╚══════════════════════════════════════════════════════╝"

echo ""
echo ">>> 1. ROL DE CADA NODO (pg_is_in_recovery = TRUE → réplica)"
run_psql_docker "MAESTRO"   $MASTER_CONTAINER "SELECT 'MAESTRO'  AS nodo, pg_is_in_recovery() AS es_replica, pg_current_wal_lsn() AS wal_lsn;"
run_psql_docker "RÉPLICA 1" $R1_CONTAINER     "SELECT 'REPLICA1' AS nodo, pg_is_in_recovery() AS es_replica, pg_last_wal_receive_lsn() AS wal_recibido;"
run_psql_docker "RÉPLICA 2" $R2_CONTAINER     "SELECT 'REPLICA2' AS nodo, pg_is_in_recovery() AS es_replica, pg_last_wal_receive_lsn() AS wal_recibido;"

echo ""
echo ">>> 2. RECEPTORES WAL CONECTADOS AL MAESTRO"
run_psql_docker "MAESTRO – pg_stat_replication" $MASTER_CONTAINER \
  "SELECT client_addr, application_name, state, sent_lsn, write_lsn, flush_lsn, replay_lsn FROM pg_stat_replication;"

echo ""
echo ">>> 3. CANTIDAD DE FILAS EN eventos_replicacion (debe coincidir)"
run_psql_docker "MAESTRO"   $MASTER_CONTAINER "SELECT 'MAESTRO'  AS nodo, COUNT(*) AS total_filas FROM eventos_replicacion;"
run_psql_docker "RÉPLICA 1" $R1_CONTAINER     "SELECT 'REPLICA1' AS nodo, COUNT(*) AS total_filas FROM eventos_replicacion;"
run_psql_docker "RÉPLICA 2" $R2_CONTAINER     "SELECT 'REPLICA2' AS nodo, COUNT(*) AS total_filas FROM eventos_replicacion;"

echo ""
echo "✅ Verificación completa."