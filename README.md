# Distributed Database E-Shop Project

## Overview

This project demonstrates a **distributed database architecture** for an e-commerce application using **Oracle Database** with database links and synchronization triggers. It simulates a real-world scenario where data is distributed across multiple geographic sites (Site1 and Site2) while maintaining consistency through a global database that orchestrates synchronization.

The project explores two different fragmentation scenarios for distributing order line data:
- **Scenario 1**: Horizontal fragmentation by product category with partial distribution
- **Scenario 2**: Horizontal fragmentation based on custom business rules

### Key Features

- ✅ Multi-database architecture with Docker Compose
- ✅ Database links connecting distributed sites
- ✅ Automatic data synchronization via triggers
- ✅ Horizontal fragmentation strategies
- ✅ Comprehensive test suite
- ✅ Configurable scenarios for experimentation

---

## Architecture

### Database Components

```
┌─────────────────────────────────────────┐
│      Global Database (Main)             │
│  - Orchestrates distribution            │
│  - Triggers sync to Site1 & Site2       │
│  - Contains replicas of all data        │
└──────────────┬──────────────────────────┘
               │
     ┌─────────┴─────────┐
     │                   │
┌────▼─────────┐   ┌────▼─────────┐
│  Site1 DB    │   │  Site2 DB    │
│  - Partial   │   │  - Partial   │
│    data      │   │    data      │
└──────────────┘   └──────────────┘
```

### Database Schema

All three databases share the same schema:

- **Categories**: Product categories
- **Produits** (Products): Product information with prices
- **Clients** (Customers): Customer details
- **Employes** (Employees): Staff information
- **Commandes** (Orders): Order headers linking clients and employees
- **LigneCommandes** (Order Lines): Order detail lines with quantities and discounts

### Data Distribution Strategies

#### Scenario 1: Category-Based Fragmentation (Partial)
- **Site1**: Order lines for products in category 50 with quantity > 100
- **Site2**: Order lines for products in category 35 with quantity > 50
- **Global**: All data including unmatched records

#### Scenario 2: Custom Business Rules
- Different fragmentation criteria based on business logic
- See `03_triggers_scenario2.sql` for detailed rules

---

## Project Structure

```
Distributed-DB/
├── compose.yml                          # Docker Compose orchestration
├── README.md                            # This file
│
├── global_db/                           # Global database container
│   ├── Dockerfile                       # Oracle setup
│   └── init/
│       ├── 01_schema.sql                # Schema creation for all tables
│       ├── 02_db_links.sql              # Database links to Site1 & Site2
│       ├── 03_triggers_scenario1.sql    # Sync triggers (Scenario 1)
│       ├── 03_triggers_scenario2.sql    # Sync triggers (Scenario 2)
│       ├── 04_seed_data.sql             # Sample data insertion
│       ├── 05_explain_plan.sql          # Query execution plans
│       └── 06_distributed_query.sql     # Test distributed queries
│
├── site1_db/                            # Site 1 database container
│   ├── Dockerfile                       # Oracle setup
│   └── init/
│       ├── 01_schema.sql                # Local schema
│       └── 02_procedures.sql            # Site1-specific procedures
│
├── site2_db/                            # Site 2 database container
│   ├── Dockerfile                       # Oracle setup
│   └── init/
│       ├── 01_schema.sql                # Local schema
│       └── 02_procedures.sql            # Site2-specific procedures
│
└── tests/                               # Test suite
    └── test_all_sites.sql               # Automated test scenarios
```

---

## Prerequisites

- **Docker** (version 20.10+)
- **Docker Compose** (version 2.0+)
- **sqlplus** (Oracle SQL client) - optional for manual testing
- ~40GB free disk space (for Oracle database images)
- ~8GB RAM minimum

### Supported Platforms
- Linux
- macOS
- Windows (with Docker Desktop)

---

## Quick Start

### 1. Start All Services

```bash
cd Distributed-DB
docker compose up --build
```

This command:
- Builds three Oracle database containers
- Starts Site1 and Site2 databases first
- Waits for health checks (180s startup period)
- Starts the Global database after Site1 and Site2 are ready
- Creates all schemas, links, and initializes sample data

**Expected startup time**: 5-10 minutes

### 2. Verify Services Are Running

```bash
docker compose ps
```

Expected output:
```
CONTAINER ID   IMAGE                    STATUS                    PORTS
...            eshop_site1_db           Up (healthy)              0.0.0.0:1522->1521/tcp
...            eshop_site2_db           Up (healthy)              0.0.0.0:1523->1521/tcp
...            eshop_global_db          Up (healthy)              0.0.0.0:1521->1521/tcp
```

### 3. Run Tests

```bash
docker exec eshop_global_db sqlplus sys/oracle123@FREEPDB1 as sysdba @/tests/test_all_sites.sql
```

---

## Configuration & Scenarios

### Selecting a Scenario

The project defaults to **Scenario 2**. To use Scenario 1:

```bash
SCENARIO=1 docker compose up --build
```

The `SCENARIO` environment variable controls which trigger set is used during database initialization.

---

## Database Connectivity

### Connection Details

| Database | Host         | Port | SID/PDB    | User | Password   |
|----------|--------------|------|-----------|------|-----------|
| Global   | localhost    | 1521 | FREEPDB1  | eshop | eshop123  |
| Site1    | localhost    | 1522 | FREEPDB1  | site1 | site1123  |
| Site2    | localhost    | 1523 | FREEPDB1  | site2 | site2123  |

### Accessing Databases with sqlplus

```bash
# Global database
sqlplus eshop/eshop123@localhost:1521/FREEPDB1

# Site1
sqlplus site1/site1123@localhost:1522/FREEPDB1

# Site2
sqlplus site2/site2123@localhost:1523/FREEPDB1

# System access (using Docker)
docker exec -it eshop_global_db sqlplus sys/oracle123@FREEPDB1 as sysdba
```

### Web Console Access

Each database includes Oracle Enterprise Manager Express:

- **Global**: http://localhost:5500 (user: sys, password: oracle123, as sysdba)
- **Site1**: http://localhost:5501
- **Site2**: http://localhost:5502

---

## Usage Examples

### Query Data Across All Sites

```sql
-- Connect to global database
CONNECT eshop/eshop123@localhost:1521/FREEPDB1

-- Query local data
SELECT COUNT(*) FROM LigneCommandes;

-- Query Site1 data via database link
SELECT COUNT(*) FROM LigneCommandes@site1_link;

-- Query Site2 data via database link
SELECT COUNT(*) FROM LigneCommandes@site2_link;
```

### Insert Order Data (Triggers Handle Sync)

```sql
CONNECT eshop/eshop123@localhost:1521/FREEPDB1

-- Insert a new order
INSERT INTO Commandes (idcommande, idclient, idemploye, datecommande)
VALUES (1001, 1, 1, SYSDATE);

-- Insert order line (triggers will sync to Site1/Site2 based on scenario)
INSERT INTO LigneCommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (1, 1001, 5001, 150, 0);

COMMIT;
```

### View Query Execution Plans

```bash
docker exec eshop_global_db sqlplus sys/oracle123@FREEPDB1 as sysdba @/tests/05_explain_plan.sql
```

---

## Testing

### Run Full Test Suite

```bash
docker exec eshop_global_db sqlplus sys/oracle123@FREEPDB1 as sysdba @/tests/test_all_sites.sql
```

### Manual Testing

```bash
# Connect to global database
docker exec -it eshop_global_db sqlplus eshop/eshop123@FREEPDB1

-- Run manual tests
SQL> SELECT * FROM LigneCommandes;
SQL> SELECT * FROM LigneCommandes@site1_link;
SQL> SELECT * FROM LigneCommandes@site2_link;
```

---

## Monitoring & Debugging

### View Container Logs

```bash
# Global database logs
docker compose logs global_db -f

# Site1 logs
docker compose logs site1_db -f

# Site2 logs
docker compose logs site2_db -f
```

### Check Database Health

```bash
docker compose ps
```

### View Database Links Status

```bash
docker exec eshop_global_db sqlplus eshop/eshop123@FREEPDB1

SQL> SELECT * FROM user_db_links;
```

### Monitor Triggers

```bash
docker exec eshop_global_db sqlplus eshop/eshop123@FREEPDB1

SQL> SELECT trigger_name, status FROM user_triggers WHERE table_name = 'LIGNECOMMANDES';
```

---

## Stopping & Cleanup

### Stop Services

```bash
docker compose down
```

### Remove All Data (Reset Project)

```bash
docker compose down -v
```

This removes containers, networks, and persistent volumes, giving you a clean slate.

### Remove Images

```bash
docker compose down --rmi all
```

---

## Troubleshooting

### Services Won't Start

**Issue**: Containers crash or health checks fail

**Solutions**:
- Check Docker is running: `docker ps`
- Increase startup timeout: `docker compose logs` for details
- Ensure ports 1521, 1522, 1523, 5500, 5501, 5502 are available
- Check disk space: `df -h`

### Database Link Connection Fails

**Issue**: Queries like `SELECT * FROM table@site1_link` return connection errors

**Solutions**:
- Verify database links exist: `SELECT * FROM user_db_links;`
- Check Site1 and Site2 are healthy: `docker compose ps`
- Check network connectivity: `docker network inspect distributed-db_eshop_net`
- Verify credentials in `02_db_links.sql`

### Tests Fail or Are Inconsistent

**Issue**: Test results vary between runs

**Solutions**:
- Ensure all containers are fully healthy (180s startup)
- Run tests multiple times to verify consistency
- Check trigger logs in database
- Verify data insertion order and constraints

### Port Conflicts

**Issue**: Container won't start due to port already in use

**Solutions**:
```bash
# Check what's using the port
lsof -i :1521  # macOS/Linux
netstat -ano | findstr :1521  # Windows

# Or change ports in compose.yml:
ports:
  - "1524:1521"  # Custom external port
```

---

## Performance Considerations

### Query Optimization
- Distributed queries using database links may incur network latency
- Use `EXPLAIN PLAN` to analyze query performance
- Consider materialized views for frequent cross-site queries

### Data Volume Scaling
- Current schema supports ~1M+ rows per site
- Adjust `STORAGE` clauses in schema for larger datasets
- Monitor `user_segments` for tablespace usage

### Tuning Parameters
- Adjust `STATISTICS_LEVEL` in database initialization
- Monitor with `V$SESSION_LONGOPS` for slow queries

---

## Architecture Deep Dive

### How Synchronization Works

1. **Insert on Global Database**: New order line inserted
2. **Trigger Fired**: `SYC_INSERT_LIGNE` analyzes the data
3. **Fragmentation Check**: Trigger evaluates scenario rules
4. **Remote Insert**: If rules match, data pushed to Site1/Site2
5. **Automatic Commit**: Each remote operation commits independently

### Trigger Logic

Triggers implement:
- **Evaluation**: Check if record matches distribution criteria
- **Insert**: Push to remote site if criteria met
- **Update**: Handle record transitions between fragments
- **Delete**: Remove from remote site if record no longer matches

### Database Links

- **Secure**: Use database credentials to authenticate
- **Transparent**: Appear as local tables with `@link_name` syntax
- **Asynchronous**: Can be configured for deferred execution
- **Bidirectional**: Allow cross-site queries and updates

---

## Future Enhancements

- [ ] Implement merge replication for conflict resolution
- [ ] Add advanced security (encryption, TLS)
- [ ] Create materialized views for performance
- [ ] Add replication monitoring dashboard
- [ ] Implement automatic failover strategies
- [ ] Support for additional scenarios and business rules

---

## Contributing

To add new scenarios or features:

1. Create new trigger file: `03_triggers_scenario_X.sql`
2. Update `Dockerfile` to support new scenario
3. Add test cases to `test_all_sites.sql`
4. Update this README with scenario documentation

---

## License

This project is provided as-is for educational and demonstration purposes.

---

## Contact & Support

For questions or issues, please check:
- Logs: `docker compose logs`
- Database health: `docker compose ps`
- Configuration: `compose.yml`
- SQL Scripts: Individual `.sql` files

---

## Glossary

- **Database Link**: Oracle mechanism for transparent access to remote databases
- **Fragmentation**: Horizontal distribution of rows across multiple databases
- **Trigger**: Stored procedure automatically executed on table events
- **Global Database**: Central coordinator managing distribution logic
- **Site Database**: Remote database holding subset of data
- **Replication**: Automatic copying of data changes across systems
- **Scenario**: Different fragmentation and synchronization rule sets

