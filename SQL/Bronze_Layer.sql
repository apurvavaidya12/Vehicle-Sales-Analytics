
----------------------------------
--Creating 1st Table in RAW Schema

USE SCHEMA RAW;

CREATE OR REPLACE TABLE RAW_SALES (
    LOAD_TS          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FILE_NAME        STRING,
    LOAD_BATCH_ID    STRING,
    INGESTION_SOURCE STRING,
    RAW_RECORD       VARIANT
);

DESC TABLE RAW_SALES;

----------------------------------

SELECT CURRENT_ACCOUNT();

----------------------------------
--Creating JSON file format

USE DATABASE NISSAN_ANALYTICS;
USE SCHEMA RAW;

CREATE OR REPLACE FILE FORMAT JSON_FORMAT
TYPE = JSON;

SHOW FILE FORMATS;

----------------------------------
--Creating internal stage

CREATE OR REPLACE STAGE STG_RAW_SALES
COMMENT='Internal Stage for Raw Vehicle Sales JSON files';

SHOW STAGES;

----------------------------------
--Seeing the data in stage

LIST @STG_RAW_SALES;

SELECT
    METADATA$FILENAME,
    $1
FROM @STG_RAW_SALES
LIMIT 20;



COPY INTO RAW_SALES
FROM (
    SELECT
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME,
        'BATCH_001',
        'INTERNAL_STAGE',
        $1
    FROM @STG_RAW_SALES
)
FILE_FORMAT = (FORMAT_NAME = JSON_FORMAT);

----------------------------------
--verify the data

SELECT *
FROM RAW_SALES
LIMIT 5;

SELECT RAW_RECORD
FROM RAW_SALES
LIMIT 1;



USE SCHEMA RAW;

--createing csv file format
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
TYPE = CSV
FIELD_DELIMITER = ','
SKIP_HEADER = 1
FIELD_OPTIONALLY_ENCLOSED_BY = '"';

--createing satge for dealer csv
CREATE OR REPLACE STAGE STG_RAW_DEALERS;

--after uploading csv checking the data in stage
LIST @STG_RAW_DEALERS;


--creating a table in which dealer sage data will be copied
CREATE OR REPLACE TABLE RAW_DEALERS (
    DEALER_ID STRING,
    DEALER_NAME STRING,
    COUNTRY STRING,
    CITY STRING,
    REGION STRING,
    DEALERSHIP_TYPE STRING,
    OPENING_YEAR NUMBER
);

--copying data from stage to dealer table
COPY INTO RAW_DEALERS
FROM @STG_RAW_DEALERS
FILE_FORMAT = (FORMAT_NAME = CSV_FORMAT);

SELECT *
FROM RAW_DEALERS;

-----------------------------customer_master--------------------------------------

--Uploading dealer_master.csv data 
USE SCHEMA RAW;

--createing sateg for dealer csv
CREATE OR REPLACE STAGE STG_RAW_CUSTOMERS;

--after uploading csv checking the data in stage
LIST @STG_RAW_CUSTOMERS;


--creating a table in which delaer sage data will be copied
CREATE OR REPLACE TABLE RAW_CUSTOMERS (
    CUSTOMER_ID STRING,
    CUSTOMER_NAME STRING,
    COUNTRY STRING,
    CUSTOMER_TYPE STRING,
    REGISTRATION_DATE STRING,
    LOYALTY_TIER STRING
);

--copying data from stage to dealer table
COPY INTO RAW_CUSTOMERS
FROM @STG_RAW_CUSTOMERS
FILE_FORMAT = (FORMAT_NAME = CSV_FORMAT);

SELECT *
FROM RAW_CUSTOMERS;


--CREATING VEHICLE_MASTER 
USE SCHEMA RAW;

CREATE OR REPLACE STAGE STG_RAW_VEHICLES;

--after uploading csv checking the data in stage
LIST @STG_RAW_VEHICLES;

CREATE OR REPLACE TABLE RAW_VEHICLES (
    VEHICLE_ID STRING,
    VEHICLE_MODEL STRING,
    VEHICLE_TYPE STRING,
    FUEL_TYPE STRING,
    BASE_PRICE_USD NUMBER(10,2),
    LAUNCH_YEAR NUMBER,
    STATUS STRING
);

COPY INTO RAW_VEHICLES
FROM @STG_RAW_VEHICLES
FILE_FORMAT = (FORMAT_NAME = CSV_FORMAT);

SELECT *
FROM RAW_VEHICLES
LIMIT 10;

