--Getting comfortable with the table
SELECT *  FROM customers LIMIT 10;
SELECT customer_id, customer_city, customer_state FROM customers LIMIT 10;

--JOIN table
SELECT oi.order_id, p.product_category_name, s.seller_city, oi.price
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN sellers s ON oi.seller_id = s.seller_id
ORDER BY oi.price DESC
LIMIT 5;

--CTE and Window Function for ranking price
WITH ranked_products AS (
    SELECT 
        seller_id, 
        product_id, 
        price, 
        DENSE_RANK() OVER(PARTITION BY seller_id ORDER BY price DESC) AS rank
    FROM order_items
    WHERE seller_id IS NOT NULL
)
SELECT rp.seller_id, rp.product_id, rp.price, rp.rank, p.product_category_name
FROM ranked_products rp
JOIN products p ON rp.product_id = p.product_id
WHERE rp.rank <= 3;

--CTE and aggregation total items sold per product.More than 100 items
WITH total as(
    SELECT 
      product_id, 
      COUNT(order_id) AS total_items
    FROM order_items
    GROUP BY product_id
)
SELECT t.product_id, t.total_items, pi.product_category_name
FROM total t
JOIN products pi 
ON t.product_id = pi.product_id
WHERE total_items > 100;

-- Example SQLite Query (simulate stored procedure)
SELECT DISTINCT c.customer_id, o.*
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE c.customer_id = 'b0830fb4747a6c6d20dea0b8c802d7ef';

--Recursive CTE – Customer Order History Depth
WITH RECURSIVE first_order AS (
    SELECT customer_id, MIN(order_purchase_timestamp) AS first_order_date
    FROM orders
    GROUP BY customer_id
),
month_sequence (customer_id, order_month, month_number) AS (
    -- Anchor member (cast to timestamp)
    SELECT customer_id, first_order_date::timestamp, 1
    FROM first_order

    UNION ALL

    -- Recursive member
    SELECT customer_id,
           order_month + INTERVAL '1 month',
           month_number + 1
    FROM month_sequence
    WHERE month_number < 6
)
SELECT customer_id, order_month::date AS followup_month, month_number
FROM month_sequence
ORDER BY customer_id, month_number;

--Rolling Average – Seller Order Price Trend
SELECT 
  seller_id,
  order_id,
  order_item_id,
  price,
  ROUND(
    AVG(price) OVER (
      PARTITION BY seller_id 
      ORDER BY order_id
      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    )::numeric, 2
  ) AS rolling_avg_price
FROM order_items;
