USE FuelCheckDW;
GO
-- ============================================================
-- 05 - Analysis
-- Purpose: Produce analytical outputs for Power BI reporting
-- Source:  dbo.fuel_prices_daily (1,249,066 rows)
-- ============================================================
-- All queries use the normalised daily table to avoid
-- overweighting heavily-polled stations (see 03_eda.sql and
-- 04_normalisation.sql for full context)
-- Primary fuel type for geographic and brand analysis: U91
-- To change the fuel type for sections 3 and 4, update the
-- @FuelCode variable at the top of each batch
-- Available codes: U91, E10, P95, P98, PDL, DL, B20, E85, LPG
-- ============================================================
-- Note: active_stations and station_count throughout use
-- CONCAT(ServiceStationName, '|', Suburb, '|', Postcode) as
-- the distinct key to count physical locations accurately.
-- Counting by name alone undercounts as chain brands share
-- the same name across multiple suburbs.
-- ============================================================


-- ============================================================
-- SECTION 1: TREND ANALYSIS
-- ============================================================

-- 1a. Monthly average price by fuel type
-- Shows how each fuel type has trended over the dataset period
-- No fuel code filter -- returns all fuel types for comparison
-- ============================================================
SELECT
    DATEFROMPARTS(YEAR(price_date), MONTH(price_date), 1)              AS month_start,
    FuelCode,
    ROUND(AVG(avg_daily_price), 2)                                     AS avg_monthly_price,
    ROUND(MIN(min_daily_price), 2)                                     AS min_monthly_price,
    ROUND(MAX(max_daily_price), 2)                                     AS max_monthly_price,
    COUNT(DISTINCT CONCAT(ServiceStationName, '|', Suburb, '|', Postcode)) AS active_stations
FROM dbo.fuel_prices_daily
GROUP BY
    DATEFROMPARTS(YEAR(price_date), MONTH(price_date), 1),
    FuelCode
ORDER BY
    month_start,
    FuelCode;
GO


-- 1b. Monthly price volatility by fuel type
-- STDEV of daily average prices within each month
-- Higher values indicate more price instability that month
-- No fuel code filter -- returns all fuel types for comparison
-- ============================================================
SELECT
    DATEFROMPARTS(YEAR(price_date), MONTH(price_date), 1)              AS month_start,
    FuelCode,
    ROUND(STDEV(avg_daily_price), 4)                                   AS price_stdev,
    COUNT(DISTINCT CONCAT(ServiceStationName, '|', Suburb, '|', Postcode)) AS active_stations
FROM dbo.fuel_prices_daily
GROUP BY
    DATEFROMPARTS(YEAR(price_date), MONTH(price_date), 1),
    FuelCode
ORDER BY
    month_start,
    FuelCode;
GO


-- ============================================================
-- SECTION 2: FUEL TYPE ANALYSIS
-- ============================================================

-- 2a. Overall average price by fuel type
-- Baseline comparison across all fuel types for full period
-- No fuel code filter -- returns all fuel types for comparison
-- ============================================================
SELECT
    FuelCode,
    ROUND(AVG(avg_daily_price), 2)                                     AS avg_price,
    ROUND(MIN(min_daily_price), 2)                                     AS min_price,
    ROUND(MAX(max_daily_price), 2)                                     AS max_price,
    ROUND(STDEV(avg_daily_price), 4)                                   AS price_stdev,
    COUNT(DISTINCT CONCAT(ServiceStationName, '|', Suburb, '|', Postcode)) AS station_coverage
FROM dbo.fuel_prices_daily
GROUP BY FuelCode
ORDER BY avg_price DESC;
GO


-- 2b. Monthly P98 price premium over U91
-- Measures how much more expensive P98 is vs U91 each month
-- A widening gap may indicate premium fuel demand behaviour
-- ============================================================
WITH monthly_avg AS (
    SELECT
        DATEFROMPARTS(YEAR(price_date), MONTH(price_date), 1) AS month_start,
        FuelCode,
        AVG(avg_daily_price) AS avg_monthly_price
    FROM dbo.fuel_prices_daily
    WHERE FuelCode IN ('P98', 'U91')
    GROUP BY
        DATEFROMPARTS(YEAR(price_date), MONTH(price_date), 1),
        FuelCode
)
SELECT
    p98.month_start,
    ROUND(p98.avg_monthly_price, 2)                         AS p98_avg,
    ROUND(u91.avg_monthly_price, 2)                         AS u91_avg,
    ROUND(p98.avg_monthly_price - u91.avg_monthly_price, 2) AS premium_cents
FROM monthly_avg p98
JOIN monthly_avg u91
    ON  p98.month_start = u91.month_start
    AND p98.FuelCode    = 'P98'
    AND u91.FuelCode    = 'U91'
ORDER BY p98.month_start;
GO


-- ============================================================
-- SECTION 3: BRAND ANALYSIS
-- ============================================================
-- To query a different fuel type, update @FuelCode below
-- Available codes: U91, E10, P95, P98, PDL, DL, B20, E85, LPG
-- ============================================================

-- 3a. Overall average price by brand
-- Ranks brands from cheapest to most expensive
-- ============================================================
DECLARE @FuelCode NVARCHAR(50) = 'U91';

SELECT
    Brand,
    ROUND(AVG(avg_daily_price), 2)                                     AS avg_price,
    ROUND(MIN(min_daily_price), 2)                                     AS min_price,
    ROUND(MAX(max_daily_price), 2)                                     AS max_price,
    COUNT(DISTINCT CONCAT(ServiceStationName, '|', Suburb, '|', Postcode)) AS station_count,
    COUNT(DISTINCT Suburb)                                             AS suburb_coverage
FROM dbo.fuel_prices_daily
WHERE FuelCode = @FuelCode
GROUP BY Brand
ORDER BY avg_price ASC;
GO


-- 3b. Brand price volatility
-- Brands with higher STDEV fluctuate more aggressively
-- May indicate price cycling behaviour
-- ============================================================
DECLARE @FuelCode NVARCHAR(50) = 'U91';

SELECT
    Brand,
    ROUND(AVG(avg_daily_price), 2)                                     AS avg_price,
    ROUND(STDEV(avg_daily_price), 4)                                   AS price_stdev,
    COUNT(DISTINCT CONCAT(ServiceStationName, '|', Suburb, '|', Postcode)) AS station_count
FROM dbo.fuel_prices_daily
WHERE FuelCode = @FuelCode
GROUP BY Brand
ORDER BY price_stdev DESC;
GO


-- 3c. Brand price premium vs dataset average
-- Positive value = more expensive than average
-- Negative value = cheaper than average
-- ============================================================
DECLARE @FuelCode NVARCHAR(50) = 'U91';

WITH dataset_avg AS (
    SELECT AVG(avg_daily_price) AS overall_avg
    FROM dbo.fuel_prices_daily
    WHERE FuelCode = @FuelCode
)
SELECT
    Brand,
    ROUND(AVG(f.avg_daily_price), 2)                AS brand_avg,
    ROUND(AVG(f.avg_daily_price) - d.overall_avg, 2) AS cents_vs_average,
    COUNT(DISTINCT CONCAT(f.ServiceStationName, '|', f.Suburb, '|', f.Postcode)) AS station_count
FROM dbo.fuel_prices_daily f
CROSS JOIN dataset_avg d
WHERE f.FuelCode = @FuelCode
GROUP BY Brand, d.overall_avg
ORDER BY cents_vs_average ASC;
GO


-- ============================================================
-- SECTION 4: GEOGRAPHIC ANALYSIS
-- ============================================================
-- To query a different fuel type, update @FuelCode below
-- Available codes: U91, E10, P95, P98, PDL, DL, B20, E85, LPG
-- ============================================================

-- 4a. Cheapest vs most expensive suburbs
-- Minimum 2 stations required per suburb to avoid
-- unrepresentative single-station results
-- Order by avg_price ASC for cheapest, DESC for most expensive
-- ============================================================
DECLARE @FuelCode NVARCHAR(50) = 'U91';

WITH suburb_stats AS (
    SELECT
        Suburb,
        Postcode,
        ROUND(AVG(avg_daily_price), 2)   AS avg_price,
        ROUND(STDEV(avg_daily_price), 4) AS price_stdev,
        COUNT(DISTINCT CONCAT(ServiceStationName, '|', Suburb, '|', Postcode)) AS station_count
    FROM dbo.fuel_prices_daily
    WHERE FuelCode = @FuelCode
    GROUP BY Suburb, Postcode
    HAVING COUNT(DISTINCT CONCAT(ServiceStationName, '|', Suburb, '|', Postcode)) >= 2
)
SELECT
    Suburb,
    Postcode,
    avg_price,
    price_stdev,
    station_count
FROM suburb_stats
ORDER BY avg_price ASC;
GO


-- 4b. Suburb price volatility
-- Suburbs with high STDEV experience more price swings
-- Minimum 2 stations required
-- ============================================================
DECLARE @FuelCode NVARCHAR(50) = 'U91';

WITH suburb_volatility AS (
    SELECT
        Suburb,
        Postcode,
        ROUND(AVG(avg_daily_price), 2)   AS avg_price,
        ROUND(STDEV(avg_daily_price), 4) AS price_stdev,
        COUNT(DISTINCT CONCAT(ServiceStationName, '|', Suburb, '|', Postcode)) AS station_count
    FROM dbo.fuel_prices_daily
    WHERE FuelCode = @FuelCode
    GROUP BY Suburb, Postcode
    HAVING COUNT(DISTINCT CONCAT(ServiceStationName, '|', Suburb, '|', Postcode)) >= 2
)
SELECT
    Suburb,
    Postcode,
    avg_price,
    price_stdev,
    station_count
FROM suburb_volatility
ORDER BY price_stdev DESC;
GO


-- 4c. Cheapest station per suburb
-- Returns the single cheapest station in each suburb
-- based on average daily price across the full period
-- Suburbs with fewer than 2 stations excluded
-- ============================================================
DECLARE @FuelCode NVARCHAR(50) = 'U91';

WITH station_avg AS (
    SELECT
        Suburb,
        Postcode,
        ServiceStationName,
        Brand,
        ROUND(AVG(avg_daily_price), 2) AS avg_price
    FROM dbo.fuel_prices_daily
    WHERE FuelCode = @FuelCode
    GROUP BY
        Suburb,
        Postcode,
        ServiceStationName,
        Brand
),
suburb_counts AS (
    SELECT
        Suburb,
        COUNT(DISTINCT CONCAT(ServiceStationName, '|', Suburb, '|', Postcode)) AS stations_in_suburb
    FROM dbo.fuel_prices_daily
    WHERE FuelCode = @FuelCode
    GROUP BY Suburb
),
ranked AS (
    SELECT
        s.Suburb,
        s.Postcode,
        s.ServiceStationName,
        s.Brand,
        s.avg_price,
        ROW_NUMBER() OVER (
            PARTITION BY s.Suburb
            ORDER BY s.avg_price ASC
        ) AS price_rank
    FROM station_avg s
    JOIN suburb_counts c
        ON s.Suburb = c.Suburb
    WHERE c.stations_in_suburb >= 2
)
SELECT
    Suburb,
    Postcode,
    ServiceStationName,
    Brand,
    avg_price
FROM ranked
WHERE price_rank = 1
ORDER BY avg_price ASC;
GO