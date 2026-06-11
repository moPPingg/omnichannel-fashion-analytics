@echo off
setlocal

REM Purpose:
REM   Execute FabricFlow SQL scripts in order on SQL Server using sqlcmd.
REM
REM Usage:
REM   1. Open Developer Command Prompt / CMD with sqlcmd available.
REM   2. Optional: set SQLCMD_SERVER=localhost
REM   3. Optional: set SQLCMD_DATABASE=master
REM   4. Run: sql\run_all_sql.bat

if "%SQLCMD_SERVER%"=="" set SQLCMD_SERVER=localhost
if "%SQLCMD_DATABASE%"=="" set SQLCMD_DATABASE=master

echo Running FabricFlow SQL setup on server %SQLCMD_SERVER%

sqlcmd -S %SQLCMD_SERVER% -d %SQLCMD_DATABASE% -E -b -i "%~dp001_create_database.sql" || goto :error
sqlcmd -S %SQLCMD_SERVER% -d master -E -b -Q "SET NOCOUNT ON; DECLARE @i INT = 0; WHILE DB_ID(N'FabricFlowDB') IS NULL OR DATABASEPROPERTYEX(N'FabricFlowDB', N'Status') <> 'ONLINE' BEGIN SET @i += 1; IF @i > 30 THROW 50002, 'FabricFlowDB did not become ready in time.', 1; WAITFOR DELAY '00:00:01'; END;" || goto :error
sqlcmd -S %SQLCMD_SERVER% -d FabricFlowDB -E -b -i "%~dp002_create_schemas.sql" || goto :error
sqlcmd -S %SQLCMD_SERVER% -d FabricFlowDB -E -b -i "%~dp003_create_masterdata_tables.sql" || goto :error
sqlcmd -S %SQLCMD_SERVER% -d FabricFlowDB -E -b -i "%~dp004_create_sales_offline_tables.sql" || goto :error
sqlcmd -S %SQLCMD_SERVER% -d FabricFlowDB -E -b -i "%~dp005_create_sales_online_tables.sql" || goto :error
sqlcmd -S %SQLCMD_SERVER% -d FabricFlowDB -E -b -i "%~dp006_create_inventory_tables.sql" || goto :error
sqlcmd -S %SQLCMD_SERVER% -d FabricFlowDB -E -b -i "%~dp007_create_supply_tables.sql" || goto :error
sqlcmd -S %SQLCMD_SERVER% -d FabricFlowDB -E -b -i "%~dp008_create_marketing_tables.sql" || goto :error
sqlcmd -S %SQLCMD_SERVER% -d FabricFlowDB -E -b -i "%~dp009_create_staging_tables.sql" || goto :error
sqlcmd -S %SQLCMD_SERVER% -d FabricFlowDB -E -b -i "%~dp010_create_calendar_table.sql" || goto :error
sqlcmd -S %SQLCMD_SERVER% -d FabricFlowDB -E -b -i "%~dp011_create_indexes.sql" || goto :error
sqlcmd -S %SQLCMD_SERVER% -d FabricFlowDB -E -b -i "%~dp012_create_analytics_views.sql" || goto :error
sqlcmd -S %SQLCMD_SERVER% -d FabricFlowDB -E -b -i "%~dp013_data_quality_checks.sql" || goto :error
sqlcmd -S %SQLCMD_SERVER% -d FabricFlowDB -E -b -i "%~dp099_verify_setup.sql" || goto :error

echo All FabricFlow SQL scripts completed successfully.
goto :eof

:error
echo SQL setup failed.
exit /b 1
