-- ============================================================
-- TRIGGERS DE SYNCHRONISATION — SCENARIO 2
-- Fragmentation horizontale par volume :
--   Site1 : quantite >= 100  (gros volumes)
--   Site2 : quantite <  100  (petits volumes)
--
-- Les triggers s'exécutent dans la transaction principale.
-- Le DML distant via DB Link participe à la transaction distribuée
-- Oracle (2PC), garantissant l'atomicité global_db + sites.
-- ============================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
CONNECT eshop/eshop123@localhost:1521/FREEPDB1

-- ==================================================================
-- SYC_INSERT_LIGNE
-- Propage l'INSERT vers le site cible et crée les enregistrements
-- parents (Categorie, Produit, Client, Employe, Commande) sur ce
-- site s'ils n'y existent pas encore.
-- ==================================================================
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

    -- Note: :NEW ne peut pas être référencé à l'intérieur d'une
    -- sous-procédure locale ; les valeurs sont passées en paramètre.
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

        INSERT INTO LigneCommandes2@site2_link(idlignecommande, idcommande, idproduit, quantite, remise)
        VALUES (p_idlignecommande, p_idcommande, p_idproduit, p_quantite, p_remise);
    END push_to_site2;

BEGIN
    -- Récupérer toutes les données parentes depuis la base globale
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

    -- Routage selon le critère de fragmentation
    IF :NEW.quantite >= 100 THEN
        push_to_site1(:NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise);
    ELSE
        push_to_site2(:NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise);
    END IF;
END SYC_INSERT_LIGNE;
/

-- ==================================================================
-- SYC_DELETE_LIGNE
-- Supprime la ligne sur le site cible.
-- Si la Commande parente n'a plus de lignes sur ce site, la supprime.
-- ==================================================================
CREATE OR REPLACE TRIGGER SYC_DELETE_LIGNE
AFTER DELETE ON LigneCommandes
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    IF :OLD.quantite >= 100 THEN
        DELETE FROM LigneCommandes1@site1_link
        WHERE  idlignecommande = :OLD.idlignecommande;

        SELECT COUNT(*) INTO v_count
        FROM   LigneCommandes1@site1_link
        WHERE  idcommande = :OLD.idcommande;

        IF v_count = 0 THEN
            DELETE FROM Commandes1@site1_link WHERE idcommande = :OLD.idcommande;
        END IF;
    ELSE
        DELETE FROM LigneCommandes2@site2_link
        WHERE  idlignecommande = :OLD.idlignecommande;

        SELECT COUNT(*) INTO v_count
        FROM   LigneCommandes2@site2_link
        WHERE  idcommande = :OLD.idcommande;

        IF v_count = 0 THEN
            DELETE FROM Commandes2@site2_link WHERE idcommande = :OLD.idcommande;
        END IF;
    END IF;
END SYC_DELETE_LIGNE;
/

-- ==================================================================
-- SYC_UPDATE_LIGNE
-- Met à jour la ligne sur le site cible.
-- Si la quantite franchit le seuil 100 (dans un sens ou l'autre),
-- la ligne migre vers l'autre site : suppression + réinsertion.
-- ==================================================================
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

    -- Charge les données parentes du nouvel état (utile en cas de migration)
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

    PROCEDURE ensure_parents_on_site1(p_idcommande IN NUMBER, p_idproduit IN NUMBER) IS
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
    END ensure_parents_on_site1;

    PROCEDURE ensure_parents_on_site2(p_idcommande IN NUMBER, p_idproduit IN NUMBER) IS
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
    END ensure_parents_on_site2;

BEGIN
    IF :OLD.quantite >= 100 AND :NEW.quantite >= 100 THEN
        -- Reste sur Site1 — mise à jour simple
        UPDATE LigneCommandes1@site1_link
        SET    idproduit = :NEW.idproduit,
               quantite  = :NEW.quantite,
               remise    = :NEW.remise
        WHERE  idlignecommande = :NEW.idlignecommande;

    ELSIF :OLD.quantite < 100 AND :NEW.quantite < 100 THEN
        -- Reste sur Site2 — mise à jour simple
        UPDATE LigneCommandes2@site2_link
        SET    idproduit = :NEW.idproduit,
               quantite  = :NEW.quantite,
               remise    = :NEW.remise
        WHERE  idlignecommande = :NEW.idlignecommande;

    ELSIF :OLD.quantite >= 100 AND :NEW.quantite < 100 THEN
        -- Migration Site1 → Site2
        DELETE FROM LigneCommandes1@site1_link WHERE idlignecommande = :OLD.idlignecommande;
        SELECT COUNT(*) INTO v_count FROM LigneCommandes1@site1_link WHERE idcommande = :OLD.idcommande;
        IF v_count = 0 THEN
            DELETE FROM Commandes1@site1_link WHERE idcommande = :OLD.idcommande;
        END IF;

        fetch_parent_data(:NEW.idcommande, :NEW.idproduit);
        ensure_parents_on_site2(:NEW.idcommande, :NEW.idproduit);
        INSERT INTO LigneCommandes2@site2_link(idlignecommande, idcommande, idproduit, quantite, remise)
        VALUES (:NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise);

    ELSE
        -- Migration Site2 → Site1  (:OLD.quantite < 100 AND :NEW.quantite >= 100)
        DELETE FROM LigneCommandes2@site2_link WHERE idlignecommande = :OLD.idlignecommande;
        SELECT COUNT(*) INTO v_count FROM LigneCommandes2@site2_link WHERE idcommande = :OLD.idcommande;
        IF v_count = 0 THEN
            DELETE FROM Commandes2@site2_link WHERE idcommande = :OLD.idcommande;
        END IF;

        fetch_parent_data(:NEW.idcommande, :NEW.idproduit);
        ensure_parents_on_site1(:NEW.idcommande, :NEW.idproduit);
        INSERT INTO LigneCommandes1@site1_link(idlignecommande, idcommande, idproduit, quantite, remise)
        VALUES (:NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise);
    END IF;
END SYC_UPDATE_LIGNE;
/

EXIT;
