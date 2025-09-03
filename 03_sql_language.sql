SELECT * FROM orders_status;

SELECT SUM(total_amount) AS total_revenue
FROM orders;

SELECT SUM(total_amount) AS total_refunds
FROM orders
WHERE status_id IN (6, 7);

SELECT COUNT(*) AS total_orders
FROM orders;

---- SQL Terms and Concepts

SELECT c.name AS customer_name, SUM(o.total_amount) AS total_spent, o.status_id AS order_status
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY customer_name, order_status
HAVING order_status IN (
    SELECT status_id
    FROM orders_status
)
ORDER BY total_spent DESC, order_status ASC;