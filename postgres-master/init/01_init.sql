-- ============================================================
--  Práctica 13 – Script de inicialización del Maestro PostgreSQL
--  Se ejecuta automáticamente al primer arranque del contenedor
-- ============================================================

-- 1. Crear el rol de replicación (WAL sender)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'replicator') THEN
    CREATE ROLE replicator
      WITH REPLICATION
           LOGIN
           PASSWORD 'replicapass';
    RAISE NOTICE 'Rol replicator creado correctamente.';
  ELSE
    RAISE NOTICE 'Rol replicator ya existe.';
  END IF;
END
$$;

-- 2. Crear tabla de demostración para la práctica
CREATE TABLE IF NOT EXISTS eventos_replicacion (
    id          SERIAL PRIMARY KEY,
    descripcion VARCHAR(255) NOT NULL,
    nodo_origen VARCHAR(50)  DEFAULT 'maestro',
    ts          TIMESTAMPTZ  DEFAULT NOW()
);

-- 3. Insertar datos iniciales
INSERT INTO eventos_replicacion (descripcion, nodo_origen) VALUES
  ('Clúster PostgreSQL iniciado – Maestro activo',       'maestro'),
  ('Replicación WAL configurada con 2 réplicas',         'maestro'),
  ('Práctica 13 – Sistemas Distribuidos en curso',       'maestro');

-- 4. Crear tabla de log de failover para auditoría
CREATE TABLE IF NOT EXISTS log_failover (
    id          SERIAL PRIMARY KEY,
    evento      VARCHAR(100) NOT NULL,
    nodo        VARCHAR(50)  NOT NULL,
    detalle     TEXT,
    ts          TIMESTAMPTZ  DEFAULT NOW()
);
