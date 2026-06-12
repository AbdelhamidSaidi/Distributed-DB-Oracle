-- Check all existing lignecommandes
SELECT idlignecommande, idcommande, quantite FROM lignecommandes ORDER BY idcommande;

-- Try inserting again with error handling
BEGIN
  INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
  VALUES (1002, 5001, 2, 50, 5);
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Insert successful');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
    ROLLBACK;
END;
/

-- Check if it's there now
SELECT * FROM lignecommandes WHERE idcommande = 5001;

-- Check trigger status
SELECT trigger_name, status FROM user_triggers WHERE table_name = 'LIGNECOMMANDES';
