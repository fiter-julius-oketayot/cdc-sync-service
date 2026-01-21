# CDC Sync Service

A bi-directional Change Data Capture (CDC) synchronization service using Debezium, Apache Kafka, Spring Boot, Oracle, and PostgreSQL. This service captures data changes in real-time from Oracle and PostgreSQL databases and synchronizes them across both systems.

## Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Technical Details](#technical-details)

## Architecture

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   Oracle    │◄───────►│   Kafka     │◄───────►│  PostgreSQL │
│  (Source)   │         │  (Broker)   │         │  (Target)   │
└──────┬──────┘         └──────┬──────┘         └──────┬──────┘
       │                       │                       │
       │    ┌──────────────────┴──────────────────┐   │
       │    │         Debezium Connect            │   │
       │    │  ┌─────────────┐ ┌─────────────┐    │   │
       └────┼──│   Oracle    │ │  PostgreSQL │────┼───┘
            │  │  Connector  │ │  Connector  │    │
            │  └─────────────┘ └─────────────┘    │
            └──────────────────┬──────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │  CDC Sync Service   │
                    │   (Spring Boot)     │
                    │                     │
                    │  - Kafka Consumer   │
                    │  - JPA (PostgreSQL) │
                    │  - JDBC (Oracle)    │
                    └─────────────────────┘
```

### Data Flow

1. **Oracle → PostgreSQL**: Changes in Oracle `DBZUSER.CUSTOMERS` table are captured by Debezium, published to Kafka topic `oracle.DBZUSER.CUSTOMERS`, consumed by the Spring Boot service, and applied to PostgreSQL `public.customers` table.

2. **PostgreSQL → Oracle**: Changes in PostgreSQL `public.customers` table are captured by Debezium, published to Kafka topic `postgres.public.customers`, consumed by the Spring Boot service, and applied to Oracle `DBZUSER.CUSTOMERS` table.

## Prerequisites

- **Docker** and **Docker Compose** v2.0+
- **Java 17** or higher
- **Gradle 7.0+** (or use the included Gradle wrapper)
- **Git Bash** or **WSL** (for running shell scripts on Windows)
- At least **8GB RAM** available for Docker containers

## Quick Start

### 1. Start Infrastructure

```bash
# Clone the repository and navigate to the project directory
cd cdc-sync-service

# Start all Docker containers (Kafka, Oracle, PostgreSQL, Debezium Connect)
docker-compose up -d
```

Wait for all containers to be healthy (Oracle may take 2-3 minutes to start):

```bash
# Check container status
docker ps
```

### 2. Setup Databases

```bash
# Run the unified setup script (sets up both Oracle and PostgreSQL)
./scripts/setup.sh

# Or setup individually:
./scripts/setup.sh oracle     # Oracle only
./scripts/setup.sh postgres   # PostgreSQL only
```

### 3. Register Debezium Connectors

```bash
# Register both Oracle and PostgreSQL connectors
./scripts/connectors.sh register
```

### 4. Run the Spring Boot Application

```bash
# Using Gradle wrapper
./gradlew bootRun

# Or build and run the JAR
./gradlew build
java -jar build/libs/cdc-sync-service-0.0.1-SNAPSHOT.jar
```

### 5. Verify Setup

```bash
# Run health check
./scripts/health-check.sh
```

## Project Structure

```
cdc-sync-service/
├── build.gradle                 # Gradle build configuration
├── docker-compose.yml           # Docker services configuration
├── settings.gradle              # Gradle settings
├── gradlew / gradlew.bat        # Gradle wrapper scripts
│
├── connectors/                  # Debezium connector configurations
│   ├── oracle-connector.json    # Oracle CDC connector config
│   └── postgres-connector.json  # PostgreSQL CDC connector config
│
├── scripts/                     # Setup and management scripts
│   ├── setup.sh                 # Database setup (Oracle & PostgreSQL)
│   ├── setup.sql                # SQL scripts for both databases
│   ├── connectors.sh            # Connector management
│   └── health-check.sh          # System health verification
│
└── src/main/
    ├── java/com/accessbank/cdc/
    │   ├── CdcSyncServiceApplication.java  # Main application
    │   ├── config/
    │   │   └── DataSourceConfig.java       # Dual datasource config
    │   ├── model/
    │   │   └── Customer.java               # JPA entity
    │   ├── repository/
    │   │   └── CustomerRepository.java     # Spring Data JPA repository
    │   └── service/
    │       └── CdcEventHandler.java        # Kafka CDC event processor
    └── resources/
        └── application.yml                 # Application configuration
```

## Configuration

### Docker Services (docker-compose.yml)

| Service | Port | Description |
|---------|------|-------------|
| kafka | 9092 | Apache Kafka broker (KRaft mode) |
| postgres | 5433 | PostgreSQL 16 database |
| oracle | 1521 | Oracle XE 21c database |
| connect | 8083 | Debezium Connect REST API |

### Application Configuration (application.yml)

| Property | Default | Description |
|----------|---------|-------------|
| `spring.datasource.url` | `jdbc:postgresql://localhost:5433/postgres` | PostgreSQL connection URL |
| `spring.kafka.bootstrap-servers` | `localhost:9092` | Kafka bootstrap servers |
| `oracle.datasource.jdbc-url` | `jdbc:oracle:thin:@localhost:1521/XE` | Oracle connection URL |
| `oracle.datasource.username` | `dbzuser` | Oracle CDC user |

### Database Credentials

**PostgreSQL:**
- Host: `localhost:5433`
- Database: `postgres`
- Username: `postgres`
- Password: `postgres`

**Oracle:**
- Host: `localhost:1521`
- Service: `XE`
- CDC User: `dbzuser`
- CDC Password: `dbzpassword`
- SYS Password: `oracle`

## Usage

### Script Commands

#### Setup Script (`./scripts/setup.sh`)

```bash
./scripts/setup.sh              # Setup both Oracle and PostgreSQL
./scripts/setup.sh oracle       # Setup Oracle only
./scripts/setup.sh postgres     # Setup PostgreSQL only
./scripts/setup.sh help         # Show help
```

#### Connector Management (`./scripts/connectors.sh`)

```bash
./scripts/connectors.sh register   # Register all connectors
./scripts/connectors.sh delete     # Delete all connectors
./scripts/connectors.sh status     # Check connector status
./scripts/connectors.sh restart    # Restart all connectors
```

#### Health Check (`./scripts/health-check.sh`)

```bash
./scripts/health-check.sh          # Run comprehensive health check
```

### Testing CDC Synchronization

#### Test Oracle → PostgreSQL

```bash
# Connect to Oracle
docker exec -it oracle-db sqlplus dbzuser/dbzpassword@//localhost:1521/XE

# Insert a new record
INSERT INTO CUSTOMERS VALUES (100, 'Test', 'User', 'test@example.com');
COMMIT;

# Verify in PostgreSQL
docker exec postgres psql -U postgres -c "SELECT * FROM public.customers WHERE id = 100;"
```

#### Test PostgreSQL → Oracle

```bash
# Connect to PostgreSQL
docker exec -it postgres psql -U postgres

# Insert a new record
INSERT INTO public.customers (id, first_name, last_name, email)
VALUES (200, 'Demo', 'User', 'demo@example.com');

# Verify in Oracle
docker exec oracle-db sqlplus dbzuser/dbzpassword@//localhost:1521/XE <<< "SELECT * FROM CUSTOMERS WHERE ID = 200;"
```

### Monitoring Kafka Topics

```bash
# List all CDC topics
docker exec kafka kafka-topics --bootstrap-server kafka:29092 --list

# Consume Oracle CDC events
docker exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic oracle.DBZUSER.CUSTOMERS \
  --from-beginning

# Consume PostgreSQL CDC events
docker exec kafka kafka-console-consumer \
  --bootstrap-server kafka:29092 \
  --topic postgres.public.customers \
  --from-beginning
```

### Viewing Logs

```bash
# Spring Boot application logs
./gradlew bootRun 2>&1 | tee app.log

# Debezium Connect logs
docker logs -f debezium-connect

# Kafka logs
docker logs -f kafka
```

## Troubleshooting

### Common Issues

#### 1. Oracle Container Not Starting

```bash
# Check Oracle logs
docker logs oracle-db

# Oracle may take 2-3 minutes to initialize on first start
# Wait and check health status
docker inspect --format='{{.State.Health.Status}}' oracle-db
```

#### 2. Debezium Connector Failing

```bash
# Check connector status
./scripts/connectors.sh status

# View detailed error logs
docker logs debezium-connect | grep -i error

# Restart connectors
./scripts/connectors.sh restart
```

#### 3. Kafka Connection Issues

```bash
# Verify Kafka is running
docker exec kafka kafka-broker-api-versions --bootstrap-server kafka:29092

# Check Kafka logs
docker logs kafka
```

#### 4. CDC Events Not Being Captured

For Oracle:
```bash
# Verify ARCHIVELOG mode
docker exec oracle-db sqlplus / as sysdba <<< "SELECT LOG_MODE FROM V\$DATABASE;"

# Verify supplemental logging
docker exec oracle-db sqlplus / as sysdba <<< "SELECT SUPPLEMENTAL_LOG_DATA_MIN FROM V\$DATABASE;"
```

For PostgreSQL:
```bash
# Verify WAL level
docker exec postgres psql -U postgres -c "SHOW wal_level;"

# Verify replica identity
docker exec postgres psql -U postgres -c \
  "SELECT relname, relreplident FROM pg_class WHERE relname = 'customers';"
```

#### 5. Application Not Connecting to Databases

```bash
# Test PostgreSQL connection
docker exec postgres psql -U postgres -c "SELECT 1;"

# Test Oracle connection
docker exec oracle-db sqlplus dbzuser/dbzpassword@//localhost:1521/XE <<< "SELECT 1 FROM DUAL;"
```

### Reset Everything

```bash
# Stop all containers and remove volumes
docker-compose down -v

# Start fresh
docker-compose up -d

# Re-run setup
./scripts/setup.sh
./scripts/connectors.sh register
```

## Technical Details

### Debezium CDC Events

Debezium publishes CDC events in JSON format with the following structure:

```json
{
  "op": "c",           // Operation: c=create, u=update, d=delete, r=read (snapshot)
  "before": null,      // Previous state (for updates/deletes)
  "after": {           // New state (for creates/updates)
    "ID": 1,
    "FIRST_NAME": "John",
    "LAST_NAME": "Doe",
    "EMAIL": "john@example.com"
  },
  "source": { ... },   // Source metadata
  "ts_ms": 1642000000  // Timestamp
}
```

### Supported Operations

| Operation | Code | Description |
|-----------|------|-------------|
| Create | `c` | New row inserted |
| Update | `u` | Existing row modified |
| Delete | `d` | Row removed |
| Read | `r` | Initial snapshot read |

### Database Table Schema

**Oracle (`DBZUSER.CUSTOMERS`):**
```sql
CREATE TABLE DBZUSER.CUSTOMERS (
  ID NUMBER(19,0) NOT NULL PRIMARY KEY,
  FIRST_NAME VARCHAR2(255),
  LAST_NAME VARCHAR2(255),
  EMAIL VARCHAR2(255)
);
```

**PostgreSQL (`public.customers`):**
```sql
CREATE TABLE public.customers (
  id BIGINT PRIMARY KEY,
  first_name VARCHAR(255),
  last_name VARCHAR(255),
  email VARCHAR(255)
);
```

### Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| Spring Boot | 3.3.4 | Application framework |
| Spring Kafka | (managed) | Kafka integration |
| Spring Data JPA | (managed) | PostgreSQL ORM |
| PostgreSQL Driver | (managed) | PostgreSQL connectivity |
| Oracle JDBC | 23.3.0 | Oracle connectivity |
| Jackson | (managed) | JSON processing |
| Debezium | 2.7 | CDC connectors |
| Apache Kafka | 3.9.1 | Message broker |

## License

This project is provided for demonstration purposes.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

**Last Updated:** January 2026
