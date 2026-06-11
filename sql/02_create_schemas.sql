/*
Purpose:
    Create all required schemas for FabricFlowDB.

Verify:
    Run the SELECT at the end to confirm all 8 schemas exist.
*/

USE [FabricFlowDB];
GO

IF SCHEMA_ID(N'masterdata') IS NULL EXEC(N'CREATE SCHEMA masterdata');
IF SCHEMA_ID(N'sales_offline') IS NULL EXEC(N'CREATE SCHEMA sales_offline');
IF SCHEMA_ID(N'sales_online') IS NULL EXEC(N'CREATE SCHEMA sales_online');
IF SCHEMA_ID(N'inventory') IS NULL EXEC(N'CREATE SCHEMA inventory');
IF SCHEMA_ID(N'supply') IS NULL EXEC(N'CREATE SCHEMA supply');
IF SCHEMA_ID(N'marketing') IS NULL EXEC(N'CREATE SCHEMA marketing');
IF SCHEMA_ID(N'analytics') IS NULL EXEC(N'CREATE SCHEMA analytics');
IF SCHEMA_ID(N'staging') IS NULL EXEC(N'CREATE SCHEMA staging');
GO

SELECT s.name AS schema_name
FROM sys.schemas AS s
WHERE s.name IN (
    N'masterdata',
    N'sales_offline',
    N'sales_online',
    N'inventory',
    N'supply',
    N'marketing',
    N'analytics',
    N'staging'
)
ORDER BY s.name;
GO
