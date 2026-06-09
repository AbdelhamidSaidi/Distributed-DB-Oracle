ALTER SESSION SET CONTAINER = FREEPDB1;

CONNECT site2/site2123@localhost:1521/FREEPDB1

-- ============================================================
-- PROCEDURE insertligne
-- ============================================================
CREATE OR REPLACE PROCEDURE insertligne(
    p_idlignecommande IN LigneCommandes2.idlignecommande%TYPE,
    p_idcommande      IN LigneCommandes2.idcommande%TYPE,
    p_idproduit       IN LigneCommandes2.idproduit%TYPE,
    p_quantite        IN LigneCommandes2.quantite%TYPE,
    p_remise          IN LigneCommandes2.remise%TYPE DEFAULT 0
) AS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM Commandes2 WHERE idcommande = p_idcommande;
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Commande introuvable dans Site2 : ' || p_idcommande);
    END IF;

    SELECT COUNT(*) INTO v_count FROM Produits2 WHERE idproduit = p_idproduit;
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Produit introuvable dans Site2 : ' || p_idproduit);
    END IF;

    INSERT INTO LigneCommandes2(idlignecommande, idcommande, idproduit, quantite, remise)
    VALUES (p_idlignecommande, p_idcommande, p_idproduit, p_quantite, p_remise);

    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20003, 'idLigneCommande deja utilise : ' || p_idlignecommande);
END insertligne;
/

-- ============================================================
-- PROCEDURE deleteligne
-- ============================================================
CREATE OR REPLACE PROCEDURE deleteligne(
    p_idlignecommande IN LigneCommandes2.idlignecommande%TYPE
) AS
    v_idcommande LigneCommandes2.idcommande%TYPE;
    v_count      NUMBER;
BEGIN
    SELECT idcommande INTO v_idcommande
    FROM LigneCommandes2
    WHERE idlignecommande = p_idlignecommande;

    DELETE FROM LigneCommandes2 WHERE idlignecommande = p_idlignecommande;

    SELECT COUNT(*) INTO v_count
    FROM LigneCommandes2
    WHERE idcommande = v_idcommande;

    IF v_count = 0 THEN
        DELETE FROM Commandes2 WHERE idcommande = v_idcommande;
    END IF;

    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20004, 'LigneCommande introuvable dans Site2 : ' || p_idlignecommande);
END deleteligne;
/

-- ============================================================
-- PROCEDURE updateligne
-- ============================================================
CREATE OR REPLACE PROCEDURE updateligne(
    p_idlignecommande IN LigneCommandes2.idlignecommande%TYPE,
    p_idproduit       IN LigneCommandes2.idproduit%TYPE,
    p_quantite        IN LigneCommandes2.quantite%TYPE,
    p_remise          IN LigneCommandes2.remise%TYPE
) AS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM LigneCommandes2 WHERE idlignecommande = p_idlignecommande;
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'LigneCommande introuvable dans Site2 : ' || p_idlignecommande);
    END IF;

    SELECT COUNT(*) INTO v_count FROM Produits2 WHERE idproduit = p_idproduit;
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Produit introuvable dans Site2 : ' || p_idproduit);
    END IF;

    UPDATE LigneCommandes2
    SET    idproduit = p_idproduit,
           quantite  = p_quantite,
           remise    = p_remise
    WHERE  idlignecommande = p_idlignecommande;

    COMMIT;
END updateligne;
/

EXIT;
