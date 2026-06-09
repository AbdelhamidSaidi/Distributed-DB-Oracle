ALTER SESSION SET CONTAINER = FREEPDB1;

CONNECT site1/site1123@localhost:1521/FREEPDB1

-- ============================================================
-- PROCEDURE insertligne
-- Inserts a row into LigneCommandes1.
-- Verifies that idcommande and idproduit exist before inserting.
-- ============================================================
CREATE OR REPLACE PROCEDURE insertligne(
    p_idlignecommande IN LigneCommandes1.idlignecommande%TYPE,
    p_idcommande      IN LigneCommandes1.idcommande%TYPE,
    p_idproduit       IN LigneCommandes1.idproduit%TYPE,
    p_quantite        IN LigneCommandes1.quantite%TYPE,
    p_remise          IN LigneCommandes1.remise%TYPE DEFAULT 0
) AS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM Commandes1 WHERE idcommande = p_idcommande;
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Commande introuvable dans Site1 : ' || p_idcommande);
    END IF;

    SELECT COUNT(*) INTO v_count FROM Produits1 WHERE idproduit = p_idproduit;
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Produit introuvable dans Site1 : ' || p_idproduit);
    END IF;

    INSERT INTO LigneCommandes1(idlignecommande, idcommande, idproduit, quantite, remise)
    VALUES (p_idlignecommande, p_idcommande, p_idproduit, p_quantite, p_remise);

    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20003, 'idLigneCommande deja utilise : ' || p_idlignecommande);
END insertligne;
/

-- ============================================================
-- PROCEDURE deleteligne
-- Deletes a LigneCommandes1 row by its PK.
-- If the parent Commande has no remaining lines after deletion,
-- the Commande is also deleted (cascade-up cleanup).
-- ============================================================
CREATE OR REPLACE PROCEDURE deleteligne(
    p_idlignecommande IN LigneCommandes1.idlignecommande%TYPE
) AS
    v_idcommande LigneCommandes1.idcommande%TYPE;
    v_count      NUMBER;
BEGIN
    -- Retrieve parent commande before deleting
    SELECT idcommande INTO v_idcommande
    FROM LigneCommandes1
    WHERE idlignecommande = p_idlignecommande;

    DELETE FROM LigneCommandes1 WHERE idlignecommande = p_idlignecommande;

    -- If the parent commande now has no remaining lines, delete it too
    SELECT COUNT(*) INTO v_count
    FROM LigneCommandes1
    WHERE idcommande = v_idcommande;

    IF v_count = 0 THEN
        DELETE FROM Commandes1 WHERE idcommande = v_idcommande;
    END IF;

    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20004, 'LigneCommande introuvable dans Site1 : ' || p_idlignecommande);
END deleteligne;
/

-- ============================================================
-- PROCEDURE updateligne
-- Updates idproduit, quantite and remise for a given ligne.
-- Verifies the new idproduit exists in Produits1.
-- ============================================================
CREATE OR REPLACE PROCEDURE updateligne(
    p_idlignecommande IN LigneCommandes1.idlignecommande%TYPE,
    p_idproduit       IN LigneCommandes1.idproduit%TYPE,
    p_quantite        IN LigneCommandes1.quantite%TYPE,
    p_remise          IN LigneCommandes1.remise%TYPE
) AS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM LigneCommandes1 WHERE idlignecommande = p_idlignecommande;
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'LigneCommande introuvable dans Site1 : ' || p_idlignecommande);
    END IF;

    SELECT COUNT(*) INTO v_count FROM Produits1 WHERE idproduit = p_idproduit;
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Produit introuvable dans Site1 : ' || p_idproduit);
    END IF;

    UPDATE LigneCommandes1
    SET    idproduit = p_idproduit,
           quantite  = p_quantite,
           remise    = p_remise
    WHERE  idlignecommande = p_idlignecommande;

    COMMIT;
END updateligne;
/

EXIT;
