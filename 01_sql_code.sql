CREATE DATABASE IF NOT EXISTS my_new_db;
USE my_new_db;
CREATE TABLE test (id int, num int);
INSERT INTO test VALUES (1, 100), (2, 200);
SELECT * FROM test LIMIT 1;
SELECT SUM(num) FROM test;
SELECT COUNT(*) FROM test;