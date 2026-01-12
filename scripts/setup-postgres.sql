-- =====================================================
-- PostgreSQL Database Setup for Debezium CDC (Simplified)
-- =====================================================
-- Run this as postgres user
-- Connect: psql -U postgres -d postgres -h localhost -p 5433
--
-- This simplified version uses only the public schema
-- No separate inventory schema needed

-- Note: PostgreSQL is already configured for logical replication in docker-compose.yml
-- command: postgres -c wal_level=logical -c max_replication_slots=4 -c max_wal_senders=4

-- Step 1: Verify WAL level (should be 'logical')
SHOW wal_level;

-- Step 2: Drop table if exists (for idempotency)
DROP TABLE IF EXISTS public.customers;

-- Step 3: Create CUSTOMERS table in public schema
CREATE TABLE public.customers (
                                  id BIGINT PRIMARY KEY,
                                  first_name VARCHAR(255),
                                  last_name VARCHAR(255),
                                  email VARCHAR(255)
);

-- Step 4: Set replica identity to FULL
-- This ensures Debezium captures all column values in UPDATE events
ALTER TABLE public.customers REPLICA IDENTITY FULL;

-- Step 5: Insert sample data for testing
INSERT INTO public.customers (id, first_name, last_name, email)
VALUES (1, 'Alice', 'Williams', 'alice.williams@example.com');
INSERT INTO public.customers (id, first_name, last_name, email)
VALUES (2, 'Charlie', 'Brown', 'charlie.brown@example.com');
INSERT INTO public.customers (id, first_name, last_name, email)
VALUES (3, 'Diana', 'Davis', 'diana.davis@example.com');

-- Step 6: Verify setup
SELECT * FROM public.customers;
SELECT schemaname, tablename, * FROM pg_tables WHERE tablename = 'customers';


