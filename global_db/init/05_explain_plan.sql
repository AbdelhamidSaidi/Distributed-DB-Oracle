-- ============================================================
-- ANALYSE DE PERFORMANCES : nombre de commandes par client en 2026
--
-- La requête utilise une plage de dates (>= / <) plutôt que
-- EXTRACT(YEAR FROM ...) car EXTRACT() est non-SARGable :
-- Oracle ne peut pas utiliser un index B-tree sur une expression
-- fonction, ce qui forcerait un Full Table Scan même avec un index.
-- ============================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
CONNECT eshop/eshop123@localhost:1521/FREEPDB1

-- Afficher les plans avec colonnes utiles
SET LINESIZE 120
SET PAGESIZE 100

-- ============================================================
-- ETAPE 1 — Plan SANS index (état initial)
-- Opérations attendues :
--   TABLE ACCESS FULL sur Commandes  → lit toutes les lignes pour
--     filtrer sur datecommande, coûteux quand la table est grande
--   TABLE ACCESS FULL sur Clients    → même problème côté jointure
--   HASH JOIN                        → Oracle construit une hash
--     table en mémoire pour joindre les deux Full Scans
--   SORT ORDER BY                    → tri final sur nb_commandes
-- ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'sans_index' FOR
SELECT   c.idclient,
         c.societe,
         COUNT(cmd.idcommande) AS nb_commandes
FROM     Clients c
    JOIN Commandes cmd ON cmd.idclient = c.idclient
WHERE    cmd.datecommande >= DATE '2026-01-01'
  AND    cmd.datecommande <  DATE '2027-01-01'
GROUP BY c.idclient, c.societe
ORDER BY nb_commandes DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'sans_index'));

-- ============================================================
-- ETAPE 2 — Création des index
--
-- Index 1 : idx_commandes_date
--   Cible  : colonne datecommande de Commandes
--   Raison : la clause WHERE filtre par plage de dates.
--            Sans index, Oracle fait un Full Table Scan sur
--            Commandes et évalue le prédicat ligne par ligne.
--            Avec cet index B-tree, Oracle fait un INDEX RANGE SCAN
--            et n'accède qu'aux blocs correspondant à 2026.
--
-- Index 2 : idx_commandes_idclient
--   Cible  : colonne idclient de Commandes (clé étrangère)
--   Raison : Oracle ne crée PAS d'index automatiquement sur les
--            colonnes FK. Sans index, la jointure Commandes → Clients
--            déclenche un Full Scan sur Clients pour chaque lot.
--            Cet index permet un NESTED LOOPS efficace ou améliore
--            le coût du HASH JOIN en réduisant le probe set.
--            Il protège aussi les DELETE sur Clients contre les
--            Full Scans de validation de contrainte FK.
-- ============================================================
CREATE INDEX idx_commandes_date     ON Commandes(datecommande);
CREATE INDEX idx_commandes_idclient ON Commandes(idclient);

-- ============================================================
-- ETAPE 3 — Plan AVEC index
-- Opérations attendues après optimisation :
--   INDEX RANGE SCAN sur idx_commandes_date → accès direct aux
--     lignes de 2026 sans lire toute la table
--   TABLE ACCESS BY INDEX ROWID sur Commandes → accès ciblé
--   NESTED LOOPS ou HASH JOIN avec coût réduit sur Clients
--   SORT ORDER BY sur un volume déjà réduit
-- ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'avec_index' FOR
SELECT   c.idclient,
         c.societe,
         COUNT(cmd.idcommande) AS nb_commandes
FROM     Clients c
    JOIN Commandes cmd ON cmd.idclient = c.idclient
WHERE    cmd.datecommande >= DATE '2026-01-01'
  AND    cmd.datecommande <  DATE '2027-01-01'
GROUP BY c.idclient, c.societe
ORDER BY nb_commandes DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(statement_id => 'avec_index'));

-- ============================================================
-- ETAPE 4 — Exécution de la requête
-- ============================================================
SELECT   c.idclient,
         c.societe,
         COUNT(cmd.idcommande) AS nb_commandes
FROM     Clients c
    JOIN Commandes cmd ON cmd.idclient = c.idclient
WHERE    cmd.datecommande >= DATE '2026-01-01'
  AND    cmd.datecommande <  DATE '2027-01-01'
GROUP BY c.idclient, c.societe
ORDER BY nb_commandes DESC;

EXIT;
