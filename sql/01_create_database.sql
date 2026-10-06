/* 01_create_database.sql
   Creates the database and the four schemas of the project.
     stg  = raw data exactly as in the CSV files (all text)
     core = cleaned and typed views
     mart = star schema for Power BI
     dq   = data-quality checks
   Run in SSMS, connected to localhost\SQLEXPRESS. */

IF DB_ID(N'olist') IS NULL
    CREATE DATABASE olist;
GO

USE olist;
GO

IF SCHEMA_ID(N'stg')  IS NULL EXEC (N'CREATE SCHEMA stg');
IF SCHEMA_ID(N'core') IS NULL EXEC (N'CREATE SCHEMA core');
IF SCHEMA_ID(N'mart') IS NULL EXEC (N'CREATE SCHEMA mart');
IF SCHEMA_ID(N'dq')   IS NULL EXEC (N'CREATE SCHEMA dq');
GO
