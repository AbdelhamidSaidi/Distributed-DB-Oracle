-- ============================================================
-- TEST SUITE — ESHOP DISTRIBUTED
-- À exécuter depuis la base globale après docker compose up :
--
--   docker exec -it eshop_global_db sqlplus sys/oracle123@FREEPDB1 as sysdba
--   @/path/to/test_all_sites.sql
--
-- Détecte automatiquement le scénario actif (1 ou 2).
-- ============================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
CONNECT eshop/eshop123@localhost:1521/FREEPDB1

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF

DECLARE
    v_count    NUMBER;
    v_passed   PLS_INTEGER := 0;
    v_failed   PLS_INTEGER := 0;
    v_scenario PLS_INTEGER;

    PROCEDURE pass(p_label VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('  [PASS] ' || p_label);
        v_passed := v_passed + 1;
    END;

    PROCEDURE fail(p_label VARCHAR2, p_detail VARCHAR2 DEFAULT NULL) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('  [FAIL] ' || p_label
            || CASE WHEN p_detail IS NOT NULL THEN ' — ' || p_detail ELSE '' END);
        v_failed := v_failed + 1;
    END;

    PROCEDURE check_eq(p_label VARCHAR2, p_expected NUMBER, p_actual NUMBER) IS
    BEGIN
        IF p_expected = p_actual THEN pass(p_label);
        ELSE fail(p_label, 'attendu ' || p_expected || ', obtenu ' || p_actual);
        END IF;
    END;

    PROCEDURE section(p_title VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('--- ' || p_title || ' ---');
    END;

BEGIN
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE(' TEST SUITE — ESHOP DISTRIBUTED');
    DBMS_OUTPUT.PUT_LINE('=======================================================');

    -- Détection du scénario actif :
    -- En scénario 2, Site1 reçoit toute ligne avec quantite >= 100,
    -- y compris les catégories 10 et 20. En scénario 1, Site1 ne
    -- reçoit que idcateg=50 AND quantite>100 — jamais idcateg=10.
    SELECT COUNT(*) INTO v_count
    FROM   LigneCommandes1@site1_link lc
    JOIN   Produits1@site1_link p ON p.idproduit = lc.idproduit
    WHERE  p.idcateg = 10;

    v_scenario := CASE WHEN v_count > 0 THEN 2 ELSE 1 END;
    DBMS_OUTPUT.PUT_LINE(' Scénario détecté : ' || v_scenario);

    -- ========================================================
    -- 1. BASE GLOBALE
    -- ========================================================
    section('1. BASE GLOBALE');

    SELECT COUNT(*) INTO v_count FROM Categories;
    check_eq('Categories        : 4 lignes', 4, v_count);

    SELECT COUNT(*) INTO v_count FROM Produits;
    check_eq('Produits          : 7 lignes', 7, v_count);

    SELECT COUNT(*) INTO v_count FROM Clients;
    check_eq('Clients           : 5 lignes', 5, v_count);

    SELECT COUNT(*) INTO v_count FROM Employes;
    check_eq('Employes          : 2 lignes', 2, v_count);

    SELECT COUNT(*) INTO v_count FROM Commandes;
    check_eq('Commandes         : 10 lignes', 10, v_count);

    SELECT COUNT(*) INTO v_count FROM LigneCommandes;
    check_eq('LigneCommandes    : 14 lignes', 14, v_count);

    -- ========================================================
    -- 2. SITE 1
    -- ========================================================
    section('2. SITE 1');

    IF v_scenario = 2 THEN
        -- LC 1,2,4,5,10,12,14 ont quantite >= 100 → 7 lignes
        SELECT COUNT(*) INTO v_count FROM LigneCommandes1@site1_link;
        check_eq('LigneCommandes    : 7 lignes (quantite >= 100)', 7, v_count);

        SELECT COUNT(*) INTO v_count FROM LigneCommandes1@site1_link WHERE quantite < 100;
        check_eq('Aucune ligne avec quantite < 100', 0, v_count);
    ELSE
        -- LC 1,2,4,5 ont idcateg=50 AND quantite>100 → 4 lignes
        SELECT COUNT(*) INTO v_count FROM LigneCommandes1@site1_link;
        check_eq('LigneCommandes    : 4 lignes (idcateg=50 AND quantite>100)', 4, v_count);

        SELECT COUNT(*) INTO v_count
        FROM   LigneCommandes1@site1_link lc
        JOIN   Produits1@site1_link p ON p.idproduit = lc.idproduit
        WHERE  p.idcateg <> 50 OR lc.quantite <= 100;
        check_eq('Toutes les lignes vérifient idcateg=50 AND quantite>100', 0, v_count);
    END IF;

    SELECT COUNT(*) INTO v_count FROM Commandes1@site1_link;
    IF v_count > 0 THEN pass('Commandes propagées (' || v_count || ' lignes)');
    ELSE fail('Aucune Commande propagée sur Site1');
    END IF;

    SELECT COUNT(*) INTO v_count FROM Produits1@site1_link;
    IF v_count > 0 THEN pass('Produits propagés (' || v_count || ' lignes)');
    ELSE fail('Aucun Produit propagé sur Site1');
    END IF;

    SELECT COUNT(*) INTO v_count FROM Clients1@site1_link;
    IF v_count > 0 THEN pass('Clients propagés (' || v_count || ' lignes)');
    ELSE fail('Aucun Client propagé sur Site1');
    END IF;

    -- ========================================================
    -- 3. SITE 2
    -- ========================================================
    section('3. SITE 2');

    IF v_scenario = 2 THEN
        -- LC 3,6,7,8,9,11,13 ont quantite < 100 → 7 lignes
        SELECT COUNT(*) INTO v_count FROM LigneCommandes2@site2_link;
        check_eq('LigneCommandes    : 7 lignes (quantite < 100)', 7, v_count);

        SELECT COUNT(*) INTO v_count FROM LigneCommandes2@site2_link WHERE quantite >= 100;
        check_eq('Aucune ligne avec quantite >= 100', 0, v_count);
    ELSE
        -- LC 6,7,9 ont idcateg=35 AND quantite>50 → 3 lignes
        SELECT COUNT(*) INTO v_count FROM LigneCommandes2@site2_link;
        check_eq('LigneCommandes    : 3 lignes (idcateg=35 AND quantite>50)', 3, v_count);

        SELECT COUNT(*) INTO v_count
        FROM   LigneCommandes2@site2_link lc
        JOIN   Produits2@site2_link p ON p.idproduit = lc.idproduit
        WHERE  p.idcateg <> 35 OR lc.quantite <= 50;
        check_eq('Toutes les lignes vérifient idcateg=35 AND quantite>50', 0, v_count);
    END IF;

    SELECT COUNT(*) INTO v_count FROM Commandes2@site2_link;
    IF v_count > 0 THEN pass('Commandes propagées (' || v_count || ' lignes)');
    ELSE fail('Aucune Commande propagée sur Site2');
    END IF;

    SELECT COUNT(*) INTO v_count FROM Produits2@site2_link;
    IF v_count > 0 THEN pass('Produits propagés (' || v_count || ' lignes)');
    ELSE fail('Aucun Produit propagé sur Site2');
    END IF;

    SELECT COUNT(*) INTO v_count FROM Clients2@site2_link;
    IF v_count > 0 THEN pass('Clients propagés (' || v_count || ' lignes)');
    ELSE fail('Aucun Client propagé sur Site2');
    END IF;

    -- ========================================================
    -- 4. PROCEDURES — SITE 1
    -- ========================================================
    section('4. PROCEDURES — Site1');

    -- insertligne : LC 999 sur commande 1, produit 1 (présents sur Site1)
    BEGIN
        insertligne@site1_link(999, 1, 1, 150, 0);
        SELECT COUNT(*) INTO v_count FROM LigneCommandes1@site1_link WHERE idlignecommande = 999;
        check_eq('insertligne — ligne insérée', 1, v_count);
    EXCEPTION WHEN OTHERS THEN
        fail('insertligne@site1_link', SQLERRM);
    END;

    -- updateligne : modifier quantite et remise
    BEGIN
        updateligne@site1_link(999, 1, 200, 5);
        SELECT quantite INTO v_count FROM LigneCommandes1@site1_link WHERE idlignecommande = 999;
        check_eq('updateligne — quantite mise à jour à 200', 200, v_count);
    EXCEPTION WHEN OTHERS THEN
        fail('updateligne@site1_link', SQLERRM);
    END;

    -- deleteligne : supprimer la ligne de test
    BEGIN
        deleteligne@site1_link(999);
        SELECT COUNT(*) INTO v_count FROM LigneCommandes1@site1_link WHERE idlignecommande = 999;
        check_eq('deleteligne — ligne supprimée', 0, v_count);
    EXCEPTION WHEN OTHERS THEN
        fail('deleteligne@site1_link', SQLERRM);
    END;

    -- ========================================================
    -- 5. PROCEDURES — SITE 2
    -- ========================================================
    section('5. PROCEDURES — Site2');

    DECLARE
        v_idcommande Commandes2.idcommande%TYPE;
        v_idproduit  Produits2.idproduit%TYPE;
    BEGIN
        SELECT MIN(idcommande) INTO v_idcommande FROM Commandes2@site2_link;
        SELECT MIN(idproduit)  INTO v_idproduit  FROM Produits2@site2_link;

        insertligne@site2_link(998, v_idcommande, v_idproduit, 10, 0);
        SELECT COUNT(*) INTO v_count FROM LigneCommandes2@site2_link WHERE idlignecommande = 998;
        check_eq('insertligne — ligne insérée', 1, v_count);

        updateligne@site2_link(998, v_idproduit, 20, 2);
        SELECT quantite INTO v_count FROM LigneCommandes2@site2_link WHERE idlignecommande = 998;
        check_eq('updateligne — quantite mise à jour à 20', 20, v_count);

        deleteligne@site2_link(998);
        SELECT COUNT(*) INTO v_count FROM LigneCommandes2@site2_link WHERE idlignecommande = 998;
        check_eq('deleteligne — ligne supprimée', 0, v_count);
    EXCEPTION WHEN OTHERS THEN
        fail('Procedures Site2', SQLERRM);
    END;

    -- ========================================================
    -- 6. TRIGGER SYC_INSERT_LIGNE
    -- ========================================================
    section('6. TRIGGER — SYC_INSERT_LIGNE');

    BEGIN
        -- INSERT dans la base globale → trigger propage vers le bon site
        -- idproduit=1 (idcateg=50), quantite=200 → Site1 dans les deux scénarios
        INSERT INTO LigneCommandes VALUES (997, 1, 1, 200, 0);

        SELECT COUNT(*) INTO v_count FROM LigneCommandes1@site1_link WHERE idlignecommande = 997;
        check_eq('LC 997 propagée vers Site1', 1, v_count);

        SELECT COUNT(*) INTO v_count FROM LigneCommandes2@site2_link WHERE idlignecommande = 997;
        check_eq('LC 997 absente de Site2', 0, v_count);

        DELETE FROM LigneCommandes WHERE idlignecommande = 997;
        COMMIT;
    EXCEPTION WHEN OTHERS THEN
        fail('SYC_INSERT_LIGNE', SQLERRM);
        ROLLBACK;
    END;

    -- ========================================================
    -- 7. TRIGGER SYC_DELETE_LIGNE
    -- ========================================================
    section('7. TRIGGER — SYC_DELETE_LIGNE');

    BEGIN
        -- Insérer puis supprimer via la base globale
        INSERT INTO LigneCommandes VALUES (996, 1, 1, 200, 0);
        COMMIT;

        SELECT COUNT(*) INTO v_count FROM LigneCommandes1@site1_link WHERE idlignecommande = 996;
        check_eq('LC 996 présente sur Site1 avant DELETE', 1, v_count);

        DELETE FROM LigneCommandes WHERE idlignecommande = 996;
        COMMIT;

        SELECT COUNT(*) INTO v_count FROM LigneCommandes1@site1_link WHERE idlignecommande = 996;
        check_eq('LC 996 retirée de Site1 après DELETE', 0, v_count);
    EXCEPTION WHEN OTHERS THEN
        fail('SYC_DELETE_LIGNE', SQLERRM);
        ROLLBACK;
    END;

    -- ========================================================
    -- 8. TRIGGER SYC_UPDATE_LIGNE — migration (scénario 2 uniquement)
    -- ========================================================
    IF v_scenario = 2 THEN
        section('8. TRIGGER — SYC_UPDATE_LIGNE (migration)');

        BEGIN
            -- LC 1 est sur Site1 (quantite=150) ; passer à 50 → doit migrer vers Site2
            UPDATE LigneCommandes SET quantite = 50 WHERE idlignecommande = 1;

            SELECT COUNT(*) INTO v_count FROM LigneCommandes1@site1_link WHERE idlignecommande = 1;
            check_eq('LC 1 retirée de Site1 (q=50)', 0, v_count);

            SELECT COUNT(*) INTO v_count FROM LigneCommandes2@site2_link WHERE idlignecommande = 1;
            check_eq('LC 1 arrivée sur Site2 (q=50)', 1, v_count);

            -- Remettre en place : q=150 → retour sur Site1
            UPDATE LigneCommandes SET quantite = 150 WHERE idlignecommande = 1;

            SELECT COUNT(*) INTO v_count FROM LigneCommandes1@site1_link WHERE idlignecommande = 1;
            check_eq('LC 1 revenue sur Site1 (q=150)', 1, v_count);

            SELECT COUNT(*) INTO v_count FROM LigneCommandes2@site2_link WHERE idlignecommande = 1;
            check_eq('LC 1 retirée de Site2 (q=150)', 0, v_count);

            COMMIT;
        EXCEPTION WHEN OTHERS THEN
            fail('SYC_UPDATE_LIGNE migration', SQLERRM);
            ROLLBACK;
        END;
    END IF;

    -- ========================================================
    -- RÉSUMÉ
    -- ========================================================
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE(' ' || v_passed || ' passed   ' || v_failed || ' failed');
    DBMS_OUTPUT.PUT_LINE('=======================================================');
END;
/

EXIT;
