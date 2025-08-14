-- 1. Database Exploration
-----------------------------------------------------

-- Explore All objects in the database
SELECT * FROM INFORMATION_SCHEMA.TABLES

-- Eplore all columns in the database
SELECT * FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_customers'

-----------------------------------------------------

-- 2. Dimension Exploration:- Identify the unique values (or categories) in each dimensions.
--      Recognizing how data might be grouped or segmented, which is useful for later analysis.
--      We can use "DISTINCT"
-----------------------------------------------------

-- Exlpore All countries our customers come from.
SELECT DISTINCT country FROM gold.dim_customers

-- Explore All product categories " The Major Divisions"

SELECT DISTINCT category, subcategory, product_name
FROM gold.dim_products
ORDER BY 1,2,3

-----------------------------------------------------

-- 3. Data Exploration:- Identify the earliest and latest dates (boundaries)
--      Understand the scope of data and the timespan.
--          We can use MIN/MAX [date dimension]
-----------------------------------------------------

-- Find the date of the first and last order from the sales table

SELECT 
MIN(order_date) AS first_order,
MAX(order_date) AS latest_order,
DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS timespan
FROM gold.fact_sales

-- Find the youngest and oldest customer.

SELECT
first_name,
birthdate,
DATEDIFF(YEAR, birthdate, GETDATE()) AS age,
MIN(DATEDIFF(YEAR, birthdate, GETDATE()))  OVER() AS Youngest,
MAX(DATEDIFF(YEAR, birthdate, GETDATE())) OVER() AS oldest
FROM gold.dim_customers

-----------------------------------------------------

-- 4. Measures Exploration:- Calculate the key metrics of the business (Big Numbers)
--       Highest Level of Aggregation | Lowest Level of Details -
--          SUM, AVG, COUNT
-----------------------------------------------------

-- Find the Total Sales
SELECT
SUM(sales_amount) AS TotalSales
FROM gold.fact_sales

-- Find how many items are sold
SELECT 
SUM(quantity) AS total_quantity 
FROM gold.fact_sales

-- Find the average selling price
SELECT
AVG(price) AS average_price
FROM gold.fact_sales

-- Find the total number of orders
SELECT 
COUNT(DISTINCT order_number)
FROM gold.fact_sales

-- Find the total number of products
SELECT
COUNT(DISTINCT product_name) AS Total_products
FROM gold.dim_products

-- Find the total number of customers
SELECT DISTINCT customer_id,
COUNT(*) OVER() AS total_customers
FROM gold.dim_customers
ORDER BY customer_id

SELECT COUNT(DISTINCT customer_key) AS total_customers  FROM gold.dim_customers

-- Find the total number of customers that has placed an order
SELECT 
COUNT(DISTINCT customer_key) AS total_customers_placed_order 
FROM gold.fact_sales


-- Generate Report that shows all key metrics of the business.

SELECT
    COUNT(DISTINCT c.customer_key) AS total_customers,
    COUNT(DISTINCT s.customer_key) AS total_customers_placed_order,
    COUNT(DISTINCT s.order_number) AS total_orders,
    COUNT(DISTINCT p.product_name) AS Total_products,
    SUM(s.quantity) AS total_items_sold,
    AVG(s.price) AS average_price,
    SUM(s.sales_amount) AS TotalSales
FROM gold.fact_sales s
LEFT JOIN gold.dim_customers c
ON s.customer_key = c.customer_key
LEFT JOIN gold.dim_products p
ON p.product_key = s.product_key

SELECT 'Total Sales' as measure_name, SUM(sales_amount) AS measure_value FROM gold.fact_sales
UNION ALL
SELECT 'Total Quantity' as measure_name, SUM(quantity) AS measure_value FROM gold.fact_sales
UNION ALL
SELECT 'Average Price' as measure_name, AVG(price) AS measure_value FROM gold.fact_sales
UNION ALL
SELECT 'Total Orders' as measure_name, COUNT(DISTINCT order_number) AS measure_value FROM gold.fact_sales
UNION ALL
SELECT 'Total Products' as measure_name, COUNT(DISTINCT product_name) AS measure_value FROM gold.dim_products
UNION ALL
SELECT 'Total Customers' as measure_name, COUNT(DISTINCT customer_key) AS measure_value FROM gold.dim_customers
-----------------------------------------------------

-- 5. Magnitude Analysis:- Compare the measure values by categories.
--      It helps us understand the importance of different categories.
--          [Measure] by [Dimension]
-----------------------------------------------------

-- Find the total customers by countries
SELECT 
    country,
    COUNT(DISTINCT customer_key) AS total_customers
FROM gold.dim_customers
GROUP BY country
ORDER BY COUNT(DISTINCT customer_key) DESC

-- Find total customers by gender
SELECT
    gender,
    COUNT(DISTINCT customer_key) AS total_customer
FROM gold.dim_customers
GROUP BY gender
ORDER BY COUNT(DISTINCT customer_key) DESC

-- Find total products by category
SELECT
    category,
    COUNT(DISTINCT product_name) AS total_products
GROUP BY category
ORDER BY COUNT(DISTINCT product_name) DESC

-- What is the average costs in each category?
SELECT
    category,
    AVG(cost) AS average_cost
FROM gold.dim_products
GROUP BY category
ORDER BY AVG(cost) DESC

-- What is the total revenue generated for each category?
SELECT
    category,
    SUM(sales_amount) AS total_revenue
FROM gold.dim_products p
LEFT JOIN gold.fact_sales s
ON s.product_key = p.product_key
GROUP BY category
ORDER BY SUM(sales_amount) DESC


-- Find total revenue is generated by each customer
SELECT 
    DISTINCT customer_key,
    SUM(sales_amount) AS total_revenue
FROM gold.fact_sales
GROUP BY customer_key
ORDER BY SUM(sales_amount) DESC

-- What is the distribution of sold items across countries?
SELECT 
    c.country,
    SUM(s.quantity) AS items_sold
FROM gold.fact_sales s
LEFT JOIN gold.dim_customers c
ON s.customer_key = c.customer_key
GROUP BY c.country
ORDER BY items_sold DESC

-----------------------------------------------------
-- 6. Ranking Aanalysis:- Order the values of dimensions by measure.
--          Top N performers | Bottom N Performers
--          Rank[Dimensions] BY [Measure]

-- Which 5 Products generate the highest revenue?

SELECT * FROM (
    SELECT
    SUM(s.sales_amount) as total_revenue,
    p.product_name,
    RANK() OVER (ORDER BY SUM(s.sales_amount) DESC) AS rank
FROM gold.fact_sales s
LEFT JOIN gold.dim_products p
ON p.product_key = s.product_key
GROUP BY p.product_name)t
WHERE rank < 6

-- What are the 5 worst-performing products in terms of sales?

SELECT * FROM (
    SELECT
    SUM(s.sales_amount) as total_revenue,
    p.product_name,
    RANK() OVER (ORDER BY SUM(s.sales_amount)) AS rank
FROM gold.fact_sales s
LEFT JOIN gold.dim_products p
ON p.product_key = s.product_key
GROUP BY p.product_name)t
WHERE rank < 6

-- Find the Top-10 customers who have generated the highest revenue
SELECT * FROM (
    SELECT
        SUM(s.sales_amount) AS total_revenue,
        c.customer_id,
        ROW_NUMBER() OVER (ORDER BY SUM(s.sales_amount) DESC) AS rank
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_customers c
    ON c.customer_key = s.customer_key
    GROUP BY c.customer_id)t
WHERE rank <= 10

-- 3 customers with the fewest orders placed
SELECT * FROM (
    SELECT
        c.customer_key,
        c.first_name,
        c.last_name,
        COUNT(DISTINCT s.order_number) AS total_orders,
        ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT s.order_number)) AS rank
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_customers c
    ON c.customer_key = s.customer_key
    GROUP BY 
    c.customer_key,
    c.first_name,
    c.last_name)t
WHERE rank <= 3
