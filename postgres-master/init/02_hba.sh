#!/bin/bash
# ================================================================
#  pg_hba.conf extra — permite al rol replicator conectarse desde
#  cualquier nodo de la red Docker
# ================================================================
set -e

echo ">>> Agregando regla de replicación a pg_hba.conf..."

cat >> "$PGDATA/pg_hba.conf" <<EOF

# Replicación – permite al rol replicator desde la red Docker
host    replication     replicator      0.0.0.0/0               md5
host    all             postgres        0.0.0.0/0               md5
EOF

echo ">>> pg_hba.conf actualizado."
psql -U "$POSTGRES_USER" -c "SELECT pg_reload_conf();"
echo ">>> Configuración recargada."
