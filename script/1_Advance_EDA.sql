-- 7. Change-Over-Time (Trends):- Analyze how measure evolves over time.
        -- Helps track trends and identify seasonality in data.
        -- [Measure] by [year]

-- Analyze Sales Performance over time.

SELECT
YEAR(order_date) AS order_year, -- can also use DATETRUNC ( to erase all the day/month data and start from the date 1) (DATETRUNC(month, orderdate))
MONTH(order_date) AS order_month,
SUM(sales_amount) AS total_revenue,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE ORDER_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date)

-- 8. Cumulative Analysis:- Aggregate the data progressively over time.
        -- hepls to understand whether our business is growing or declining.
        -- [Cumulative Measure] BY [Date Dimension]
        -- WINDOW FUNCTION

-- Calculate the total sales per month and the running total of sales over time. | Add Moving average of price

SELECT
    order_month,
    total_revenue,
    -- Window Function
    SUM(total_revenue) OVER (PARTITION BY order_year ORDER BY order_month) AS running_total_sales,
    AVG(avg_price) OVER (PARTITION BY order_year ORDER BY order_month) AS moving_average_price
FROM
(
    SELECT
    YEAR(order_date) AS order_year,
    MONTH(order_date) AS order_month,
    SUM(sales_amount) AS total_revenue,
    AVG(price) AS avg_price
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY YEAR(order_date), MONTH(order_date)
)t

-- 9. Performance Analysis:- Comparing the current value to a target value.
        -- Helps measure success and compare performance.
        -- Current[Measure] - Target [Measure]

-- Analyse the yearly performance of products by comparing each product's sales to both its average sales performance and the previous year's sales.

WITH yearly_product_sales AS (
SELECT
YEAR(f.order_date) AS order_year,
p.product_name,
SUM(f.sales_amount) AS current_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY YEAR(f.order_date), p.product_name
)

SELECT 
order_year,
product_name,
current_sales,
AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
CASE 
    WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Average'
    WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Average'
    ELSE 'Avg'
END avg_change,
-- Year-over-year analysis
LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS py_sales,
current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS diff_py,
CASE 
    WHEN LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) > 0 THEN 'increase'
    WHEN LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) < 0 THEN 'decrease'
    ELSE 'No change'
END avg_change
FROM yearly_product_sales
ORDER BY product_name, order_year   


-- 10. Part-To-Whole Analysis:- Analyze how an individual part is performing compared to the overall, allowing us to understand which category has the greatest impact on the business.
        -- ([Measure]/Total[Measure])*100 By [Dimension]
        -- Similar to PIE chart

-- Which category contributes the most to overall sales?



WITH category_sales AS 
(
    SELECT
        p.category AS category,
        SUM(f.sales_amount) AS total_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
    ON f.product_key = p.product_key
    GROUP BY p.category
)

SELECT 
category,
total_sales,
SUM(total_sales) OVER () AS overall_sales,
CONCAT(ROUND ((CAST (total_sales AS FLOAT) / SUM(total_sales) OVER ()) * 100, 2), '%') AS contribution
FROM category_sales
ORDER BY total_sales DESC

-- 11. Data Segmentation:- Group that data based on a specific range.
        -- Helps understand the correlation b/w two measures.
        -- [Measure] by [Measure] --> USE CASE WHEN Statement

-- Segment products into cost ranges and count how many products fall into each segment

WITH cost_range_category AS 
(
    SELECT
    product_name,
    cost,
    CASE 
        WHEN cost < 100 THEN 'Below 100'
        WHEN cost BETWEEN 100 AND 500 THEN '100-500'
        WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
        ELSE 'Above 1000'
    END as cost_category
    FROM gold.dim_products
)

SELECT
cost_category,
COUNT(product_name) AS no_of_products_in_each_category
FROM cost_range_category
GROUP BY cost_category
ORDER BY no_of_products_in_each_category DESC

/*
Group customer into three segments based on their spending behavior:
    -VIP: Customers with at least 12 months of history and spending more than $5000.
    -Regular: Customer with at least 12 months of history but spending b/w $5000 or less.
    -New: Customers with a lifespan less than 12 months.
And find the total number of customers by each group.
HINT: We need to find the first order and the last order of each customer.
*/

WITH new_customer_seg AS
(
    SELECT
    c.customer_key AS customer_key,
    s.order_date,
    MIN(s.order_date) OVER (PARTITION BY c.customer_key ORDER BY c.customer_key) AS fist_order,
    MAX(s.order_date) OVER (PARTITION BY c.customer_key ORDER BY c.customer_key) AS latest_order,
    SUM(s.sales_amount) OVER (PARTITION BY c.customer_key) AS total_spending_by_each_customer,
    CASE
        WHEN DATEDIFF (MONTH, MIN(s.order_date) OVER (PARTITION BY c.customer_key ORDER BY c.customer_key), MAX(s.order_date) OVER (PARTITION BY c.customer_key ORDER BY c.customer_key)) >= 12 AND SUM(s.sales_amount) OVER (PARTITION BY c.customer_key) > 5000 THEN 'VIP'
        WHEN DATEDIFF (MONTH, MIN(s.order_date) OVER (PARTITION BY c.customer_key ORDER BY c.customer_key), MAX(s.order_date) OVER (PARTITION BY c.customer_key ORDER BY c.customer_key)) >= 12 AND SUM(s.sales_amount) OVER (PARTITION BY c.customer_key) <= 5000 THEN 'Regular'
        ELSE 'New'
    END as new_category,
    s.sales_amount 
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_customers c
    ON s.customer_key = c.customer_key
)

SELECT
new_category,
COUNT(DISTINCT customer_key) AS count_each_group
FROM new_customer_seg
GROUP BY new_category
ORDER BY count_each_group DESC
