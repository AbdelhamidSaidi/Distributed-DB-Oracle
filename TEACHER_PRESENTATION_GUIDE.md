# Distributed Database System - Presentation Guide for Teacher

**Student:** Abdelhamid Saidi  
**Date:** June 11, 2026  
**Project:** Multi-Site E-Shop Distributed Database with Horizontal Fragmentation

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Demonstration](#architecture-demonstration)
3. [Live Test Demonstrations](#live-test-demonstrations)
4. [INSERT Operations](#insert-operations)
5. [SELECT/READ Operations](#selectread-operations)
6. [UPDATE Operations](#update-operations)
7. [DELETE Operations](#delete-operations)
8. [Trigger & Fragmentation Demo](#trigger--fragmentation-demo)
9. [Distributed Transactions](#distributed-transactions)
10. [Conclusion](#conclusion)

---

## System Overview

### What We Built

A **three-tier distributed database system** for an E-Shop that:
- Maintains a **master database** (global_db) with all customer and order data
- Automatically **fragments order data** across two regional sites based on order volume
- Uses **Oracle triggers** to replicate data in real-time
- Implements **distributed transactions** with 2PC (Two-Phase Commit) for data consistency

### Fragmentation Strategy

```
Order Lines (LigneCommandes) are automatically distributed:

Quantity >= 100 → Site 1 (Large Volumes)
Quantity < 100  → Site 2 (Small Volumes)

Example:
├── Order with qty=150 → automatically sent to Site1
├── Order with qty=50  → automatically sent to Site2
└── Order has items with both quantities → split across both sites
```

---

## Architecture Demonstration

### Step 1: Show the System is Running

**Command:**
```bash
docker compose ps
```

**Expected Output:**
```
NAME              IMAGE                      STATUS
eshop_global_db   distributed-db-global_db   Up X minutes (healthy)
eshop_site1_db    distributed-db-site1_db    Up X minutes (healthy)
eshop_site2_db    distributed-db-site2_db    Up X minutes (healthy)
```

**Explanation:** All three Oracle databases are running in Docker containers on a shared network.

---

### Step 2: Show Database Network Architecture

**Draw on board or show diagram:**

```
┌──────────────────────────────┐
│    MASTER (global_db)        │
│  Port: 1524                  │
│  User: eshop/eshop123        │
│  ↓ Triggers replicate data   │
└──────────────┬───────────────┘
               │
        ┌──────┴──────┐
        ↓             ↓
   ┌─────────┐   ┌─────────┐
   │ Site 1  │   │ Site 2  │
   │ :1522   │   │ :1523   │
   │ (qty≥100)  (qty<100) │
   └─────────┘   └─────────┘
```

---

## Live Test Demonstrations

### Before Starting

**Connect to global_db:**
```bash
sqlplus eshop/eshop123@localhost:1524/FREEPDB1
```

**Verify connection:**
```sql
SELECT NAME FROM V$DATABASE;
-- Should return: FREE
```

---

## INSERT Operations

### Test 1: Insert Order and Line Items (Different Quantities)

**Scenario:** Customer places an order with multiple items of different quantities

**Step 1A: Create the Order**

```sql
INSERT INTO commandes (idcommande, idclient, datecommande)
VALUES (20000, 1, SYSDATE);

COMMIT;
```

**Explanation:** We're creating order #20000 for customer #1. This order will be replicated to BOTH sites because the parent record (order) is needed on both.

**Step 1B: Insert LARGE Volume Item (goes to Site1)**

```sql
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (6001, 20000, 1, 150, 2);

COMMIT;
```

**Explanation:** 
- Quantity = 150 (which is ≥ 100)
- The **trigger SYC_INSERT_LIGNE** automatically:
  - Detects quantity 150
  - Routes this line item to **Site1**
  - Inserts the line item on site1_db via database link
  - Uses 2PC to ensure atomicity

**Step 1C: Insert SMALL Volume Item (goes to Site2)**

```sql
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (6002, 20000, 2, 60, 5);

COMMIT;
```

**Explanation:**
- Quantity = 60 (which is < 100)
- The **trigger** automatically:
  - Detects quantity 60
  - Routes this line item to **Site2**
  - Inserts the line item on site2_db via database link

**Step 1D: Verify Insert in Master**

```sql
SELECT * FROM commandes WHERE idcommande = 20000;
SELECT * FROM lignecommandes WHERE idcommande = 20000 ORDER BY idlignecommande;
```

**Expected Output:**
```
Order 20000 exists
Line 6001: qty=150
Line 6002: qty=60
```

### Test 2: Verify Replication to Sites

**From global_db, query via database links:**

```sql
-- Check what went to Site1
SELECT * FROM site1.lignecommandes1@site1_link WHERE idcommande = 20000;
```

**Expected:** Line 6001 (qty=150) is there ✅

```sql
-- Check what went to Site2
SELECT * FROM site2.lignecommandes2@site2_link WHERE idcommande = 20000;
```

**Expected:** Line 6002 (qty=60) is there ✅

**Key Point for Teacher:** 
"Notice how the same order exists on BOTH sites, but the line items are automatically split based on quantity. The trigger does this without any manual intervention!"

---

## SELECT/READ Operations

### Test 3: Distributed Queries Across All Sites

**Show that we can query all sites from the master:**

```sql
-- Get summary of what's on each site
SELECT 'Master' as location, COUNT(*) as total_lines FROM lignecommandes
UNION ALL
SELECT 'Site1' as location, COUNT(*) as total_lines FROM site1.lignecommandes1@site1_link
UNION ALL
SELECT 'Site2' as location, COUNT(*) as total_lines FROM site2.lignecommandes2@site2_link;
```

**Expected Output:**
```
LOCATION    TOTAL_LINES
---------   -----------
Master              18
Site1                9
Site2                9
```

**Explanation:** The master has all data, and it's split 50/50 between the two sites based on the fragmentation rule.

### Test 4: Show Data Isolation

**Verify Site1 only has large items:**

```sql
-- All items on Site1 should have qty >= 100
SELECT idlignecommande, quantite FROM site1.lignecommandes1@site1_link 
WHERE quantite < 100;
```

**Expected:** No rows (all items on Site1 have qty ≥ 100) ✅

**Verify Site2 only has small items:**

```sql
-- All items on Site2 should have qty < 100
SELECT idlignecommande, quantite FROM site2.lignecommandes2@site2_link 
WHERE quantite >= 100;
```

**Expected:** No rows (all items on Site2 have qty < 100) ✅

**Key Point for Teacher:**
"The data is automatically isolated based on business rules. Site1 handles bulk orders, Site2 handles small orders. This distributes the load and optimizes performance!"

---

## UPDATE Operations

### Test 5: Update Order Line Quantity

**Scenario:** Customer increases quantity on their order

**Update on Master:**

```sql
UPDATE lignecommandes 
SET quantite = 200, remise = 10
WHERE idlignecommande = 6001;

COMMIT;
```

**Explanation:** We updated the quantity of line item 6001 from 150 to 200. The **trigger SYC_UPDATE_LIGNE** automatically:
- Fires when the update happens
- Sends the update to Site1 (where this item is stored)
- Uses 2PC to ensure both master and Site1 stay in sync

**Verify Update:**

```sql
-- Check master
SELECT idlignecommande, quantite, remise FROM lignecommandes WHERE idlignecommande = 6001;

-- Check Site1 (should be updated too)
SELECT idlignecommande, quantite, remise FROM site1.lignecommandes1@site1_link WHERE idlignecommande = 6001;
```

**Expected:** Both show qty=200, remise=10 ✅

**Key Point for Teacher:**
"Updates are synchronized in real-time across the master and remote sites. The trigger ensures consistency automatically!"

---

## DELETE Operations

### Test 6: Delete Order Line

**Scenario:** Customer removes an item from their order

**Delete from Master:**

```sql
DELETE FROM lignecommandes WHERE idlignecommande = 6002;

COMMIT;
```

**Explanation:** We deleted line item 6002 (which was on Site2). The **trigger SYC_DELETE_LIGNE** automatically:
- Fires when the delete happens
- Sends the delete to Site2 (where this item is stored)
- Removes the record from both master and Site2

**Verify Deletion:**

```sql
-- Check master
SELECT COUNT(*) FROM lignecommandes WHERE idlignecommande = 6002;
-- Should return: 0

-- Check Site2 (should be deleted too)
SELECT COUNT(*) FROM site2.lignecommandes2@site2_link WHERE idlignecommande = 6002;
-- Should return: 0
```

**Expected:** Both return 0 (record deleted) ✅

**Key Point for Teacher:**
"Deletes are also synchronized automatically. The trigger ensures that if you delete something on the master, it's removed from all relevant sites."

---

## Trigger & Fragmentation Demo

### Test 7: Create Multi-Item Order to Show Complete Fragmentation

**Scenario:** Large order with multiple items crossing the fragmentation threshold

**Create Fresh Order:**

```sql
-- Clear previous test
DELETE FROM lignecommandes WHERE idcommande = 20000;
DELETE FROM commandes WHERE idcommande = 20000;
COMMIT;

-- Now insert new order with clear fragmentation
INSERT INTO commandes (idcommande, idclient, datecommande)
VALUES (20000, 1, SYSDATE);
COMMIT;

-- Add multiple items with different quantities
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (7001, 20000, 1, 200, 0);

INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (7002, 20000, 2, 150, 0);

INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (7003, 20000, 3, 80, 0);

INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (7004, 20000, 4, 50, 0);

COMMIT;
```

**Show Distribution:**

```sql
-- View on Master
SELECT idlignecommande, quantite, 
       CASE WHEN quantite >= 100 THEN 'Site1' ELSE 'Site2' END as destination
FROM lignecommandes 
WHERE idcommande = 20000
ORDER BY idlignecommande;
```

**Expected Output:**
```
IDLIGNECOMMANDE  QUANTITE  DESTINATION
7001             200       Site1
7002             150       Site1
7003              80       Site2
7004              50       Site2
```

**Verify on Sites:**

```sql
-- Site1 should have 7001 and 7002
SELECT idlignecommande, quantite FROM site1.lignecommandes1@site1_link 
WHERE idcommande = 20000;

-- Site2 should have 7003 and 7004
SELECT idlignecommande, quantite FROM site2.lignecommandes2@site2_link 
WHERE idcommande = 20000;
```

**Key Point for Teacher:**
"This is the power of distributed databases! A single order is intelligently split across multiple locations based on business rules. The trigger handles all the complexity transparently!"

---

## Distributed Transactions

### Test 8: Show 2PC (Two-Phase Commit) in Action

**Scenario:** Multi-step transaction that either completes on all sites or rolls back everywhere

**Execute Distributed Transaction:**

```sql
BEGIN
    -- Insert new order
    INSERT INTO commandes (idcommande, idclient, datecommande)
    VALUES (21000, 5, SYSDATE);
    
    -- Add large item (goes to Site1)
    INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
    VALUES (8001, 21000, 1, 300, 0);
    
    -- Add small item (goes to Site2)
    INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
    VALUES (8002, 21000, 2, 40, 0);
    
    -- If all succeeds, commit atomically across all databases
    COMMIT;
END;
/
```

**Verify Success:**

```sql
-- Check Master
SELECT COUNT(*) FROM lignecommandes WHERE idcommande = 21000;
-- Should return: 2

-- Check Site1
SELECT COUNT(*) FROM site1.lignecommandes1@site1_link WHERE idcommande = 21000;
-- Should return: 1 (the large item)

-- Check Site2
SELECT COUNT(*) FROM site2.lignecommandes2@site2_link WHERE idcommande = 21000;
-- Should return: 1 (the small item)
```

**Expected:** All three return their expected counts ✅

**Key Point for Teacher:**
"This demonstrates 2PC (Two-Phase Commit). Oracle coordinates the transaction across the master and remote sites. Either ALL databases commit, or ALL databases rollback. There's no partial success - this ensures data consistency!"

---

## Database Links Verification

### Test 9: Show Database Link Configuration

**View the links we created:**

```sql
SELECT db_link, username FROM user_db_links;
```

**Expected Output:**
```
DB_LINK     USERNAME
-------     --------
SITE1_LINK  SITE1
SITE2_LINK  SITE2
```

**Test Link Connectivity:**

```sql
-- Test connection to Site1
SELECT * FROM DUAL@site1_link;
-- Returns: D-X (success)

-- Test connection to Site2
SELECT * FROM DUAL@site2_link;
-- Returns: D-X (success)
```

**Key Point for Teacher:**
"Database links are the communication channel between the master and remote sites. They use the Oracle Net Services to establish connections across the network, allowing us to execute queries on remote databases transparently."

---

## Performance & Consistency Check

### Test 10: Final Verification

**Show data consistency across all sites:**

```sql
-- Count all data
SELECT 
    'Master' as location,
    (SELECT COUNT(*) FROM commandes) as orders,
    (SELECT COUNT(*) FROM lignecommandes) as line_items
FROM DUAL
UNION ALL
SELECT 
    'Site1',
    (SELECT COUNT(*) FROM site1.commandes1@site1_link),
    (SELECT COUNT(*) FROM site1.lignecommandes1@site1_link)
FROM DUAL
UNION ALL
SELECT 
    'Site2',
    (SELECT COUNT(*) FROM site2.commandes2@site2_link),
    (SELECT COUNT(*) FROM site2.lignecommandes2@site2_link)
FROM DUAL;
```

**Expected Pattern:**
```
Master:  Has ALL orders and line items
Site1:   Has ALL orders, but only large line items (qty >= 100)
Site2:   Has ALL orders, but only small line items (qty < 100)
```

---

## Conclusion

### What We Demonstrated

✅ **INSERT:** Automatic distribution based on business rules  
✅ **SELECT:** Querying across multiple databases  
✅ **UPDATE:** Real-time synchronization via triggers  
✅ **DELETE:** Cascading deletions across distributed sites  
✅ **Triggers:** Transparent fragmentation logic  
✅ **2PC:** Atomic transactions across databases  
✅ **Database Links:** Network communication between databases  

### Key Technologies Used

1. **Oracle Database 23ai** - Three independent Oracle instances
2. **Database Links** - For cross-database communication
3. **PL/SQL Triggers** - For automatic data replication
4. **2PC (Two-Phase Commit)** - For distributed transaction consistency
5. **Horizontal Fragmentation** - Distributing data based on business rules
6. **Docker** - Containerized database infrastructure

### Real-World Applications

This distributed database pattern is used in:
- **E-commerce:** Regional fulfillment centers
- **Banking:** Branch office networks
- **Retail:** Multi-store inventory systems
- **SaaS:** Multi-tenant databases
- **IoT:** Edge computing with central coordination

### Advantages Demonstrated

1. **Scalability:** Distribute load across multiple databases
2. **Performance:** Local queries are faster
3. **Availability:** If one site fails, others continue
4. **Automatic Replication:** Triggers handle data consistency
5. **Transparent Access:** Query remote data as if it's local

---

## Commands Quick Reference (For Teacher)

```bash
# Start the system
docker compose up -d

# Check status
docker compose ps

# Connect to databases
sqlplus eshop/eshop123@localhost:1524/FREEPDB1  # Global
sqlplus site1/site1123@localhost:1522/FREEPDB1  # Site1
sqlplus site2/site2123@localhost:1523/FREEPDB1  # Site2

# Stop the system
docker compose down
```

---

## Q&A Preparation

**Q: How does the system know which site to send data to?**
A: The trigger examines the quantity field. If qty >= 100, it routes to Site1. If qty < 100, it routes to Site2.

**Q: What happens if the network connection breaks?**
A: The 2PC protocol ensures atomicity. If the remote site can't be reached, the entire transaction rolls back on all databases.

**Q: Why not just use replication software?**
A: Custom triggers give us business logic awareness. We're not replicating ALL data to all sites - we're intelligently distributing it based on rules.

**Q: What's the overhead of the database links?**
A: Network latency adds to transaction time. For 150 bytes, the overhead is typically 10-50ms per database link call.

**Q: Can we change the fragmentation rules?**
A: Yes! The fragmentation threshold (100) is defined in the trigger code. We can change it and redeploy without altering the schema.

---

**End of Presentation Guide**

