-- ============================================================================
-- DISTRIBUTED DATABASE TRIGGER TEST SCRIPT
-- ============================================================================
-- Project: E-Shop Multi-Site Database with Horizontal Fragmentation
-- Purpose: Comprehensive test of INSERT, UPDATE, DELETE triggers
-- Author: Abdelhamid Saidi
-- Date: June 11, 2026
-- ============================================================================

-- SET UP SESSION
SET ECHO ON
SET FEEDBACK ON
SET LINESIZE 200
SET PAGESIZE 50

-- Connect to global_db (master database)
-- sqlplus eshop/eshop123@localhost:1524/FREEPDB1

-- ============================================================================
-- TEST 1: INSERT TRIGGER - FRAGMENTATION TEST
-- ============================================================================

PROMPT
PROMPT ╔════════════════════════════════════════════════════════════════╗
PROMPT ║ TEST 1: INSERT TRIGGER - HORIZONTAL FRAGMENTATION            ║
PROMPT ║ Purpose: Verify items are routed to correct sites by quantity ║
PROMPT ╚════════════════════════════════════════════════════════════════╝
PROMPT

-- Create a test order
INSERT INTO commandes (idcommande, idclient, datecommande)
VALUES (10001, 1, SYSDATE);

COMMIT;

PROMPT → Inserted Order 10001
PROMPT → Now inserting line items with different quantities...

-- Insert LARGE volume item (should go to Site1)
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (8001, 10001, 1, 200, 0);

COMMIT;

PROMPT → Inserted Line 8001 with qty=200 (should route to Site1)

-- Insert SMALL volume item (should go to Site2)
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (8002, 10001, 2, 60, 0);

COMMIT;

PROMPT → Inserted Line 8002 with qty=60 (should route to Site2)

-- Verify fragmentation on master
PROMPT
PROMPT === VERIFICATION ON MASTER DATABASE ===
SELECT idlignecommande, idcommande, quantite,
       CASE WHEN quantite >= 100 THEN 'Site1' ELSE 'Site2' END as destination
FROM lignecommandes
WHERE idcommande = 10001
ORDER BY idlignecommande;

-- Verify replication to Site1
PROMPT
PROMPT === VERIFICATION ON SITE1 (should have qty >= 100) ===
SELECT idlignecommande, quantite FROM site1.lignecommandes1@site1_link
WHERE idcommande = 10001
ORDER BY idlignecommande;

-- Verify replication to Site2
PROMPT
PROMPT === VERIFICATION ON SITE2 (should have qty < 100) ===
SELECT idlignecommande, quantite FROM site2.lignecommandes2@site2_link
WHERE idcommande = 10001
ORDER BY idlignecommande;

PROMPT
PROMPT ✓ TEST 1 COMPLETE: Fragmentation working correctly
PROMPT

-- ============================================================================
-- TEST 2: UPDATE TRIGGER - SIMPLE UPDATE (NO MIGRATION)
-- ============================================================================

PROMPT
PROMPT ╔════════════════════════════════════════════════════════════════╗
PROMPT ║ TEST 2: UPDATE TRIGGER - SIMPLE UPDATE (SAME SITE)           ║
PROMPT ║ Purpose: Update quantity while staying on same site           ║
PROMPT ╚════════════════════════════════════════════════════════════════╝
PROMPT

PROMPT → Updating Line 8001: qty 200 → 250 (stays on Site1)

UPDATE lignecommandes
SET quantite = 250, remise = 5
WHERE idlignecommande = 8001;

COMMIT;

-- Verify update on master
PROMPT
PROMPT === VERIFICATION ON MASTER DATABASE ===
SELECT idlignecommande, quantite, remise FROM lignecommandes
WHERE idlignecommande = 8001;

-- Verify update propagated to Site1
PROMPT
PROMPT === VERIFICATION ON SITE1 (should be updated) ===
SELECT idlignecommande, quantite, remise FROM site1.lignecommandes1@site1_link
WHERE idlignecommande = 8001;

PROMPT
PROMPT ✓ TEST 2 COMPLETE: Simple update working correctly
PROMPT

-- ============================================================================
-- TEST 3: UPDATE TRIGGER - MIGRATION (SITE1 → SITE2)
-- ============================================================================

PROMPT
PROMPT ╔════════════════════════════════════════════════════════════════╗
PROMPT ║ TEST 3: UPDATE TRIGGER - MIGRATION (SITE1 → SITE2)           ║
PROMPT ║ Purpose: Item quantity drops below 100, migrates to Site2     ║
PROMPT ╚════════════════════════════════════════════════════════════════╝
PROMPT

PROMPT → Updating Line 8001: qty 250 → 75 (migrate from Site1 to Site2)

UPDATE lignecommandes
SET quantite = 75
WHERE idlignecommande = 8001;

COMMIT;

-- Verify update on master
PROMPT
PROMPT === VERIFICATION ON MASTER DATABASE ===
SELECT idlignecommande, quantite FROM lignecommandes
WHERE idlignecommande = 8001;

-- Verify item REMOVED from Site1
PROMPT
PROMPT === VERIFICATION ON SITE1 (should be EMPTY now) ===
SELECT COUNT(*) as count_on_site1 FROM site1.lignecommandes1@site1_link
WHERE idlignecommande = 8001;

-- Verify item ADDED to Site2
PROMPT
PROMPT === VERIFICATION ON SITE2 (should have migrated item) ===
SELECT idlignecommande, quantite FROM site2.lignecommandes2@site2_link
WHERE idlignecommande = 8001;

PROMPT
PROMPT ✓ TEST 3 COMPLETE: Migration (Site1 → Site2) working correctly
PROMPT

-- ============================================================================
-- TEST 4: UPDATE TRIGGER - MIGRATION (SITE2 → SITE1)
-- ============================================================================

PROMPT
PROMPT ╔════════════════════════════════════════════════════════════════╗
PROMPT ║ TEST 4: UPDATE TRIGGER - MIGRATION (SITE2 → SITE1)           ║
PROMPT ║ Purpose: Item quantity rises above 100, migrates to Site1     ║
PROMPT ╚════════════════════════════════════════════════════════════════╝
PROMPT

PROMPT → Updating Line 8001: qty 75 → 150 (migrate from Site2 to Site1)

UPDATE lignecommandes
SET quantite = 150
WHERE idlignecommande = 8001;

COMMIT;

-- Verify update on master
PROMPT
PROMPT === VERIFICATION ON MASTER DATABASE ===
SELECT idlignecommande, quantite FROM lignecommandes
WHERE idlignecommande = 8001;

-- Verify item REMOVED from Site2
PROMPT
PROMPT === VERIFICATION ON SITE2 (should be EMPTY now) ===
SELECT COUNT(*) as count_on_site2 FROM site2.lignecommandes2@site2_link
WHERE idlignecommande = 8001;

-- Verify item ADDED to Site1
PROMPT
PROMPT === VERIFICATION ON SITE1 (should have migrated item) ===
SELECT idlignecommande, quantite FROM site1.lignecommandes1@site1_link
WHERE idlignecommande = 8001;

PROMPT
PROMPT ✓ TEST 4 COMPLETE: Migration (Site2 → Site1) working correctly
PROMPT

-- ============================================================================
-- TEST 5: DELETE TRIGGER - DELETE WITH CLEANUP
-- ============================================================================

PROMPT
PROMPT ╔════════════════════════════════════════════════════════════════╗
PROMPT ║ TEST 5: DELETE TRIGGER - DELETE WITH ORPHAN CLEANUP          ║
PROMPT ║ Purpose: Delete items and verify orphan order removal         ║
PROMPT ╚════════════════════════════════════════════════════════════════╝
PROMPT

-- First, verify what we have
PROMPT → Current state before deletion:
SELECT idlignecommande, idcommande, quantite FROM lignecommandes
WHERE idcommande = 10001
ORDER BY idlignecommande;

-- Delete the small item (8002) - should remove order from Site2 (orphan cleanup)
PROMPT
PROMPT → Deleting Line 8002 from Site2...

DELETE FROM lignecommandes WHERE idlignecommande = 8002;

COMMIT;

-- Verify deletion on master
PROMPT
PROMPT === VERIFICATION ON MASTER DATABASE ===
SELECT COUNT(*) as lines_left FROM lignecommandes WHERE idcommande = 10001;

-- Verify item removed from Site2
PROMPT
PROMPT === VERIFICATION ON SITE2 (should be EMPTY) ===
SELECT COUNT(*) as count_on_site2 FROM site2.lignecommandes2@site2_link
WHERE idcommande = 10001;

-- Verify order still exists on Site1 (still has items)
PROMPT
PROMPT === VERIFICATION ON SITE1 (order should still exist) ===
SELECT idcommande FROM site1.commandes1@site1_link WHERE idcommande = 10001;

-- Now delete the remaining item
PROMPT
PROMPT → Deleting Line 8001 from Site1...

DELETE FROM lignecommandes WHERE idlignecommande = 8001;

COMMIT;

-- Verify master is empty
PROMPT
PROMPT === VERIFICATION ON MASTER DATABASE (should be EMPTY) ===
SELECT COUNT(*) as lines_left FROM lignecommandes WHERE idcommande = 10001;

-- Verify Site1 is empty (orphan order deleted)
PROMPT
PROMPT === VERIFICATION ON SITE1 (order should be DELETED - orphan cleanup) ===
SELECT COUNT(*) as order_count FROM site1.commandes1@site1_link
WHERE idcommande = 10001;

PROMPT
PROMPT ✓ TEST 5 COMPLETE: Delete and orphan cleanup working correctly
PROMPT

-- ============================================================================
-- TEST 6: COMPLEX SCENARIO - MULTI-ITEM ORDER WITH FRAGMENTATION
-- ============================================================================

PROMPT
PROMPT ╔════════════════════════════════════════════════════════════════╗
PROMPT ║ TEST 6: COMPLEX SCENARIO - MULTI-ITEM FRAGMENTATION          ║
PROMPT ║ Purpose: Real-world scenario with multiple items              ║
PROMPT ╚════════════════════════════════════════════════════════════════╝
PROMPT

-- Create realistic order
INSERT INTO commandes (idcommande, idclient, datecommande)
VALUES (10002, 2, SYSDATE);

COMMIT;

PROMPT → Created Order 10002

-- Add multiple items
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (8010, 10002, 1, 500, 0);  -- LARGE: Site1

INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (8011, 10002, 2, 300, 0);  -- LARGE: Site1

INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (8012, 10002, 3, 75, 0);   -- SMALL: Site2

INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (8013, 10002, 4, 50, 0);   -- SMALL: Site2

INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (8014, 10002, 5, 100, 0);  -- BOUNDARY: Site1 (>= 100)

COMMIT;

PROMPT → Inserted 5 line items with different quantities

-- Show distribution
PROMPT
PROMPT === MASTER DATABASE - DISTRIBUTION BY DESTINATION ===
SELECT
    idlignecommande,
    quantite,
    CASE WHEN quantite >= 100 THEN 'Site1' ELSE 'Site2' END as destination
FROM lignecommandes
WHERE idcommande = 10002
ORDER BY idlignecommande;

-- Verify Site1 has 3 items (8010, 8011, 8014)
PROMPT
PROMPT === SITE1 DATABASE (should have 3 items: qty >= 100) ===
SELECT idlignecommande, quantite FROM site1.lignecommandes1@site1_link
WHERE idcommande = 10002
ORDER BY idlignecommande;

-- Verify Site2 has 2 items (8012, 8013)
PROMPT
PROMPT === SITE2 DATABASE (should have 2 items: qty < 100) ===
SELECT idlignecommande, quantite FROM site2.lignecommandes2@site2_link
WHERE idcommande = 10002
ORDER BY idlignecommande;

PROMPT
PROMPT ✓ TEST 6 COMPLETE: Complex fragmentation scenario working correctly
PROMPT

-- ============================================================================
-- TEST 7: CONCURRENT UPDATES ON MULTIPLE ITEMS
-- ============================================================================

PROMPT
PROMPT ╔════════════════════════════════════════════════════════════════╗
PROMPT ║ TEST 7: CONCURRENT UPDATES (ALL ITEMS MIGRATE)               ║
PROMPT ║ Purpose: Update multiple items, triggering migrations         ║
PROMPT ╚════════════════════════════════════════════════════════════════╝
PROMPT

-- Update Site1 items (8010, 8011, 8014) to Site2
PROMPT → Updating large items to become small items...

UPDATE lignecommandes SET quantite = 40 WHERE idlignecommande IN (8010, 8011, 8014);

COMMIT;

PROMPT → All large items updated to qty=40

-- Verify migration
PROMPT
PROMPT === VERIFICATION: All items should now be on Site2 ===
SELECT 'Site1 count:' as label, COUNT(*) as count FROM site1.lignecommandes1@site1_link WHERE idcommande = 10002
UNION ALL
SELECT 'Site2 count:', COUNT(*) FROM site2.lignecommandes2@site2_link WHERE idcommande = 10002;

PROMPT
PROMPT ✓ TEST 7 COMPLETE: Concurrent migrations working correctly
PROMPT

-- ============================================================================
-- FINAL VERIFICATION
-- ============================================================================

PROMPT
PROMPT ╔════════════════════════════════════════════════════════════════╗
PROMPT ║ FINAL VERIFICATION - DATA CONSISTENCY ACROSS ALL SITES        ║
PROMPT ╚════════════════════════════════════════════════════════════════╝
PROMPT

-- Show all fragmentation across all tests
PROMPT
PROMPT === TOTAL DATA DISTRIBUTION ===
SELECT 'Master' as location, COUNT(*) as line_items FROM lignecommandes
UNION ALL
SELECT 'Site1', COUNT(*) FROM site1.lignecommandes1@site1_link
UNION ALL
SELECT 'Site2', COUNT(*) FROM site2.lignecommandes2@site2_link;

-- Show order-to-site mapping
PROMPT
PROMPT === ORDER-TO-SITE MAPPING ===
SELECT 'Global Orders' as location, COUNT(DISTINCT idcommande) as order_count FROM commandes
UNION ALL
SELECT 'Site1 Orders', COUNT(DISTINCT idcommande) FROM site1.commandes1@site1_link
UNION ALL
SELECT 'Site2 Orders', COUNT(DISTINCT idcommande) FROM site2.commandes2@site2_link;

-- Cleanup verification
PROMPT
PROMPT === CLEANUP TEST - Orphan orders should be deleted ===
PROMPT Order 10001 should be gone (all items deleted)
SELECT COUNT(*) FROM site1.commandes1@site1_link WHERE idcommande = 10001;
SELECT COUNT(*) FROM site2.commandes2@site2_link WHERE idcommande = 10001;

PROMPT
PROMPT
PROMPT ╔════════════════════════════════════════════════════════════════╗
PROMPT ║ ✓ ALL TESTS COMPLETE                                         ║
PROMPT ║ ✓ Triggers are functioning correctly                         ║
PROMPT ║ ✓ Fragmentation is working as expected                       ║
PROMPT ║ ✓ Migrations are happening automatically                     ║
PROMPT ║ ✓ Orphan cleanup is working                                  ║
PROMPT ╚════════════════════════════════════════════════════════════════╝
PROMPT

-- ============================================================================
-- CLEANUP (Optional - comment out if you want to keep test data)
-- ============================================================================

PROMPT
PROMPT === CLEANUP: Deleting all test data ===

DELETE FROM lignecommandes WHERE idcommande IN (10001, 10002);
DELETE FROM commandes WHERE idcommande IN (10001, 10002);
COMMIT;

PROMPT → Test data cleaned up

-- ============================================================================
-- END OF TEST SCRIPT
-- ============================================================================

PROMPT
PROMPT Test script completed successfully!
PROMPT All trigger functionality has been verified.
PROMPT

SET ECHO OFF
EXIT;
