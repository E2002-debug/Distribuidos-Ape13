#!/bin/bash
# ================================================================
#  Práctica 13 – FASE 2: Insertar datos en el Maestro y
#                         verificar replicación en las Réplicas
#  Ejecutar: bash scripts/02_insertar_y_verificar.sh (Modificado para Docker con Sudo)
# ================================================================

MASTER_CONTAINER="pg-master"
R1_CONTAINER="pg-replica1"
R2_CONTAINER="pg-replica2"

PG_USER="postgres"
PG_DB="postgres"  # Aseguramos que apunte a la BD correcta

exec_master() {
  # Agregamos sudo de forma interna
  sudo docker exec -i "$MASTER_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -c "$1"
}

exec_node() {
  local container="$1"
  local query="$2"
  # Agregamos sudo de forma interna y removemos el silenciador para ver errores reales
  sudo docker exec -i "$container" psql -U "$PG_USER" -d "$PG_DB" -c "$query" || echo "  ⚠️  Nodo no disponible"
}

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  PRÁCTICA 13 – Inserción en Maestro + Verificación WAL       ║"
echo "╚══════════════════════════════════════════════════════════════╝"

echo ""
echo ">>> PASO 1: Insertar 5 registros en el MAESTRO..."
for i in $(seq 1 5); do
  exec_master "INSERT INTO eventos_replicacion (descripcion, nodo_origen) \
               VALUES ('Evento de prueba WAL #$i - $(date +%H:%M:%S)', 'maestro');"
  echo "    ✔ Registro $i insertado"
  sleep 0.5
done

echo ""
echo ">>> PASO 2: Esperar propagación WAL (2 segundos)..."
sleep 2

echo ""
echo ">>> PASO 3: Leer últimos 5 registros desde cada nodo"
echo ""
echo "  📌 MAESTRO (Contenedor: $MASTER_CONTAINER):"
exec_node "$MASTER_CONTAINER" \
  "SELECT id, descripcion, nodo_origen, ts FROM eventos_replicacion ORDER BY id DESC LIMIT 5;"

echo ""
echo "  📌 RÉPLICA 1 (Contenedor: $R1_CONTAINER):"
exec_node "$R1_CONTAINER" \
  "SELECT id, descripcion, nodo_origen, ts FROM eventos_replicacion ORDER BY id DESC LIMIT 5;"

echo ""
echo "  📌 RÉPLICA 2 (Contenedor: $R2_CONTAINER):"
exec_node "$R2_CONTAINER" \
  "SELECT id, descripcion, nodo_origen, ts FROM eventos_replicacion ORDER BY id DESC LIMIT 5;"

echo ""
echo ">>> PASO 4: Intentar escribir directamente en RÉPLICA 1 (debe fallar)"
echo "  (Las réplicas en standby rechazan escrituras – esto es esperado)"
echo ""

# Ejecución con sudo para capturar el error de read-only esperado
sudo docker exec -i "$R1_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" \
  -c "INSERT INTO eventos_replicacion (descripcion, nodo_origen) VALUES ('Escritura directa en réplica', 'replica1-test');" 2>&1 \
  | grep -E "ERROR|FATAL|cannot|read-only" | head -3 || true

echo ""
echo "  ✅ Error esperado: las réplicas son de solo lectura."

echo ""
echo "✅ Verificación de replicación completada."