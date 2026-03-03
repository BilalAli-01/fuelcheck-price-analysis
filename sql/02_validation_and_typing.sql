USE FuelCheckDW
GO

-- ============================================================
-- 02 - Validation & Typing
-- Goal: validate imported text columns then convert to proper types
-- ============================================================


-- Confirm rows were loaded before proceeding
SELECT COUNT(*)
FROM dbo.fuelcheck_prices


-- Identify unparseable values before attempting type conversion
-- Any non-zero result here will cause the ALTER TABLE statements below to fail
SELECT
    SUM(CASE
        WHEN PriceUpdatedDate IS NULL THEN 0
        WHEN TRY_CONVERT(DATETIME2, PriceUpdatedDate) IS NULL THEN 1 ELSE 0
    END) AS bad_priceupdateddate_rows,

    SUM(CASE 
        WHEN LoadDate IS NULL THEN 0
        WHEN TRY_CONVERT(DATETIME2, LoadDate) IS NULL THEN 1 ELSE 0
    END) AS bad_loaddate_rows,

    SUM(CASE 
        WHEN Price IS NULL THEN 0
        WHEN TRY_CONVERT(DECIMAL(10,3), Price) IS NULL THEN 1 ELSE 0
    END) AS bad_price_rows
FROM dbo.fuelcheck_prices


-- Convert date and numeric columns from NVARCHAR to their proper types
-- Validation query above must return 0 for all bad_* columns
ALTER TABLE dbo.fuelcheck_prices
ALTER COLUMN PriceUpdatedDate DATETIME2

ALTER TABLE dbo.fuelcheck_prices
ALTER COLUMN LoadDate DATETIME2

ALTER TABLE dbo.fuelcheck_prices
ALTER COLUMN Price DECIMAL(10,2)


-- Verify converted values look correct after typing
SELECT TOP 5
    PriceUpdatedDate, Price, LoadDate
FROM dbo.fuelcheck_prices
ORDER BY PriceUpdatedDate