-- Oracle GoldenGate Setup Script for PostgreSQL Target Database
-- This script creates the necessary tables and users for OGG replication

-- Create customers table matching Oracle structure
CREATE TABLE IF NOT EXISTS public.customers (
    id BIGINT PRIMARY KEY,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255)
);

-- Create GoldenGate checkpoint table
CREATE TABLE IF NOT EXISTS public.gg_checkpoint (
    group_name VARCHAR(255) NOT NULL,
    group_key VARCHAR(255) NOT NULL,
    seqno BIGINT NOT NULL,
    rba BIGINT NOT NULL,
    applied_ts TIMESTAMP,
    PRIMARY KEY (group_name, group_key)
);

-- Create user for GoldenGate (if needed)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE username = 'oggadmin') THEN
        CREATE USER oggadmin WITH PASSWORD 'Welcome1';
    END IF;
END
$$;

GRANT ALL PRIVILEGES ON TABLE public.customers TO oggadmin;
GRANT ALL PRIVILEGES ON TABLE public.gg_checkpoint TO oggadmin;
GRANT ALL PRIVILEGES ON SCHEMA public TO oggadmin;

-- Enable PostgreSQL logical replication (for reverse sync via Debezium/custom app)
ALTER SYSTEM SET wal_level = logical;
ALTER SYSTEM SET max_replication_slots = 4;
ALTER SYSTEM SET max_wal_senders = 4;

-- Verify setup
\dt public.customers
\dt public.gg_checkpoint

-- Show table structure
\d public.customers

SELECT 'PostgreSQL setup complete for Oracle GoldenGate' AS status;

