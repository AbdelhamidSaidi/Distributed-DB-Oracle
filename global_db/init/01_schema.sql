-- Changed from XEPDB1 to FREEPDB1 to match Oracle 23ai Free defaults
ALTER SESSION SET CONTAINER = FREEPDB1;

CREATE USER eshop IDENTIFIED BY eshop123 DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CONNECT, RESOURCE TO eshop;
ALTER SESSION SET CURRENT_SCHEMA = eshop;

CREATE TABLE Categories (
    idcateg     NUMBER          PRIMARY KEY,
    nomcateg    VARCHAR2(100)   NOT NULL
);

CREATE TABLE Produits (
    idproduit       NUMBER          PRIMARY KEY,
    idcateg         NUMBER          NOT NULL,
    designation     VARCHAR2(200)   NOT NULL,
    prixunitaire    NUMBER(10,2)    NOT NULL,
    CONSTRAINT fk_produits_categ FOREIGN KEY (idcateg) REFERENCES Categories(idcateg)
);

CREATE TABLE Clients (
    idclient    NUMBER          PRIMARY KEY,
    codeclient  VARCHAR2(20)    NOT NULL,
    societe     VARCHAR2(200)   NOT NULL,
    contact     VARCHAR2(100),
    adresse     VARCHAR2(300),
    ville       VARCHAR2(100),
    pays        VARCHAR2(100)
);

CREATE TABLE Employes (
    idemploye   NUMBER          PRIMARY KEY,
    nom         VARCHAR2(100)   NOT NULL,
    prenom      VARCHAR2(100)   NOT NULL,
    fonction    VARCHAR2(100)
);

CREATE TABLE Commandes (
    idcommande      NUMBER      PRIMARY KEY,
    idclient        NUMBER      NOT NULL,
    idemploye       NUMBER      ,
    datecommande    DATE        DEFAULT SYSDATE,
    CONSTRAINT fk_commandes_client  FOREIGN KEY (idclient)  REFERENCES Clients(idclient),
    CONSTRAINT fk_commandes_employe FOREIGN KEY (idemploye) REFERENCES Employes(idemploye)
);

CREATE TABLE LigneCommandes (
    idlignecommande NUMBER      PRIMARY KEY,
    idcommande      NUMBER      NOT NULL,
    idproduit       NUMBER      NOT NULL,
    quantite        NUMBER      NOT NULL,
    remise          NUMBER(5,2) DEFAULT 0,
    CONSTRAINT fk_lc_commande FOREIGN KEY (idcommande) REFERENCES Commandes(idcommande),
    CONSTRAINT fk_lc_produit  FOREIGN KEY (idproduit)  REFERENCES Produits(idproduit)
);

EXIT;