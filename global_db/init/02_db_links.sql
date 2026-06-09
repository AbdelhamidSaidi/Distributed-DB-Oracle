ALTER SESSION SET CONTAINER = FREEPDB1;

-- Grant CREATE DATABASE LINK to eshop (running as SYS here)
GRANT CREATE DATABASE LINK TO eshop;

-- Reconnect as eshop so the links are owned by that user
CONNECT eshop/eshop123@localhost:1521/FREEPDB1

-- Link to Site1 (port 1521 is the internal Docker port, container name is the hostname)
CREATE DATABASE LINK site1_link
    CONNECT TO site1 IDENTIFIED BY site1123
    USING '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=eshop_site1_db)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=FREEPDB1)))';

-- Link to Site2
CREATE DATABASE LINK site2_link
    CONNECT TO site2 IDENTIFIED BY site2123
    USING '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=eshop_site2_db)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=FREEPDB1)))';

EXIT;
