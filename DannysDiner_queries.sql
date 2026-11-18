-- Schema Setup
CREATE SCHEMA dannys_diner;
USE dannys_diner;


-- Create sales table
CREATE TABLE sales (
    customer_id VARCHAR(1),
    order_date DATE,
    product_id INT
);

INSERT INTO sales (customer_id, order_date, product_id)
VALUES
    ('A', '2021-01-01', 1),
    ('A', '2021-01-01', 2),
    ('A', '2021-01-07', 2),
    ('A', '2021-01-10', 3),
    ('A', '2021-01-11', 3),
    ('A', '2021-01-11', 3),
    ('B', '2021-01-01', 2),
    ('B', '2021-01-02', 2),
    ('B', '2021-01-04', 1),
    ('B', '2021-01-11', 1),
    ('B', '2021-01-16', 3),
    ('B', '2021-02-01', 3),
    ('C', '2021-01-01', 3),
    ('C', '2021-01-01', 3),
    ('C', '2021-01-07', 3);


-- Create menu table
CREATE TABLE menu (
    product_id INT,
    product_name VARCHAR(5),
    price INT
);

INSERT INTO menu (product_id, product_name, price)
VALUES
    (1, 'sushi', 10),
    (2, 'curry', 15),
    (3, 'ramen', 12);


-- Create members table
CREATE TABLE members (
    customer_id VARCHAR(1),
    join_date DATE
);

INSERT INTO members (customer_id, join_date)
VALUES
    ('A', '2021-01-07'),
    ('B', '2021-01-09');



-- 1. What is the total amount each customer spent at the restaurant?
SELECT s.customer_id AS 'Customer ID',
       SUM(price) AS 'Amount Spent'
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id;


-- 2. How many days has each customer visited the restaurant?
SELECT customer_id,
       COUNT(DISTINCT order_date) AS 'Days Count'
FROM sales
GROUP BY customer_id;


-- 3. What was the first item from the menu purchased by each customer?
WITH ranked AS (
    SELECT s.customer_id, s.order_date, m.product_name,
           DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS rn
    FROM sales s
    JOIN menu m ON s.product_id = m.product_id
)
SELECT customer_id, product_name FROM ranked WHERE rn = 1;


-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
WITH ranked AS (
    SELECT m.product_name, p.cnt,
           DENSE_RANK() OVER(ORDER BY p.cnt DESC) AS rked
    FROM (SELECT product_id, COUNT(product_id) AS cnt FROM sales GROUP BY product_id) p
    JOIN menu m ON p.product_id = m.product_id
)
SELECT * FROM ranked WHERE rked = 1;


-- 5. Which item was the most popular for each customer?
WITH temp AS (
    SELECT p.customer_id, m.product_name, p.cnt,
           DENSE_RANK() OVER (PARTITION BY p.customer_id ORDER BY p.cnt DESC) AS rked
    FROM (SELECT customer_id, product_id, COUNT(product_id) AS cnt FROM sales GROUP BY customer_id, product_id) p
    JOIN menu m ON p.product_id = m.product_id
)
SELECT customer_id, cnt, product_name FROM temp WHERE rked = 1;


-- 6. Which item was purchased first by the customer after they became a member?
WITH id AS (
    SELECT s.customer_id, s.order_date, s.product_id
    FROM sales s
    JOIN members m ON s.customer_id = m.customer_id AND s.order_date >= m.join_date
)
SELECT customer_id, product_name FROM (
    SELECT i.customer_id, m.product_name,
           DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY order_date) AS rked
    FROM id i JOIN menu m ON i.product_id = m.product_id
) a WHERE rked = 1;


-- 7. Which item was purchased just before the customer became a member?
WITH temp AS (
    SELECT customer_id, product_name,
           DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY order_date DESC) AS rked
    FROM (
        SELECT s.customer_id, s.order_date, s.product_id
        FROM sales s
        JOIN members m ON s.customer_id = m.customer_id AND s.order_date < m.join_date
    ) t JOIN menu m ON t.product_id = m.product_id
)
SELECT customer_id, product_name FROM temp WHERE rked = 1;


-- 8. What is the total items and amount spent for each member before they became a member?
SELECT customer_id, COUNT(t.product_id) AS 'Items', SUM(m.price) AS 'Total'
FROM (
    SELECT s.customer_id, s.product_id FROM sales s
    JOIN members m ON s.customer_id = m.customer_id AND s.order_date < m.join_date
) t JOIN menu m ON t.product_id = m.product_id
GROUP BY customer_id;


-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH computed AS (
    SELECT s.customer_id,
    CASE WHEN product_name = 'sushi' THEN price*20 ELSE price*10 END AS points
    FROM sales s JOIN menu m ON s.product_id = m.product_id
)
SELECT customer_id, SUM(points) AS points_earned FROM computed GROUP BY customer_id;


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
SELECT customer_id,
       SUM(CASE
           WHEN order_date < join_date AND product_name = 'sushi' THEN price*20
           WHEN order_date BETWEEN join_date AND DATE_ADD(join_date, INTERVAL 7 DAY) THEN price*20
           ELSE price*10 END) AS points_earned
FROM (SELECT s.*, m.join_date FROM sales s JOIN members m ON s.customer_id = m.customer_id) t
JOIN menu m ON t.product_id = m.product_id
WHERE order_date <= '2021-01-31'
GROUP BY customer_id;


