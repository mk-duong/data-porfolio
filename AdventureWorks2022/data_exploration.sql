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

SELECT 
    EnglishCountryRegionName
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
   If they exceed, then by how much (%)? 
   (assume that their sales can be counted once order date is created) */
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
WHERE qs.EmployeeKey = qt.EmployeeKey
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
    WHERE qs.EmployeeKey = qt.EmployeeKey
        AND qs.SalesYear = qt.CalendarYear
        AND qs.SalesQuarter = qt.CalendarQuarter
)
-- New query
SELECT
    a.EmployeeKey
    , CONCAT(e1.FirstName, ' ', e1.LastName) AS EmployeeName
    , a.QuarterlySales
    , CONCAT(e2.FirstName, ' ', e2.LastName) AS ManagerName
FROM [reach_quota] a
LEFT JOIN [dbo].[DimEmployee] e1
    ON a.EmployeeKey = e1.EmployeeKey
-- Self-join
LEFT JOIN [dbo].[DimEmployee] e2
    ON e1.ParentEmployeeKey = e2.EmployeeKey
WHERE a.ReachQuota = 'Y'
    AND a.SalesYear = 2011
    AND a.SalesQuarter = 3
ORDER BY a.SalesYear, a.SalesQuarter, a.QuarterlySales DESC
;

/* Did these employees handle a lot of reseller cutsomers during 2011-Q3? */
SELECT 
    s.EmployeeKey
    , COUNT(DISTINCT s.ResellerKey) AS CustomerCounts
FROM [dbo].[FactResellerSales] s
LEFT JOIN [dbo].[DimDate] d
    ON s.OrderDateKey = d.DateKey
WHERE s.EmployeeKey IN (288, 281, 289, 286)
    AND d.CalendarYear = 2011
    AND d.CalendarQuarter = 3
GROUP BY s.EmployeeKey
;

/* Provide the name, business type, and location of the 
   top 10 resellers with most purchase amount in 2011-Q3?
   Sort their total amount purchased in descending order */
WITH top_ten AS (
    SELECT TOP(10)
        s.ResellerKey
        , SUM(SalesAmount) AS TotalAmount
    FROM [dbo].[FactResellerSales] s
    LEFT JOIN [dbo].[DimDate] d
        ON s.OrderDateKey = d.DateKey
    WHERE d.CalendarYear = 2011
        AND d.CalendarQuarter = 3
    GROUP BY s.ResellerKey
    ORDER BY TotalAmount DESC
)

SELECT 
    g.EnglishCountryRegionName
    , g.City
    , r.ResellerName
    , r.BusinessType
FROM top_ten
LEFT JOIN [dbo].[DimReseller] r
    ON top_ten.ResellerKey = r.ResellerKey
LEFT JOIN [dbo].[DimGeography] g
    ON r.GeographyKey = g.GeographyKey
ORDER BY top_ten.TotalAmount DESC
;

/* Total Sales? */
SELECT 
    s.SalesOrderNumber, p.ProductKey, SalesAmount
    , cat.EnglishProductCategoryName
    , sub.EnglishProductSubcategoryName
FROM [dbo].[FactResellerSales] s
LEFT JOIN [dbo].[DimProduct] p
    ON s.ProductKey = p.ProductKey
LEFT JOIN [dbo].[DimProductSubCategory] sub
    ON p.ProductSubcategoryKey = sub.ProductSubcategoryKey
LEFT JOIN [dbo].[DimProductCategory] cat
    ON sub.ProductCategoryKey = cat.ProductCategoryKey
;

/* Total Sales? */
SELECT 
    s.SalesOrderNumber, p.ProductKey, SalesAmount
    , cat.EnglishProductCategoryName
    , sub.EnglishProductSubcategoryName
FROM [dbo].[FactInternetSales] s
LEFT JOIN [dbo].[DimProduct] p
    ON s.ProductKey = p.ProductKey
LEFT JOIN [dbo].[DimProductSubCategory] sub
    ON p.ProductSubcategoryKey = sub.ProductSubcategoryKey
LEFT JOIN [dbo].[DimProductCategory] cat
    ON sub.ProductCategoryKey = cat.ProductCategoryKey
ORDER BY s.SalesOrderNumber
;

SELECT 
    s.SalesOrderNumber, SUM(SalesAmount) AS TotalSales, SUM(SUM(SalesAmount)) OVER() AS OverallSales
FROM [dbo].[FactResellerSales] s
LEFT JOIN [dbo].[DimProduct] p
    ON s.ProductKey = p.ProductKey
LEFT JOIN [dbo].[DimProductSubCategory] sub
    ON p.ProductSubcategoryKey = sub.ProductSubcategoryKey
LEFT JOIN [dbo].[DimProductCategory] cat
    ON sub.ProductCategoryKey = cat.ProductCategoryKey
WHERE cat.EnglishProductCategoryName='Bikes'
GROUP BY SalesOrderNumber
;

/* Is there any sales during July-Dec FY2010 */
SELECT *
FROM [dbo].[FactInternetSales] s
LEFT JOIN [dbo].[DimDate] d
    ON s.OrderDateKey = d.DateKey
WHERE d.FiscalYear = 2010
AND MonthNumberOfYear IN (7,8,9,10,11,12)
;

/* Sales in Canada? */
SELECT g.City, SUM(SalesAmount)
FROM [dbo].[FactInternetSales] s
LEFT JOIN [dbo].[DimCustomer] c
    ON s.CustomerKey = c.CustomerKey
LEFT JOIN [dbo].[DimGeography] g
    ON c.GeographyKey = g.GeographyKey
WHERE g.EnglishCountryRegionName = 'Canada'
GROUP BY g.City
;

/* Why loss in Feb 2012 */
-- What products cost more than it's sold?

SELECT SUM(TotalProductCost) AS TotalCost, SUM(SalesAmount) AS TotalSales
FROM [dbo].[FactInternetSales] s
LEFT JOIN [dbo].[DimDate] d
    ON s.OrderDateKey = d.DateKey
LEFT JOIN [dbo].[DimProduct] p
    ON s.ProductKey = p.ProductKey
WHERE d.FiscalYear = 2012
    AND d.MonthNumberOfYear = 2
;
-- => internet profit

SELECT SUM(TotalProductCost) AS TotalCost, SUM(SalesAmount) AS TotalSales
FROM [dbo].[FactResellerSales] s
LEFT JOIN [dbo].[DimDate] d
    ON s.OrderDateKey = d.DateKey
LEFT JOIN [dbo].[DimProduct] p
    ON s.ProductKey = p.ProductKey
WHERE d.FiscalYear = 2012
    AND d.MonthNumberOfYear = 2
;
-- => reseller loss

SELECT DISTINCT p.EnglishProductName
FROM [dbo].[FactResellerSales] s

LEFT JOIN [dbo].[DimDate] d
    ON s.OrderDateKey = d.DateKey
LEFT JOIN [dbo].[DimProduct] p
    ON s.ProductKey = p.ProductKey
LEFT JOIN [dbo].[DimProductSubCategory] sub
    ON p.ProductSubcategoryKey = sub.ProductSubcategoryKey
LEFT JOIN [dbo].[DimProductCategory] cat
    ON sub.ProductCategoryKey = cat.ProductCategoryKey

WHERE d.FiscalYear = 2012
    AND d.MonthNumberOfYear = 2
    AND cat.EnglishProductCategoryName = 'Bikes'
GROUP BY p.EnglishProductName
HAVING SUM(TotalProductCost) > SUM(SalesAmount)
;
-- These bike products has higher cost than they're sold

/* Are the above products doing well in other months in 2012, or still as bad? so i can consider stop producing them / try to increase their sales / etc.? */
SELECT
    p1.EnglishProductName
    , SUM(CASE WHEN d1.MonthNumberOfYear = 1 THEN SalesAmount - TotalProductCost END) AS 'Jan'
    , SUM(CASE WHEN d1.MonthNumberOfYear = 2 THEN SalesAmount - TotalProductCost END) AS 'Feb'
    , SUM(CASE WHEN d1.MonthNumberOfYear = 3 THEN SalesAmount - TotalProductCost END) AS 'Mar'
    , SUM(CASE WHEN d1.MonthNumberOfYear = 4 THEN SalesAmount - TotalProductCost END) AS 'Apr'
    , SUM(CASE WHEN d1.MonthNumberOfYear = 5 THEN SalesAmount - TotalProductCost END) AS 'May'
    , SUM(CASE WHEN d1.MonthNumberOfYear = 6 THEN SalesAmount - TotalProductCost END) AS 'Jun'
    , SUM(CASE WHEN d1.MonthNumberOfYear = 7 THEN SalesAmount - TotalProductCost END) AS 'Jul'
    , SUM(CASE WHEN d1.MonthNumberOfYear = 8 THEN SalesAmount - TotalProductCost END) AS 'Aug'
    , SUM(CASE WHEN d1.MonthNumberOfYear = 5 THEN SalesAmount - TotalProductCost END) AS 'Sep'
    , SUM(CASE WHEN d1.MonthNumberOfYear = 6 THEN SalesAmount - TotalProductCost END) AS 'Oct'
    , SUM(CASE WHEN d1.MonthNumberOfYear = 7 THEN SalesAmount - TotalProductCost END) AS 'Nov'
    , SUM(CASE WHEN d1.MonthNumberOfYear = 8 THEN SalesAmount - TotalProductCost END) AS 'Dec'

FROM [dbo].[FactResellerSales] s1
LEFT JOIN [dbo].[DimDate] d1
    ON s1.OrderDateKey = d1.DateKey
LEFT JOIN [dbo].[DimProduct] p1
    ON s1.ProductKey = p1.ProductKey

WHERE d1.FiscalYear = 2012
    AND p1.EnglishProductName IN (
        'Road-250 Black, 44'
        , 'Road-250 Black, 48'
        , 'Road-250 Black, 52'
        , 'Road-250 Black, 58'
        , 'Road-250 Red, 58'
        , 'Road-350-W Yellow, 40'
        , 'Road-350-W Yellow, 42'
        , 'Road-350-W Yellow, 44'
        , 'Road-350-W Yellow, 48'
        , 'Road-550-W Yellow, 38'
        , 'Road-550-W Yellow, 40'
        , 'Road-550-W Yellow, 42'
        , 'Road-550-W Yellow, 44'
        , 'Road-550-W Yellow, 48'
        , 'Road-750 Black, 44'
        , 'Road-750 Black, 48'
        , 'Road-750 Black, 52'
        , 'Road-750 Black, 58'
        , 'Touring-1000 Blue, 46'
        , 'Touring-1000 Blue, 50'
        , 'Touring-1000 Blue, 54'
        , 'Touring-1000 Blue, 60'
        , 'Touring-1000 Yellow, 46'
        , 'Touring-1000 Yellow, 50'
        , 'Touring-1000 Yellow, 54'
        , 'Touring-1000 Yellow, 60'
        , 'Touring-2000 Blue, 46'
        , 'Touring-2000 Blue, 50'
        , 'Touring-2000 Blue, 54'
        , 'Touring-2000 Blue, 60'
        , 'Touring-3000 Blue, 44'
        , 'Touring-3000 Blue, 50'
        , 'Touring-3000 Blue, 54'
        , 'Touring-3000 Blue, 58'
        , 'Touring-3000 Blue, 62'
        , 'Touring-3000 Yellow, 44'
        , 'Touring-3000 Yellow, 50'
        , 'Touring-3000 Yellow, 54'
        , 'Touring-3000 Yellow, 58'
        , 'Touring-3000 Yellow, 62'
    )
GROUP BY p1.EnglishProductName
;

/* Why sales in Aug 2011 - 2012 vast difference? */
-- How many orders from internet in Aug 2011 and 2012
SELECT 
    d.FiscalYear
    , COUNT(DISTINCT SalesOrderNumber)
FROM [dbo].[FactInternetSales] s
LEFT JOIN [dbo].[DimDate] d
    ON s.OrderDateKey = d.DateKey
LEFT JOIN [dbo].[DimProduct] p
    ON s.ProductKey = p.ProductKey
LEFT JOIN [dbo].[DimProductSubCategory] sub
    ON p.ProductSubcategoryKey = sub.ProductSubcategoryKey
LEFT JOIN [dbo].[DimProductCategory] cat
    ON sub.ProductCategoryKey = cat.ProductCategoryKey
WHERE d.FiscalYear IN (2011, 2012)
    AND d.MonthNumberOfYear = 8
    AND cat.EnglishProductCategoryName = 'Bikes'
GROUP BY d.FiscalYear
;
-- => Orders from Internet increased

-- How many orders from reseller in Aug 2011 and 2012
SELECT 
    d.FiscalYear
    , COUNT(DISTINCT SalesOrderNumber)
FROM [dbo].[FactResellerSales] s
LEFT JOIN [dbo].[DimDate] d
    ON s.OrderDateKey = d.DateKey
LEFT JOIN [dbo].[DimProduct] p
    ON s.ProductKey = p.ProductKey
LEFT JOIN [dbo].[DimProductSubCategory] sub
    ON p.ProductSubcategoryKey = sub.ProductSubcategoryKey
LEFT JOIN [dbo].[DimProductCategory] cat
    ON sub.ProductCategoryKey = cat.ProductCategoryKey
WHERE d.FiscalYear IN (2011, 2012)
    AND d.MonthNumberOfYear = 8
    AND cat.EnglishProductCategoryName = 'Bikes'
GROUP BY d.FiscalYear
;
-- => Orders from reseller Aug-2011 < Aug-2012
-- => Reseller usually have significant sales amount => their decrease in number of orders have led to a huge sales drop

/* Why orders peak in Jun 2012 (hint: Customer accounts for the majority of orders*/
-- Is it because promotions are available in Jun 2012?
SELECT *
FROM (
    SELECT *
    FROM [dbo].[DimPromotion] p
    WHERE p.StartDate BETWEEN '20120101' AND '20121231'
        OR p.EndDate BETWEEN '20120101' AND '20121231'
) AS sub
WHERE MONTH(sub.StartDate) <= 6
    AND MONTH(sub.StartDate) > 6
;
-- => It's not promotions that affect the peak in orders

-- Is it because many new customers joined in Jun 2012?
SELECT COUNT(*)
FROM [dbo].[DimCustomer]
WHERE DateFirstPurchase BETWEEN '20120601' AND '20120630'
;

SELECT COUNT(DISTINCT CustomerKey)
FROM [dbo].[FactInternetSales] s
LEFT JOIN [dbo].[DimDate] d
    ON s.OrderDateKey = d.DateKey
WHERE FiscalYear = 2012
    AND MonthNumberOfYear = 6
;


/* Sales Variance for each fiscal month in 2012 */
SELECT
    d.MonthNumberOfYear
    , SUM(s.OrderQuantity * p.ListPrice) AS BudgetedSales
    , SUM(s.SalesAmount) AS ActualSales
    , AVG( (s.SalesAmount - s.OrderQuantity * p.ListPrice) * 1.0 / (s.OrderQuantity * p.ListPrice) * 100 ) AS Variance
FROM [dbo].[FactResellerSales] s
LEFT JOIN [dbo].[DimDate] d
    ON s.OrderDateKey = d.DateKey
LEFT JOIN [dbo].[DimProduct] p
    ON s.ProductKey = p.ProductKey
WHERE d.FiscalYear = 2012
GROUP BY d.MonthNumberOfYear
ORDER BY d.MonthNumberOfYear
;