ALTER SESSION SET CONTAINER = FREEPDB1;

CREATE USER site1 IDENTIFIED BY site1123 DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CONNECT, RESOURCE TO site1;
ALTER SESSION SET CURRENT_SCHEMA = site1;

CREATE TABLE Categories1 (
    idcateg     NUMBER          PRIMARY KEY,
    nomcateg    VARCHAR2(100)   NOT NULL
);

CREATE TABLE Produits1 (
    idproduit       NUMBER          PRIMARY KEY,
    idcateg         NUMBER          NOT NULL,
    designation     VARCHAR2(200)   NOT NULL,
    prixunitaire    NUMBER(10,2)    NOT NULL,
    CONSTRAINT fk_p1_categ FOREIGN KEY (idcateg) REFERENCES Categories1(idcateg)
);

CREATE TABLE Clients1 (
    idclient    NUMBER          PRIMARY KEY,
    codeclient  VARCHAR2(20)    NOT NULL,
    societe     VARCHAR2(200)   NOT NULL,
    contact     VARCHAR2(100),
    adresse     VARCHAR2(300),
    ville       VARCHAR2(100),
    pays        VARCHAR2(100)
);

CREATE TABLE Employes1 (
    idemploye   NUMBER          PRIMARY KEY,
    nom         VARCHAR2(100)   NOT NULL,
    prenom      VARCHAR2(100)   NOT NULL,
    fonction    VARCHAR2(100)
);

CREATE TABLE Commandes1 (
    idcommande      NUMBER      PRIMARY KEY,
    idclient        NUMBER      NOT NULL,
    idemploye       NUMBER,
    datecommande    DATE        DEFAULT SYSDATE,
    CONSTRAINT fk_cmd1_client  FOREIGN KEY (idclient)  REFERENCES Clients1(idclient),
    CONSTRAINT fk_cmd1_employe FOREIGN KEY (idemploye) REFERENCES Employes1(idemploye)
);

CREATE TABLE LigneCommandes1 (
    idlignecommande NUMBER      PRIMARY KEY,
    idcommande      NUMBER      NOT NULL,
    idproduit       NUMBER      NOT NULL,
    quantite        NUMBER      NOT NULL,
    remise          NUMBER(5,2) DEFAULT 0,
    CONSTRAINT fk_lc1_commande FOREIGN KEY (idcommande) REFERENCES Commandes1(idcommande) ON DELETE CASCADE,
    CONSTRAINT fk_lc1_produit  FOREIGN KEY (idproduit)  REFERENCES Produits1(idproduit)   ON DELETE CASCADE
);

EXIT;
