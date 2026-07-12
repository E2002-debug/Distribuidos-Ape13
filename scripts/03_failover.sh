#!/bin/bash
# ================================================================
#  Práctica 13 – FASE 3: Simulación de Failover (Modificado para Docker con Sudo)
#  Ejecutar: bash scripts/03_failover.sh
# ================================================================

PG_USER="postgres"
PG_DB="postgres"       # 👈 Corregido: cambiada a la BD que sí existe
R1_CONTAINER="pg-replica1"
R2_CONTAINER="pg-replica2"

exec_node() {
  local container="$1"
  local query="$2"
  # Ejecuta la query agregando sudo internamente y quitando el silenciador
  sudo docker exec -i "$container" psql -U "$PG_USER" -d "$PG_DB" -c "$query" \
    || echo "  ⚠️  Nodo no disponible"
}

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  PRÁCTICA 13 – SIMULACIÓN DE FAILOVER PostgreSQL             ║"
echo "╚══════════════════════════════════════════════════════════════╝"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PASO 1: Detener el contenedor MAESTRO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sudo docker stop pg-master
echo "  ✔ pg-master detenido."
echo ""
echo "  ⏳ Esperando 5 segundos para que las réplicas detecten la caída..."
sleep 5

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PASO 2: Promover RÉPLICA 1 a nuevo Maestro"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Ejecutamos la promoción directo dentro de la réplica 1 usando sudo
sudo docker exec -i "$R1_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" \
  -c "SELECT pg_promote(wait := true, wait_seconds := 15);" 2>/dev/null || {
    echo "  ⚠️  pg_promote() vía psql falló. Usando pg_ctl dentro del contenedor...";
    sudo docker exec "$R1_CONTAINER" su postgres -c "pg_ctl promote -D /var/lib/postgresql/data";
  }
echo "  ✔ Promoción ejecutada."
sleep 3

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PASO 3: Verificar nuevo rol de RÉPLICA 1"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  pg_is_in_recovery() debe ser FALSE (ahora es Primary):"
exec_node "$R1_CONTAINER" \
  "SELECT pg_is_in_recovery() AS todavia_es_replica, pg_current_wal_lsn() AS nuevo_wal_lsn;"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PASO 4: Insertar datos en el NUEVO MAESTRO (Réplica 1 promovida)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# 👈 Corregido: Insertamos en eventos_replicacion para garantizar que no falle por falta de tabla
sudo docker exec -i "$R1_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" \
  -c "INSERT INTO eventos_replicacion (descripcion, nodo_origen)
      VALUES ('FAILOVER COMPLETADO: Réplica 1 asumió rol de Maestro', 'replica1-promovida')
      RETURNING *;"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PASO 5: Estado de RÉPLICA 2 (quedó huérfana)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exec_node "$R2_CONTAINER" \
  "SELECT pg_is_in_recovery() AS es_replica, pg_last_wal_receive_lsn() AS ultimo_wal_recibido;"
echo "  ⚠️  Réplica 2 apunta al Maestro caído → está huérfana."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RESUMEN DEL FAILOVER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  [CAÍDO]    pg-master   → (Detenido con éxito)"
echo "  [MAESTRO]  pg-replica1 → (Promovido a Maestro - Acepta escrituras)"
echo "  [HUÉRFANA] pg-replica2 → (Sin fuente WAL - Esperando reconexión)"
echo ""
echo "  Para reconectar Réplica 2:  bash scripts/04_reconectar_replica2.sh"
echo ""
echo "✅ Failover completado."