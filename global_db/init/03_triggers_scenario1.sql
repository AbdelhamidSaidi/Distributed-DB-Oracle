-- ============================================================
-- TRIGGERS DE SYNCHRONISATION — SCENARIO 1
-- Fragmentation horizontale par catégorie :
--   R1 → Site1 : idcateg = 50 AND quantite > 100
--   R2 → Site2 : idcateg = 35 AND quantite > 50
--
-- Fragmentation PARTIELLE : les lignes ne vérifiant ni R1 ni R2
-- restent uniquement dans la base globale (non distribuées).
--
-- Le trigger UPDATE gère aussi les transitions :
--   - ligne qui entre dans un fragment (ex : changement de produit)
--   - ligne qui sort d'un fragment
--   - migration entre les deux fragments
-- ============================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
CONNECT eshop/eshop123@localhost:1521/FREEPDB1

-- ==================================================================
-- SYC_INSERT_LIGNE
-- ==================================================================
CREATE OR REPLACE TRIGGER SYC_INSERT_LIGNE
AFTER INSERT ON LigneCommandes
FOR EACH ROW
DECLARE
    v_count        NUMBER;
    v_idcateg      Produits.idcateg%TYPE;
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
    v_designation  Produits.designation%TYPE;
    v_prixunitaire Produits.prixunitaire%TYPE;
    v_nomcateg     Categories.nomcateg%TYPE;

    PROCEDURE push_to_site1(
        p_idlignecommande IN NUMBER,
        p_idcommande      IN NUMBER,
        p_idproduit       IN NUMBER,
        p_quantite        IN NUMBER,
        p_remise          IN NUMBER
    ) IS
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Categories1@site1_link WHERE idcateg = v_idcateg;
        IF v_count = 0 THEN
            INSERT INTO Categories1@site1_link(idcateg, nomcateg) VALUES (v_idcateg, v_nomcateg);
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
        INSERT INTO LigneCommandes1@site1_link(idlignecommande, idcommande, idproduit, quantite, remise)
        VALUES (p_idlignecommande, p_idcommande, p_idproduit, p_quantite, p_remise);
    END push_to_site1;

    PROCEDURE push_to_site2(
        p_idlignecommande IN NUMBER,
        p_idcommande      IN NUMBER,
        p_idproduit       IN NUMBER,
        p_quantite        IN NUMBER,
        p_remise          IN NUMBER
    ) IS
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Categories2@site2_link WHERE idcateg = v_idcateg;
        IF v_count = 0 THEN
            INSERT INTO Categories2@site2_link(idcateg, nomcateg) VALUES (v_idcateg, v_nomcateg);
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
        INSERT INTO LigneCommandes2@site2_link(idlignecommande, idcommande, idproduit, quantite, remise)
        VALUES (p_idlignecommande, p_idcommande, p_idproduit, p_quantite, p_remise);
    END push_to_site2;

BEGIN
    SELECT idcateg, designation, prixunitaire
    INTO   v_idcateg, v_designation, v_prixunitaire
    FROM   Produits WHERE idproduit = :NEW.idproduit;

    SELECT nomcateg INTO v_nomcateg FROM Categories WHERE idcateg = v_idcateg;

    -- Vérifier si la ligne appartient à un fragment
    IF NOT (v_idcateg = 50 AND :NEW.quantite > 100)
       AND NOT (v_idcateg = 35 AND :NEW.quantite > 50)
    THEN
        RETURN; -- Fragmentation partielle : ligne non distribuée
    END IF;

    SELECT idclient, idemploye, datecommande
    INTO   v_idclient, v_idemploye, v_datecommande
    FROM   Commandes WHERE idcommande = :NEW.idcommande;

    SELECT codeclient, societe, contact, adresse, ville, pays
    INTO   v_codeclient, v_societe, v_contact, v_adresse, v_ville, v_pays
    FROM   Clients WHERE idclient = v_idclient;

    IF v_idemploye IS NOT NULL THEN
        SELECT nom, prenom, fonction INTO v_nom, v_prenom, v_fonction
        FROM   Employes WHERE idemploye = v_idemploye;
    END IF;

    IF v_idcateg = 50 AND :NEW.quantite > 100 THEN
        push_to_site1(:NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise);
    ELSE
        push_to_site2(:NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise);
    END IF;
END SYC_INSERT_LIGNE;
/

-- ==================================================================
-- SYC_DELETE_LIGNE
-- ==================================================================
CREATE OR REPLACE TRIGGER SYC_DELETE_LIGNE
AFTER DELETE ON LigneCommandes
FOR EACH ROW
DECLARE
    v_count   NUMBER;
    v_idcateg Produits.idcateg%TYPE;
BEGIN
    SELECT idcateg INTO v_idcateg FROM Produits WHERE idproduit = :OLD.idproduit;

    IF v_idcateg = 50 AND :OLD.quantite > 100 THEN
        DELETE FROM LigneCommandes1@site1_link WHERE idlignecommande = :OLD.idlignecommande;
        SELECT COUNT(*) INTO v_count FROM LigneCommandes1@site1_link WHERE idcommande = :OLD.idcommande;
        IF v_count = 0 THEN
            DELETE FROM Commandes1@site1_link WHERE idcommande = :OLD.idcommande;
        END IF;

    ELSIF v_idcateg = 35 AND :OLD.quantite > 50 THEN
        DELETE FROM LigneCommandes2@site2_link WHERE idlignecommande = :OLD.idlignecommande;
        SELECT COUNT(*) INTO v_count FROM LigneCommandes2@site2_link WHERE idcommande = :OLD.idcommande;
        IF v_count = 0 THEN
            DELETE FROM Commandes2@site2_link WHERE idcommande = :OLD.idcommande;
        END IF;
    -- else : ligne non distribuée, rien à faire sur les sites
    END IF;
END SYC_DELETE_LIGNE;
/

-- ==================================================================
-- SYC_UPDATE_LIGNE
-- Gère 6 transitions possibles :
--   (1,1) reste Site1  (2,2) reste Site2
--   (1,2) migre vers Site2  (2,1) migre vers Site1
--   (x,0) sort de la distribution  (0,x) entre en distribution
-- ==================================================================
CREATE OR REPLACE TRIGGER SYC_UPDATE_LIGNE
AFTER UPDATE ON LigneCommandes
FOR EACH ROW
DECLARE
    v_count          NUMBER;
    v_old_idcateg    Produits.idcateg%TYPE;
    v_new_idcateg    Produits.idcateg%TYPE;
    v_old_site       NUMBER; -- 0=non distribué, 1=Site1, 2=Site2
    v_new_site       NUMBER;
    v_idclient       Commandes.idclient%TYPE;
    v_idemploye      Commandes.idemploye%TYPE;
    v_datecommande   Commandes.datecommande%TYPE;
    v_codeclient     Clients.codeclient%TYPE;
    v_societe        Clients.societe%TYPE;
    v_contact        Clients.contact%TYPE;
    v_adresse        Clients.adresse%TYPE;
    v_ville          Clients.ville%TYPE;
    v_pays           Clients.pays%TYPE;
    v_nom            Employes.nom%TYPE;
    v_prenom         Employes.prenom%TYPE;
    v_fonction       Employes.fonction%TYPE;
    v_designation    Produits.designation%TYPE;
    v_prixunitaire   Produits.prixunitaire%TYPE;
    v_nomcateg       Categories.nomcateg%TYPE;

    PROCEDURE fetch_parent_data(p_idcommande IN NUMBER, p_idproduit IN NUMBER) IS
    BEGIN
        SELECT idclient, idemploye, datecommande
        INTO   v_idclient, v_idemploye, v_datecommande
        FROM   Commandes WHERE idcommande = p_idcommande;

        SELECT codeclient, societe, contact, adresse, ville, pays
        INTO   v_codeclient, v_societe, v_contact, v_adresse, v_ville, v_pays
        FROM   Clients WHERE idclient = v_idclient;

        SELECT idcateg, designation, prixunitaire
        INTO   v_new_idcateg, v_designation, v_prixunitaire
        FROM   Produits WHERE idproduit = p_idproduit;

        SELECT nomcateg INTO v_nomcateg FROM Categories WHERE idcateg = v_new_idcateg;

        IF v_idemploye IS NOT NULL THEN
            SELECT nom, prenom, fonction INTO v_nom, v_prenom, v_fonction
            FROM   Employes WHERE idemploye = v_idemploye;
        END IF;
    END fetch_parent_data;

    PROCEDURE ensure_parents_on_site1(p_idcommande IN NUMBER, p_idproduit IN NUMBER) IS
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Categories1@site1_link WHERE idcateg = v_new_idcateg;
        IF v_count = 0 THEN
            INSERT INTO Categories1@site1_link(idcateg, nomcateg) VALUES (v_new_idcateg, v_nomcateg);
        END IF;
        SELECT COUNT(*) INTO v_count FROM Produits1@site1_link WHERE idproduit = p_idproduit;
        IF v_count = 0 THEN
            INSERT INTO Produits1@site1_link(idproduit, idcateg, designation, prixunitaire)
            VALUES (p_idproduit, v_new_idcateg, v_designation, v_prixunitaire);
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

    PROCEDURE ensure_parents_on_site2(p_idcommande IN NUMBER, p_idproduit IN NUMBER) IS
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Categories2@site2_link WHERE idcateg = v_new_idcateg;
        IF v_count = 0 THEN
            INSERT INTO Categories2@site2_link(idcateg, nomcateg) VALUES (v_new_idcateg, v_nomcateg);
        END IF;
        SELECT COUNT(*) INTO v_count FROM Produits2@site2_link WHERE idproduit = p_idproduit;
        IF v_count = 0 THEN
            INSERT INTO Produits2@site2_link(idproduit, idcateg, designation, prixunitaire)
            VALUES (p_idproduit, v_new_idcateg, v_designation, v_prixunitaire);
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

    -- Supprime la ligne de l'ancien site avec cascade-up sur la Commande
    PROCEDURE delete_from_site1(p_idlignecommande IN NUMBER, p_idcommande IN NUMBER) IS
    BEGIN
        DELETE FROM LigneCommandes1@site1_link WHERE idlignecommande = p_idlignecommande;
        SELECT COUNT(*) INTO v_count FROM LigneCommandes1@site1_link WHERE idcommande = p_idcommande;
        IF v_count = 0 THEN
            DELETE FROM Commandes1@site1_link WHERE idcommande = p_idcommande;
        END IF;
    END delete_from_site1;

    PROCEDURE delete_from_site2(p_idlignecommande IN NUMBER, p_idcommande IN NUMBER) IS
    BEGIN
        DELETE FROM LigneCommandes2@site2_link WHERE idlignecommande = p_idlignecommande;
        SELECT COUNT(*) INTO v_count FROM LigneCommandes2@site2_link WHERE idcommande = p_idcommande;
        IF v_count = 0 THEN
            DELETE FROM Commandes2@site2_link WHERE idcommande = p_idcommande;
        END IF;
    END delete_from_site2;

BEGIN
    -- Déterminer l'ancien et le nouveau site
    SELECT idcateg INTO v_old_idcateg FROM Produits WHERE idproduit = :OLD.idproduit;
    SELECT idcateg INTO v_new_idcateg FROM Produits WHERE idproduit = :NEW.idproduit;

    IF    v_old_idcateg = 50 AND :OLD.quantite > 100 THEN v_old_site := 1;
    ELSIF v_old_idcateg = 35 AND :OLD.quantite > 50  THEN v_old_site := 2;
    ELSE  v_old_site := 0;
    END IF;

    IF    v_new_idcateg = 50 AND :NEW.quantite > 100 THEN v_new_site := 1;
    ELSIF v_new_idcateg = 35 AND :NEW.quantite > 50  THEN v_new_site := 2;
    ELSE  v_new_site := 0;
    END IF;

    -- Gérer les 6 transitions significatives
    IF v_old_site = 1 AND v_new_site = 1 THEN
        UPDATE LigneCommandes1@site1_link
        SET idproduit=:NEW.idproduit, quantite=:NEW.quantite, remise=:NEW.remise
        WHERE idlignecommande=:NEW.idlignecommande;

    ELSIF v_old_site = 2 AND v_new_site = 2 THEN
        UPDATE LigneCommandes2@site2_link
        SET idproduit=:NEW.idproduit, quantite=:NEW.quantite, remise=:NEW.remise
        WHERE idlignecommande=:NEW.idlignecommande;

    ELSIF v_old_site = 1 AND v_new_site = 2 THEN
        -- Migration Site1 → Site2
        delete_from_site1(:OLD.idlignecommande, :OLD.idcommande);
        fetch_parent_data(:NEW.idcommande, :NEW.idproduit);
        ensure_parents_on_site2(:NEW.idcommande, :NEW.idproduit);
        INSERT INTO LigneCommandes2@site2_link(idlignecommande, idcommande, idproduit, quantite, remise)
        VALUES (:NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise);

    ELSIF v_old_site = 2 AND v_new_site = 1 THEN
        -- Migration Site2 → Site1
        delete_from_site2(:OLD.idlignecommande, :OLD.idcommande);
        fetch_parent_data(:NEW.idcommande, :NEW.idproduit);
        ensure_parents_on_site1(:NEW.idcommande, :NEW.idproduit);
        INSERT INTO LigneCommandes1@site1_link(idlignecommande, idcommande, idproduit, quantite, remise)
        VALUES (:NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise);

    ELSIF v_old_site IN (1, 2) AND v_new_site = 0 THEN
        -- La ligne sort de la distribution
        IF v_old_site = 1 THEN delete_from_site1(:OLD.idlignecommande, :OLD.idcommande);
        ELSE                   delete_from_site2(:OLD.idlignecommande, :OLD.idcommande);
        END IF;

    ELSIF v_old_site = 0 AND v_new_site IN (1, 2) THEN
        -- La ligne entre en distribution
        fetch_parent_data(:NEW.idcommande, :NEW.idproduit);
        IF v_new_site = 1 THEN
            ensure_parents_on_site1(:NEW.idcommande, :NEW.idproduit);
            INSERT INTO LigneCommandes1@site1_link(idlignecommande, idcommande, idproduit, quantite, remise)
            VALUES (:NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise);
        ELSE
            ensure_parents_on_site2(:NEW.idcommande, :NEW.idproduit);
            INSERT INTO LigneCommandes2@site2_link(idlignecommande, idcommande, idproduit, quantite, remise)
            VALUES (:NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise);
        END IF;
    -- else : v_old_site=0 AND v_new_site=0, ligne toujours non distribuée
    END IF;
END SYC_UPDATE_LIGNE;
/

EXIT;
