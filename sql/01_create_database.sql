/*
Purpose:
    Create FabricFlowDB for the FabricFlow omnichannel fashion analytics project.
    This script is idempotent and safe to re-run.

Verify:
    Run the SELECT at the end to confirm the database exists.
*/

USE [master];
GO

IF DB_ID(N'FabricFlowDB') IS NULL
BEGIN
    PRINT N'Creating database FabricFlowDB...';
    CREATE DATABASE [FabricFlowDB];
END
ELSE
BEGIN
    PRINT N'Database FabricFlowDB already exists.';
END;
GO

SELECT
    d.name,
    d.state_desc,
    d.recovery_model_desc,
    d.compatibility_level
FROM sys.databases AS d
WHERE d.name = N'FabricFlowDB';
GO
