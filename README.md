# Oracle GoldenGate CDC Implementation

A complete Change Data Capture (CDC) solution using **Oracle GoldenGate Free Edition** to replicate data changes from Oracle Database to PostgreSQL in real-time.

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Scripts](#scripts)
- [Web UI Configuration](#web-ui-configuration)
- [Testing CDC](#testing-cdc)
- [Troubleshooting](#troubleshooting)
- [Useful Commands](#useful-commands)

---

## Overview

This project implements **real-time data replication** from Oracle Database to PostgreSQL using Oracle GoldenGate Free Edition.

### Key Features
- ✅ **Real-time CDC** - Changes replicated in milliseconds
- ✅ **Transaction Consistency** - ACID properties maintained
- ✅ **All DML Operations** - INSERT, UPDATE, DELETE support
- ✅ **Web Monitoring UI** - Visual dashboards on ports 9100/9200
- ✅ **Free for Production** - No license costs

---

## Architecture

```
┌──────────────────┐
│  Oracle Database │  (Source - Port 1521)
│   OGGUSER schema │
│  CUSTOMERS table │
└────────┬─────────┘
         │ Redo Logs
         ↓
┌──────────────────┐
│ GoldenGate       │  (Extract - Port 9100)
│ for Oracle       │  Captures DML changes
│ goldengate-oracle│  Writes to trail files
└────────┬─────────┘
         │ Trail Files / Network
         ↓
┌──────────────────┐
│ GoldenGate       │  (Replicat - Port 9200)
│ for PostgreSQL   │  Reads trail files
│ goldengate-postgres│ Applies via JDBC
└────────┬─────────┘
         │
         ↓
┌──────────────────┐
│ PostgreSQL DB    │  (Target - Port 5434)
│  public schema   │
│  customers table │
└──────────────────┘
```

### Services

| Service | Container | Port | Description |
|---------|-----------|------|-------------|
| Oracle DB | oracle-db | 1521 | Source database (XE 21c) |
| PostgreSQL | postgres-db | 5434 | Target database (v16) |
| GoldenGate Oracle | goldengate-oracle | 9100 (HTTPS), 7809 | Extract/Pump processes |
| GoldenGate PostgreSQL | goldengate-postgres | 9200 (HTTPS), 7810 | Replicat process |

---

## Prerequisites

### Software Requirements
- **Docker** (20.10+) and **Docker Compose** (2.0+)
- **Oracle Account** (free) - for Oracle Container Registry access
- **8 GB RAM minimum**
- **20 GB disk space**

### Oracle Container Registry Setup

1. **Create Oracle Account**: Register at [oracle.com](https://profile.oracle.com/myprofile/account/create-account.jspx) (free)

2. **Accept License Agreement**:
   - Go to [container-registry.oracle.com](https://container-registry.oracle.com)
   - Search for "goldengate"
   - Click **goldengate-oracle-free** and **goldengate-postgresql-free**
   - Accept the Oracle Standard Terms and Restrictions

3. **Login to Docker**:
   ```bash
   docker login container-registry.oracle.com
   # Username: your-oracle-email@example.com
   # Password: your-account-password (or auth token)
   ```

---

## Quick Start

### 1. Start All Services

```bash
# Start containers
docker-compose up -d

# Check status (wait ~3 minutes for healthy status)
docker-compose ps
```

### 2. Run Setup Script

```bash
cd scripts
chmod +x *.sh    # Make scripts executable (Linux/Mac)
./setup.sh
```

### 3. Access Web UIs

| Service | URL | Credentials |
|---------|-----|-------------|
| Oracle GoldenGate | https://localhost:9100 | oggadmin / Welcome1! |
| PostgreSQL GoldenGate | https://localhost:9200 | oggadmin / Welcome1! |

> **Note**: Accept the self-signed certificate warning in your browser.

### 4. Test CDC

```bash
./test.sh
```

---

## Scripts

The `scripts/` folder contains 4 main scripts:

| Script | Description |
|--------|-------------|
| `setup.sh` | Complete setup - databases and GoldenGate configuration |
| `monitor.sh` | Health checks and monitoring |
| `test.sh` | Test CDC replication (INSERT/UPDATE) |
| `manage.sh` | Service management (start/stop/restart/status/logs/clean) |

### Usage Examples

```bash
cd scripts

# Initial setup
./setup.sh

# Check health
./monitor.sh

# Test replication
./test.sh

# Service management
./manage.sh status
./manage.sh restart
./manage.sh logs
./manage.sh stop
./manage.sh clean    # Remove all data
```

---

## Web UI Configuration

GoldenGate Free Edition uses web-based configuration. This section provides detailed step-by-step procedures to set up the complete CDC data flow from Oracle to PostgreSQL.

### Overview of Configuration Steps

```
1. Access Web UIs and Login
2. Configure Database Connections (Credentials)
3. Create Extract Process (Oracle side)
4. Create Trail Files
5. Create Distribution Path (Oracle → PostgreSQL)
6. Create Replicat Process (PostgreSQL side)
7. Start All Processes
8. Verify Data Flow
```

---

### Step 1: Access the Web UIs

#### Oracle GoldenGate Admin Console
1. Open browser and navigate to: **https://localhost:9100**
2. Accept the self-signed certificate warning:
   - Chrome: Click "Advanced" → "Proceed to localhost (unsafe)"
   - Firefox: Click "Advanced" → "Accept the Risk and Continue"
   - Edge: Click "Continue to localhost (unsafe)"

#### PostgreSQL GoldenGate Admin Console
1. Open a new browser tab: **https://localhost:9200**
2. Accept the certificate warning (same as above)

#### Login Credentials
- **Username**: `oggadmin`
- **Password**: `Welcome1!`

> **Tip**: Open both consoles in separate browser tabs for easier configuration.

---

### Step 2: Configure Oracle Database Connection (Source)

On the **Oracle GoldenGate console** (https://localhost:9100):

#### 2.1 Add Database Credential
1. Click **Configuration** in the left sidebar
2. Click **Credentials** tab
3. Click **+ Add Credential** (or the "+" button)
4. Fill in the form:

   | Field | Value |
   |-------|-------|
   | Credential Domain | `OracleGoldenGate` |
   | Credential Alias | `ogg_oracle` |
   | User ID | `oggadmin@//oracle-db:1521/XEPDB1` |
   | Password | `Welcome1` |
   | Verify Password | `Welcome1` |

   > **Important**: Oracle XE 21c is a **Container Database (CDB)**. You must connect to the **Pluggable Database (PDB)** named `XEPDB1`, NOT to `XE`.
   >
   > - ✅ Correct: `oggadmin@//oracle-db:1521/XEPDB1`
   > - ❌ Wrong: `oggadmin@//oracle-db:1521/XE` (this connects to CDB root, not the PDB)

5. Click **Submit**

#### 2.2 Verify Database Connectivity (Optional)
To test the connection before proceeding:

```bash
# From your host machine, verify Oracle is accessible from GoldenGate container
docker exec goldengate-oracle bash -c "getent hosts oracle-db"
# Should return: 172.x.x.x  oracle-db

# Verify the oggadmin user works on the XEPDB1 pluggable database
docker exec oracle-db sqlplus -S oggadmin/Welcome1@//localhost:1521/XEPDB1 <<< "SELECT 1 FROM DUAL; EXIT;"
# Should return: 1
```

If the credential still fails, check:
- Oracle container is healthy: `docker ps` should show `(healthy)`
- Network connectivity: containers must be on the same `ogg-network`
- User exists in PDB: The `oggadmin` user must be created in `XEPDB1`

---

### Step 3: Create Extract Process (Capture Changes)

The Extract process captures changes from Oracle redo logs.

#### 3.1 Add Extract
1. On Oracle console, click **Extracts** in the left sidebar
2. Click **+ Add Extract** (or the "+" button)
3. Select Extract Type: **Integrated Extract**
4. Click **Next**

#### 3.2 Configure Extract Basic Options

| Field | Value |
|-------|-------|
| Process Name | `EXT_ORA` |
| Description | `Extract changes from Oracle CUSTOMERS table` |
| Credential Domain | `OracleGoldenGate` |
| Credential Alias | `ogg_oracle` |
| Trail Name | `eo` |
| Trail Size (MB) | `500` |

#### 3.3 Configure Extract Registration
1. In the **Registration** section:
   - Check **Register to PDBs** if using pluggable databases
   - Database: Select your Oracle database connection

#### 3.4 Configure Extract Parameters
Click on **Parameter File** or **Edit Parameters** and enter:

```
EXTRACT EXT_ORA
USERID oggadmin, PASSWORD Welcome1
EXTTRAIL ./dirdat/eo

-- Report statistics every 60 seconds
REPORTCOUNT EVERY 60 SECONDS, RATE

-- Table selection
TABLE OGGUSER.CUSTOMERS;
```

#### 3.5 Add Trail File
1. Go to **Trail Files** section (or it may be part of Extract wizard)
2. Configure local trail:

   | Field | Value |
   |-------|-------|
   | Trail Name | `eo` |
   | Trail Path | `./dirdat/eo` |
   | Max Size (MB) | `500` |

3. Click **Create and Run** or **Submit**

---

### Step 4: Create Distribution Path (Data Pump)

The Distribution Path sends trail data from Oracle GoldenGate to PostgreSQL GoldenGate.

#### 4.1 Add Distribution Path
1. On Oracle console, click **Distribution Service** or **Distribution Paths**
2. Click **+ Add Path**

#### 4.2 Configure Distribution Path

| Field | Value |
|-------|-------|
| Path Name | `DIST_ORA_PG` |
| Description | `Distribute trail to PostgreSQL GoldenGate` |
| Source Trail | `./dirdat/eo` |
| Target Host | `goldengate-postgres` |
| Target Port | `443` (HTTPS) or `9200` |
| Target Trail | `./dirdat/ep` |
| Protocol | `wss` (WebSocket Secure) or `https` |

#### 4.3 Target Credentials
If prompted for target authentication:

| Field | Value |
|-------|-------|
| Target User | `oggadmin` |
| Target Password | `Welcome1!` |

3. Click **Create and Run** or **Submit**

---

### Step 5: Configure PostgreSQL Database Connection (Target)

On the **PostgreSQL GoldenGate console** (https://localhost:9200):

#### 5.1 Add Database Credential
1. Click **Configuration** → **Credentials**
2. Click **+ Add Credential**
3. Fill in:

   | Field | Value |
   |-------|-------|
   | Credential Domain | `OracleGoldenGate` |
   | Credential Alias | `ogg_postgres` |
   | User ID | `postgres@postgres-db:5432/postgres` |
   | Password | `postgres` |

   > **Important**: Use port `5432` (internal Docker port), NOT `5434` (external host port).
   >
   > - ✅ Correct: `postgres@postgres-db:5432/postgres`
   > - ❌ Wrong: `postgres@postgres-db:5434/postgres`

4. Click **Submit**

#### 5.2 Configure Database Connection
Some GoldenGate versions require a connection properties file. If prompted:

1. Click **Configuration** → **Database**
2. Add connection with JDBC URL:

   ```
   jdbc:postgresql://postgres-db:5432/postgres
   ```

   Or configure individual fields:

   | Field | Value |
   |-------|-------|
   | Host | `postgres-db` |
   | Port | `5432` |
   | Database | `postgres` |
   | User | `postgres` |
   | Password | `postgres` |

   > **Note**: Inside Docker network, always use the internal port `5432`, not the external mapped port `5434`.

---

### Step 6: Create Replicat Process (Apply Changes)

The Replicat process applies captured changes to PostgreSQL.

#### 6.1 Add Replicat
1. On PostgreSQL console, click **Replicats**
2. Click **+ Add Replicat**
3. Select Replicat Type: **Parallel Replicat** (recommended) or **Classic Replicat**
4. Click **Next**

#### 6.2 Configure Replicat Basic Options

| Field | Value |
|-------|-------|
| Process Name | `REP_PG` |
| Description | `Replicate Oracle changes to PostgreSQL` |
| Credential Domain | `OracleGoldenGate` |
| Credential Alias | `ogg_postgres` |
| Trail Name | `ep` |
| Trail Path | `./dirdat/ep` |
| Checkpoint Table | `public.gg_checkpoint` |

#### 6.3 Configure Replicat Parameters
Click **Parameter File** or **Edit Parameters** and enter:

```
REPLICAT REP_PG
TARGETDB LIBFILE libggjava.so SET property=dirprm/postgres.props
REPORTCOUNT EVERY 60 SECONDS, RATE

-- Handle collisions (for initial load or recovery)
HANDLECOLLISIONS

-- Enable batch SQL for better performance
BATCHSQL

-- Table mapping: Oracle source -> PostgreSQL target
MAP OGGUSER.CUSTOMERS, TARGET public.customers,
    COLMAP (
        id = ID,
        first_name = FIRST_NAME,
        last_name = LAST_NAME,
        email = EMAIL
    );
```

#### 6.4 Create/Verify Checkpoint Table
The checkpoint table should already exist from setup. If not:

```sql
-- Run in PostgreSQL
CREATE TABLE IF NOT EXISTS public.gg_checkpoint (
    group_name VARCHAR(255) NOT NULL,
    group_key VARCHAR(255) NOT NULL,
    seqno BIGINT NOT NULL,
    rba BIGINT NOT NULL,
    applied_ts TIMESTAMP,
    PRIMARY KEY (group_name, group_key)
);
```

#### 6.5 Configure postgres.props (if needed)
If the Replicat requires a properties file, create/edit `dirprm/postgres.props`:

```properties
gg.handlerlist=postgres
gg.handler.postgres.type=postgresql
gg.handler.postgres.connectionURL=jdbc:postgresql://postgres-db:5432/postgres
gg.handler.postgres.userName=postgres
gg.handler.postgres.password=postgres
gg.handler.postgres.batchSize=1000
```

> **Important**: Always use port `5432` in the connection URL (internal Docker port).

3. Click **Create and Run** or **Submit**

---

### Step 7: Start All Processes

#### 7.1 Start Extract (Oracle Console)
1. Go to **Extracts** → Click on `EXT_ORA`
2. Click **Start** button (play icon)
3. Status should change to **Running** (green)

#### 7.2 Start Distribution Path (Oracle Console)
1. Go to **Distribution Paths** → Click on `DIST_ORA_PG`
2. Click **Start**
3. Status should show **Running**

#### 7.3 Start Replicat (PostgreSQL Console)
1. Go to **Replicats** → Click on `REP_PG`
2. Click **Start**
3. Status should change to **Running**

---

### Step 8: Verify the Data Flow

#### 8.1 Check Process Status on Web UIs

**Oracle Console (https://localhost:9100):**
- **Extracts** → `EXT_ORA` should show:
  - Status: `Running`
  - Lag: Low (ideally < 1 second)
  - Statistics: Shows records processed

**PostgreSQL Console (https://localhost:9200):**
- **Replicats** → `REP_PG` should show:
  - Status: `Running`
  - Lag: Low
  - Statistics: Shows records applied

#### 8.2 Monitor on Dashboard
Both consoles have a **Dashboard** or **Overview** page showing:
- Process health
- Throughput graphs
- Lag metrics
- Error counts

#### 8.3 Test with Sample Data
Run the test script:

```bash
cd scripts
./test.sh
```

Or manually test:

```bash
# Insert test record in Oracle
docker exec oracle-db bash -c "echo \"INSERT INTO ogguser.CUSTOMERS VALUES (888, 'WebUI', 'Test', 'webui.test@example.com'); COMMIT; EXIT;\" | sqlplus -S system/oracle@//localhost:1521/XE"

# Wait 5-10 seconds, then verify in PostgreSQL
docker exec postgres-db psql -U postgres -d postgres -c "SELECT * FROM public.customers WHERE id = 888;"
```

Expected output:
```
 id  | first_name | last_name |        email
-----+------------+-----------+----------------------
 888 | WebUI      | Test      | webui.test@example.com
```

---

### Process Status Reference

| Status | Color | Meaning |
|--------|-------|---------|
| Running | Green | Process is active and processing |
| Stopped | Gray | Process is stopped (manual) |
| Starting | Yellow | Process is initializing |
| Abended | Red | Process crashed - check logs |

---

### Quick Troubleshooting During Configuration

#### Extract won't start
- Check Oracle database connection
- Verify credentials are correct
- Check Oracle redo logs are accessible
- Review Extract report: **Extracts** → `EXT_ORA` → **Report**

#### Distribution Path shows errors
- Verify target host is reachable: `goldengate-postgres`
- Check target credentials
- Ensure target GoldenGate is running

#### Replicat won't start
- Verify PostgreSQL connection
- Check checkpoint table exists
- Verify trail files are being received
- Review Replicat report: **Replicats** → `REP_PG` → **Report**

#### View Detailed Logs
- Click on any process → **Details** → **Report** or **Log**
- Or check container logs: `docker logs goldengate-oracle`

---

## Testing CDC

### Automated Test

```bash
cd scripts
./test.sh
```

### Manual Testing

#### Test INSERT
```bash
# Insert in Oracle
docker exec oracle-db bash -c "echo \"INSERT INTO ogguser.CUSTOMERS VALUES (999, 'John', 'Doe', 'john@example.com'); COMMIT; EXIT;\" | sqlplus -S system/oracle@//localhost:1521/XE"

# Check PostgreSQL (wait 5-10 seconds)
docker exec postgres-db psql -U postgres -d postgres -c "SELECT * FROM public.customers WHERE id = 999;"
```

#### Test UPDATE
```bash
docker exec oracle-db bash -c "echo \"UPDATE ogguser.CUSTOMERS SET FIRST_NAME='Jane' WHERE ID=999; COMMIT; EXIT;\" | sqlplus -S system/oracle@//localhost:1521/XE"
```

#### Test DELETE
```bash
docker exec oracle-db bash -c "echo \"DELETE FROM ogguser.CUSTOMERS WHERE ID=999; COMMIT; EXIT;\" | sqlplus -S system/oracle@//localhost:1521/XE"
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs goldengate-oracle
docker logs goldengate-postgres

# Restart with fresh volumes
docker-compose down -v
docker-compose up -d
```

### "Service Manager already running" Error

This happens when volumes have stale state:
```bash
docker-compose down
docker volume rm cdc-sync-service_ogg_oracle_data cdc-sync-service_ogg_postgres_data
docker-compose up -d
```

### Web UI Shows 401 Unauthorized

- Clear browser cache
- Use incognito/private window
- Try credentials: `oggadmin` / `Welcome1!`

### Replication Not Working

1. Check GoldenGate services are running:
   ```bash
   ./scripts/monitor.sh
   ```

2. Verify Extract/Replicat processes are configured via Web UI

3. Check database connectivity:
   ```bash
   # Oracle
   docker exec oracle-db sqlplus system/oracle@//localhost:1521/XE
   
   # PostgreSQL
   docker exec postgres-db psql -U postgres -d postgres
   ```

### Oracle Container Registry Auth Failed

```bash
docker logout container-registry.oracle.com
docker login container-registry.oracle.com
```

---

## Useful Commands

### Docker Management

```bash
# Start/Stop
docker-compose up -d
docker-compose down
docker-compose restart goldengate-oracle

# Logs
docker logs -f goldengate-oracle
docker logs -f goldengate-postgres
```

### Database Access

```bash
# Oracle SQL*Plus
docker exec -it oracle-db sqlplus ogguser/oggpassword@//localhost:1521/XE

# PostgreSQL psql
docker exec -it postgres-db psql -U postgres -d postgres

# From host (PostgreSQL)
psql -h localhost -p 5434 -U postgres -d postgres
```

### Quick Queries

```bash
# Count rows in Oracle
docker exec oracle-db bash -c "echo 'SELECT COUNT(*) FROM ogguser.CUSTOMERS; EXIT;' | sqlplus -S system/oracle@//localhost:1521/XE"

# Count rows in PostgreSQL
docker exec postgres-db psql -U postgres -d postgres -c "SELECT COUNT(*) FROM public.customers;"

# Compare data
docker exec postgres-db psql -U postgres -d postgres -c "SELECT * FROM public.customers ORDER BY id;"
```

---

## Project Structure

```
cdc-sync-service/
├── docker-compose.yml          # Main Docker Compose configuration
├── README.md                   # This file
├── Dockerfile                  # Spring Boot app (optional)
├── build.gradle               # Gradle build
├── scripts/
│   ├── setup.sh               # Complete setup script
│   ├── monitor.sh             # Health monitoring
│   ├── test.sh                # CDC testing
│   ├── manage.sh              # Service management
│   ├── setup-oracle.sql       # Oracle database setup
│   ├── setup-postgres.sql     # PostgreSQL database setup
│   ├── ogg-oracle/            # Oracle GoldenGate configs
│   │   ├── mgr.prm
│   │   ├── ext_oracle.prm
│   │   └── pump_oracle.prm
│   └── ogg-postgres/          # PostgreSQL GoldenGate configs
│       ├── mgr.prm
│       ├── rep_postgres.prm
│       └── postgres.props
└── src/                       # Spring Boot application (optional)
```

---

## Cleanup

```bash
# Stop services (keep data)
docker-compose down

# Remove everything including data
docker-compose down -v

# Remove images
docker rmi container-registry.oracle.com/goldengate/goldengate-oracle-free:latest
docker rmi container-registry.oracle.com/goldengate/goldengate-postgresql-free:latest
```

---

## License

- **Oracle GoldenGate Free Edition** - Free for development and production
- **Oracle Database XE** - Free for development
- **PostgreSQL** - Open Source (PostgreSQL License)

---

**Last Updated**: January 20, 2026
