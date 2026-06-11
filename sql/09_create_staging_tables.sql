/*
Purpose:
    Create staging tables for event ingestion and failed event capture.

Verify:
    Run the SELECT at the end to confirm both staging tables exist.
*/

USE [FabricFlowDB];
GO

IF OBJECT_ID(N'staging.order_events', N'U') IS NULL
BEGIN
    CREATE TABLE staging.order_events
    (
        event_id           UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_order_events_event_id DEFAULT (NEWID()),
        event_type         NVARCHAR(50) NOT NULL,
        channel            NVARCHAR(20) NOT NULL,
        event_timestamp    DATETIME2(0) NOT NULL,
        store_id           INT NULL,
        variant_id         INT NOT NULL,
        quantity           INT NOT NULL,
        order_payload      NVARCHAR(MAX) NOT NULL,
        processing_status  NVARCHAR(30) NOT NULL CONSTRAINT DF_order_events_processing_status DEFAULT (N'pending'),
        processed_at       DATETIME2(0) NULL,
        error_message      NVARCHAR(MAX) NULL,
        inserted_at        DATETIME2(0) NOT NULL CONSTRAINT DF_order_events_inserted_at DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_order_events PRIMARY KEY (event_id),
        CONSTRAINT FK_order_events_stores FOREIGN KEY (store_id) REFERENCES masterdata.stores(store_id),
        CONSTRAINT FK_order_events_product_variants FOREIGN KEY (variant_id) REFERENCES masterdata.product_variants(variant_id),
        CONSTRAINT CK_order_events_event_type CHECK (event_type IN (N'order_placed', N'order_returned', N'inventory_adj')),
        CONSTRAINT CK_order_events_channel CHECK (channel IN (N'offline', N'online')),
        CONSTRAINT CK_order_events_quantity_nonzero CHECK (quantity <> 0)
    );
END;
GO

IF OBJECT_ID(N'staging.failed_events', N'U') IS NULL
BEGIN
    CREATE TABLE staging.failed_events
    (
        failed_event_id     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_failed_events PRIMARY KEY,
        event_id            UNIQUEIDENTIFIER NULL,
        event_type          NVARCHAR(50) NULL,
        channel             NVARCHAR(20) NULL,
        failed_at           DATETIME2(0) NOT NULL CONSTRAINT DF_failed_events_failed_at DEFAULT (SYSDATETIME()),
        error_message       NVARCHAR(MAX) NOT NULL,
        payload_snapshot    NVARCHAR(MAX) NULL,
        retry_status        NVARCHAR(30) NOT NULL CONSTRAINT DF_failed_events_retry_status DEFAULT (N'pending')
    );
END;
GO

SELECT
    s.name AS schema_name,
    t.name AS table_name
FROM sys.tables AS t
JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = N'staging'
ORDER BY t.name;
GO
