# Debezium CDC Sync Service

A bi-directional Change Data Capture (CDC) synchronization service between Oracle Database and PostgreSQL using Debezium, Kafka, and Spring Boot.

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Testing CDC](#testing-cdc)
- [Troubleshooting](#troubleshooting)
- [How It Works](#how-it-works)

---

## Overview

This project implements real-time bi-directional database synchronization:
- **Oracle → PostgreSQL**: Captures changes from Oracle DBZUSER.CUSTOMERS and replicates to PostgreSQL public.customers
- **PostgreSQL → Oracle**: Captures changes from PostgreSQL and replicates back to Oracle

### Key Features
- ✅ Real-time CDC using Debezium Oracle and PostgreSQL connectors
- ✅ Bi-directional synchronization
- ✅ Automatic schema discovery
- ✅ Support for INSERT, UPDATE, DELETE operations
- ✅ LogMiner-based Oracle CDC (no Golden Gate required)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     CDC Architecture                         │
└─────────────────────────────────────────────────────────────┘

Oracle DB (DBZUSER.CUSTOMERS)
    ↓ LogMiner CDC
Debezium Connect (Oracle Connector)
    ↓ Publishes to
Kafka Topic: oracle.DBZUSER.CUSTOMERS
    ↓ Consumed by
Spring Boot Application
    ↓ Writes to
PostgreSQL (public.customers)
    ↓ PostgreSQL CDC
Debezium Connect (PostgreSQL Connector)
    ↓ Publishes to
Kafka Topic: postgres.public.customers
    ↓ Consumed by
Spring Boot Application
    ↓ Writes back to
Oracle DB (DBZUSER.CUSTOMERS)
```

### Components
- **Oracle XE 21c**: Source database with DBZUSER schema
- **PostgreSQL 15**: Target database with public schema
- **Apache Kafka**: Message broker for CDC events
- **Debezium Connect**: CDC connectors for Oracle and PostgreSQL
- **Spring Boot**: Java application that consumes CDC events and performs sync

---

## Prerequisites

### Software Requirements
- Docker & Docker Compose
- JDK 17+
- Gradle 8+ (or use included wrapper)

### Docker Containers
All services run in Docker:
- `oracle-db`: Oracle XE 21c (port 1521)
- `postgres`: PostgreSQL 15 (port 5433)
- `zookeeper`: Kafka coordination (port 2181)
- `kafka`: Message broker (port 9092)
- `connect`: Debezium Connect (port 8083)

---

## Quick Start

### 1. Start All Services

```bash
docker-compose up -d
```

Wait ~2 minutes for all services to be healthy.

### 2. Setup Oracle Database

#### Enable ARCHIVELOG Mode

Connect to Oracle using DBeaver or SQL*Plus as SYSDBA:

```sql
-- Connect as SYSDBA
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;

-- Verify
SELECT LOG_MODE FROM V$DATABASE;
-- Should show: ARCHIVELOG
```

#### Create CDC User and Table

```bash
cd scripts
docker cp setup-oracle.sql oracle-db:/tmp/
docker exec oracle-db sqlplus / as sysdba @/tmp/setup-oracle.sql
```

This creates:
- `DBZUSER` user with LogMiner permissions
- `DBZUSER.CUSTOMERS` table with supplemental logging
- Sample test data

### 3. Setup PostgreSQL Database

```bash
docker cp setup-postgres.sql postgres:/tmp/
docker exec postgres psql -U postgres -f /tmp/setup-postgres.sql
```

This creates:
- `public.customers` table
- Enables PostgreSQL logical replication

### 4. Register Debezium Connectors

```bash
./register-connectors.sh
```

Wait ~30 seconds for connectors to start.

### 5. Verify Connector Status

```bash
./health-check.sh
```

Expected output:
```
✓ Oracle Connector: RUNNING
✓ PostgreSQL Connector: RUNNING
✓ Kafka topics created
✓ Spring Boot ready to start
```

### 6. Start Spring Boot Application

```bash
cd ..
./gradlew bootRun
```

---

## Configuration

### Oracle Connector Configuration

File: `connectors/oracle-connector.json`

Key settings:
```json
{
  "database.hostname": "oracle-db",
  "database.user": "dbzuser",
  "database.password": "dbzpassword",
  "database.dbname": "XE",
  "schema.include.list": "DBZUSER",
  "log.mining.strategy": "online_catalog",
  "snapshot.mode": "initial"
}
```

**Important Notes:**
- Uses **DBZUSER** schema (NOT SYSTEM) to avoid Debezium filtering
- Requires all V$ views permissions for LogMiner
- ARCHIVELOG mode must be enabled
- Supplemental logging required at table level

### PostgreSQL Connector Configuration

File: `connectors/postgres-connector.json`

Key settings:
```json
{
  "database.hostname": "postgres",
  "database.user": "postgres",
  "schema.include.list": "public",
  "plugin.name": "pgoutput"
}
```

### Application Configuration

File: `src/main/resources/application.yml`

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5433/postgres
    username: postgres
    password: postgres

oracle:
  datasource:
    jdbc-url: jdbc:oracle:thin:@localhost:1521/XE
    username: dbzuser
    password: dbzpassword

kafka:
  bootstrap-servers: localhost:9092
```

---

## Testing CDC

### Test Oracle → PostgreSQL Sync

1. **Insert in Oracle:**
```bash
docker exec oracle-db sqlplus dbzuser/dbzpassword@//localhost:1521/XE <<EOF
INSERT INTO CUSTOMERS VALUES (999, 'Test', 'User', 'test@example.com');
COMMIT;
EXIT;
EOF
```

2. **Verify in PostgreSQL (within 2-3 seconds):**
```bash
docker exec postgres psql -U postgres -d postgres -c "SELECT * FROM public.customers WHERE id = 999;"
```

### Test PostgreSQL → Oracle Sync

1. **Insert in PostgreSQL:**
```bash
docker exec postgres psql -U postgres -d postgres -c "INSERT INTO public.customers VALUES (888, 'Reverse', 'Sync', 'reverse@test.com');"
```

2. **Verify in Oracle (within 2-3 seconds):**
```bash
docker exec oracle-db sqlplus dbzuser/dbzpassword@//localhost:1521/XE <<EOF
SELECT * FROM CUSTOMERS WHERE ID=888;
EXIT;
EOF
```

### Monitor Kafka Topics

```bash
# List all topics
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# View Oracle CDC events
docker exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic oracle.DBZUSER.CUSTOMERS \
  --from-beginning

# View PostgreSQL CDC events
docker exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic postgres.public.customers \
  --from-beginning
```

---

## Troubleshooting

### Issue 1: Oracle Connector Shows FAILED

**Symptom:** Connector state is FAILED, task shows error

**Check:**
```bash
curl -s http://localhost:8083/connectors/oracle-connector/status | jq '.'
```

**Common Causes:**

#### Missing V$ Permissions
```sql
-- Connect as SYSDBA
GRANT SELECT ON V_$LOGMNR_CONTENTS TO DBZUSER;
GRANT SELECT ON V_$LOGMNR_LOGS TO DBZUSER;
GRANT SELECT ON V_$LOG TO DBZUSER;
GRANT SELECT ON V_$ARCHIVED_LOG TO DBZUSER;
GRANT SELECT ON V_$DATABASE TO DBZUSER;
GRANT SELECT ON V_$THREAD TO DBZUSER;
GRANT SELECT ON V_$TRANSACTION TO DBZUSER;
GRANT SELECT ON V_$ARCHIVE_DEST_STATUS TO DBZUSER;
GRANT SELECT ON V_$STATNAME TO DBZUSER;
GRANT SELECT ON V_$MYSTAT TO DBZUSER;
GRANT EXECUTE_CATALOG_ROLE TO DBZUSER;
GRANT SELECT ANY TRANSACTION TO DBZUSER;
GRANT FLASHBACK ANY TABLE TO DBZUSER;
```

#### ARCHIVELOG Not Enabled
```sql
-- Check status
SELECT LOG_MODE FROM V$DATABASE;

-- If NOARCHIVELOG, enable it:
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
```

#### Supplemental Logging Not Enabled
```sql
-- Enable at database level
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

-- Enable at table level
ALTER TABLE DBZUSER.CUSTOMERS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Verify
SELECT SUPPLEMENTAL_LOG_DATA_MIN FROM V$DATABASE;
SELECT TABLE_NAME, LOG_GROUP_NAME FROM USER_LOG_GROUPS WHERE TABLE_NAME='CUSTOMERS';
```

### Issue 2: No Kafka Topics Created

**Symptom:** Connector is RUNNING but no topics appear

**Check:**
```bash
# Check connector status
curl -s http://localhost:8083/connectors/oracle-connector/status

# Check Debezium logs
docker logs debezium-connect --tail 100 | grep -i oracle
```

**Solution:**
```bash
# Force redo log switch
docker exec oracle-db sqlplus / as sysdba <<EOF
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;
EXIT;
EOF

# Insert a test record
docker exec oracle-db sqlplus dbzuser/dbzpassword@//localhost:1521/XE <<EOF
INSERT INTO CUSTOMERS VALUES (777, 'Force', 'Topic', 'force@test.com');
COMMIT;
EXIT;
EOF

# Wait 15 seconds and check topics
sleep 15
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list | grep oracle
```

### Issue 3: Spring Boot Application Errors

**Error:** `ORA-00903: invalid table name` when querying `public.customers`

**Cause:** PostgreSQL table doesn't exist

**Solution:**
```bash
docker exec postgres psql -U postgres -d postgres <<EOF
CREATE TABLE IF NOT EXISTS public.customers (
    id BIGINT PRIMARY KEY,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255)
);
EOF
```

### Issue 4: "No changes will be captured" Warning

**Symptom:** Debezium logs show "After applying the include/exclude list filters, no changes will be captured"

**Cause:** Using SYSTEM schema which Debezium filters out

**Solution:** Use DBZUSER schema (already configured in this project)

### Check Overall Health

```bash
cd scripts
./health-check.sh
```

This script verifies:
- ✓ All Docker containers running
- ✓ Kafka accessible
- ✓ Databases accessible
- ✓ Tables exist with correct structure
- ✓ Connectors registered and RUNNING
- ✓ Spring Boot application ready

---

## How It Works

### Oracle CDC with LogMiner

1. **ARCHIVELOG Mode**: Oracle writes all changes to redo logs in archive mode
2. **Supplemental Logging**: Enriches redo logs with before/after column values
3. **LogMiner**: Debezium queries `V$LOGMNR_CONTENTS` to read redo log entries
4. **Change Extraction**: Converts redo log entries to CDC events
5. **Kafka Publishing**: Publishes events to `oracle.DBZUSER.CUSTOMERS` topic

### PostgreSQL CDC with pgoutput

1. **Logical Replication**: PostgreSQL WAL contains logical change records
2. **Replication Slot**: Debezium creates a slot to track position
3. **Publication**: Defines which tables to capture
4. **Event Extraction**: Reads WAL and converts to CDC events
5. **Kafka Publishing**: Publishes events to `postgres.public.customers` topic

### Spring Boot Event Processing

#### Oracle → PostgreSQL

```java
@KafkaListener(topics = "oracle.DBZUSER.CUSTOMERS")
public void handleOracleChange(ConsumerRecord<String, String> record) {
    // Parse CDC event
    JsonNode root = objectMapper.readTree(record.value());
    String op = root.get("op").asText(); // c=create, u=update, d=delete
    
    // Extract data (Oracle uses UPPERCASE columns)
    JsonNode after = root.get("after");
    Long id = after.get("ID").asLong();
    String firstName = after.get("FIRST_NAME").asText();
    
    // Save to PostgreSQL using JPA
    customerRepository.save(customer);
}
```

#### PostgreSQL → Oracle

```java
@KafkaListener(topics = "postgres.public.customers")
public void handlePostgresChange(ConsumerRecord<String, String> record) {
    // Parse CDC event
    JsonNode root = objectMapper.readTree(record.value());
    
    // Extract data (PostgreSQL uses lowercase columns)
    JsonNode after = root.get("after");
    Long id = after.get("id").asLong();
    
    // Upsert to Oracle using JDBC
    String sql = "MERGE INTO DBZUSER.CUSTOMERS c USING (...) s ON (c.ID = s.ID) ...";
    oracleJdbcTemplate.update(sql, id, firstName, lastName, email);
}
```

### CDC Event Format

Debezium CDC events follow this structure:

```json
{
  "before": { "ID": 1, "FIRST_NAME": "John", ... },
  "after": { "ID": 1, "FIRST_NAME": "Jane", ... },
  "source": {
    "version": "2.7.4.Final",
    "connector": "oracle",
    "name": "oracle",
    "ts_ms": 1768123456789,
    "snapshot": "false",
    "db": "XE",
    "schema": "DBZUSER",
    "table": "CUSTOMERS",
    "scn": 5027093
  },
  "op": "u",  // c=create, u=update, d=delete, r=read(snapshot)
  "ts_ms": 1768123456789
}
```

---

## Project Structure

```
cdc-sync-service/
├── src/main/java/com/accessbank/cdc/
│   ├── CdcSyncServiceApplication.java    # Spring Boot main class
│   ├── config/
│   │   └── DataSourceConfig.java         # Oracle + PostgreSQL datasource config
│   ├── model/
│   │   └── Customer.java                 # JPA entity
│   ├── repository/
│   │   └── CustomerRepository.java       # Spring Data JPA repository
│   └── service/
│       └── CdcEventHandler.java          # Kafka listener & CDC logic
├── src/main/resources/
│   └── application.yml                    # Application configuration
├── connectors/
│   ├── oracle-connector.json             # Debezium Oracle connector config
│   └── postgres-connector.json           # Debezium PostgreSQL connector config
├── scripts/
│   ├── setup-oracle.sql                  # Oracle setup script
│   ├── setup-postgres.sql                # PostgreSQL setup script
│   ├── register-connectors.sh            # Register Debezium connectors
│   └── health-check.sh                   # Health check script
├── docker-compose.yml                     # All services configuration
├── build.gradle                          # Gradle build file
└── README.md                             # This file
```

---

## API Endpoints

### Debezium Connect REST API

```bash
# List all connectors
curl http://localhost:8083/connectors

# Check connector status
curl http://localhost:8083/connectors/oracle-connector/status

# Get connector configuration
curl http://localhost:8083/connectors/oracle-connector

# Delete connector
curl -X DELETE http://localhost:8083/connectors/oracle-connector

# Register connector
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @connectors/oracle-connector.json
```

### Spring Boot Application

The application runs on port **8080** and provides:
- Health check: `http://localhost:8080/actuator/health`
- Metrics: `http://localhost:8080/actuator/metrics`

---

## Performance Tuning

### Oracle LogMiner

Adjust in `connectors/oracle-connector.json`:

```json
{
  "log.mining.batch.size.default": "1000",
  "log.mining.sleep.time.default.ms": "1000",
  "log.mining.view.fetch.size": "10000"
}
```

### Kafka Consumer

Adjust in `application.yml`:

```yaml
spring:
  kafka:
    consumer:
      max-poll-records: 500
      fetch-min-size: 1024
      fetch-max-wait-ms: 500
```

---

## Security Considerations

### Production Recommendations

1. **Change Default Passwords:**
   - Oracle: `dbzuser/dbzpassword`
   - PostgreSQL: `postgres/postgres`
   - Kafka: Enable SASL authentication

2. **Network Security:**
   - Use private networks
   - Enable SSL/TLS for all connections
   - Restrict port access

3. **Oracle Permissions:**
   - Grant only necessary V$ views
   - Use dedicated CDC user (not SYSTEM or SYS)
   - Enable auditing

4. **Kafka Security:**
   - Enable authentication (SASL)
   - Enable encryption (SSL)
   - Configure ACLs for topic access

---

## Limitations

1. **Schema Changes**: Schema evolution is not automatically handled. Requires manual connector restart.
2. **Large Transactions**: Very large transactions may cause memory issues. Monitor heap usage.
3. **Oracle XE**: Limited to 2 CPU threads and 2GB RAM. Use Oracle EE for production.
4. **Data Types**: Complex types (CLOB, BLOB, custom types) may require special handling.
5. **Conflict Resolution**: Last-write-wins strategy. No automatic conflict detection.

---

## License

This project is for demonstration purposes. Adjust as needed for your use case.

---

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review Debezium logs: `docker logs debezium-connect`
3. Check connector status: `curl http://localhost:8083/connectors/oracle-connector/status`
4. Run health check: `./scripts/health-check.sh`

---

## Useful Commands Reference

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker logs oracle-db
docker logs postgres
docker logs kafka
docker logs debezium-connect

# Restart a service
docker-compose restart connect

# Execute SQL in Oracle
docker exec -it oracle-db sqlplus dbzuser/dbzpassword@//localhost:1521/XE

# Execute SQL in PostgreSQL
docker exec -it postgres psql -U postgres -d postgres

# List Kafka topics
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# Consume from topic
docker exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic oracle.DBZUSER.CUSTOMERS \
  --from-beginning

# Check connector status
curl -s http://localhost:8083/connectors/oracle-connector/status | jq '.'

# Register connector
cd scripts && ./register-connectors.sh

# Health check
cd scripts && ./health-check.sh

# Build application
./gradlew clean build

# Run application
./gradlew bootRun
```

---

**Last Updated:** January 11, 2026

