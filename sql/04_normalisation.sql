USE FuelCheckDW
GO
-- ============================================================
-- 04 - Normalisation
-- Purpose: Remove intraday polling bias by reducing multiple
--          daily snapshots to a single observation per
--          station + fuel type + day
-- Input:   dbo.fuelcheck_prices  (1,750,341 rows)
-- Output:  dbo.fuel_prices_daily (1,249,066 rows)
-- ============================================================
-- Approach: AVG(Price) per day chosen over latest-snapshot
-- because intraday prices alternate irregularly
--
-- Brand handling: Brand excluded from GROUP BY due to
-- inconsistent labelling in the source data. Investigation
-- found 457 station+fuelcode+date groups with multiple brand
-- values -- 442 of these (97%) are Ampol vs Ampol Foodary,
-- a known sub-brand labelling inconsistency in the FuelCheck
-- dataset. Remaining 15 rows involve small independents.
-- Resolution: MAX(Brand) used as a deterministic tiebreaker.
-- Impact is negligible at this dataset scale.
--
-- Note: observations_that_day is retained so downstream
-- queries can identify and flag heavily-polled stations
-- ============================================================


-- Drop and recreate table to allow safe re-runs
DROP TABLE IF EXISTS dbo.fuel_prices_daily;


-- Build daily aggregated table from raw polling data
SELECT
    ServiceStationName,
    Address,
    Suburb,
    Postcode,
    MAX(Brand)                     AS Brand,
    FuelCode,
    CAST(PriceUpdatedDate AS DATE) AS price_date,
    AVG(Price)                     AS avg_daily_price,
    MIN(Price)                     AS min_daily_price,
    MAX(Price)                     AS max_daily_price,
    COUNT(*)                       AS observations_that_day
INTO dbo.fuel_prices_daily
FROM dbo.fuelcheck_prices
GROUP BY
    ServiceStationName,
    Address,
    Suburb,
    Postcode,
    FuelCode,
    CAST(PriceUpdatedDate AS DATE)
GO


-- ============================================================
-- Validation
-- ============================================================

-- Row count: should be significantly less than raw table
-- Expected: ~1,249,066 rows after normalisation
SELECT COUNT(*) AS daily_rows
FROM dbo.fuel_prices_daily
GO

-- Duplicate check: should return 0 rows
-- Any result here indicates the GROUP BY is incomplete
SELECT TOP 50
    ServiceStationName,
    Address,
    FuelCode,
    price_date,
    COUNT(*) AS cnt
FROM dbo.fuel_prices_daily
GROUP BY
    ServiceStationName,
    Address,
    FuelCode,
    price_date
HAVING COUNT(*) > 1
ORDER BY cnt DESC
GO

-- Date range: should match cleaned source table
-- Expected: 2024-01-01 to 2026-01-31
SELECT
    MIN(price_date) AS min_date,
    MAX(price_date) AS max_date
FROM dbo.fuel_prices_daily
GO

-- Spot check: confirm aggregation looks sensible
-- observations_that_day should vary -- high values indicate
-- formerly heavily-polled stations, now normalised to one row
SELECT TOP 20
    ServiceStationName,
    FuelCode,
    price_date,
    Brand,
    avg_daily_price,
    min_daily_price,
    max_daily_price,
    observations_that_day
FROM dbo.fuel_prices_daily
ORDER BY observations_that_day DESC
GO