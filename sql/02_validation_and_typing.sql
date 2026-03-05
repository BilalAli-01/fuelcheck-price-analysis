USE FuelCheckDW;
GO

-- ============================================================
-- 02 - Validation & Typing
-- Goal: validate imported text columns then convert to proper types
-- ============================================================


-- Confirm rows were loaded before proceeding
SELECT COUNT(*)
FROM dbo.fuel_prices_raw;
GO

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
FROM dbo.fuel_prices_raw;
GO

-- Convert date and numeric columns from NVARCHAR to their proper types
-- Validation query above must return 0 for all bad_* columns
ALTER TABLE dbo.fuel_prices_raw
ALTER COLUMN PriceUpdatedDate DATETIME2;
GO

ALTER TABLE dbo.fuel_prices_raw
ALTER COLUMN LoadDate DATETIME2;
GO

ALTER TABLE dbo.fuel_prices_raw
ALTER COLUMN Price DECIMAL(10,2);
GO

-- Verify converted values look correct after typing
SELECT TOP 5
    PriceUpdatedDate, Price, LoadDate
FROM dbo.fuel_prices_raw
ORDER BY PriceUpdatedDate;
GO