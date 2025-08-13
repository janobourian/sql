--- First and basic query
SELECT t.name AS tour_name, COUNT(*) AS num_waterfalls
FROM tour t LEFT JOIN waterfall w ON t.stop = w.id
WHERE w.open_to_public = 'y'
GROUP BY t.name
HAVING COUNT(*) >= 2
ORDER BY tour_name;

--- SELECT clause
SELECT id, name 
FROM owner;

SELECT *
FROM owner;

SELECT name, ROUND(population*0.9, 0) AS population_90
FROM country;

SELECT CURRENT_DATE AS today;

SELECT id AS country_id, name AS country_name, ROUND(population*0.9, 0) AS population_90
FROM country;

SELECT my_new_db.test.id AS test_id, my_new_db.test.num AS test_num
FROM my_new_db.test; --- Qualifiying tables

SELECT t.id AS test_id, t.num AS test_num
FROM my_new_db.test AS t; --- Using alias for table

SELECT t.num,
       (SELECT AVG(ts.is_even) 
       FROM test_summary ts
       WHERE ts.id = t.id) AS is_even
FROM test t;

--- Subqueries
SELECT id, name, population,
       (SELECT AVG(population) FROM country) AS average_population
FROM country;

SELECT o.id, o.name,
       (SELECT COUNT(*) FROM waterfall w
        WHERE o.id = w.owner_id) AS num_waterfalls
FROM owner o;

--- DISTINCT
SELECT DISTINCT o.type, w.open_to_public
FROM owner o
JOIN waterfall w ON o.id = w.owner_id;