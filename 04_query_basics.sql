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