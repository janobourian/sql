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

SELECT DISTINCT ord.status_id, cus.name AS customer_name
FROM orders ord
JOIN customers cus ON ord.customer_id = cus.customer_id
ORDER BY customer_name ASC, status_id DESC;

SELECT COUNT(DISTINCT status_id) AS unique_statuses
FROM orders;

--- FROM
 SELECT status_id, status_name, description
 FROM orders_status;

SELECT AVG(total_amount) AS avg_order_amount
FROM orders;

SELECT COUNT(*) AS total_orders, os.status_name
FROM orders_status os
JOIN orders o ON os.status_id = o.status_id
WHERE o.total_amount > 1143 AND os.status_name NOT LIKE '%Pend%'
GROUP BY os.status_name
HAVING COUNT(*) > 6
ORDER BY total_orders DESC
LIMIT 1;
