--CREATING SILVER LAYER

USE SCHEMA SILVER;

CREATE OR REPLACE TABLE SALES (
    SALE_ID STRING,
    SALE_DATE DATE,
    CUSTOMER_ID STRING,
    DEALER_ID STRING,
    VEHICLE_ID STRING,
    SALES_CHANNEL STRING,
    QUANTITY NUMBER,
    UNIT_PRICE NUMBER(10,2)
);

DESC TABLE SALES;

----------------------------------
--PASTING DATA FROM RAW TABLE TO SILVER TABLE, as our JSON data is array [{JSON}], we flatten the data and then added

INSERT INTO SILVER.SALES
SELECT
    f.value:sale_id::STRING,
    f.value:sale_date::DATE,
    f.value:customer_id::STRING,
    f.value:dealer_id::STRING,
    f.value:vehicle_id::STRING,
    f.value:sales_channel::STRING,
    f.value:quantity::NUMBER,
    f.value:unit_price::NUMBER(10,2)
FROM RAW.RAW_SALES,
LATERAL FLATTEN(input => RAW_RECORD) f;

SELECT *
FROM SILVER.SALES
LIMIT 10;

----Dealers data
USE SCHEMA SILVER;

CREATE OR REPLACE TABLE DEALERS (
    DEALER_ID STRING,
    DEALER_NAME STRING,
    COUNTRY STRING,
    CITY STRING,
    REGION STRING,
    DEALERSHIP_TYPE STRING,
    OPENING_YEAR NUMBER
);

--Copying data from raw dealer to silver dealer
INSERT INTO SILVER.DEALERS
SELECT
    DEALER_ID,
    DEALER_NAME,
    COUNTRY,
    CITY,
    REGION,
    DEALERSHIP_TYPE,
    OPENING_YEAR
FROM RAW.RAW_DEALERS;

SELECT *
FROM SILVER.DEALERS;

USE SCHEMA SILVER;

CREATE OR REPLACE TABLE CUSTOMERS (
    CUSTOMER_ID STRING,
    CUSTOMER_NAME STRING,
    COUNTRY STRING,
    CUSTOMER_TYPE STRING,
    REGISTRATION_DATE DATE,
    LOYALTY_TIER STRING
);

--Copying data from raw CUSTOMER to silver CUSTOMER
INSERT INTO SILVER.CUSTOMERS
SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    COUNTRY,
    CUSTOMER_TYPE,
    TO_DATE(REGISTRATION_DATE),
    LOYALTY_TIER
FROM RAW.RAW_CUSTOMERS;


--silver_layer_vehicle_csv_data
USE SCHEMA SILVER;

CREATE OR REPLACE TABLE VEHICLES (
    VEHICLE_ID STRING,
    VEHICLE_MODEL STRING,
    VEHICLE_TYPE STRING,
    FUEL_TYPE STRING,
    BASE_PRICE_USD NUMBER(10,2),
    LAUNCH_YEAR NUMBER,
    STATUS STRING
);

INSERT INTO SILVER.VEHICLES
SELECT
    VEHICLE_ID,
    VEHICLE_MODEL,
    VEHICLE_TYPE,
    FUEL_TYPE,
    BASE_PRICE_USD,
    LAUNCH_YEAR,
    STATUS
FROM RAW.RAW_VEHICLES;

SELECT *
FROM SILVER.VEHICLES;


-------Created Silver Layer again this time did data cleaning validation and then loaded data into silver layer


DROP TABLE IF EXISTS SILVER.SALES;

CREATE TABLE SILVER.SALES (
    SALE_ID STRING,
    CUSTOMER_ID STRING,
    DEALER_ID STRING,
    VEHICLE_ID STRING,
    SALE_DATE DATE,
    SALES_CHANNEL STRING,
    QUANTITY NUMBER,
    UNIT_PRICE NUMBER(10,2)
);

CREATE OR REPLACE TABLE SILVER.REJECTED_SALES (
    SALE_ID STRING,
    CUSTOMER_ID STRING,
    DEALER_ID STRING,
    VEHICLE_ID STRING,
    SALE_DATE DATE,
    SALES_CHANNEL STRING,Convert the JSON into a normal relational table
    QUANTITY NUMBER,
    UNIT_PRICE NUMBER(10,2),
    REJECTION_REASON STRING
);

---Cleaning the data and loading into silver table step by step
---Phase 1 - SALES_DATA CTE
---Our objective is not to clean anything yet --> Convert the JSON into a normal relational table

WITH SALES_DATA AS (

    SELECT
        f.value:sale_id::STRING           AS SALE_ID,
        f.value:customer_id::STRING       AS CUSTOMER_ID,
        f.value:dealer_id::STRING         AS DEALER_ID,
        f.value:vehicle_id::STRING        AS VEHICLE_ID,
        f.value:sale_date::DATE           AS SALE_DATE,
        f.value:sales_channel::STRING     AS SALES_CHANNEL,
        f.value:quantity::NUMBER          AS QUANTITY,
        f.value:unit_price::NUMBER(10,2)  AS UNIT_PRICE

    FROM RAW.RAW_SALES,
    LATERAL FLATTEN(INPUT => RAW_RECORD) f

)

SELECT *
FROM SALES_DATA;


WITH SALES_DATA AS (

    SELECT
        f.value:sale_id::STRING          AS SALE_ID,
        f.value:customer_id::STRING      AS CUSTOMER_ID,
        f.value:dealer_id::STRING        AS DEALER_ID,
        f.value:vehicle_id::STRING       AS VEHICLE_ID,
        f.value:sale_date::DATE          AS SALE_DATE,
        f.value:sales_channel::STRING    AS SALES_CHANNEL,
        f.value:quantity::NUMBER         AS QUANTITY,
        f.value:unit_price::NUMBER(10,2) AS UNIT_PRICE

    FROM RAW.RAW_SALES,
         LATERAL FLATTEN(INPUT => RAW_RECORD) f

),

VALIDATED_DATA AS (

SELECT

    s.*,

    CASE

        WHEN d.DEALER_ID IS NULL THEN 'Invalid Dealer'

        WHEN c.CUSTOMER_ID IS NULL THEN 'Invalid Customer'

        WHEN v.VEHICLE_ID IS NULL THEN 'Invalid Vehicle'

        WHEN QUANTITY <= 0 THEN 'Negative Quantity'

        WHEN UNIT_PRICE <= 0 THEN 'Negative Unit Price'

        WHEN SALE_DATE > CURRENT_DATE() THEN 'Future Sale Date'

        WHEN SALES_CHANNEL NOT IN
            ('Online','Corporate','Dealership')
            THEN 'Invalid Sales Channel'

        ELSE 'VALID'

    END AS VALIDATION_STATUS

FROM SALES_DATA s

LEFT JOIN SILVER.DEALERS d
ON s.DEALER_ID = d.DEALER_ID

LEFT JOIN SILVER.CUSTOMERS c
ON s.CUSTOMER_ID = c.CUSTOMER_ID

LEFT JOIN SILVER.VEHICLES v
ON s.VEHICLE_ID = v.VEHICLE_ID

)

SELECT
    VALIDATION_STATUS,
    COUNT(*) AS RECORD_COUNT
FROM VALIDATED_DATA
GROUP BY VALIDATION_STATUS
ORDER BY RECORD_COUNT DESC;



---- Loading invalid rows into rejected_sales table

INSERT INTO SILVER.REJECTED_SALES

WITH SALES_DATA AS (

    SELECT
        f.value:sale_id::STRING          AS SALE_ID,
        f.value:customer_id::STRING      AS CUSTOMER_ID,
        f.value:dealer_id::STRING        AS DEALER_ID,
        f.value:vehicle_id::STRING       AS VEHICLE_ID,
        f.value:sale_date::DATE          AS SALE_DATE,
        f.value:sales_channel::STRING    AS SALES_CHANNEL,
        f.value:quantity::NUMBER         AS QUANTITY,
        f.value:unit_price::NUMBER(10,2) AS UNIT_PRICE

    FROM RAW.RAW_SALES,
         LATERAL FLATTEN(INPUT => RAW_RECORD) f

),

VALIDATED_DATA AS (

SELECT

    s.*,

    CASE

        WHEN d.DEALER_ID IS NULL THEN 'Invalid Dealer'

        WHEN c.CUSTOMER_ID IS NULL THEN 'Invalid Customer'

        WHEN v.VEHICLE_ID IS NULL THEN 'Invalid Vehicle'

        WHEN QUANTITY <= 0 THEN 'Negative Quantity'

        WHEN UNIT_PRICE <= 0 THEN 'Negative Unit Price'

        WHEN SALE_DATE > CURRENT_DATE() THEN 'Future Sale Date'

        WHEN SALES_CHANNEL NOT IN
            ('Online','Corporate','Dealership')
            THEN 'Invalid Sales Channel'

        ELSE 'VALID'

    END AS VALIDATION_STATUS

FROM SALES_DATA s

LEFT JOIN SILVER.DEALERS d
ON s.DEALER_ID = d.DEALER_ID

LEFT JOIN SILVER.CUSTOMERS c
ON s.CUSTOMER_ID = c.CUSTOMER_ID

LEFT JOIN SILVER.VEHICLES v
ON s.VEHICLE_ID = v.VEHICLE_ID

)

SELECT
    SALE_ID,
    CUSTOMER_ID,
    DEALER_ID,
    VEHICLE_ID,
    SALE_DATE,
    SALES_CHANNEL,
    QUANTITY,
    UNIT_PRICE,
    VALIDATION_STATUS
FROM VALIDATED_DATA
WHERE VALIDATION_STATUS <> 'VALID';

---- Loading valid rows into sales table

INSERT INTO SILVER.SALES

WITH SALES_DATA AS (

    SELECT
        f.value:sale_id::STRING          AS SALE_ID,
        f.value:customer_id::STRING      AS CUSTOMER_ID,
        f.value:dealer_id::STRING        AS DEALER_ID,
        f.value:vehicle_id::STRING       AS VEHICLE_ID,
        f.value:sale_date::DATE          AS SALE_DATE,
        f.value:sales_channel::STRING    AS SALES_CHANNEL,
        f.value:quantity::NUMBER         AS QUANTITY,
        f.value:unit_price::NUMBER(10,2) AS UNIT_PRICE

    FROM RAW.RAW_SALES,
         LATERAL FLATTEN(INPUT => RAW_RECORD) f

),

VALIDATED_DATA AS (

SELECT

    s.*,

    CASE

        WHEN d.DEALER_ID IS NULL THEN 'Invalid Dealer'

        WHEN c.CUSTOMER_ID IS NULL THEN 'Invalid Customer'

        WHEN v.VEHICLE_ID IS NULL THEN 'Invalid Vehicle'

        WHEN QUANTITY <= 0 THEN 'Negative Quantity'

        WHEN UNIT_PRICE <= 0 THEN 'Negative Unit Price'

        WHEN SALE_DATE > CURRENT_DATE() THEN 'Future Sale Date'

        WHEN SALES_CHANNEL NOT IN
            ('Online','Corporate','Dealership')
            THEN 'Invalid Sales Channel'

        ELSE 'VALID'

    END AS VALIDATION_STATUS

FROM SALES_DATA s

LEFT JOIN SILVER.DEALERS d
ON s.DEALER_ID = d.DEALER_ID

LEFT JOIN SILVER.CUSTOMERS c
ON s.CUSTOMER_ID = c.CUSTOMER_ID

LEFT JOIN SILVER.VEHICLES v
ON s.VEHICLE_ID = v.VEHICLE_ID

)

SELECT
    SALE_ID,
    CUSTOMER_ID,
    DEALER_ID,
    VEHICLE_ID,
    SALE_DATE,
    SALES_CHANNEL,
    QUANTITY,
    UNIT_PRICE
FROM VALIDATED_DATA
WHERE VALIDATION_STATUS = 'VALID';
