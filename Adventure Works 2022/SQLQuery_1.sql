/* What is the total number of products */
SELECT COUNT(*) TotalNumberProducts
FROM [dbo].[DimProduct]
;

/* What is the total number of products by category & subcategory? */
SELECT 
    cat.EnglishProductCategoryName
    , sub.EnglishProductSubcategoryName
    , COUNT(*) TotalNumberProducts
FROM [dbo].[DimProduct] p
LEFT JOIN [dbo].[DimProductSubCategory] sub
    ON p.ProductSubcategoryKey = sub.ProductSubcategoryKey
LEFT JOIN [dbo].[DimProductCategory] cat
    ON sub.ProductCategoryKey = cat.ProductCategoryKey
GROUP BY cat.EnglishProductCategoryName, sub.EnglishProductSubcategoryName
ORDER BY cat.EnglishProductCategoryName, sub.EnglishProductSubcategoryName
;

/* What is the average profit for each category & subcategory? 
   Which subcategory yields the highest average profit in each category? */

WITH cte as (
    SELECT
        cat.EnglishProductCategoryName AS CategoryName
        , sub.EnglishProductSubcategoryName AS SubcategoryName
        , AVG(s.SalesAmount - s.TotalProductCost) AS AvgProfit

    FROM [AdventureWorksDW2022].[dbo].[FactInternetSales] s
    LEFT JOIN [dbo].[DimProduct] p
        ON s.ProductKey = p.ProductKey
    LEFT JOIN [dbo].[DimProductSubCategory] sub
        ON p.ProductSubcategoryKey = sub.ProductSubcategoryKey
    LEFT JOIN [dbo].[DimProductCategory] cat
        ON sub.ProductCategoryKey = cat.ProductCategoryKey

    GROUP BY cat.EnglishProductCategoryName, sub.EnglishProductSubcategoryName
)

, cte_rank AS (
    SELECT 
        CategoryName
        , SubcategoryName
        , AvgProfit
        , RANK() OVER(PARTITION BY CategoryName ORDER BY AvgProfit DESC) AS ranking
    FROM cte
)

SELECT 
    CategoryName
    , SubcategoryName
    , AvgProfit
FROM cte_rank
WHERE ranking = 1
;

/* Select the products that started selling between 2012 and 2013 */
SELECT DISTINCT EnglishProductName
FROM [dbo].[DimProduct]
WHERE YEAR(StartDate) IN (2012, 2013)
;

/* Select all info for all orders placed in June 2011
   and include a column for an estimated delivery date
   (assume 7 days after the order date) */
SELECT *
    , DATEADD(DAY, 7, OrderDate) AS EstimateShipDate
FROM [AdventureWorksDW2022].[dbo].[FactInternetSales]
WHERE CAST(OrderDate AS DATE) BETWEEN '2011-06-01' AND '2011-06-30'
;

/* On average, how long does it take for products 
   to be delivered to customers depending on product category? */
SELECT
    cat.EnglishProductCategoryName
    , AVG(DATEDIFF(DAY, OrderDate, DueDate)) AS AvgDeliveryDays
FROM [AdventureWorksDW2022].[dbo].[FactInternetSales] AS s
LEFT JOIN [dbo].[DimProduct] AS p
    ON s.ProductKey = p.ProductKey
LEFT JOIN [dbo].[DimProductSubCategory] sub
    ON p.ProductSubcategoryKey = sub.ProductSubcategoryKey
LEFT JOIN [dbo].[DimProductCategory] cat
    ON sub.ProductCategoryKey = cat.ProductCategoryKey
GROUP BY cat.EnglishProductCategoryName
;

/* Retrieve the Customer ID and total number of orders 
   of those placing more than one order in 2011 */
SELECT CustomerKey, COUNT(*) AS OrderCounts
FROM [dbo].[FactInternetSales]
GROUP BY CustomerKey
HAVING COUNT(*) > 1

/* Use the query above, retrieve customer's full name, state, country, and order counts */
WITH cte AS (
    SELECT CustomerKey, COUNT(*) AS OrderCounts
    FROM [dbo].[FactInternetSales]
    GROUP BY CustomerKey
    HAVING COUNT(*) > 1
)

SELECT
    CONCAT(c.FirstName, ' ', c.LastName) AS FullName
    , g.StateProvinceName
    , g.EnglishCountryRegionName
    , cte.OrderCounts
FROM cte
LEFT JOIN [dbo].[DimCustomer] as c
    ON cte.CustomerKey = c.CustomerKey
LEFT JOIN [dbo].[DimGeography] as g
    ON c.GeographyKey = g.GeographyKey
ORDER BY OrderCounts DESC
;

/* What is the percentage of grand total orders each country region account for? */
WITH cte AS (
SELECT
    g.EnglishCountryRegionName
    , COUNT(*) AS OrderCounts
    , SUM(COUNT(*)) OVER() AS TotalOrders
FROM [dbo].[FactInternetSales] AS s
LEFT JOIN [dbo].[DimCustomer] as c
    ON s.CustomerKey = c.CustomerKey
LEFT JOIN [dbo].[DimGeography] as g
    ON c.GeographyKey = g.GeographyKey
GROUP BY g.EnglishCountryRegionName
)

SELECT *
    , CAST((OrderCounts * 1.0 / TotalOrders) * 100 AS DECIMAL(4,2)) AS PercOfGrandTotal
FROM cte
ORDER BY PercOfGrandTotal DESC
;

/* Provide a list of info for sales person who have sold product ID 314 
   What is their employee ID, full name, and sales territory*/
SELECT 
    EmployeeKey
    , CONCAT(FirstName, ' ', LastName) AS FullName
    , SalesTerritoryCountry
FROM [dbo].[DimEmployee] e
LEFT JOIN [dbo].[DimSalesTerritory] t
    ON e.SalesTerritoryKey = t.SalesTerritoryKey
WHERE EmployeeKey IN (
    SELECT EmployeeKey
    FROM [dbo].[FactResellerSales]
    WHERE ProductKey = 314
)
;

/* Did the employees from the list above meet or exceed their sales quota? 
   If they exceed, then by how much (%)? (assume that their sales can be 
   counted once order date is created) */
WITH employee_quarterly_sales AS (
    SELECT
        s.EmployeeKey
        , d.CalendarYear AS SalesYear
        , d.CalendarQuarter AS SalesQuarter
        , SUM(s.SalesAmount) AS QuarterlySales
    FROM [dbo].[FactResellerSales] s
    LEFT JOIN [dbo].[DimDate] d
        ON s.OrderDateKey = d.DateKey
    WHERE s.EmployeeKey IN (272, 281, 282, 283, 284, 285, 286, 287, 288, 289)
    GROUP BY s.EmployeeKey, d.CalendarYear, d.CalendarQuarter
)

-- There are instances where an employee's quarterly quota got updated (e.g., 2011-Q3)
-- use the latest date on which quota was updated as the benchmark
, max_date AS (
    SELECT 
        *
        , MAX([Date]) OVER(PARTITION BY EmployeeKey, CalendarYear, CalendarQuarter) AS LatestUpdateDate
    FROM [dbo].[FactSalesQuota]
)

, latest_quota AS (
    SELECT
        EmployeeKey
        , CalendarYear
        , CalendarQuarter
        , SalesAmountQuota
        , [Date]
    FROM [max_date]
    WHERE [Date] = LatestUpdateDate
)

SELECT 
    qs.EmployeeKey
    , qs.SalesYear
    , qs.SalesQuarter
    , qs.QuarterlySales
    , qt.SalesAmountQuota
    , CASE WHEN qs.QuarterlySales >= qt.SalesAmountQuota THEN 'Y' ELSE 'N' END AS ReachQuota
    , CASE WHEN qs.QuarterlySales >= qt.SalesAmountQuota THEN (qs.QuarterlySales - qt.SalesAmountQuota) / qt.SalesAmountQuota * 100
      ELSE null END AS Perc
FROM 
    [employee_quarterly_sales] qs
    , [latest_quota] qt
WHERE 
    qs.EmployeeKey = qt.EmployeeKey
    AND qs.SalesYear = qt.CalendarYear
    AND qs.SalesQuarter = qt.CalendarQuarter
ORDER BY qs.SalesYear, qs.SalesQuarter, EmployeeKey
;

/* Provide a list of employee names who met their quota in 2011-Q3. 
   Let's also inform their manager to give them a bonus! Provide their manager's info */
-- Reuse previous query
WITH employee_quarterly_sales AS (
    SELECT
        s.EmployeeKey
        , d.CalendarYear AS SalesYear
        , d.CalendarQuarter AS SalesQuarter
        , SUM(s.SalesAmount) AS QuarterlySales
    FROM [dbo].[FactResellerSales] s
    LEFT JOIN [dbo].[DimDate] d
        ON s.OrderDateKey = d.DateKey
    WHERE s.EmployeeKey IN (272, 281, 282, 283, 284, 285, 286, 287, 288, 289)
    GROUP BY s.EmployeeKey, d.CalendarYear, d.CalendarQuarter
)

, max_date AS (
    SELECT 
        *
        , MAX([Date]) OVER(PARTITION BY EmployeeKey, CalendarYear, CalendarQuarter) AS LatestUpdateDate
    FROM [dbo].[FactSalesQuota]
)

, latest_quota AS (
    SELECT
        EmployeeKey
        , CalendarYear
        , CalendarQuarter
        , SalesAmountQuota
        , [Date]
    FROM [max_date]
    WHERE [Date] = LatestUpdateDate
)

, reach_quota AS (
    SELECT 
        qs.EmployeeKey
        , qs.SalesYear
        , qs.SalesQuarter
        , qs.QuarterlySales
        , qt.SalesAmountQuota
        , CASE WHEN qs.QuarterlySales >= qt.SalesAmountQuota THEN 'Y' ELSE 'N' END AS ReachQuota
        , CASE WHEN qs.QuarterlySales >= qt.SalesAmountQuota THEN (qs.QuarterlySales - qt.SalesAmountQuota) / qt.SalesAmountQuota * 100
          ELSE null END AS Perc
    FROM 
        [employee_quarterly_sales] qs
        , [latest_quota] qt
    WHERE 
        qs.EmployeeKey = qt.EmployeeKey
        AND qs.SalesYear = qt.CalendarYear
        AND qs.SalesQuarter = qt.CalendarQuarter
)
-- New query
SELECT
    CONCAT(e1.FirstName, ' ', e1.LastName) AS EmployeeName
    , CONCAT(e2.FirstName, ' ', e2.LastName) AS ManagerName
FROM [reach_quota] a
LEFT JOIN [dbo].[DimEmployee] e1
    ON a.EmployeeKey = e1.EmployeeKey
-- Self-join
LEFT JOIN [dbo].[DimEmployee] e2
    ON e1.ParentEmployeeKey = e2.EmployeeKey
WHERE 
    a.ReachQuota = 'Y'
    AND a.SalesYear = 2011
    AND a.SalesQuarter = 3
ORDER BY a.SalesYear, a.SalesQuarter, a.Perc DESC
;
