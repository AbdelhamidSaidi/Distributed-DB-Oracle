# Manual Trigger Testing Guide - Step by Step

**Purpose:** Demonstrate trigger functionality with hands-on CLI commands  
**Date:** June 11, 2026

---

## Prerequisites

- All 3 containers running and healthy
- Docker installed and working
- Connection strings configured

---

## STEP 1: Connect to Each Container

### 1.1 Connect to Global DB (Master)

```bash
sqlplus eshop/eshop123@localhost:1524/FREEPDB1
```

**Verify connection:**
```sql
SELECT NAME FROM V$DATABASE;
-- Expected: FREE
```

### 1.2 Connect to Site1 DB

```bash
sqlplus site1/site1123@localhost:1522/FREEPDB1
```

**Verify connection:**
```sql
SELECT COUNT(*) FROM lignecommandes1;
-- Expected: Number of items on site1
```

### 1.3 Connect to Site2 DB

```bash
sqlplus site2/site2123@localhost:1523/FREEPDB1
```

**Verify connection:**
```sql
SELECT COUNT(*) FROM lignecommandes2;
-- Expected: Number of items on site2
```

---

## STEP 2: Create Commands - Store in Each Site

### 2.1 In Global DB - Insert Command to Test Site1

**Connect to global_db:**
```bash
sqlplus eshop/eshop123@localhost:1524/FREEPDB1
```

**Execute:** Create an order and insert a LARGE item (qty >= 100)

```sql
-- Create order
INSERT INTO commandes (idcommande, idclient, datecommande)
VALUES (40001, 1, SYSDATE);
COMMIT;

-- Insert LARGE item (should go to Site1)
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (9001, 40001, 1, 180, 0);
COMMIT;
```

**Verify in global_db:**
```sql
SELECT * FROM lignecommandes WHERE idlignecommande = 9001;
```

---

### 2.2 In Site1 DB - Verify Synchronization

**Open NEW terminal window and connect to site1:**

```bash
sqlplus site1/site1123@localhost:1522/FREEPDB1
```

**Verify the item was synchronized:**

```sql
SELECT * FROM lignecommandes1 WHERE idlignecommande = 9001;
```

**Expected Output:**
```
IDLIGNECOMMANDE IDCOMMANDE  IDPRODUIT   QUANTITE     REMISE
           9001      40001          1        180          0
```

✅ **SUCCESS:** Item replicated to Site1!

---

### 2.3 Create Command for Site2

**Back in global_db terminal:**

```sql
-- Insert SMALL item (should go to Site2)
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (9002, 40001, 2, 60, 0);
COMMIT;
```

**Verify in global_db:**
```sql
SELECT * FROM lignecommandes WHERE idlignecommande = 9002;
```

---

### 2.4 In Site2 DB - Verify Synchronization

**Open ANOTHER NEW terminal and connect to site2:**

```bash
sqlplus site2/site2123@localhost:1523/FREEPDB1
```

**Verify the item was synchronized:**

```sql
SELECT * FROM lignecommandes2 WHERE idlignecommande = 9002;
```

**Expected Output:**
```
IDLIGNECOMMANDE IDCOMMANDE  IDPRODUIT   QUANTITE     REMISE
           9002      40001          2         60          0
```

✅ **SUCCESS:** Item replicated to Site2!

---

## STEP 3: Verify Items Synced to Their Sites

### 3.1 Verify Site1 ONLY has large items (qty >= 100)

**In site1 terminal:**

```sql
-- Should return 0 rows (no items with qty < 100)
SELECT * FROM lignecommandes1 WHERE quantite < 100;
```

**Expected:** No rows selected ✅

### 3.2 Verify Site2 ONLY has small items (qty < 100)

**In site2 terminal:**

```sql
-- Should return 0 rows (no items with qty >= 100)
SELECT * FROM lignecommandes2 WHERE quantite >= 100;
```

**Expected:** No rows selected ✅

### 3.3 Summary View - All Three Databases

**In global_db terminal:**

```sql
-- See distribution
SELECT 'Master' as location, COUNT(*) as line_count FROM lignecommandes WHERE idcommande = 40001
UNION ALL
SELECT 'Site1', COUNT(*) FROM site1.lignecommandes1@site1_link WHERE idcommande = 40001
UNION ALL
SELECT 'Site2', COUNT(*) FROM site2.lignecommandes2@site2_link WHERE idcommande = 40001;
```

**Expected Output:**
```
LOCATION   LINE_COUNT
------     ----------
Master              2
Site1               1
Site2               1
```

✅ **Fragmentation working perfectly!**

---

## STEP 4: Complex Command - Two Items (One >100, One <100)

### 4.1 Create New Order with Multiple Items

**In global_db terminal:**

```sql
-- Create new order
INSERT INTO commandes (idcommande, idclient, datecommande)
VALUES (40002, 2, SYSDATE);
COMMIT;

-- Add LARGE item (qty >= 100 → Site1)
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (9010, 40002, 1, 250, 2);
COMMIT;

-- Add SMALL item (qty < 100 → Site2)
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (9011, 40002, 2, 45, 3);
COMMIT;
```

### 4.2 Verify Complex Fragmentation

**In global_db terminal:**

```sql
-- See all items in this order
SELECT idlignecommande, quantite,
       CASE WHEN quantite >= 100 THEN 'Site1' ELSE 'Site2' END as destination
FROM lignecommandes
WHERE idcommande = 40002
ORDER BY idlignecommande;
```

**Expected Output:**
```
IDLIGNECOMMANDE QUANTITE DESTINATION
           9010      250 Site1
           9011       45 Site2
```

### 4.3 Verify Site1 Has Only Large Item

**In site1 terminal:**

```sql
SELECT idlignecommande, quantite FROM lignecommandes1 WHERE idcommande = 40002;
```

**Expected:**
```
IDLIGNECOMMANDE QUANTITE
           9010      250
```

### 4.4 Verify Site2 Has Only Small Item

**In site2 terminal:**

```sql
SELECT idlignecommande, quantite FROM lignecommandes2 WHERE idcommande = 40002;
```

**Expected:**
```
IDLIGNECOMMANDE QUANTITE
           9011       45
```

✅ **Complex fragmentation working!**

---

## STEP 5: Test Migration - Site1 to Site2

### 5.1 Insert Large Item in Site1

**In global_db terminal:**

```sql
-- Add a LARGE item to order 40002 (currently has 9010)
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (9012, 40002, 3, 180, 0);
COMMIT;
```

**Verify on global_db:**
```sql
SELECT idlignecommande, quantite FROM lignecommandes WHERE idcommande = 40002 ORDER BY idlignecommande;
```

**Expected:**
```
IDLIGNECOMMANDE QUANTITE
           9010      250
           9011       45
           9012      180
```

### 5.2 Verify on Site1 (should have 2 items now)

**In site1 terminal:**

```sql
SELECT idlignecommande, quantite FROM lignecommandes1 WHERE idcommande = 40002 ORDER BY idlignecommande;
```

**Expected:**
```
IDLIGNECOMMANDE QUANTITE
           9010      250
           9012      180
```

### 5.3 Update Item to Migrate Site1 → Site2

**In global_db terminal:**

```sql
-- Update item 9010 from qty 250 → 75 (crosses threshold, moves to Site2)
UPDATE lignecommandes SET quantite = 75 WHERE idlignecommande = 9010;
COMMIT;
```

**Verify on global_db:**
```sql
SELECT idlignecommande, quantite FROM lignecommandes WHERE idcommande = 40002 ORDER BY idlignecommande;
```

**Expected:**
```
IDLIGNECOMMANDE QUANTITE
           9010       75
           9011       45
           9012      180
```

### 5.4 Verify Migration - Item LEFT Site1

**In site1 terminal:**

```sql
-- Item 9010 should be GONE now (migrated to Site2)
SELECT idlignecommande, quantite FROM lignecommandes1 WHERE idcommande = 40002 ORDER BY idlignecommande;
```

**Expected Output:**
```
IDLIGNECOMMANDE QUANTITE
           9012      180
```

✅ **Item 9010 is gone from Site1!**

### 5.5 Verify Migration - Item ARRIVED on Site2

**In site2 terminal:**

```sql
-- Item 9010 should now be HERE with new quantity 75
SELECT idlignecommande, quantite FROM lignecommandes2 WHERE idcommande = 40002 ORDER BY idlignecommande;
```

**Expected Output:**
```
IDLIGNECOMMANDE QUANTITE
           9010       75
           9011       45
```

✅ **Item 9010 appeared on Site2 with qty=75!**

---

## Summary View - After Migration

### View Current State Across All Sites

**In global_db terminal:**

```sql
-- Show distribution after migration
SELECT 'Order 40002 Distribution' as title;
SELECT
    idlignecommande,
    quantite,
    CASE WHEN quantite >= 100 THEN 'Site1' ELSE 'Site2' END as destination
FROM lignecommandes
WHERE idcommande = 40002
ORDER BY idlignecommande;
```

**Expected:**
```
IDLIGNECOMMANDE QUANTITE DESTINATION
           9010       75 Site2
           9011       45 Site2
           9012      180 Site1
```

### Cross-Database Summary

**In global_db terminal:**

```sql
-- Count all items per location
SELECT 'Master' as location, COUNT(*) as line_items FROM lignecommandes WHERE idcommande = 40002
UNION ALL
SELECT 'Site1', COUNT(*) FROM site1.lignecommandes1@site1_link WHERE idcommande = 40002
UNION ALL
SELECT 'Site2', COUNT(*) FROM site2.lignecommandes2@site2_link WHERE idcommande = 40002;
```

**Expected:**
```
LOCATION LINE_ITEMS
Master              3
Site1               1
Site2               2
```

✅ **Perfect distribution: Site1 has large items, Site2 has small items!**

---

## Terminal Setup Recommendation

For the best experience during demonstration, open **3 terminal windows side by side:**

```
┌─────────────────────┬─────────────────────┬─────────────────────┐
│   GLOBAL DB         │     SITE 1 DB       │     SITE 2 DB       │
│ (eshop user)        │  (site1 user)       │  (site2 user)       │
│ Port: 1524          │  Port: 1522         │  Port: 1523         │
├─────────────────────┼─────────────────────┼─────────────────────┤
│                     │                     │                     │
│ sqlplus eshop/...   │ sqlplus site1/...   │ sqlplus site2/...   │
│ @localhost:1524     │ @localhost:1522     │ @localhost:1523     │
│                     │                     │                     │
│ [Run commands]      │ [Verify results]    │ [Verify results]    │
│                     │                     │                     │
└─────────────────────┴─────────────────────┴─────────────────────┘
```

---

## Quick Reference - Copy-Paste Commands

### Terminal 1: Global DB
```bash
sqlplus eshop/eshop123@localhost:1524/FREEPDB1
```

### Terminal 2: Site1
```bash
sqlplus site1/site1123@localhost:1522/FREEPDB1
```

### Terminal 3: Site2
```bash
sqlplus site2/site2123@localhost:1523/FREEPDB1
```

---

## Expected Flow for Presentation

1. **Show containers running** - `docker compose ps`
2. **Connect to all 3 terminals** simultaneously
3. **Insert into global** - large item + small item
4. **Switch to Site1** - verify large item is there
5. **Switch to Site2** - verify small item is there
6. **Back to global** - show data distribution summary
7. **Update item to cross threshold** - change qty from 250 to 75
8. **Show Site1** - item disappeared
9. **Show Site2** - item appeared with new quantity
10. **Global summary** - show final distribution

---

## Verification Queries - Copy Ready

**Check fragmentation rule compliance:**
```sql
-- No items on Site1 with qty < 100
SELECT COUNT(*) FROM site1.lignecommandes1@site1_link WHERE quantite < 100;
-- Expected: 0

-- No items on Site2 with qty >= 100
SELECT COUNT(*) FROM site2.lignecommandes2@site2_link WHERE quantite >= 100;
-- Expected: 0
```

**See all orders and their locations:**
```sql
SELECT 'Master' as db, idcommande, COUNT(*) as items FROM lignecommandes GROUP BY idcommande
UNION ALL
SELECT 'Site1', idcommande, COUNT(*) FROM site1.lignecommandes1@site1_link GROUP BY idcommande
UNION ALL
SELECT 'Site2', idcommande, COUNT(*) FROM site2.lignecommandes2@site2_link GROUP BY idcommande
ORDER BY idcommande, db;
```

---

**End of Manual Test Guide**

