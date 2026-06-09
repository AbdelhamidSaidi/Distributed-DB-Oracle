-- ============================================================
-- DONNÉES DE TEST
-- ============================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
CONNECT eshop/eshop123@localhost:1521/FREEPDB1

-- Categories
INSERT INTO Categories VALUES (10, 'Electronique');
INSERT INTO Categories VALUES (20, 'Bureautique');
INSERT INTO Categories VALUES (35, 'Mobilier');
INSERT INTO Categories VALUES (50, 'Informatique');

-- Produits
INSERT INTO Produits VALUES (1, 50, 'Laptop ProBook 450',      899.99);
INSERT INTO Produits VALUES (2, 50, 'Serveur Dell PowerEdge', 2499.99);
INSERT INTO Produits VALUES (3, 50, 'Switch réseau 48 ports',  349.99);
INSERT INTO Produits VALUES (4, 35, 'Bureau ergonomique',      279.99);
INSERT INTO Produits VALUES (5, 35, 'Chaise de direction',     199.99);
INSERT INTO Produits VALUES (6, 10, 'Ecran 27 pouces 4K',      449.99);
INSERT INTO Produits VALUES (7, 20, 'Imprimante laser couleur',329.99);

-- Clients
INSERT INTO Clients VALUES (1, 'CLI001', 'TechCorp SA',    'Ahmed Benali',  '12 rue des Oliviers',   'Casablanca', 'Maroc');
INSERT INTO Clients VALUES (2, 'CLI002', 'InnoSoft SARL',  'Fatima Zahra',  '45 avenue Hassan II',   'Rabat',      'Maroc');
INSERT INTO Clients VALUES (3, 'CLI003', 'DataSystems',    'Karim Alaoui',  '8 boulevard Zerktouni', 'Casablanca', 'Maroc');
INSERT INTO Clients VALUES (4, 'CLI004', 'MegaOffice',     'Zineb Chraibi', '22 rue Ibn Battouta',   'Marrakech',  'Maroc');
INSERT INTO Clients VALUES (5, 'CLI005', 'Groupe Atlas',   'Omar Mansouri', '3 avenue Mohammed V',   'Fes',        'Maroc');

-- Employes
INSERT INTO Employes VALUES (1, 'Idrissi',  'Youssef', 'Commercial');
INSERT INTO Employes VALUES (2, 'Bensouda', 'Sara',    'Responsable ventes');

-- Commandes 2026
INSERT INTO Commandes VALUES (1,  1, 1, DATE '2026-02-10');
INSERT INTO Commandes VALUES (2,  1, 2, DATE '2026-03-15');
INSERT INTO Commandes VALUES (3,  2, 1, DATE '2026-04-20');
INSERT INTO Commandes VALUES (4,  2, 2, DATE '2026-05-05');
INSERT INTO Commandes VALUES (5,  3, 1, DATE '2026-06-01');
INSERT INTO Commandes VALUES (6,  3, 2, DATE '2026-07-14');
INSERT INTO Commandes VALUES (7,  3, 1, DATE '2026-09-02');
INSERT INTO Commandes VALUES (8,  4, 2, DATE '2026-08-22');
INSERT INTO Commandes VALUES (9,  5, 1, DATE '2026-10-30');

-- Commande hors 2026 (exclue par le filtre date)
INSERT INTO Commandes VALUES (10, 4, 1, DATE '2025-11-20');

-- LigneCommandes
-- (idligne, idcommande, idproduit, quantite, remise)
--
--         idcateg  qte   S2       S1
-- LC 1  :   50     150   Site1    Site1
-- LC 2  :   50     200   Site1    Site1
-- LC 3  :   50      80   Site2    global
-- LC 4  :   50     110   Site1    Site1
-- LC 5  :   50     300   Site1    Site1
-- LC 6  :   35      75   Site2    Site2
-- LC 7  :   35      60   Site2    Site2
-- LC 8  :   35      30   Site2    global
-- LC 9  :   35      55   Site2    Site2
-- LC 10 :   10     120   Site1    global
-- LC 11 :   10      15   Site2    global
-- LC 12 :   20     100   Site1    global
-- LC 13 :   20      40   Site2    global
-- LC 14 :   50     130   Site1    Site1  (commande hors 2026)

INSERT INTO LigneCommandes VALUES (1,  1,  1, 150,  5);
INSERT INTO LigneCommandes VALUES (2,  2,  2, 200, 10);
INSERT INTO LigneCommandes VALUES (3,  3,  1,  80,  0);
INSERT INTO LigneCommandes VALUES (4,  4,  3, 110,  8);
INSERT INTO LigneCommandes VALUES (5,  5,  2, 300, 15);
INSERT INTO LigneCommandes VALUES (6,  3,  4,  75,  5);
INSERT INTO LigneCommandes VALUES (7,  6,  5,  60,  3);
INSERT INTO LigneCommandes VALUES (8,  7,  4,  30,  0);
INSERT INTO LigneCommandes VALUES (9,  8,  5,  55,  2);
INSERT INTO LigneCommandes VALUES (10, 1,  6, 120,  0);
INSERT INTO LigneCommandes VALUES (11, 9,  6,  15,  0);
INSERT INTO LigneCommandes VALUES (12, 5,  7, 100,  5);
INSERT INTO LigneCommandes VALUES (13, 8,  7,  40,  0);
INSERT INTO LigneCommandes VALUES (14, 10, 1, 130, 10);

COMMIT;
