ALTER SESSION SET CONTAINER = FREEPDB1;

CREATE USER site2 IDENTIFIED BY site2123 DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CONNECT, RESOURCE TO site2;
ALTER SESSION SET CURRENT_SCHEMA = site2;

CREATE TABLE Categories2 (
    idcateg     NUMBER          PRIMARY KEY,
    nomcateg    VARCHAR2(100)   NOT NULL
);

CREATE TABLE Produits2 (
    idproduit       NUMBER          PRIMARY KEY,
    idcateg         NUMBER          NOT NULL,
    designation     VARCHAR2(200)   NOT NULL,
    prixunitaire    NUMBER(10,2)    NOT NULL,
    CONSTRAINT fk_p2_categ FOREIGN KEY (idcateg) REFERENCES Categories2(idcateg)
);

CREATE TABLE Clients2 (
    idclient    NUMBER          PRIMARY KEY,
    codeclient  VARCHAR2(20)    NOT NULL,
    societe     VARCHAR2(200)   NOT NULL,
    contact     VARCHAR2(100),
    adresse     VARCHAR2(300),
    ville       VARCHAR2(100),
    pays        VARCHAR2(100)
);

CREATE TABLE Employes2 (
    idemploye   NUMBER          PRIMARY KEY,
    nom         VARCHAR2(100)   NOT NULL,
    prenom      VARCHAR2(100)   NOT NULL,
    fonction    VARCHAR2(100)
);

CREATE TABLE Commandes2 (
    idcommande      NUMBER      PRIMARY KEY,
    idclient        NUMBER      NOT NULL,
    idemploye       NUMBER,
    datecommande    DATE        DEFAULT SYSDATE,
    CONSTRAINT fk_cmd2_client  FOREIGN KEY (idclient)  REFERENCES Clients2(idclient),
    CONSTRAINT fk_cmd2_employe FOREIGN KEY (idemploye) REFERENCES Employes2(idemploye)
);

CREATE TABLE LigneCommandes2 (
    idlignecommande NUMBER      PRIMARY KEY,
    idcommande      NUMBER      NOT NULL,
    idproduit       NUMBER      NOT NULL,
    quantite        NUMBER      NOT NULL,
    remise          NUMBER(5,2) DEFAULT 0,
    CONSTRAINT fk_lc2_commande FOREIGN KEY (idcommande) REFERENCES Commandes2(idcommande) ON DELETE CASCADE,
    CONSTRAINT fk_lc2_produit  FOREIGN KEY (idproduit)  REFERENCES Produits2(idproduit)   ON DELETE CASCADE
);

EXIT;
