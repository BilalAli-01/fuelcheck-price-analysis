USE FuelCheckDW;
GO
-- ============================================================
-- 03 - Exploration (EDA)
-- Purpose: Understand dataset shape and detect issues
--          before analysis
-- Table:   dbo.fuelcheck_prices
-- ============================================================


-- ============================================================
-- Dataset profile: date range, row count, distinct value counts
-- ============================================================
SELECT
    MIN(PriceUpdatedDate)              AS min_priceupdateddate,
    MAX(PriceUpdatedDate)              AS max_priceupdateddate,
    COUNT(*)                           AS total_rows,
    COUNT(DISTINCT ServiceStationName) AS distinct_stations,
    COUNT(DISTINCT Suburb)             AS distinct_suburbs,
    COUNT(DISTINCT Postcode)             AS distinct_postcodes,
    COUNT(DISTINCT Brand)              AS distinct_brands,
    COUNT(DISTINCT FuelCode)           AS distinct_fuelcodes
FROM dbo.fuelcheck_prices;
GO


-- ============================================================
-- Null check: key columns
-- Confirms no structural nulls in fields required for analysis
-- ============================================================
SELECT
    SUM(CASE WHEN ServiceStationName IS NULL THEN 1 ELSE 0 END) AS null_station,
    SUM(CASE WHEN FuelCode          IS NULL THEN 1 ELSE 0 END) AS null_fuelcode,
    SUM(CASE WHEN Price             IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN PriceUpdatedDate  IS NULL THEN 1 ELSE 0 END) AS null_date
FROM dbo.fuelcheck_prices;
GO


-- ============================================================
-- Price range sanity check
-- Verifies no extreme outliers or zeroes that would
-- distort aggregations
-- ============================================================
SELECT
    MIN(Price) AS min_price,
    MAX(Price) AS max_price
FROM dbo.fuelcheck_prices;
GO


-- ============================================================
-- Anomaly check: sentinel date 1900-01-01
-- Indicates rows where PriceUpdatedDate failed to parse
-- during import and was defaulted to 1900-01-01
-- ============================================================
SELECT COUNT(*) AS bad_date_rows
FROM dbo.fuelcheck_prices
WHERE PriceUpdatedDate = '1900-01-01';
GO

-- Remediation: remove bad-date rows if found above
-- Only run after confirming bad_date_rows > 0
-- Do NOT re-run after data has been cleaned; re-import from scratch if needed
-- DELETE FROM dbo.fuelcheck_prices
-- WHERE PriceUpdatedDate = '1900-01-01';
-- GO


-- ============================================================
-- Geographic scope verification
-- Confirms all records are within NSW or ACT
-- ============================================================

-- Step 1: Check for addresses with no NSW or ACT state token
-- Result: all addresses contained a valid state reference
SELECT *
FROM dbo.fuelcheck_prices
WHERE Address NOT LIKE '%NSW%'
  AND Address NOT LIKE '%ACT%'
  AND Address NOT LIKE '%NEW SOUTH WALES%';
GO

-- Step 2: Postcode range check -- identify min and max values
-- to spot anything obviously out of scope
SELECT
    MIN(Postcode) AS min_postcode,
    MAX(Postcode) AS max_postcode
FROM dbo.fuelcheck_prices;
GO

-- Step 3: Investigate postcodes outside the core NSW/ACT range
-- NSW standard range: 1000-2999, ACT: 2600-2618
-- Upper bound set to 4999 to cast a wide net for edge cases
-- Results explained:
--   2902-2914  ACT postcodes, valid (ACT extends beyond 2618)
--   3644       Baroonga NSW, valid rural NSW near Victorian border
--   4383       Jennings NSW, valid border town on QLD/NSW boundary
-- Conclusion: all out-of-range postcodes verified as legitimate
--             NSW or ACT locations, no rows removed
SELECT DISTINCT
    Postcode,
    Suburb,
    Address
FROM dbo.fuelcheck_prices
WHERE TRY_CAST(Postcode AS INT) < 1000
   OR TRY_CAST(Postcode AS INT) > 4999
ORDER BY TRY_CAST(Postcode AS INT);
GO

-- Step 4: Confirm Jennings (4383) specifically
-- Border town on QLD/NSW boundary -- address confirms NSW scope
SELECT DISTINCT Address
FROM dbo.fuelcheck_prices
WHERE Postcode = '4383';
GO


-- ============================================================
-- FuelCode distribution
-- Identifies which fuel types have the most coverage;
-- used to select focus fuel codes for deeper analysis
-- ============================================================
SELECT
    FuelCode,
    COUNT(*) AS total_rows
FROM dbo.fuelcheck_prices
GROUP BY FuelCode
ORDER BY total_rows DESC;
GO


-- ============================================================
-- Monthly price trend (P98)
-- Filtered to P98 as it returned the highest row count
-- in the distribution query above
-- Note: observations reflect polling snapshots, not unique
-- price changes -- averages may be skewed toward
-- frequently-polled stations (see polling investigation below)
-- ============================================================
SELECT
    DATEFROMPARTS(YEAR(PriceUpdatedDate), MONTH(PriceUpdatedDate), 1) AS month_start,
    AVG(Price)   AS avg_price,
    MIN(Price)   AS min_price,
    MAX(Price)   AS max_price,
    COUNT(*)     AS observations
FROM dbo.fuelcheck_prices
WHERE FuelCode = 'P98'
GROUP BY DATEFROMPARTS(YEAR(PriceUpdatedDate), MONTH(PriceUpdatedDate), 1)
ORDER BY month_start;
GO


-- ============================================================
-- Station update frequency (P98)
-- Flags stations with more than one recorded price on the
-- same day for the same fuel code
-- High counts here suggest repeated polling snapshots rather
-- than genuine price changes
-- ============================================================
SELECT TOP 20
    ServiceStationName,
    CAST(PriceUpdatedDate AS DATE) AS price_date,
    COUNT(*)                       AS updates_that_day
FROM dbo.fuelcheck_prices
WHERE FuelCode = 'P98'
GROUP BY ServiceStationName, CAST(PriceUpdatedDate AS DATE)
HAVING COUNT(*) > 1
ORDER BY updates_that_day DESC;
GO


-- ============================================================
-- Drill-down: Ampol Foodary Werrington, 2024-08-02 (P98)
-- This station recorded 38 price updates in a single day --
-- the highest in the dataset for P98
-- Result confirms this is periodic polling, not genuine price
-- changes: price alternates by a few cents every ~14-16 mins
-- Conclusion: this dataset represents polling snapshots, not
-- price change events -- downstream aggregates must account
-- for this (see 04_core_views.sql)
-- ============================================================
SELECT
    PriceUpdatedDate,
    Price
FROM dbo.fuelcheck_prices
WHERE ServiceStationName = 'Ampol Foodary Werrington'
  AND CAST(PriceUpdatedDate AS DATE) = '2024-08-02'
  AND FuelCode = 'P98'
ORDER BY PriceUpdatedDate;
GO