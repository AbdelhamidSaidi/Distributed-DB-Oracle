# Distributed Database Triggers - Complete Documentation

**Project:** E-Shop Distributed Database with Horizontal Fragmentation  
**Scenario:** Scenario 2 - Multi-Master with Intelligent Data Routing  
**Date:** June 11, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Trigger: SYC_INSERT_LIGNE](#trigger-syc_insert_ligne)
3. [Trigger: SYC_UPDATE_LIGNE](#trigger-syc_update_ligne)
4. [Trigger: SYC_DELETE_LIGNE](#trigger-syc_delete_ligne)
5. [How Triggers Work Together](#how-triggers-work-together)
6. [Database Links Used](#database-links-used)
7. [2PC (Two-Phase Commit)](#2pc-two-phase-commit)

---

## Overview

### Fragmentation Strategy

```
HORIZONTAL FRAGMENTATION BY VOLUME:

Order Line Items (LigneCommandes) are automatically distributed:

├─ Quantity >= 100  →  SITE1 (Large volumes / Bulk orders)
└─ Quantity < 100   →  SITE2 (Small volumes / Regular orders)

Benefits:
✓ Load distribution across multiple database servers
✓ Faster local queries at each site
✓ Automatic routing without application logic
✓ Parent records (Clients, Orders) replicated to all sites for integrity
```

### Key Concepts

1. **Triggers fire AFTER INSERT/UPDATE/DELETE** on LIGNECOMMANDES
2. **Database links (@site1_link, @site2_link)** connect to remote sites
3. **Parent records** are created on-demand if missing on remote site
4. **2PC (Two-Phase Commit)** ensures atomicity across all databases
5. **Migration logic** handles items moving between sites when quantity crosses threshold

---

## Trigger: SYC_INSERT_LIGNE

### What It Does

When a **new order line item is inserted**, this trigger:
1. Retrieves all parent data (order, client, product, category, employee)
2. Checks the item's quantity
3. Routes to **Site1** if quantity ≥ 100, or **Site2** if quantity < 100
4. Creates parent records on the remote site if they don't exist
5. Inserts the line item on the appropriate remote site
6. Participates in 2PC transaction

### Full Trigger Code

```sql
CREATE OR REPLACE TRIGGER SYC_INSERT_LIGNE
AFTER INSERT ON LigneCommandes
FOR EACH ROW
DECLARE
    v_count        NUMBER;
    v_idclient     Commandes.idclient%TYPE;
    v_idemploye    Commandes.idemploye%TYPE;
    v_datecommande Commandes.datecommande%TYPE;
    v_codeclient   Clients.codeclient%TYPE;
    v_societe      Clients.societe%TYPE;
    v_contact      Clients.contact%TYPE;
    v_adresse      Clients.adresse%TYPE;
    v_ville        Clients.ville%TYPE;
    v_pays         Clients.pays%TYPE;
    v_nom          Employes.nom%TYPE;
    v_prenom       Employes.prenom%TYPE;
    v_fonction     Employes.fonction%TYPE;
    v_idcateg      Produits.idcateg%TYPE;
    v_designation  Produits.designation%TYPE;
    v_prixunitaire Produits.prixunitaire%TYPE;
    v_nomcateg     Categories.nomcateg%TYPE;

    -- Procedure to replicate to Site1 (quantity >= 100)
    PROCEDURE push_to_site1(
        p_idlignecommande IN NUMBER,
        p_idcommande      IN NUMBER,
        p_idproduit       IN NUMBER,
        p_quantite        IN NUMBER,
        p_remise          IN NUMBER
    ) IS
    BEGIN
        -- Check if category exists on Site1
        SELECT COUNT(*) INTO v_count FROM Categories1@site1_link 
        WHERE idcateg = v_idcateg;
        IF v_count = 0 THEN
            -- Create category if missing
            INSERT INTO Categories1@site1_link(idcateg, nomcateg)
            VALUES (v_idcateg, v_nomcateg);
        END IF;

        -- Check if product exists on Site1
        SELECT COUNT(*) INTO v_count FROM Produits1@site1_link 
        WHERE idproduit = p_idproduit;
        IF v_count = 0 THEN
            -- Create product if missing
            INSERT INTO Produits1@site1_link(idproduit, idcateg, designation, prixunitaire)
            VALUES (p_idproduit, v_idcateg, v_designation, v_prixunitaire);
        END IF;

        -- Check if client exists on Site1
        SELECT COUNT(*) INTO v_count FROM Clients1@site1_link 
        WHERE idclient = v_idclient;
        IF v_count = 0 THEN
            -- Create client if missing
            INSERT INTO Clients1@site1_link(idclient, codeclient, societe, contact, adresse, ville, pays)
            VALUES (v_idclient, v_codeclient, v_societe, v_contact, v_adresse, v_ville, v_pays);
        END IF;

        -- Check if employee exists on Site1 (if not NULL)
        IF v_idemploye IS NOT NULL THEN
            SELECT COUNT(*) INTO v_count FROM Employes1@site1_link 
            WHERE idemploye = v_idemploye;
            IF v_count = 0 THEN
                -- Create employee if missing
                INSERT INTO Employes1@site1_link(idemploye, nom, prenom, fonction)
                VALUES (v_idemploye, v_nom, v_prenom, v_fonction);
            END IF;
        END IF;

        -- Check if order exists on Site1
        SELECT COUNT(*) INTO v_count FROM Commandes1@site1_link 
        WHERE idcommande = p_idcommande;
        IF v_count = 0 THEN
            -- Create order if missing
            INSERT INTO Commandes1@site1_link(idcommande, idclient, idemploye, datecommande)
            VALUES (p_idcommande, v_idclient, v_idemploye, v_datecommande);
        END IF;

        -- Finally, insert the line item on Site1
        INSERT INTO LigneCommandes1@site1_link(idlignecommande, idcommande, idproduit, quantite, remise)
        VALUES (p_idlignecommande, p_idcommande, p_idproduit, p_quantite, p_remise);
    END push_to_site1;

    -- Procedure to replicate to Site2 (quantity < 100)
    PROCEDURE push_to_site2(
        p_idlignecommande IN NUMBER,
        p_idcommande      IN NUMBER,
        p_idproduit       IN NUMBER,
        p_quantite        IN NUMBER,
        p_remise          IN NUMBER
    ) IS
    BEGIN
        -- Check if category exists on Site2
        SELECT COUNT(*) INTO v_count FROM Categories2@site2_link 
        WHERE idcateg = v_idcateg;
        IF v_count = 0 THEN
            -- Create category if missing
            INSERT INTO Categories2@site2_link(idcateg, nomcateg)
            VALUES (v_idcateg, v_nomcateg);
        END IF;

        -- Check if product exists on Site2
        SELECT COUNT(*) INTO v_count FROM Produits2@site2_link 
        WHERE idproduit = p_idproduit;
        IF v_count = 0 THEN
            -- Create product if missing
            INSERT INTO Produits2@site2_link(idproduit, idcateg, designation, prixunitaire)
            VALUES (p_idproduit, v_idcateg, v_designation, v_prixunitaire);
        END IF;

        -- Check if client exists on Site2
        SELECT COUNT(*) INTO v_count FROM Clients2@site2_link 
        WHERE idclient = v_idclient;
        IF v_count = 0 THEN
            -- Create client if missing
            INSERT INTO Clients2@site2_link(idclient, codeclient, societe, contact, adresse, ville, pays)
            VALUES (v_idclient, v_codeclient, v_societe, v_contact, v_adresse, v_ville, v_pays);
        END IF;

        -- Check if employee exists on Site2 (if not NULL)
        IF v_idemploye IS NOT NULL THEN
            SELECT COUNT(*) INTO v_count FROM Employes2@site2_link 
            WHERE idemploye = v_idemploye;
            IF v_count = 0 THEN
                -- Create employee if missing
                INSERT INTO Employes2@site2_link(idemploye, nom, prenom, fonction)
                VALUES (v_idemploye, v_nom, v_prenom, v_fonction);
            END IF;
        END IF;

        -- Check if order exists on Site2
        SELECT COUNT(*) INTO v_count FROM Commandes2@site2_link 
        WHERE idcommande = p_idcommande;
        IF v_count = 0 THEN
            -- Create order if missing
            INSERT INTO Commandes2@site2_link(idcommande, idclient, idemploye, datecommande)
            VALUES (p_idcommande, v_idclient, v_idemploye, v_datecommande);
        END IF;

        -- Finally, insert the line item on Site2
        INSERT INTO LigneCommandes2@site2_link(idlignecommande, idcommande, idproduit, quantite, remise)
        VALUES (p_idlignecommande, p_idcommande, p_idproduit, p_quantite, p_remise);
    END push_to_site2;

BEGIN
    -- MAIN TRIGGER LOGIC
    
    -- Step 1: Fetch all parent data from the master database
    SELECT idclient, idemploye, datecommande
    INTO   v_idclient, v_idemploye, v_datecommande
    FROM   Commandes WHERE idcommande = :NEW.idcommande;

    SELECT codeclient, societe, contact, adresse, ville, pays
    INTO   v_codeclient, v_societe, v_contact, v_adresse, v_ville, v_pays
    FROM   Clients WHERE idclient = v_idclient;

    SELECT idcateg, designation, prixunitaire
    INTO   v_idcateg, v_designation, v_prixunitaire
    FROM   Produits WHERE idproduit = :NEW.idproduit;

    SELECT nomcateg INTO v_nomcateg
    FROM   Categories WHERE idcateg = v_idcateg;

    IF v_idemploye IS NOT NULL THEN
        SELECT nom, prenom, fonction INTO v_nom, v_prenom, v_fonction
        FROM   Employes WHERE idemploye = v_idemploye;
    END IF;

    -- Step 2: Route based on fragmentation rule (quantity threshold = 100)
    IF :NEW.quantite >= 100 THEN
        -- Route to Site1
        push_to_site1(:NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise);
    ELSE
        -- Route to Site2
        push_to_site2(:NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise);
    END IF;
END SYC_INSERT_LIGNE;
```

### Step-by-Step Execution

```
WHEN: INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
      VALUES (6001, 5000, 1, 150, 0);

TRIGGER EXECUTES:
├─ 1. Fetch parent records from master (order 5000, client, product, etc.)
├─ 2. Check if quantity (150) >= 100? YES → Route to Site1
├─ 3. Ensure parent records exist on Site1:
│  ├─ Check Categories1 exists → Create if missing
│  ├─ Check Produits1 exists → Create if missing
│  ├─ Check Clients1 exists → Create if missing
│  ├─ Check Employes1 exists → Create if missing
│  └─ Check Commandes1 exists → Create if missing
└─ 4. Insert line item on Site1 via database link
   └─ INSERT INTO LigneCommandes1@site1_link VALUES (...)

RESULT:
✓ Master DB: Line item 6001 exists (qty=150)
✓ Site1 DB:  Line item 6001 replicated (qty=150)
✓ Site2 DB:  Line item NOT there (correct - qty >= 100)
```

### Example: Order with Mixed Quantities

```
INSERT INTO commandes VALUES (20000, 1, NULL, SYSDATE);

INSERT INTO lignecommandes VALUES (6001, 20000, 1, 150, 0);
→ Trigger fires → Routes to Site1 (qty >= 100)

INSERT INTO lignecommandes VALUES (6002, 20000, 2, 60, 5);
→ Trigger fires → Routes to Site2 (qty < 100)

Final State:
├─ Master:  Order 20000 with items 6001 and 6002
├─ Site1:   Order 20000 with item 6001 (qty=150)
└─ Site2:   Order 20000 with item 6002 (qty=60)
```

---

## Trigger: SYC_UPDATE_LIGNE

### What It Does

When an **order line item is updated**, this trigger:
1. Detects if the quantity changed
2. If quantity stays in same range → Simple update on remote site
3. If quantity crosses the 100 threshold → Migrate to other site (delete + reinsert)
4. Ensures parent records exist on the destination site
5. Participates in 2PC transaction

### Full Trigger Code

```sql
CREATE OR REPLACE TRIGGER SYC_UPDATE_LIGNE
AFTER UPDATE ON LigneCommandes
FOR EACH ROW
DECLARE
    v_count        NUMBER;
    v_idclient     Commandes.idclient%TYPE;
    v_idemploye    Commandes.idemploye%TYPE;
    v_datecommande Commandes.datecommande%TYPE;
    v_codeclient   Clients.codeclient%TYPE;
    v_societe      Clients.societe%TYPE;
    v_contact      Clients.contact%TYPE;
    v_adresse      Clients.adresse%TYPE;
    v_ville        Clients.ville%TYPE;
    v_pays         Clients.pays%TYPE;
    v_nom          Employes.nom%TYPE;
    v_prenom       Employes.prenom%TYPE;
    v_fonction     Employes.fonction%TYPE;
    v_idcateg      Produits.idcateg%TYPE;
    v_designation  Produits.designation%TYPE;
    v_prixunitaire Produits.prixunitaire%TYPE;
    v_nomcateg     Categories.nomcateg%TYPE;

    -- Helper procedure to fetch parent data
    PROCEDURE fetch_parent_data(p_idcommande IN NUMBER, p_idproduit IN NUMBER) IS
    BEGIN
        SELECT idclient, idemploye, datecommande
        INTO   v_idclient, v_idemploye, v_datecommande
        FROM   Commandes WHERE idcommande = p_idcommande;

        SELECT codeclient, societe, contact, adresse, ville, pays
        INTO   v_codeclient, v_societe, v_contact, v_adresse, v_ville, v_pays
        FROM   Clients WHERE idclient = v_idclient;

        SELECT idcateg, designation, prixunitaire
        INTO   v_idcateg, v_designation, v_prixunitaire
        FROM   Produits WHERE idproduit = p_idproduit;

        SELECT nomcateg INTO v_nomcateg FROM Categories WHERE idcateg = v_idcateg;

        IF v_idemploye IS NOT NULL THEN
            SELECT nom, prenom, fonction INTO v_nom, v_prenom, v_fonction
            FROM   Employes WHERE idemploye = v_idemploye;
        END IF;
    END fetch_parent_data;

    -- Helper procedure to ensure parents exist on Site1
    PROCEDURE ensure_parents_on_site1(p_idcommande IN NUMBER, p_idproduit IN NUMBER) IS
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Categories1@site1_link WHERE idcateg = v_idcateg;
        IF v_count = 0 THEN
            INSERT INTO Categories1@site1_link(idcateg, nomcateg) 
            VALUES (v_idcateg, v_nomcateg);
        END IF;
        SELECT COUNT(*) INTO v_count FROM Produits1@site1_link WHERE idproduit = p_idproduit;
        IF v_count = 0 THEN
            INSERT INTO Produits1@site1_link(idproduit, idcateg, designation, prixunitaire)
            VALUES (p_idproduit, v_idcateg, v_designation, v_prixunitaire);
        END IF;
        SELECT COUNT(*) INTO v_count FROM Clients1@site1_link WHERE idclient = v_idclient;
        IF v_count = 0 THEN
            INSERT INTO Clients1@site1_link(idclient, codeclient, societe, contact, adresse, ville, pays)
            VALUES (v_idclient, v_codeclient, v_societe, v_contact, v_adresse, v_ville, v_pays);
        END IF;
        IF v_idemploye IS NOT NULL THEN
            SELECT COUNT(*) INTO v_count FROM Employes1@site1_link WHERE idemploye = v_idemploye;
            IF v_count = 0 THEN
                INSERT INTO Employes1@site1_link(idemploye, nom, prenom, fonction)
                VALUES (v_idemploye, v_nom, v_prenom, v_fonction);
            END IF;
        END IF;
        SELECT COUNT(*) INTO v_count FROM Commandes1@site1_link WHERE idcommande = p_idcommande;
        IF v_count = 0 THEN
            INSERT INTO Commandes1@site1_link(idcommande, idclient, idemploye, datecommande)
            VALUES (p_idcommande, v_idclient, v_idemploye, v_datecommande);
        END IF;
    END ensure_parents_on_site1;

    -- Helper procedure to ensure parents exist on Site2
    PROCEDURE ensure_parents_on_site2(p_idcommande IN NUMBER, p_idproduit IN NUMBER) IS
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Categories2@site2_link WHERE idcateg = v_idcateg;
        IF v_count = 0 THEN
            INSERT INTO Categories2@site2_link(idcateg, nomcateg) 
            VALUES (v_idcateg, v_nomcateg);
        END IF;
        SELECT COUNT(*) INTO v_count FROM Produits2@site2_link WHERE idproduit = p_idproduit;
        IF v_count = 0 THEN
            INSERT INTO Produits2@site2_link(idproduit, idcateg, designation, prixunitaire)
            VALUES (p_idproduit, v_idcateg, v_designation, v_prixunitaire);
        END IF;
        SELECT COUNT(*) INTO v_count FROM Clients2@site2_link WHERE idclient = v_idclient;
        IF v_count = 0 THEN
            INSERT INTO Clients2@site2_link(idclient, codeclient, societe, contact, adresse, ville, pays)
            VALUES (v_idclient, v_codeclient, v_societe, v_contact, v_adresse, v_ville, v_pays);
        END IF;
        IF v_idemploye IS NOT NULL THEN
            SELECT COUNT(*) INTO v_count FROM Employes2@site2_link WHERE idemploye = v_idemploye;
            IF v_count = 0 THEN
                INSERT INTO Employes2@site2_link(idemploye, nom, prenom, fonction)
                VALUES (v_idemploye, v_nom, v_prenom, v_fonction);
            END IF;
        END IF;
        SELECT COUNT(*) INTO v_count FROM Commandes2@site2_link WHERE idcommande = p_idcommande;
        IF v_count = 0 THEN
            INSERT INTO Commandes2@site2_link(idcommande, idclient, idemploye, datecommande)
            VALUES (p_idcommande, v_idclient, v_idemploye, v_datecommande);
        END IF;
    END ensure_parents_on_site2;

BEGIN
    -- MAIN TRIGGER LOGIC
    
    -- CASE 1: Stays on Site1 (old qty >= 100 AND new qty >= 100)
    IF :OLD.quantite >= 100 AND :NEW.quantite >= 100 THEN
        -- Simple update on Site1
        UPDATE LigneCommandes1@site1_link
        SET    idproduit = :NEW.idproduit,
               quantite  = :NEW.quantite,
               remise    = :NEW.remise
        WHERE  idlignecommande = :NEW.idlignecommande;

    -- CASE 2: Stays on Site2 (old qty < 100 AND new qty < 100)
    ELSIF :OLD.quantite < 100 AND :NEW.quantite < 100 THEN
        -- Simple update on Site2
        UPDATE LigneCommandes2@site2_link
        SET    idproduit = :NEW.idproduit,
               quantite  = :NEW.quantite,
               remise    = :NEW.remise
        WHERE  idlignecommande = :NEW.idlignecommande;

    -- CASE 3: Migration from Site1 to Site2 (old qty >= 100 AND new qty < 100)
    ELSIF :OLD.quantite >= 100 AND :NEW.quantite < 100 THEN
        -- Delete from Site1
        DELETE FROM LigneCommandes1@site1_link 
        WHERE idlignecommande = :OLD.idlignecommande;
        
        -- If no more items on this order at Site1, delete the order
        SELECT COUNT(*) INTO v_count FROM LigneCommandes1@site1_link 
        WHERE idcommande = :OLD.idcommande;
        IF v_count = 0 THEN
            DELETE FROM Commandes1@site1_link WHERE idcommande = :OLD.idcommande;
        END IF;

        -- Prepare parent data for Site2
        fetch_parent_data(:NEW.idcommande, :NEW.idproduit);
        
        -- Ensure all parents exist on Site2
        ensure_parents_on_site2(:NEW.idcommande, :NEW.idproduit);
        
        -- Insert on Site2
        INSERT INTO LigneCommandes2@site2_link(idlignecommande, idcommande, idproduit, quantite, remise)
        VALUES (:NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise);

    -- CASE 4: Migration from Site2 to Site1 (old qty < 100 AND new qty >= 100)
    ELSE
        -- Delete from Site2
        DELETE FROM LigneCommandes2@site2_link 
        WHERE idlignecommande = :OLD.idlignecommande;
        
        -- If no more items on this order at Site2, delete the order
        SELECT COUNT(*) INTO v_count FROM LigneCommandes2@site2_link 
        WHERE idcommande = :OLD.idcommande;
        IF v_count = 0 THEN
            DELETE FROM Commandes2@site2_link WHERE idcommande = :OLD.idcommande;
        END IF;

        -- Prepare parent data for Site1
        fetch_parent_data(:NEW.idcommande, :NEW.idproduit);
        
        -- Ensure all parents exist on Site1
        ensure_parents_on_site1(:NEW.idcommande, :NEW.idproduit);
        
        -- Insert on Site1
        INSERT INTO LigneCommandes1@site1_link(idlignecommande, idcommande, idproduit, quantite, remise)
        VALUES (:NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise);
    END IF;
END SYC_UPDATE_LIGNE;
```

### Execution Scenarios

**Scenario 1: Update quantity but stay on same site**

```
UPDATE lignecommandes SET quantite = 120 WHERE idlignecommande = 6001;
-- OLD: 150 >= 100 ✓
-- NEW: 120 >= 100 ✓
-- Action: Simple UPDATE on Site1
-- Result: quantity changed from 150 to 120 on Site1
```

**Scenario 2: Quantity drops below 100 (migrate from Site1 to Site2)**

```
UPDATE lignecommandes SET quantite = 80 WHERE idlignecommande = 6001;
-- OLD: 150 >= 100 ✓ (on Site1)
-- NEW: 80 < 100 ✓ (should be on Site2)
-- Action: 
--   1. DELETE from LigneCommandes1@site1_link
--   2. If order has no more items on Site1, DELETE order from Site1
--   3. Ensure parents exist on Site2
--   4. INSERT into LigneCommandes2@site2_link with new quantity
-- Result: Line migrated from Site1 to Site2
```

**Scenario 3: Quantity exceeds 100 (migrate from Site2 to Site1)**

```
UPDATE lignecommandes SET quantite = 150 WHERE idlignecommande = 6002;
-- OLD: 60 < 100 ✓ (on Site2)
-- NEW: 150 >= 100 ✓ (should be on Site1)
-- Action: Reverse of Scenario 2 - migrate from Site2 to Site1
-- Result: Line migrated from Site2 to Site1
```

---

## Trigger: SYC_DELETE_LIGNE

### What It Does

When an **order line item is deleted**, this trigger:
1. Detects which site the item was on (based on old quantity)
2. Deletes the line item from the appropriate remote site
3. Checks if the order still has items on that site
4. If no items left, deletes the order from that site (orphan cleanup)
5. Participates in 2PC transaction

### Full Trigger Code

```sql
CREATE OR REPLACE TRIGGER SYC_DELETE_LIGNE
AFTER DELETE ON LigneCommandes
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    -- CASE 1: Item was on Site1 (qty >= 100)
    IF :OLD.quantite >= 100 THEN
        -- Delete line item from Site1
        DELETE FROM LigneCommandes1@site1_link
        WHERE  idlignecommande = :OLD.idlignecommande;

        -- Check if order still has items on Site1
        SELECT COUNT(*) INTO v_count
        FROM   LigneCommandes1@site1_link
        WHERE  idcommande = :OLD.idcommande;

        -- If order has no more items on Site1, delete the order
        IF v_count = 0 THEN
            DELETE FROM Commandes1@site1_link 
            WHERE idcommande = :OLD.idcommande;
        END IF;

    -- CASE 2: Item was on Site2 (qty < 100)
    ELSE
        -- Delete line item from Site2
        DELETE FROM LigneCommandes2@site2_link
        WHERE  idlignecommande = :OLD.idlignecommande;

        -- Check if order still has items on Site2
        SELECT COUNT(*) INTO v_count
        FROM   LigneCommandes2@site2_link
        WHERE  idcommande = :OLD.idcommande;

        -- If order has no more items on Site2, delete the order
        IF v_count = 0 THEN
            DELETE FROM Commandes2@site2_link 
            WHERE idcommande = :OLD.idcommande;
        END IF;
    END IF;
END SYC_DELETE_LIGNE;
```

### Execution Example

**Delete a large item from Site1**

```
DELETE FROM lignecommandes WHERE idlignecommande = 6001;
-- OLD.quantite = 150 >= 100 → Was on Site1

TRIGGER EXECUTES:
├─ 1. DELETE FROM LigneCommandes1@site1_link WHERE idlignecommande = 6001
├─ 2. SELECT COUNT(*) FROM LigneCommandes1@site1_link WHERE idcommande = 5000
│     (Check if order 5000 still has items on Site1)
├─ 3a. IF count = 0:
│      DELETE FROM Commandes1@site1_link WHERE idcommande = 5000
│      (Orphan order cleanup - order has no items left)
└─ 3b. IF count > 0:
       Keep order on Site1 (order still has other items)

RESULT:
✓ Master DB: Line 6001 deleted
✓ Site1 DB:  Line 6001 deleted
✓ Site1 DB:  Order 5000 deleted IF it has no more items
✓ Site2 DB:  Unchanged (line was never there)
```

---

## How Triggers Work Together

### Complete Order Lifecycle

**Step 1: Order Creation**

```sql
INSERT INTO commandes (idcommande, idclient, datecommande) 
VALUES (20000, 1, SYSDATE);
-- No trigger (triggers are only on LIGNECOMMANDES)
-- Order created on master only
```

**Step 2: Add large volume item**

```sql
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (6001, 20000, 1, 150, 0);

-- SYC_INSERT_LIGNE fires:
-- ├─ Quantity 150 >= 100? YES
-- ├─ Route to Site1
-- ├─ Create order on Site1 (first time seeing this order)
-- └─ Create and insert line item on Site1
```

**Step 3: Add small volume item**

```sql
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
VALUES (6002, 20000, 2, 60, 0);

-- SYC_INSERT_LIGNE fires:
-- ├─ Quantity 60 < 100? YES
-- ├─ Route to Site2
-- ├─ Create order on Site2 (site2 sees this order for first time)
-- └─ Create and insert line item on Site2

RESULT AFTER BOTH INSERTS:
├─ Master:  Order 20000 with items 6001 (qty=150) and 6002 (qty=60)
├─ Site1:   Order 20000 with item 6001 (qty=150)
└─ Site2:   Order 20000 with item 6002 (qty=60)
```

**Step 4: Update item quantity (migration scenario)**

```sql
UPDATE lignecommandes SET quantite = 80 WHERE idlignecommande = 6001;

-- SYC_UPDATE_LIGNE fires:
-- ├─ OLD.quantite = 150 >= 100 (was on Site1)
-- ├─ NEW.quantite = 80 < 100 (should be on Site2)
-- ├─ Delete from Site1
-- ├─ Order 20000 still has items on Site1? NO (item 6001 was the only one)
-- ├─ Delete order from Site1
-- └─ Create on Site2 (if not exist) and insert item with new quantity

RESULT AFTER UPDATE:
├─ Master:  Order 20000 with items 6001 (qty=80) and 6002 (qty=60)
├─ Site1:   Order 20000 DELETED (no items left)
└─ Site2:   Order 20000 with items 6001 (qty=80) and 6002 (qty=60)
```

**Step 5: Delete item**

```sql
DELETE FROM lignecommandes WHERE idlignecommande = 6002;

-- SYC_DELETE_LIGNE fires:
-- ├─ OLD.quantite = 60 < 100 (was on Site2)
-- ├─ Delete from Site2
-- ├─ Order 20000 still has items on Site2? NO
-- └─ Delete order from Site2

RESULT AFTER DELETE:
├─ Master:  Order 20000 with only item 6001 (qty=80)
├─ Site1:   Order 20000 DELETED (no items)
└─ Site2:   Order 20000 DELETED (no items)
```

---

## Database Links Used

### Link Definitions

```sql
-- Link to Site1
CREATE DATABASE LINK site1_link
    CONNECT TO site1 IDENTIFIED BY site1123
    USING '(DESCRIPTION=
        (ADDRESS=(PROTOCOL=TCP)
                 (HOST=eshop_site1_db)
                 (PORT=1521))
        (CONNECT_DATA=
            (SERVICE_NAME=FREEPDB1)))';

-- Link to Site2
CREATE DATABASE LINK site2_link
    CONNECT TO site2 IDENTIFIED BY site2123
    USING '(DESCRIPTION=
        (ADDRESS=(PROTOCOL=TCP)
                 (HOST=eshop_site2_db)
                 (PORT=1521))
        (CONNECT_DATA=
            (SERVICE_NAME=FREEPDB1)))';
```

### How Links Are Used in Triggers

```sql
-- In triggers, queries to remote databases use @ notation:

-- Query remote table
SELECT * FROM LigneCommandes1@site1_link WHERE idcommande = 5000;

-- Insert to remote table
INSERT INTO Clients1@site1_link(idclient, codeclient, societe) 
VALUES (1, 'CLI001', 'TechCorp');

-- Update remote table
UPDATE LigneCommandes1@site1_link SET quantite = 200 WHERE idlignecommande = 1;

-- Delete from remote table
DELETE FROM Commandes1@site1_link WHERE idcommande = 5000;
```

---

## 2PC (Two-Phase Commit)

### How It Works in Our System

**Oracle automatically handles 2PC** when a trigger performs remote DML via database links.

### Transaction Flow

```
User INSERT into global_db → Phase 1: Prepare
                            └─ Trigger fires
                              └─ Remote INSERT via @site1_link
                                 ├─ Site1 acquires locks
                                 ├─ Site1 validates statement
                                 └─ Site1 returns OK (prepared)

                            Phase 2: Commit
                            ├─ Global DB commits
                            ├─ All remote sites commit
                            └─ All changes are final

EITHER ALL COMMIT OR ALL ROLLBACK (no partial updates)
```

### Atomicity Guarantee

**Example: What if Site1 is unreachable during commit?**

```
INSERT INTO lignecommandes VALUES (6001, 5000, 1, 150, 0);

Trigger executes:
  ├─ Master: INSERT line item ✓
  ├─ Site1:  INSERT order ✓
  ├─ Site1:  INSERT line item ✓
  └─ COMMIT?
      ├─ Master: ready to commit ✓
      ├─ Site1: ready to commit ✓
      └─ Network fails!
         └─ Oracle waits and retries
            └─ Once connection restored:
               ├─ Both commit, OR
               └─ Both rollback (if timeout)

RESULT: Either everything succeeds or nothing succeeds
        No partial states exist
```

### Exception Handling

If 2PC fails, the entire transaction rolls back:

```sql
-- This would fail if Site1 is unreachable:
BEGIN
    INSERT INTO lignecommandes VALUES (6001, 5000, 1, 150, 0);
    -- Trigger fires and tries to access Site1
    -- If Site1 unreachable → ORA-02049 or similar
    COMMIT;  -- Never reached if Site1 fails
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;  -- Everything rolled back (master + attempted remotes)
        RAISE;
END;
```

---

## Key Points for Teacher

### 1. **Automatic Fragmentation**
The triggers intelligently distribute data without any application logic. The database itself knows where to route each order line based on quantity.

### 2. **Transparent Replication**
From the application's perspective, there's only one master database. The triggers handle all replication silently.

### 3. **Consistency Guarantee**
2PC ensures that either the entire operation succeeds on all sites, or the entire operation fails. There's no middle ground with partial updates.

### 4. **Orphan Prevention**
The deletion trigger cleans up orders if they have no more line items, preventing orphaned records.

### 5. **Dynamic Migration**
If an item's quantity changes enough to cross the fragmentation threshold, it automatically migrates to the other site.

---

## Testing the Triggers

**Insert test (see fragmentation):**
```sql
INSERT INTO commandes (idcommande, idclient, datecommande) VALUES (20000, 1, SYSDATE);
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise) VALUES (6001, 20000, 1, 150, 0);
INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise) VALUES (6002, 20000, 2, 60, 5);

-- Check fragmentation:
SELECT * FROM site1.lignecommandes1@site1_link WHERE idcommande = 20000;  -- Should have 6001
SELECT * FROM site2.lignecommandes2@site2_link WHERE idcommande = 20000;  -- Should have 6002
```

**Update test (see migration):**
```sql
UPDATE lignecommandes SET quantite = 80 WHERE idlignecommande = 6001;

-- Check migration:
SELECT * FROM site1.lignecommandes1@site1_link WHERE idcommande = 20000;  -- Should be empty now
SELECT * FROM site2.lignecommandes2@site2_link WHERE idcommande = 20000;  -- Should now have 6001 AND 6002
```

**Delete test (see orphan cleanup):**
```sql
DELETE FROM lignecommandes WHERE idlignecommande = 6002;

-- Check cleanup:
SELECT * FROM site2.lignecommandes2@site2_link WHERE idcommande = 20000;  -- Should be empty
SELECT * FROM site2.commandes2@site2_link WHERE idcommande = 20000;      -- Order should be deleted too
```

---

**End of Trigger Documentation**

