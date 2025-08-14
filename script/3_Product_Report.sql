/*
=======================================================================================
Product Report
=======================================================================================
Purpose:
    - This report consolidates key product metrics and behaviors

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-range, or Low-Performers.
    3. Aggregate product-level metrics:
        -total orders
        -total sales
        -total quantity sold
        -total customers (unique)
        -lifespan (in months)
    4. Calculates valuable KPIs:
        -recent (months since last sale)
        -average order revenue --> AVG order revenue = total sales / total_orders
        -average monthly spend --> total_sales/lifespan
=======================================================================================
*/

/*
---------------------------------------------------------------------------------------
1) Base Query: Retrieves core columns from table
---------------------------------------------------------------------------------------
*/
IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
  DROP VIEW gold.report_products;
GO

CREATE VIEW gold.report_products AS
WITH base_query AS
(
    SELECT
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost,
        f.order_number,
        f.sales_amount,
        f.quantity,
        f.customer_key,
        f.order_date
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
    WHERE f.order_date IS NOT NULL
)
/*
---------------------------------------------------------------------------------------
1) Product Aggregation: Summarize key metrics at the product level
---------------------------------------------------------------------------------------
*/
, product_aggregation AS (
    SELECT 
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        COUNT(quantity) AS total_quantity,
        COUNT(DISTINCT customer_key)  AS total_customers,
        MAX(order_date) AS last_sale,
        DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan,
        ROUND(AVG(CAST(sales_amount AS FLOAT)/ NULLIF(quantity, 0)), 1) AS avg_selling_price
    FROM base_query
    GROUP BY 
        product_key,
        product_name,
        category,
        subcategory,
        cost
)

SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    DATEDIFF(month, last_sale, GETDATE()) AS recency,
    CASE
        WHEN total_sales > 50000 THEN 'High-Performer'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE 'Low-Performer'
    END AS product_segment,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    avg_selling_price,
    -- AOR
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END AS AOR,
    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS avg_monthly_revenue
FROM product_aggregation
