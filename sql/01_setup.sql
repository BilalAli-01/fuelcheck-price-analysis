-- ============================================================
-- FuelCheck Data - Initial Setup
-- Purpose:
-- 1) Create database
-- 2) Create raw landing table (all text)
-- ============================================================


-- Create database if it doesn't already exist
IF DB_ID('FuelCheckDW') IS NULL
BEGIN
	CREATE DATABASE FuelCheckDW
END;
GO

-- Switch context to the database
USE FuelCheckDW;
GO


-- Landing table for imported CSV data (all columns stored as text)
CREATE TABLE dbo.fuel_prices_raw (
	ServiceStationName NVARCHAR(255) NULL,
	Address NVARCHAR(400) NULL,
	Suburb NVARCHAR(200) NULL,
	Postcode NVARCHAR(10) NULL,
	Brand NVARCHAR(100) NULL,
	FuelCode NVARCHAR(50) NULL,
	PriceUpdatedDate NVARCHAR(50) NULL,
	Price NVARCHAR(50) NULL,
	SourceFile NVARCHAR(255) NULL,
	LoadDate NVARCHAR(50) NULL
);
GO

-- Verify row count after load
-- SELECT COUNT(*) AS row_count FROM dbo.fuel_prices_raw