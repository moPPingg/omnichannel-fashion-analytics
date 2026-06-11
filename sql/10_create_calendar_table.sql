/*
Purpose:
    Populate masterdata.dim_date for 2023-01-01 through 2026-12-31.
    This follows the blueprint requirement for a mandatory date table with fashion_season.

Verify:
    Run the SELECT at the end to confirm 1,461 rows across the 2023-2026 range.
*/

USE [FabricFlowDB];
GO

IF OBJECT_ID(N'masterdata.dim_date', N'U') IS NULL
BEGIN
    THROW 50001, N'masterdata.dim_date does not exist. Run 03_create_masterdata_tables.sql first.', 1;
END;
GO

DECLARE @d DATE = '2023-01-01';
DECLARE @end DATE = '2026-12-31';

WHILE @d <= @end
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM masterdata.dim_date
        WHERE full_date = @d
    )
    BEGIN
        INSERT INTO masterdata.dim_date
        (
            date_key,
            full_date,
            [year],
            quarter,
            [month],
            month_name,
            month_name_vn,
            week_of_year,
            day_of_week,
            day_name,
            is_weekend,
            is_weekday,
            fashion_season,
            is_tet_holiday,
            is_public_holiday,
            fiscal_year,
            fiscal_quarter,
            year_month,
            quarter_label
        )
        VALUES
        (
            CAST(CONVERT(CHAR(8), @d, 112) AS INT),
            @d,
            YEAR(@d),
            DATEPART(QUARTER, @d),
            MONTH(@d),
            DATENAME(MONTH, @d),
            N'Thang ' + CAST(MONTH(@d) AS NVARCHAR(2)),
            DATEPART(ISO_WEEK, @d),
            DATEPART(WEEKDAY, @d),
            DATENAME(WEEKDAY, @d),
            CASE WHEN DATENAME(WEEKDAY, @d) IN (N'Saturday', N'Sunday') THEN 1 ELSE 0 END,
            CASE WHEN DATENAME(WEEKDAY, @d) IN (N'Saturday', N'Sunday') THEN 0 ELSE 1 END,
            CASE WHEN MONTH(@d) BETWEEN 3 AND 8 THEN N'SS' ELSE N'FW' END,
            0,
            0,
            YEAR(@d),
            DATEPART(QUARTER, @d),
            CONVERT(NVARCHAR(7), @d, 126),
            N'Q' + CAST(DATEPART(QUARTER, @d) AS NVARCHAR(1)) + N' ' + CAST(YEAR(@d) AS NVARCHAR(4))
        );
    END;

    SET @d = DATEADD(DAY, 1, @d);
END;
GO

SELECT
    COUNT(*) AS row_count,
    MIN(full_date) AS min_full_date,
    MAX(full_date) AS max_full_date,
    MIN(fashion_season) AS min_season,
    MAX(fashion_season) AS max_season
FROM masterdata.dim_date;
GO
