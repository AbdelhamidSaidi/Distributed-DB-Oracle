-- ============================================================
-- REQUÊTE DISTRIBUÉE : chiffre d'affaires par catégorie en 2026
--
-- Agrège les LigneCommandes des deux sites via DB Links.
-- CA = quantite * prixunitaire * (1 - remise / 100)
--
-- Architecture de la requête :
--   1. Sous-requête Site1 via @site1_link  → CA partiel par catégorie
--   2. Sous-requête Site2 via @site2_link  → CA partiel par catégorie
--   3. UNION ALL + GROUP BY final          → CA total consolidé
--
-- Oracle exécute chaque sous-requête sur son site respectif
-- (remote query shipping) et rapatrie uniquement les agrégats,
-- minimisant le volume de données transférées sur le réseau.
-- ============================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
CONNECT eshop/eshop123@localhost:1521/FREEPDB1

SET LINESIZE 120
SET PAGESIZE 100
COLUMN nomcateg      FORMAT A30
COLUMN ca_total      FORMAT 999,999,999.99
COLUMN ca_site1      FORMAT 999,999,999.99
COLUMN ca_site2      FORMAT 999,999,999.99

SELECT
    idcateg,
    nomcateg,
    SUM(ca_site1)  AS ca_site1,
    SUM(ca_site2)  AS ca_site2,
    SUM(ca_total)  AS ca_total
FROM (
    -- Contribution de Site1
    SELECT
        p.idcateg,
        cat.nomcateg,
        SUM(lc.quantite * p.prixunitaire * (1 - lc.remise / 100)) AS ca_site1,
        0                                                           AS ca_site2,
        SUM(lc.quantite * p.prixunitaire * (1 - lc.remise / 100)) AS ca_total
    FROM  LigneCommandes1@site1_link  lc
    JOIN  Commandes1@site1_link       cmd ON cmd.idcommande = lc.idcommande
    JOIN  Produits1@site1_link        p   ON p.idproduit    = lc.idproduit
    JOIN  Categories1@site1_link      cat ON cat.idcateg    = p.idcateg
    WHERE cmd.datecommande >= DATE '2026-01-01'
      AND cmd.datecommande <  DATE '2027-01-01'
    GROUP BY p.idcateg, cat.nomcateg

    UNION ALL

    -- Contribution de Site2
    SELECT
        p.idcateg,
        cat.nomcateg,
        0                                                           AS ca_site1,
        SUM(lc.quantite * p.prixunitaire * (1 - lc.remise / 100)) AS ca_site2,
        SUM(lc.quantite * p.prixunitaire * (1 - lc.remise / 100)) AS ca_total
    FROM  LigneCommandes2@site2_link  lc
    JOIN  Commandes2@site2_link       cmd ON cmd.idcommande = lc.idcommande
    JOIN  Produits2@site2_link        p   ON p.idproduit    = lc.idproduit
    JOIN  Categories2@site2_link      cat ON cat.idcateg    = p.idcateg
    WHERE cmd.datecommande >= DATE '2026-01-01'
      AND cmd.datecommande <  DATE '2027-01-01'
    GROUP BY p.idcateg, cat.nomcateg
)
GROUP BY idcateg, nomcateg
ORDER BY ca_total DESC;

EXIT;
