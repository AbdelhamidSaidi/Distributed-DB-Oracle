# Testing Updates and Triggers in Distributed Database

This guide explains how to test updates and triggers across your distributed database system (global_db, site1_db, site2_db).

## Understanding Your Trigger Setup

Your distributed database has **two replication scenarios**:

- **Scenario 1:** Master-Slave replication (one-way from global to sites)
- **Scenario 2:** **Horizontal Fragmentation by Volume** (currently active)

**Scenario 2 - Horizontal Fragmentation Strategy:**

```
Order Line Items (LigneCommandes) are distributed based on quantity:

┌─────────────────────────────────┐
│   global_db (Master)            │
│   All orders and line items     │
└────────┬────────────────────────┘
         │
    ┌────┴─────┐
    │           │
    ▼           ▼
┌─────────┐   ┌─────────┐
│ Site 1  │   │ Site 2  │
├─────────┤   ├─────────┤
│ QUANTITÉ│   │ QUANTITÉ│
│  >= 100 │   │  < 100  │
│(Large)  │   │ (Small) │
└─────────┘   └─────────┘

Triggers automatically route orders:
- Large volume items → Site1
- Small volume items → Site2
- Parent records (Clients, Products, etc.) are created on-demand
```

**Triggers Created:**
1. `SYC_INSERT_LIGNE` - Routes new order lines based on quantity
2. `SYC_UPDATE_LIGNE` - Manages updates to order lines
3. `SYC_DELETE_LIGNE` - Handles deletions

Currently, **Scenario 2** is active (see compose.yml: `SCENARIO=2`).

---

## Prerequisites

Connect to each database:

```bash
# Global DB (port 1524)
sqlplus eshop/eshop123@localhost:1524/FREEPDB1

# Site 1 (port 1522)
sqlplus site1/site1123@localhost:1522/FREEPDB1

# Site 2 (port 1523)
sqlplus site2/site2123@localhost:1523/FREEPDB1
```

---

## Test 1: View Available Triggers

### Check triggers on LIGNECOMMANDES

**In global_db (as eshop):**
```sql
SELECT trigger_name, table_name, triggering_event, trigger_type, status
FROM user_triggers 
WHERE table_name = 'LIGNECOMMANDES'
ORDER BY trigger_name;
```

**Expected output:**
```
TRIGGER_NAME        TABLE_NAME       TRIGGERING_EVENT  TRIGGER_TYPE  STATUS
-----------------   ---------------  ----------------  -----------   -------
SYC_DELETE_LIGNE    LIGNECOMMANDES   DELETE            AFTER         ENABLED
SYC_INSERT_LIGNE    LIGNECOMMANDES   INSERT            AFTER         ENABLED
SYC_UPDATE_LIGNE    LIGNECOMMANDES   UPDATE            AFTER         ENABLED
```

### View trigger code

**View the INSERT trigger:**
```sql
SELECT trigger_body FROM user_triggers WHERE trigger_name = 'SYC_INSERT_LIGNE';
```

This trigger automatically:
1. Routes order lines to Site1 if quantity >= 100
2. Routes order lines to Site2 if quantity < 100
3. Creates parent records (Client, Product, Category, Employee, Order) on remote site if they don't exist
4. Uses distributed transactions to ensure atomicity

---

## Test 2: Insert Large Volume Order Line (Quantité >= 100) → Site1

### Step 1: Insert order and line item with LARGE quantity in global_db

**In global_db (eshop):**
```sql
-- First, insert an order for client 1
INSERT INTO commandes (idcommande, idclient, datecommande)
VALUES (5000, 1, SYSDATE);
COMMIT;

-- Now insert a line item with quantity >= 100 (should go to Site1)
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (1001, 5000, 1, 150, 0);  -- 150 >= 100, so goes to Site1

COMMIT;
```

### Step 2: Verify order and line item in global_db

```sql
SELECT * FROM commandes WHERE idcommande = 5000;
SELECT * FROM lignecommandes WHERE idcommande = 5000;
```

### Step 3: Check if order line was replicated to Site1

**In site1_db (site1):**
```sql
-- The trigger should have created all parent records and the line item
SELECT * FROM lignecommandes1 WHERE idcommande = 5000;
SELECT * FROM commandes1 WHERE idcommande = 5000;
SELECT * FROM clients1 WHERE idclient = 1;
```

**Expected:** Records appear on Site1 (because quantity 150 >= 100)

### Step 4: Verify NOT in Site2

**In site2_db (site2):**
```sql
SELECT * FROM lignecommandes2 WHERE idcommande = 5000;
-- Should return NO ROWS (because quantity >= 100 goes to Site1, not Site2)
```

**Expected:** No records on Site2

---

## Test 3: Insert Small Volume Order Line (Quantité < 100) → Site2

### Step 1: Insert order and line item with SMALL quantity in global_db

**In global_db (eshop):**
```sql
-- Insert another order
INSERT INTO commandes (idcommande, idclient, datecommande)
VALUES (5001, 2, SYSDATE);
COMMIT;

-- Insert a line item with quantity < 100 (should go to Site2)
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (1002, 5001, 2, 50, 5);  -- 50 < 100, so goes to Site2

COMMIT;
```

### Step 2: Verify order and line item in global_db

```sql
SELECT * FROM commandes WHERE idcommande = 5001;
SELECT * FROM lignecommandes WHERE idcommande = 5001;
```

### Step 3: Check if order line was replicated to Site2

**In site2_db (site2):**
```sql
-- The trigger should have created all parent records and the line item
SELECT * FROM lignecommandes2 WHERE idcommande = 5001;
SELECT * FROM commandes2 WHERE idcommande = 5001;
SELECT * FROM clients2 WHERE idclient = 2;
```

**Expected:** Records appear on Site2 (because quantity 50 < 100)

### Step 4: Verify NOT in Site1

**In site1_db (site1):**
```sql
SELECT * FROM lignecommandes1 WHERE idcommande = 5001;
-- Should return NO ROWS (because quantity < 100 goes to Site2, not Site1)
```

**Expected:** No records on Site1

---

## Test 4: Update Order Line (Test SYC_UPDATE_LIGNE trigger)

### Step 1: Update an order line quantity in global_db

**In global_db (eshop):**
```sql
-- Update the large volume order line we created
UPDATE lignecommandes 
SET quantite = 200, remise = 10
WHERE idlignecommande = 1001;

COMMIT;
```

### Step 2: Verify update in global_db

```sql
SELECT * FROM lignecommandes WHERE idlignecommande = 1001;
-- Should show: quantite=200, remise=10
```

### Step 3: Check if update replicated to Site1

**In site1_db (site1):**
```sql
SELECT * FROM lignecommandes1 WHERE idlignecommande = 1001;
-- Should show updated: quantite=200, remise=10
```

**Expected:** Update appears on Site1 (where the record was replicated)

## Test 5: Delete Order Line (Test SYC_DELETE_LIGNE trigger)

### Step 1: Delete an order line from global_db

**In global_db (eshop):**
```sql
DELETE FROM lignecommandes WHERE idlignecommande = 1001;

COMMIT;
```

### Step 2: Verify deletion in global_db

```sql
SELECT COUNT(*) FROM lignecommandes WHERE idlignecommande = 1001;
-- Should return: 0
```

### Step 3: Check if deletion replicated to Site1

**In site1_db (site1):**
```sql
SELECT COUNT(*) FROM lignecommandes1 WHERE idlignecommande = 1001;
-- Should return: 0 (if trigger working correctly)
```

**Expected:** Deletion appears on Site1 (distributed transaction)

---

## Test 6: Fragmentation Verification - View Data Distribution

### Check data distribution across all databases

**In global_db (eshop):**
```sql
-- All order lines in global (master)
SELECT COUNT(*) as total_global FROM lignecommandes;

-- View all order lines with their quantities
SELECT idlignecommande, idcommande, idproduit, quantite 
FROM lignecommandes
ORDER BY idlignecommande;
```

**In site1_db (site1):**
```sql
-- Order lines with quantity >= 100
SELECT COUNT(*) as site1_total FROM lignecommandes1;

-- Verify all have quantity >= 100
SELECT idlignecommande, idcommande, quantite 
FROM lignecommandes1
WHERE quantite < 100;  -- Should return NO ROWS

-- If any found, fragmentation is not working correctly
```

**In site2_db (site2):**
```sql
-- Order lines with quantity < 100
SELECT COUNT(*) as site2_total FROM lignecommandes2;

-- Verify all have quantity < 100
SELECT idlignecommande, idcommande, quantite 
FROM lignecommandes2
WHERE quantite >= 100;  -- Should return NO ROWS

-- If any found, fragmentation is not working correctly
```

**Expected Result:**
```
Global Total:    10 order lines
Site1 Total:     X lines (all with quantité >= 100)
Site2 Total:     Y lines (all with quantité < 100)
X + Y = 10
```

---

## Test 7: Distributed Transaction - 2PC (Two-Phase Commit)

### Test atomic operations across databases

The trigger uses **Oracle Distributed Transactions (2PC)** to ensure atomicity. This means:
- If the INSERT succeeds on global AND remote site: COMMIT
- If either fails: ROLLBACK on both

**In global_db (eshop):**
```sql
-- Create a new order with TWO line items (different quantities)
BEGIN
    -- Insert order for client 3
    INSERT INTO commandes (idcommande, idclient, datecommande)
    VALUES (5002, 3, SYSDATE);
    
    -- Insert large quantity (goes to Site1)
    INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
    VALUES (1003, 5002, 3, 120, 0);
    
    -- Insert small quantity (goes to Site2)
    INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
    VALUES (1004, 5002, 4, 80, 5);
    
    COMMIT;
END;
/
```

### Verify distributed inserts

**In site1_db (site1):**
```sql
-- Large quantity item should be here
SELECT * FROM lignecommandes1 WHERE idlignecommande = 1003;
-- Should return 1 row (quantite=120)
```

**In site2_db (site2):**
```sql
-- Small quantity item should be here
SELECT * FROM lignecommandes2 WHERE idlignecommande = 1004;
-- Should return 1 row (quantite=80)
```

**Expected:** Both inserts succeeded atomically across the network

---

## Test 8: Monitor Trigger Status and Activity

### Check trigger status

**In global_db (eshop):**
```sql
SELECT trigger_name, table_name, status, triggering_event
FROM user_triggers
WHERE table_name = 'LIGNECOMMANDES';
```

**Expected:**
```
TRIGGER_NAME      TABLE_NAME        STATUS   TRIGGERING_EVENT
-----------       ---------------   --------  ----------------
SYC_DELETE_LIGNE  LIGNECOMMANDES    ENABLED   DELETE
SYC_INSERT_LIGNE  LIGNECOMMANDES    ENABLED   INSERT
SYC_UPDATE_LIGNE  LIGNECOMMANDES    ENABLED   UPDATE
```

### View order line distribution

```sql
-- Count fragmented data
SELECT 'Global' as db, COUNT(*) as total_lines FROM lignecommandes
UNION ALL
SELECT 'Site1', COUNT(*) FROM site1.lignecommandes1@site1_link
UNION ALL
SELECT 'Site2', COUNT(*) FROM site2.lignecommandes2@site2_link;
```

---

## Test 9: Verify Fragmentation Logic

### Confirm quantity-based routing

**In global_db (eshop):**
```sql
-- Check distribution by quantity
SELECT 
    CASE WHEN quantite >= 100 THEN 'Site1' ELSE 'Site2' END as destination,
    COUNT(*) as line_count,
    MIN(quantite) as min_qty,
    MAX(quantite) as max_qty
FROM lignecommandes
GROUP BY CASE WHEN quantite >= 100 THEN 'Site1' ELSE 'Site2' END;
```

**Expected output:**
```
DESTINATION  LINE_COUNT  MIN_QTY  MAX_QTY
-----------  ----------  -------  -------
Site1               X       100+    large
Site2               Y       <100     small
```

### Verify no misrouted data

**In site1_db (site1):**
```sql
-- Check for any items with quantity < 100 (should be none)
SELECT COUNT(*) FROM lignecommandes1 WHERE quantite < 100;
-- Should return: 0
```

**In site2_db (site2):**
```sql
-- Check for any items with quantity >= 100 (should be none)
SELECT COUNT(*) FROM lignecommandes2 WHERE quantite >= 100;
-- Should return: 0
```

---

## Test 10: End-to-End Order Processing with Triggers

### Scenario: Multi-item order across fragmentation sites

**Step 1: Create order in global_db**
```sql
-- In global_db (eshop)
INSERT INTO commandes (idcommande, idclient, datecommande)
VALUES (6000, 5, SYSDATE);
COMMIT;
```

**Step 2: Add LARGE quantity item (→ Site1)**
```sql
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (2001, 6000, 5, 200, 5);  -- quantite >= 100
COMMIT;
```

**Step 3: Add SMALL quantity item (→ Site2)**
```sql
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (2002, 6000, 6, 50, 0);   -- quantite < 100
COMMIT;
```

**Step 4: Verify fragmentation**

**In site1_db (site1):**
```sql
-- Should have the large item and order
SELECT * FROM commandes1 WHERE idcommande = 6000;
SELECT * FROM lignecommandes1 WHERE idcommande = 6000 AND idlignecommande = 2001;
-- Must have: the large quantity item (2001, quantite=200)
-- Must NOT have: the small quantity item (2002)
```

**In site2_db (site2):**
```sql
-- Should have the small item and order
SELECT * FROM commandes2 WHERE idcommande = 6000;
SELECT * FROM lignecommandes2 WHERE idcommande = 6000 AND idlignecommande = 2002;
-- Must have: the small quantity item (2002, quantite=50)
-- Must NOT have: the large quantity item (2001)
```

**Expected Result:** 
- Order exists on both sites (parent record replication)
- Large item ONLY on Site1
- Small item ONLY on Site2

---

## Quick Reference: Common Commands

### View trigger-based fragmentation
```sql
-- Global DB (all data)
SELECT COUNT(*) as global_lines FROM lignecommandes;

-- Site1 DB (large volumes: quantity >= 100)
SELECT COUNT(*) as site1_lines FROM site1.lignecommandes1@site1_link;

-- Site2 DB (small volumes: quantity < 100)
SELECT COUNT(*) as site2_lines FROM site2.lignecommandes2@site2_link;
```

### Check parent record replication
```sql
-- Global DB
SELECT COUNT(*) FROM clients;
SELECT COUNT(*) FROM commandes;

-- Via Site1 link
SELECT COUNT(*) FROM site1.clients1@site1_link;
SELECT COUNT(*) FROM site1.commandes1@site1_link;

-- Via Site2 link
SELECT COUNT(*) FROM site2.clients2@site2_link;
SELECT COUNT(*) FROM site2.commandes2@site2_link;
```

### Reset test data
```sql
-- Delete test order lines (replace 2000 with your test order ID)
DELETE FROM lignecommandes WHERE idcommande >= 5000;
DELETE FROM commandes WHERE idcommande >= 5000;
COMMIT;
```

### Verify fragmentation correctness
```sql
-- Check for misrouted data
-- Site1 should have ZERO lines with quantity < 100
SELECT COUNT(*) FROM site1.lignecommandes1@site1_link WHERE quantite < 100;

-- Site2 should have ZERO lines with quantity >= 100
SELECT COUNT(*) FROM site2.lignecommandes2@site2_link WHERE quantite >= 100;

-- Both should return 0 if fragmentation is working correctly
```

---

## Expected Results Summary

| Test | Operation | Global | Site1 | Site2 | Expected |
|------|-----------|--------|-------|-------|----------|
| 2 | Large item (qty>=100) | ✅ | ✅ | ❌ | Site1 only |
| 3 | Small item (qty<100) | ✅ | ❌ | ✅ | Site2 only |
| 4 | Update line | ✅ | ✅ | N/A | Atomic 2PC |
| 5 | Delete line | ✅ | ❌ | N/A | Atomic 2PC |
| 6 | Fragmentation check | ✅ | qty>=100 | qty<100 | Correct routing |
| 7 | Distributed TX | ✅ | ✅ | ✅ | Both succeed or both fail |
| 8 | Triggers enabled | ✅ | N/A | N/A | All ENABLED |
| 9 | No misroutes | ✅ | ✅ | ✅ | Zero count both |
| 10 | Multi-item order | ✅ | Large only | Small only | Perfect distribution |

**If all tests pass: Your distributed database with horizontal fragmentation triggers is fully operational!** ✅

---

## Troubleshooting Tips

**Issue:** Data not replicating  
**Solution:** Check if triggers are enabled: `SELECT status FROM user_triggers;`

**Issue:** ORA-03113 connection error  
**Solution:** Reconnect to the database and retry

**Issue:** Triggers failing silently  
**Solution:** Check error log: `SELECT * FROM user_errors WHERE type='TRIGGER';`

**Issue:** Circular replication (infinite loops)  
**Solution:** Triggers should have logic to prevent recursion (built into Scenario 2)

