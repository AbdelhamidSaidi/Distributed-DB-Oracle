# Distributed Database Testing Tutorial

This guide provides step-by-step instructions to test your distributed database setup with three Oracle instances: `site1_db`, `site2_db`, and `global_db`.

## Prerequisites

- Docker Desktop running
- All three containers healthy (`site1_db`, `site2_db`, `global_db`)
- `sqlplus` installed on your machine or access via Docker containers

## Setup Overview

Your distributed database consists of:

| Database | Port | Purpose | Role |
|----------|------|---------|------|
| **site1_db** | 1522 | Local database at Site 1 | Participant |
| **site2_db** | 1523 | Local database at Site 2 | Participant |
| **global_db** | 1524 | Global coordinator database | Master |

**Credentials (all databases):**
- Username: `sys`
- Password: `oracle123`
- Service Name: `FREEPDB1`
- Role: `SYSDBA`

---

## Step 1: Verify Container Status

Check that all containers are running and healthy:

```bash
docker compose ps
```

**Expected output:**
```
NAME              STATUS
eshop_site1_db    Up X minutes (healthy)
eshop_site2_db    Up X minutes (healthy)
eshop_global_db   Up X minutes (healthy)
```

---

## Step 2: Connect to Each Database

### Option A: Connect via Docker (Recommended)

#### Connect to site1_db
```bash
docker exec eshop_site1_db sqlplus -s sys/oracle123@localhost:1521/FREEPDB1 as sysdba
```

#### Connect to site2_db
```bash
docker exec eshop_site2_db sqlplus -s sys/oracle123@localhost:1521/FREEPDB1 as sysdba
```

#### Connect to global_db
```bash
docker exec eshop_global_db sqlplus -s sys/oracle123@localhost:1521/FREEPDB1 as sysdba
```

### Option B: Connect from Host Machine

If sqlplus is installed on your machine:

```bash
# Site 1
sqlplus sys/oracle123@localhost:1522/FREEPDB1 as sysdba

# Site 2
sqlplus sys/oracle123@localhost:1523/FREEPDB1 as sysdba

# Global
sqlplus sys/oracle123@localhost:1524/FREEPDB1 as sysdba
```

---

## Step 3: Test Basic Connectivity

Once connected to any database, run:

```sql
SELECT NAME FROM V$DATABASE;
```

**Expected output:**
```
NAME
---------
FREE
```

Exit the session:
```sql
EXIT;
```

---

## Step 4: View Database Schema

Connect to each database and view the tables:

```sql
-- List all tables in the database
SELECT TABLE_NAME FROM DBA_TABLES WHERE OWNER='SYSTEM' OR OWNER='SYS';

-- Or view user tables
SELECT TABLE_NAME FROM USER_TABLES;
```

---

## Step 5: Test Local Data

### In site1_db

Check the local data in Site 1:

```sql
-- Connect to site1_db
docker exec eshop_site1_db sqlplus -s sys/oracle123@localhost:1521/FREEPDB1 as sysdba

-- Run this SQL:
SELECT * FROM CLIENTS LIMIT 10;
SELECT * FROM ORDERS LIMIT 10;
```

### In site2_db

Check the local data in Site 2:

```sql
-- Connect to site2_db
docker exec eshop_site2_db sqlplus -s sys/oracle123@localhost:1521/FREEPDB1 as sysdba

-- Run this SQL:
SELECT * FROM CLIENTS LIMIT 10;
SELECT * FROM ORDERS LIMIT 10;
```

---

## Step 6: Test Distributed Queries

### Query from global_db

The global database should have references (database links) to the other two sites. Test distributed queries:

```sql
-- Connect to global_db
docker exec eshop_global_db sqlplus -s sys/oracle123@localhost:1521/FREEPDB1 as sysdba

-- View all database links available
SELECT DB_LINK FROM DBA_DB_LINKS;

-- Query remote data from site1
SELECT * FROM CLIENTS@SITE1DB;

-- Query remote data from site2
SELECT * FROM CLIENTS@SITE2DB;

-- Join data from multiple sites
SELECT 
    c.IDCLIENT,
    c.NOMCLIENT,
    o.NUMCOMMANDE
FROM CLIENTS@SITE1DB c
JOIN ORDERS@SITE2DB o ON c.IDCLIENT = o.IDCLIENT;
```

---

## Step 7: Test Data Synchronization

### Check distributed triggers

If your setup uses triggers for replication:

```sql
-- Connect to site1_db or site2_db
docker exec eshop_site1_db sqlplus -s sys/oracle123@localhost:1521/FREEPDB1 as sysdba

-- List triggers
SELECT TRIGGER_NAME, TRIGGER_TYPE FROM DBA_TRIGGERS;

-- View trigger code
SELECT TRIGGER_NAME, TRIGGER_BODY FROM DBA_TRIGGERS WHERE TRIGGER_NAME LIKE '%REPL%';
```

### Insert data and verify replication

**On site1_db:**
```sql
INSERT INTO CLIENTS (IDCLIENT, NOMCLIENT) VALUES (999, 'Test Client 1');
COMMIT;
```

**On site2_db:**
```sql
-- Check if the data appears here (if replication is enabled)
SELECT * FROM CLIENTS WHERE IDCLIENT = 999;
```

---

## Step 8: Monitor Database Activity

### Check active sessions

```sql
-- Connect to any database
docker exec eshop_global_db sqlplus -s sys/oracle123@localhost:1521/FREEPDB1 as sysdba

-- View active sessions
SELECT SESS_ID, USERNAME, STATUS FROM V$SESSION WHERE USERNAME IS NOT NULL;

-- View current SQL being executed
SELECT SQL_TEXT FROM V$SQL WHERE EXECUTIONS > 0 ORDER BY LAST_LOAD_TIME DESC;
```

### Check database logs

```sql
-- View alert log entries
SELECT * FROM V$DIAG_ALERT_EXT ORDER BY ORIGINATING_TIMESTAMP DESC FETCH FIRST 20 ROWS ONLY;
```

---

## Step 9: Test Distributed Transactions

### Using global_db to perform distributed transactions

```sql
-- Connect to global_db
docker exec eshop_global_db sqlplus -s sys/oracle123@localhost:1521/FREEPDB1 as sysdba

-- Start a distributed transaction
BEGIN
  -- Insert on site1
  INSERT INTO CLIENTS@SITE1DB (IDCLIENT, NOMCLIENT) VALUES (1000, 'Dist Client 1');
  
  -- Insert on site2
  INSERT INTO CLIENTS@SITE2DB (IDCLIENT, NOMCLIENT) VALUES (1001, 'Dist Client 2');
  
  -- If everything succeeds, commit
  COMMIT;
  
  -- If there's an error, ROLLBACK
  -- ROLLBACK;
END;
/
```

---

## Step 10: Run Explain Plan Analysis

Analyze the execution plan of distributed queries:

```sql
-- Connect to global_db
docker exec eshop_global_db sqlplus -s sys/oracle123@localhost:1521/FREEPDB1 as sysdba

-- Enable explain plan
EXPLAIN PLAN FOR
SELECT 
    c.NOMCLIENT,
    COUNT(o.NUMCOMMANDE) as order_count
FROM CLIENTS@SITE1DB c
LEFT JOIN ORDERS@SITE2DB o ON c.IDCLIENT = o.IDCLIENT
GROUP BY c.NOMCLIENT;

-- View the plan
SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());
```

---

## Step 11: Test Failover Scenarios (Optional)

### Simulate site1_db going down

```bash
# Stop site1_db
docker stop eshop_site1_db

# Try to query from global_db - it should fail or timeout
docker exec eshop_global_db sqlplus -s sys/oracle123@localhost:1521/FREEPDB1 as sysdba
SELECT * FROM CLIENTS@SITE1DB;  -- This will fail

# Bring site1_db back online
docker start eshop_site1_db

# Wait for it to become healthy
docker compose ps  # Watch for "healthy" status
```

---

## Step 12: Cleanup and Disconnect

To disconnect from SQL*Plus:

```sql
EXIT;
```

To stop all containers:

```bash
docker compose down
```

To restart all containers:

```bash
docker compose up -d
```

---

## Common SQL Queries for Testing

### View all tables
```sql
SELECT TABLE_NAME FROM DBA_TABLES WHERE OWNER NOT IN ('SYS', 'SYSTEM', 'XDBADMIN');
```

### Count records in key tables
```sql
SELECT 'CLIENTS' as table_name, COUNT(*) as record_count FROM CLIENTS
UNION ALL
SELECT 'ORDERS' as table_name, COUNT(*) as record_count FROM ORDERS
UNION ALL
SELECT 'PRODUCTS' as table_name, COUNT(*) as record_count FROM PRODUCTS
UNION ALL
SELECT 'CATEGORIES' as table_name, COUNT(*) as record_count FROM CATEGORIES;
```

### View database links
```sql
SELECT DB_LINK, USERNAME, HOST FROM DBA_DB_LINKS;
```

### Test remote connectivity
```sql
SELECT * FROM DUAL@SITE1DB;
SELECT * FROM DUAL@SITE2DB;
```

---

## Troubleshooting

### ORA-12541: No listener
- **Cause:** Database not running or not accessible
- **Solution:** Check `docker compose ps` and wait for containers to become healthy

### ORA-01017: Invalid credentials
- **Cause:** Wrong password or database reset
- **Solution:** Reset password: `docker exec eshop_site1_db resetPassword oracle123`

### ORA-02019: Connection description for remote database not found
- **Cause:** Database link doesn't exist or is misconfigured
- **Solution:** Check `SELECT DB_LINK FROM DBA_DB_LINKS;`

### Distributed query fails
- **Cause:** Network or database link issue
- **Solution:** Test basic connectivity with `SELECT * FROM DUAL@SITE1DB;`

---

## Next Steps

1. **Explore the data model:** Look at the table structure using `DESCRIBE table_name;`
2. **Test specific scenarios:** Based on your BDD requirements
3. **Monitor performance:** Use `V$SQL` and explain plans
4. **Test edge cases:** Concurrent updates, distributed locks, deadlocks

---

## Additional Resources

- [Oracle Database Links Documentation](https://docs.oracle.com/en/database/)
- [Distributed Database Concepts](https://docs.oracle.com/en/database/)
- Container logs: `docker compose logs <service_name>`

