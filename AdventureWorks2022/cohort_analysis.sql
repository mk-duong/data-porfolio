-- USE AdventureWorksDW2022;
-- GO

-- CREATE SCHEMA Project;
-- GO

-- Limit results to 2012
-- Determine the month on which the resellers first purchase?
WITH first_order_date AS (
    SELECT
        ResellerKey
        , DATETRUNC(MONTH, MIN(OrderDate)) AS FirstMonth
    FROM [dbo].[FactResellerSales]
    WHERE OrderDate BETWEEN '2012-01-01' AND '2012-12-31'
    GROUP BY ResellerKey
)

-- Caclculate the number of new resellers by month
, new_reseller_by_month AS (
    SELECT FirstMonth, COUNT(ResellerKey) AS NewResellers
    FROM first_order_date
    GROUP BY FirstMonth
)

-- For each reseller, determine the months on which they had purchases
, reseller_retenion_month AS (
    SELECT DISTINCT
        ResellerKey
        , DATETRUNC(MONTH, OrderDate) AS RetentionMonth
    FROM [dbo].[FactResellerSales]
    WHERE OrderDate BETWEEN '2012-01-01' AND '2012-12-31'
)

-- Calculate the number of retained resellers
, retained_reseller_by_month AS (
    SELECT 
        FirstMonth
        , RetentionMonth
        , COUNT(r.ResellerKey) AS RetainedResellers
    FROM reseller_retenion_month r
    LEFT JOIN first_order_date f
        ON r.ResellerKey = f.ResellerKey
    GROUP BY FirstMonth, RetentionMonth
)

, cohort AS (
SELECT 
    n.FirstMonth
    , r.RetentionMonth
    , n.NewResellers
    , r.RetainedResellers
    , CAST(r.RetainedResellers * 1.0 / n.NewResellers AS DECIMAL(5,3)) AS RetentionRate
FROM new_reseller_by_month n
LEFT JOIN retained_reseller_by_month r
    ON n.FirstMonth = r.FirstMonth
)

SELECT
    FirstMonth
    , MAX(CASE WHEN RetentionMonth = '2012-01-01' THEN RetentionRate END) AS 'Jan'
    , MAX(CASE WHEN RetentionMonth = '2012-02-01' THEN RetentionRate END) AS 'Feb'
    , MAX(CASE WHEN RetentionMonth = '2012-03-01' THEN RetentionRate END) AS 'Mar'
    , MAX(CASE WHEN RetentionMonth = '2012-04-01' THEN RetentionRate END) AS 'Apr'
    , MAX(CASE WHEN RetentionMonth = '2012-05-01' THEN RetentionRate END) AS 'May'
    , MAX(CASE WHEN RetentionMonth = '2012-06-01' THEN RetentionRate END) AS 'Jun'
    , MAX(CASE WHEN RetentionMonth = '2012-07-01' THEN RetentionRate END) AS 'Jul'
    , MAX(CASE WHEN RetentionMonth = '2012-08-01' THEN RetentionRate END) AS 'Aug'
    , MAX(CASE WHEN RetentionMonth = '2012-09-01' THEN RetentionRate END) AS 'Sep'
    , MAX(CASE WHEN RetentionMonth = '2012-10-01' THEN RetentionRate END) AS 'Oct'
    , MAX(CASE WHEN RetentionMonth = '2012-11-01' THEN RetentionRate END) AS 'Nov'
    , MAX(CASE WHEN RetentionMonth = '2012-12-01' THEN RetentionRate END) AS 'Dec'
FROM cohort
GROUP BY FirstMonth
;