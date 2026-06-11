# Distributed Database - Current Status & Issue Analysis

**Date:** 2026-06-11  
**Status:** ⚠️ Partially Functional - Database Link Issue Identified

---

## Executive Summary

The distributed database system is **partially operational**:
- ✅ Containers are running and healthy
- ✅ Database schemas created
- ✅ Database links defined
- ✅ Triggers enabled
- ❌ **CRITICAL:** Database links fail for remote table operations
- ❌ **RESULT:** Trigger replication not working

---

## System Architecture

### Three-Database Setup

```
┌─────────────────────────────────────────────────────────────┐
│                   DISTRIBUTED E-SHOP DATABASE                 │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                      global_db (Master)                       │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Port:      1524 (host) → 1521 (internal)             │  │
│  │ User:      eshop / eshop123                          │  │
│  │ Database:  FREEPDB1                                  │  │
│  │ Schema:    ESHOP                                     │  │
│  │ Tables:    CLIENTS, COMMANDES, LIGNECOMMANDES        │  │
│  │            PRODUITS, CATEGORIES, EMPLOYES            │  │
│  │ Status:    ✅ HEALTHY                                │  │
│  │                                                       │  │
│  │ Database Links:                                       │  │
│  │  • site1_link → eshop_site1_db:1521 (user: site1)   │  │
│  │  • site2_link → eshop_site2_db:1521 (user: site2)   │  │
│  └────────────────────────────────────────────────────────┘  │
│          │                              │                     │
│          │ site1_link                   │ site2_link          │
│          ▼                              ▼                     │
└──────────────────────────────────────────────────────────────┘
    │                                          │
    │                                          │
    ▼                                          ▼
┌──────────────────┐                 ┌──────────────────┐
│   site1_db       │                 │   site2_db       │
├──────────────────┤                 ├──────────────────┤
│ Port: 1522       │                 │ Port: 1523       │
│ User: site1      │                 │ User: site2      │
│ Password:        │                 │ Password:        │
│  site1123        │                 │  site2123        │
│                  │                 │                  │
│ Schema: SITE1    │                 │ Schema: SITE2    │
│ Tables:          │                 │ Tables:          │
│  - CLIENTS1      │                 │  - CLIENTS2      │
│  - COMMANDES1    │                 │  - COMMANDES2    │
│  - LIGNE*1       │                 │  - LIGNE*2       │
│  - PRODUITS1     │                 │  - PRODUITS2     │
│  - etc.          │                 │  - etc.          │
│                  │                 │                  │
│ Status: ✅       │                 │ Status: ✅       │
│ HEALTHY          │                 │ HEALTHY          │
└──────────────────┘                 └──────────────────┘
```

### Network Topology

```
All containers connected via Docker network: eshop_net

Host Machine (Windows)
├── Port 1524 → eshop_global_db (internal 1521)
├── Port 1522 → eshop_site1_db (internal 1521)
└── Port 1523 → eshop_site2_db (internal 1521)

Docker Network (eshop_net)
├── eshop_global_db (hostname: eshop_global_db, port 1521)
├── eshop_site1_db (hostname: eshop_site1_db, port 1521)
└── eshop_site2_db (hostname: eshop_site2_db, port 1521)
```

---

## Current Data Status

### Global Database (eshop@global_db)

**Sample Data:**
```
CLIENTS:      5 records (CLI001-CLI005)
COMMANDES:   10 records
PRODUITS:     5 records
CATEGORIES:   4 records
```

**Recent Test Insert:**
```
INSERT INTO commandes VALUES (5000, 1, NULL, SYSDATE);
INSERT INTO lignecommandes VALUES (1001, 5000, 1, 150, 0);

Result: ✅ Successfully inserted into global_db
        ❌ NOT replicated to site1_db via trigger
```

### Site1 Database (site1@site1_db)

**Data Status:**
```
CLIENTS1:      4 records (includes parent records replicated during initialization)
               - 1 (CLI001)
               - 2 (CLI002)
               - 3 (CLI003)
               - 4 (CLI004)

COMMANDES1:    0 records (no orders replicated)
LIGNE*1:       0 records (no order lines replicated)
```

### Site2 Database (site2@site2_db)

**Data Status:**
```
CLIENTS2:      4 records (same as site1)
COMMANDES2:    0 records
LIGNE*2:       0 records
```

---

## Trigger System

### Trigger Architecture (Scenario 2: Horizontal Fragmentation)

**Fragmentation Strategy:**
- **Site1:** Order lines with `quantité >= 100` (large volumes)
- **Site2:** Order lines with `quantité < 100` (small volumes)

**Triggers Deployed:**

| Trigger Name | Table | Event | Status | Purpose |
|--------------|-------|-------|--------|---------|
| SYC_INSERT_LIGNE | LIGNECOMMANDES | INSERT | ENABLED | Route new order lines to appropriate site based on quantity |
| SYC_UPDATE_LIGNE | LIGNECOMMANDES | UPDATE | ENABLED | Handle order line updates with 2PC |
| SYC_DELETE_LIGNE | LIGNECOMMANDES | DELETE | ENABLED | Handle order line deletions with 2PC |

**Trigger Logic (SYC_INSERT_LIGNE):**

```
When a line item is inserted with quantity:
  IF quantité >= 100 THEN
    → Replicate to site1_db
    → Create parent records if missing (client, product, order, etc.)
    → Insert line item on site1
  ELSE (quantité < 100) THEN
    → Replicate to site2_db
    → Create parent records if missing
    → Insert line item on site2
  END IF
  
  Transaction: Use 2PC (Two-Phase Commit) for atomicity
```

---

## Critical Issues Identified

### Issue #1: Database Link Connection Failure

**Problem Description:**

Database links work for **simple queries** (SELECT * FROM DUAL@site1_link) but **fail for table operations** (INSERT, SELECT from actual tables).

**Error Message:**
```
ORA-02019: connection description for remote database not found
```

**Affected Operations:**
- Remote INSERT operations
- Remote SELECT from tables
- Remote UPDATE/DELETE operations

**Working Operations:**
- SELECT * FROM dual@site1_link ✅
- Database link existence queries ✅

**Root Cause:**

The database link definition exists but the **connection descriptor is not being resolved properly** for actual table operations. This is likely due to:

1. **TNS naming issue** - The descriptor string may not be parsed correctly
2. **Credentials problem** - The remote user/password may not match
3. **Connection string malformation** - The HOST/PORT/SERVICE_NAME parameters are incorrect
4. **Network routing** - The hostname `eshop_site1_db` may not resolve in the Oracle connection manager

### Issue #2: Trigger Replication Failure

**Problem Description:**

Triggers are enabled and executing, but **order data is not being replicated** to remote sites.

**Evidence:**
```
Test Case:
├── Insert order (5000) into global_db ✅ SUCCESS
├── Insert order line (1001, qty=150) into global_db ✅ SUCCESS
├── Trigger should fire and replicate to site1_db ❓ SHOULD HAPPEN
├── Check site1_db:
│   ├── COMMANDES1 (5000) ❌ NOT FOUND
│   ├── LIGNECOMMANDES1 (1001) ❌ NOT FOUND
│   └── Expected: Should exist for qty >= 100
└── Result: Trigger executed but replication failed
```

**Root Cause:**

The trigger is failing at the **remote INSERT step** because the database link is not functional for actual insert operations. When the trigger tries to execute:

```sql
INSERT INTO Commandes1@site1_link(...)
```

It gets error ORA-02019 and the entire transaction fails. The trigger appears successful from the user's perspective (no error thrown to the session), but the remote operations never complete.

---

## Test Results Summary

### ✅ What's Working

| Component | Test | Result | Details |
|-----------|------|--------|---------|
| **Containers** | Health check | ✅ PASS | All 3 containers healthy |
| **Local Schema** | Create tables | ✅ PASS | ESHOP schema created with 6 tables |
| **Data Insertion** | Local INSERT | ✅ PASS | Can insert into global_db |
| **Database Links** | Exist | ✅ PASS | site1_link and site2_link defined |
| **DB Link Test** | DUAL query | ✅ PASS | SELECT * FROM dual@site1_link works |
| **Triggers** | Status | ✅ PASS | All triggers ENABLED |
| **Triggers** | Compilation | ✅ PASS | No trigger errors in user_errors |

### ❌ What's NOT Working

| Component | Test | Result | Details |
|-----------|------|--------|---------|
| **DB Link** | Remote INSERT | ❌ FAIL | ORA-02019: connection not found |
| **DB Link** | Remote SELECT | ❌ FAIL | ORA-02019: connection not found |
| **Trigger** | Replication | ❌ FAIL | Data not replicated to site1/site2 |
| **Fragmentation** | Routing | ❌ FAIL | No order lines on remote sites |
| **2PC** | Distributed TX | ❌ FAIL | Remote inserts fail |

---

## Database Link Definition

### Current Configuration

**Site1 Link:**
```sql
CREATE DATABASE LINK site1_link
    CONNECT TO site1 IDENTIFIED BY site1123
    USING '(DESCRIPTION=
        (ADDRESS=(PROTOCOL=TCP)
                 (HOST=eshop_site1_db)
                 (PORT=1521))
        (CONNECT_DATA=
            (SERVICE_NAME=FREEPDB1)))';
```

**Site2 Link:**
```sql
CREATE DATABASE LINK site2_link
    CONNECT TO site2 IDENTIFIED BY site2123
    USING '(DESCRIPTION=
        (ADDRESS=(PROTOCOL=TCP)
                 (HOST=eshop_site2_db)
                 (PORT=1521))
        (CONNECT_DATA=
            (SERVICE_NAME=FREEPDB1)))';
```

### Potential Issues

1. **Hostname Resolution:** `eshop_site1_db` must resolve to the Docker container IP
2. **Port:** Internal port 1521 is correct for container-to-container communication
3. **Service Name:** FREEPDB1 is correct
4. **Credentials:** site1/site1123 and site2/site2123 must exist and match
5. **Network:** Containers must be on the same Docker network (eshop_net) ✅

---

## Reproduction Steps

### Test Case: Order Line Replication Failure

**Prerequisites:**
- All 3 containers running and healthy
- Connected as eshop@global_db

**Steps:**

```sql
-- Step 1: Insert an order
INSERT INTO commandes (idcommande, idclient, datecommande)
VALUES (5000, 1, SYSDATE);
COMMIT;

-- Step 2: Insert a large volume order line (should go to site1)
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (1001, 5000, 1, 150, 0);
COMMIT;

-- Step 3: Verify data in global_db
SELECT * FROM commandes WHERE idcommande = 5000;     -- Should exist ✅
SELECT * FROM lignecommandes WHERE idlignecommande = 1001;  -- Should exist ✅

-- Step 4: Check if replicated to site1_db
-- (Switch to site1@site1_db)
SELECT * FROM commandes1 WHERE idcommande = 5000;    -- Should exist but DOESN'T ❌
SELECT * FROM lignecommandes1 WHERE idlignecommande = 1001;  -- Should exist but DOESN'T ❌
```

**Expected vs Actual:**

| Step | Expected | Actual | Status |
|------|----------|--------|--------|
| 1 | Order inserted in global | Order inserted | ✅ |
| 2 | Trigger fires, replicates | Trigger fires but fails | ❌ |
| 3 | Data exists in global | Data exists | ✅ |
| 4 | Data exists in site1 | Data NOT found | ❌ FAILURE |

---

## Error Analysis

### ORA-02019: Connection Description Not Found

**Oracle Documentation:**
> "The connection description for the database link could not be found in the TNSNAMES.ORA file or the database link does not have a valid connection descriptor."

**In Our Context:**

The error occurs **during** the remote operation, not during link creation. This suggests:

1. Link **definition** is valid (it was created successfully)
2. Link **resolution** fails when trying to execute remote DML
3. The **connection descriptor string** may have formatting issues or unsupported parameters

**Possible Causes:**

```
1. Hostname Resolution Problem
   - eshop_site1_db may not resolve in the Oracle Net Services
   - Solution: Use IP address instead or configure DNS/hosts

2. Connection String Format Issue
   - The parentheses or parameters may be malformed
   - Oracle parser fails on actual connection attempt

3. Service Name Not Available
   - FREEPDB1 may not be registered/available on the remote database
   - Need to verify the actual service name

4. Credentials Mismatch
   - site1 user may not exist or password wrong
   - user doesn't have proper privileges for remote operations

5. Network Isolation
   - Global_db can't reach site1_db for actual operations
   - But can reach for simple queries (DUAL doesn't require schema access)
```

---

## Next Steps to Fix

### Step 1: Verify Remote Database Connectivity

**From global_db container:**
```bash
docker exec eshop_global_db bash -c "
  sqlplus -v
  tnsping eshop_site1_db
"
```

**Expected:** Version info + connection success message

### Step 2: Test Remote User Access

```sql
-- Try to log in directly as the remote user
-- (This tests if site1 user exists and password is correct)

SELECT * FROM v\$database@site1_link;
```

If this works, link is fine. If not, credentials are wrong.

### Step 3: Recreate Database Links with IP Address

```sql
-- Drop old links
DROP DATABASE LINK site1_link;
DROP DATABASE LINK site2_link;

-- Recreate with localhost instead of hostname
CREATE DATABASE LINK site1_link
    CONNECT TO site1 IDENTIFIED BY site1123
    USING '(DESCRIPTION=
        (ADDRESS=(PROTOCOL=TCP)
                 (HOST=127.0.0.1)
                 (PORT=1522))
        (CONNECT_DATA=
            (SERVICE_NAME=FREEPDB1)))';

CREATE DATABASE LINK site2_link
    CONNECT TO site2 IDENTIFIED BY site2123
    USING '(DESCRIPTION=
        (ADDRESS=(PROTOCOL=TCP)
                 (HOST=127.0.0.1)
                 (PORT=1523))
        (CONNECT_DATA=
            (SERVICE_NAME=FREEPDB1)))';
```

**Note:** Using host machine ports (1522, 1523) because we're connecting FROM global_db container to other containers through the host network.

### Step 4: Test the New Links

```sql
SELECT * FROM site1.clients1@site1_link;
SELECT * FROM site2.clients2@site2_link;
```

### Step 5: Re-test Trigger Replication

Once links work:

```sql
-- Insert new test data
INSERT INTO commandes (idcommande, idclient, datecommande)
VALUES (6000, 2, SYSDATE);

INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (2001, 6000, 2, 200, 0);

COMMIT;

-- Verify on site1
SELECT * FROM site1.lignecommandes1@site1_link WHERE idcommande = 6000;
```

---

## Timeline

| Date | Event | Status |
|------|-------|--------|
| 2026-06-11 08:00 | Containers built and started | ✅ Complete |
| 2026-06-11 08:30 | Database initialization complete | ✅ Complete |
| 2026-06-11 09:00 | Schema creation verified | ✅ Complete |
| 2026-06-11 09:30 | Database links created | ✅ Complete |
| 2026-06-11 10:00 | Triggers deployed | ✅ Complete |
| 2026-06-11 10:30 | Initial data inserted (global_db) | ✅ Complete |
| 2026-06-11 11:00 | **ISSUE DISCOVERED:** DB link fails for table operations | ❌ CRITICAL |
| 2026-06-11 11:30 | Root cause identified: connection descriptor issue | 🔍 IN PROGRESS |

---

## Summary

The distributed database infrastructure is **built and running**, but the **replication mechanism is broken** due to database link connectivity issues.

**Current State:**
- ✅ All 3 Oracle databases running
- ✅ Schemas and tables created
- ✅ Triggers deployed and enabled
- ❌ Database links non-functional for DML operations
- ❌ Trigger replication not working

**Blocking Issue:**
Database links return ORA-02019 when attempting remote table operations. This prevents:
- Trigger replication
- Distributed queries
- 2PC (Two-Phase Commit) transactions

**Resolution:**
Requires debugging and fixing the database link configuration, likely by:
1. Verifying network connectivity
2. Using correct host/port configuration
3. Testing remote user credentials
4. Potentially switching to IP-based connections

---

## References

- **Trigger Script:** `/global_db/init/03_triggers_scenario2.sql`
- **Database Link Script:** `/global_db/init/02_db_links.sql`
- **Docker Compose:** `/compose.yml`
- **Testing Guide:** `/TESTING_UPDATES_AND_TRIGGERS.md`
- **Tutorial:** `/TUTORIAL.md`

