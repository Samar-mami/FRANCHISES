DROP TABLE TMP_CASH_FRANCHISE 
CREATE TEMP TABLE TMP_CASH_FRANCHISE AS 
WITH PERF_CASH AS (
    SELECT 
        EXTRACT (YEAR FROM TDT.THE_DATE_TRANSACTION) AS YEAR,
        DATE_PART (MONTH, TDT.THE_DATE_TRANSACTION) AS MONTH, 
        DATE_PART (W, TDT.THE_DATE_TRANSACTION) AS WEEK,
        TDT.THE_TRANSACTION_ID,
        TDT.THE_NUM_OPERATOR AS CASHIER_ID,
        DBU.CNT_COUNTRY_CODE,
        DBU.but_name_business_unit AS store_name,
        SPLIT_PART (TDT.THE_TRANSACTION_ID, '-', 2) AS store_number,
        CAST (TDT.THE_DATE_TRANSACTION AS DATE) AS THE_DATE_TRANSACTION,
        CASE
            WHEN FTH.RDT_IDR_REALLOCATED_DIGITAL_TYPE IN (0,2,6,7,8,9) THEN 'INSTORE' 
            WHEN FTH.RDT_IDR_REALLOCATED_DIGITAL_TYPE IN (1,3,4,5,10) THEN 'OUTSTORE'
        END AS TYPE_CANAL,
        CASE 
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) THEN TDT.TDT_ITEM_ID::INT8
            ELSE SKU.SKU_NUM_SKU_R3
        END AS ITEM_CODE,
        CASE 
            WHEN TDT.TDT_ITEM_ID in (4000000004,6000000006,7000000007) or (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID NOT IN (1000000001)) THEN TDT.F_QTY_ITEM_INITIAL
            ELSE TDT.F_QTY_ITEM
        END AS ITEM_QUANTITY, 
        SKU.SKU_EAN_NUM,
        SKU.MDL_NUM_MODEL,
        CASE 
            WHEN TDT.TDT_ITEM_ID in (4000000004) THEN 'Livraison a domicile' --pas dispo actuellement
            WHEN TDT.TDT_ITEM_ID in (6000000006) THEN 'Bon de location' --pas dispo actuellement
            WHEN TDT.TDT_ITEM_ID in (7000000007) THEN 'Commande borne' --dispo en france uniquement, le détail de ces commandes n'est pas dispo, pour le moment pas de détail sur le ticket
            ELSE SKU.MDL_LABEL
        END AS MODEL_LABEL, 
        SKU.FAM_IDR_FAMILY,
        SKU.FAMILY_LABEL,
        SKU.UNV_NUM_UNIVERS,
        SKU.UNV_LABEL,  
        TDT.TDT_SERIAL_NUMBER_RFID,  
        CUR.CUR_CODE_CURRENCY,
        CASE 
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) OR (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID not in (1000000001)) THEN TDT.F_AMT_TAX_INITIAL
            ELSE TDT.F_AMT_TAX
        END AS TAX_AMOUNT, 
        CASE 
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) OR (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID NOT IN (1000000001)) THEN TDT.F_TO_TAX_EX_INITIAL
            ELSE TDT.F_TO_TAX_EX 
        END AS AMOUNT_EXCLUDING_TAX,
        CASE 
            WHEN SKU.FAM_IDR_FAMILY = 3398 THEN TDT.F_PRI_REGULAR_SALES_UNIT
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) OR (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID NOT IN (1000000001)) THEN TDT.F_TO_TAX_IN_INITIAL
            ELSE TDT.F_TO_TAX_IN
        END AS AMOUNT_INCLUDING_TAX,
        CASE 
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) OR (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID NOT IN (1000000001)) THEN TDT.F_AMT_DISCOUNT_INITIAL
            ELSE TDT.F_AMT_DISCOUNT
        END AS DISCOUNT_AMOUNT_INCLUDING_TAX,
        TO_CHAR(TTX.F_AMT_PERCENT,'90D99') AS TAX_RATE,
        DTT.TNT_TENDER_GROUP,
        DTT.TNT_TENDER_TYPE AS MOP
    FROM CDS.F_TRANSACTION_DETAIL_LAST_TWO_YEARS TDT
    INNER JOIN CDS.D_SKU SKU 
        ON SKU.SKU_IDR_SKU = TDT.SKU_IDR_SKU
    INNER JOIN cds.f_delivery_detail_last_two_years FTH
        ON TDT.the_transaction_id = FTH.the_transaction_id 
    INNER JOIN CDS.D_CURRENCY CUR 
        ON TDT.CUR_IDR_CURRENCY = CUR.CUR_IDR_CURRENCY
    INNER JOIN CDS.D_BUSINESS_UNIT DBU 
        ON DBU.BUT_IDR_BUSINESS_UNIT = TDT.BUT_IDR_BUSINESS_UNIT
    LEFT JOIN CDS.F_TRANSACTION_TENDER_LAST_TWO_YEARS TND 
        ON TND.THE_TRANSACTION_ID = TDT.THE_TRANSACTION_ID
    INNER JOIN CDS.D_TENDER_TYPE DTT 
        ON DTT.TNT_IDR_TENDER_TYPE = TND.TNT_IDR_TENDER_TYPE  ------ récupérer tender type plus haut dans le select
    LEFT JOIN CDS.F_TRANSACTION_TAX_CURRENT TTX
        ON TTX.THE_TRANSACTION_ID = TDT.THE_TRANSACTION_ID AND TTX.TTX_NUM_LINE = TDT.TDT_NUM_LINE AND TXT_TAX_NAME NOT IN ('DKT:DEEE')
    WHERE 1=1
        AND CAST(TDT.THE_DATE_TRANSACTION AS DATE) BETWEEN '2021-01-01' AND GETDATE() -- => Date de dernière exécution
        AND TDT.THE_TRANSACTION_STATUS <>'canceled'
        AND DBU.BUT_NUM_BUSINESS_UNIT IN (787,1067,2708,1944,1094,2444,2426,580,2556,440,441,2770,775,2635,2670,2671,2627,770,2668,978,2776,2698,404,745,2857)
    GROUP BY 
        EXTRACT(YEAR FROM TDT.THE_DATE_TRANSACTION),
        DATE_PART(MONTH, TDT.THE_DATE_TRANSACTION), 
        DATE_PART(W, TDT.THE_DATE_TRANSACTION),
        TDT.THE_TRANSACTION_ID,
        DBU.CNT_COUNTRY_CODE,
        store_number,
        store_name,
        MOP,
        DTT.TNT_TENDER_GROUP,
        TDT.THE_NUM_OPERATOR,
        CAST(TDT.THE_DATE_TRANSACTION AS DATE),
        CASE
            WHEN FTH.RDT_IDR_REALLOCATED_DIGITAL_TYPE IN (0,2,6,7,8,9) THEN 'INSTORE' 
            WHEN FTH.RDT_IDR_REALLOCATED_DIGITAL_TYPE IN (1,3,4,5,10) THEN 'OUTSTORE'
        END,
        CASE 
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) THEN TDT.TDT_ITEM_ID::INT8
            ELSE SKU.SKU_NUM_SKU_R3
        END,
        CASE 
            WHEN TDT.TDT_ITEM_ID in (4000000004,6000000006,7000000007) or (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID NOT IN (1000000001)) THEN TDT.F_QTY_ITEM_INITIAL
            ELSE TDT.F_QTY_ITEM
        END, 
        SKU.SKU_EAN_NUM,
        SKU.MDL_NUM_MODEL,
        CASE 
            WHEN TDT.TDT_ITEM_ID in (4000000004) THEN 'Livraison a domicile' --pas dispo actuellement
            WHEN TDT.TDT_ITEM_ID in (6000000006) THEN 'Bon de location' --pas dispo actuellement
            WHEN TDT.TDT_ITEM_ID in (7000000007) THEN 'Commande borne' --dispo en france uniquement, le détail de ces commandes n'est pas dispo, pour le moment pas de détail sur le ticket
            ELSE SKU.MDL_LABEL
        END, 
        SKU.FAM_IDR_FAMILY,
        SKU.FAMILY_LABEL,
        SKU.UNV_NUM_UNIVERS,
        SKU.UNV_LABEL,  
        TDT.TDT_SERIAL_NUMBER_RFID,  
        CUR.CUR_CODE_CURRENCY,
        CASE 
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) OR (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID not in (1000000001)) THEN TDT.F_AMT_TAX_INITIAL
            ELSE TDT.F_AMT_TAX
        END, 
        CASE 
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) OR (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID NOT IN (1000000001)) THEN TDT.F_TO_TAX_EX_INITIAL
            ELSE TDT.F_TO_TAX_EX 
        END,
        CASE 
            WHEN SKU.FAM_IDR_FAMILY = 3398 THEN TDT.F_PRI_REGULAR_SALES_UNIT
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) OR (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID NOT IN (1000000001)) THEN TDT.F_TO_TAX_IN_INITIAL
            ELSE TDT.F_TO_TAX_IN
        END,
        CASE 
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) OR (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID NOT IN (1000000001)) THEN TDT.F_AMT_DISCOUNT_INITIAL
            ELSE TDT.F_AMT_DISCOUNT
        END,
        TO_CHAR(TTX.F_AMT_PERCENT,'90D99')
    UNION ALL
    SELECT 
        EXTRACT (YEAR FROM TDT.THE_DATE_TRANSACTION) AS YEAR,
        DATE_PART (MONTH, TDT.THE_DATE_TRANSACTION) AS MONTH, 
        DATE_PART (W, TDT.THE_DATE_TRANSACTION) AS WEEK,
        TDT.THE_TRANSACTION_ID,
        TDT.THE_NUM_OPERATOR AS CASHIER_ID,
        DBU.but_name_business_unit AS store_name,
        DBU.CNT_COUNTRY_CODE,
        SPLIT_PART (TDT.THE_TRANSACTION_ID, '-', 2) AS store_number,
        CAST (TDT.THE_DATE_TRANSACTION AS DATE) AS THE_DATE_TRANSACTION,
        'INSTORE' AS TYPE_CANAL,
        CASE 
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) THEN TDT.TDT_ITEM_ID::INT8
            ELSE SKU.SKU_NUM_SKU_R3
        END AS ITEM_CODE,
        CASE 
            WHEN TDT.TDT_ITEM_ID in (4000000004,6000000006,7000000007) or (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID NOT IN (1000000001)) THEN TDT.F_QTY_ITEM_INITIAL
            ELSE TDT.F_QTY_ITEM
        END AS ITEM_QUANTITY, 
        SKU.SKU_EAN_NUM,
        SKU.MDL_NUM_MODEL,
        CASE 
            WHEN TDT.TDT_ITEM_ID in (4000000004) THEN 'Livraison a domicile' --pas dispo actuellement
            WHEN TDT.TDT_ITEM_ID in (6000000006) THEN 'Bon de location' --pas dispo actuellement
            WHEN TDT.TDT_ITEM_ID in (7000000007) THEN 'Commande borne' --dispo en france uniquement, le détail de ces commandes n'est pas dispo, pour le moment pas de détail sur le ticket
            ELSE SKU.MDL_LABEL
        END AS MODEL_LABEL, 
        SKU.FAM_IDR_FAMILY,
        SKU.FAMILY_LABEL,
        SKU.UNV_NUM_UNIVERS,
        SKU.UNV_LABEL,  
        TDT.TDT_SERIAL_NUMBER_RFID,  
        CUR.CUR_CODE_CURRENCY,
        CASE 
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) OR (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID not in (1000000001)) THEN TDT.F_AMT_TAX_INITIAL
            ELSE TDT.F_AMT_TAX
        END AS TAX_AMOUNT, 
        CASE 
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) OR (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID NOT IN (1000000001)) THEN TDT.F_TO_TAX_EX_INITIAL
            ELSE TDT.F_TO_TAX_EX
        END AS AMOUNT_EXCLUDING_TAX,
        CASE 
            WHEN SKU.FAM_IDR_FAMILY = 3398 THEN TDT.F_PRI_REGULAR_SALES_UNIT
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) OR (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID NOT IN (1000000001)) THEN TDT.F_TO_TAX_IN_INITIAL
            ELSE TDT.F_TO_TAX_IN
        END AS AMOUNT_INCLUDING_TAX,
        CASE 
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) OR (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID NOT IN (1000000001)) THEN TDT.F_AMT_DISCOUNT_INITIAL
            ELSE TDT.F_AMT_DISCOUNT
        END AS DISCOUNT_AMOUNT_INCLUDING_TAX,
        TO_CHAR(TTX.F_AMT_PERCENT,'90D99') AS TAX_RATE, 
        DTT.TNT_TENDER_GROUP,
        DTT.TNT_TENDER_TYPE  AS MOP
    FROM CDS.F_TRANSACTION_DETAIL_LAST_TWO_YEARS TDT
    INNER JOIN CDS.D_SKU SKU 
        ON SKU.SKU_IDR_SKU = TDT.SKU_IDR_SKU
    INNER JOIN cds.f_delivery_detail_last_two_years FTH
        ON TDT.the_transaction_id = FTH.the_transaction_id 
    INNER JOIN CDS.D_CURRENCY CUR 
        ON TDT.CUR_IDR_CURRENCY = CUR.CUR_IDR_CURRENCY
    INNER JOIN CDS.D_BUSINESS_UNIT DBU 
        ON DBU.BUT_IDR_BUSINESS_UNIT = TDT.BUT_IDR_BUSINESS_UNIT
    LEFT JOIN CDS.F_TRANSACTION_TENDER_LAST_TWO_YEARS TND 
        ON TND.THE_TRANSACTION_ID = TDT.THE_TRANSACTION_ID
    INNER JOIN CDS.D_TENDER_TYPE DTT 
        ON DTT.TNT_IDR_TENDER_TYPE = TND.TNT_IDR_TENDER_TYPE  ------ récupérer tender type plus haut dans le select
    LEFT JOIN CDS.F_TRANSACTION_TAX_CURRENT TTX
        ON TTX.THE_TRANSACTION_ID = TDT.THE_TRANSACTION_ID AND TTX.TTX_NUM_LINE = TDT.TDT_NUM_LINE AND TXT_TAX_NAME NOT IN ('DKT:DEEE')
    WHERE 1=1
        AND TDT.THE_TRANSACTION_STATUS <>'canceled'
        AND TDT.TDT_DATE_TO_ORDERED IS NOT NULL
        AND TDT.TDT_TYPE_DETAIL IN ('sale', 'return')
        AND TDT.THE_TO_TYPE = 'offline'
        AND DBU.BUT_NUM_TYP_BUT = 7 
        AND DBU.BUT_NUM_BUSINESS_UNIT IN (787,1067,2708,1944,1094,2444,2426,580,2556,440,441,2770,775,2635,2670,2671,2627,770,2668,978,2776,2698,404,745,2857)
        AND CAST(TDT.THE_DATE_TRANSACTION AS DATE) BETWEEN '2021-01-01' AND GETDATE() -- => Date de dernière exécution
    GROUP BY 
        EXTRACT(YEAR FROM TDT.THE_DATE_TRANSACTION),
        DATE_PART(MONTH, TDT.THE_DATE_TRANSACTION), 
        DATE_PART(W, TDT.THE_DATE_TRANSACTION),
        TDT.THE_TRANSACTION_ID,
        DBU.CNT_COUNTRY_CODE,
        store_number,
        store_name,
        MOP,
        DTT.TNT_TENDER_GROUP,
        TDT.THE_NUM_OPERATOR,
        CAST(TDT.THE_DATE_TRANSACTION AS DATE),
        CASE
            WHEN FTH.RDT_IDR_REALLOCATED_DIGITAL_TYPE IN (0,2,6,7,8,9) THEN 'INSTORE' 
            WHEN FTH.RDT_IDR_REALLOCATED_DIGITAL_TYPE IN (1,3,4,5,10) THEN 'OUTSTORE'
        END,
        CASE 
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) THEN TDT.TDT_ITEM_ID::INT8
            ELSE SKU.SKU_NUM_SKU_R3
        END,
        CASE 
            WHEN TDT.TDT_ITEM_ID in (4000000004,6000000006,7000000007) or (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID NOT IN (1000000001)) THEN TDT.F_QTY_ITEM_INITIAL
            ELSE TDT.F_QTY_ITEM
        END, 
        SKU.SKU_EAN_NUM,
        SKU.MDL_NUM_MODEL,
        CASE 
            WHEN TDT.TDT_ITEM_ID in (4000000004) THEN 'Livraison a domicile' --pas dispo actuellement
            WHEN TDT.TDT_ITEM_ID in (6000000006) THEN 'Bon de location' --pas dispo actuellement
            WHEN TDT.TDT_ITEM_ID in (7000000007) THEN 'Commande borne' --dispo en france uniquement, le détail de ces commandes n'est pas dispo, pour le moment pas de détail sur le ticket
            ELSE SKU.MDL_LABEL
        END, 
        SKU.FAM_IDR_FAMILY,
        SKU.FAMILY_LABEL,
        SKU.UNV_NUM_UNIVERS,
        SKU.UNV_LABEL,  
        TDT.TDT_SERIAL_NUMBER_RFID,  
        CUR.CUR_CODE_CURRENCY,
        CASE 
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) OR (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID not in (1000000001)) THEN TDT.F_AMT_TAX_INITIAL
            ELSE TDT.F_AMT_TAX
        END, 
        CASE 
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) OR (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID NOT IN (1000000001)) THEN TDT.F_TO_TAX_EX_INITIAL
            ELSE TDT.F_TO_TAX_EX
        END,
        CASE 
            WHEN SKU.FAM_IDR_FAMILY = 3398 THEN TDT.F_PRI_REGULAR_SALES_UNIT
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) OR (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID NOT IN (1000000001)) THEN TDT.F_TO_TAX_IN_INITIAL
            ELSE TDT.F_TO_TAX_IN
        END,
        CASE 
            WHEN TDT.TDT_ITEM_ID IN (4000000004,6000000006,7000000007) OR (SKU.SKU_NUM_SKU_R3 = 0 AND TDT.TDT_ITEM_ID NOT IN (1000000001)) THEN TDT.F_AMT_DISCOUNT_INITIAL
            ELSE TDT.F_AMT_DISCOUNT
        END,
        TO_CHAR(TTX.F_AMT_PERCENT,'90D99')
)
SELECT
    PAA.YEAR,
    PAA.MONTH,
    PAA.WEEK, 
    PAA.THE_TRANSACTION_ID,
    PAA.CASHIER_ID,
    PAA.CNT_COUNTRY_CODE,
    PAA.STORE_NAME,
    PAA.STORE_NUMBER,
    PAA.THE_DATE_TRANSACTION, 
    PAA.TYPE_CANAL,
    PAA.ITEM_CODE,
    SUM(PAA.ITEM_QUANTITY) AS ITEM_QUANTITY, --
    PAA.SKU_EAN_NUM,--
    PAA.MDL_NUM_MODEL,--
    PAA.MODEL_LABEL,
    PAA.FAM_IDR_FAMILY,
    PAA.FAMILY_LABEL,
    PAA.UNV_NUM_UNIVERS,
    PAA.UNV_LABEL,  
    PAA.TDT_SERIAL_NUMBER_RFID,  
    PAA.CUR_CODE_CURRENCY,
    PAA.MOP,
    PAA.TNT_TENDER_GROUP,
    SUM(PAA.TAX_AMOUNT) AS TAX_AMOUNT, --
    SUM(PAA.AMOUNT_EXCLUDING_TAX) AS AMOUNT_EXCLUDING_TAX, --
    SUM(PAA.AMOUNT_INCLUDING_TAX) AS AMOUNT_INCLUDING_TAX, --
    SUM(PAA.DISCOUNT_AMOUNT_INCLUDING_TAX) AS DISCOUNT_AMOUNT_INCLUDING_TAX, --
    PAA.TAX_RATE
FROM PERF_CASH PAA
GROUP BY 
    PAA.YEAR,
    PAA.MONTH,
    PAA.WEEK, 
    PAA.THE_TRANSACTION_ID,
    PAA.CASHIER_ID,
    PAA.CNT_COUNTRY_CODE,
    PAA.STORE_NAME,
    PAA.STORE_NUMBER,
    PAA.THE_DATE_TRANSACTION, 
    PAA.TYPE_CANAL,
    PAA.ITEM_CODE,
    --PAA.ITEM_QUANTITY,
    PAA.SKU_EAN_NUM,--
    PAA.MDL_NUM_MODEL,--
    PAA.MODEL_LABEL,
    PAA.FAM_IDR_FAMILY,
    PAA.FAMILY_LABEL,
    PAA.UNV_NUM_UNIVERS,
    PAA.UNV_LABEL,  
    PAA.TDT_SERIAL_NUMBER_RFID,  
    PAA.CUR_CODE_CURRENCY,
    --PAA.TAX_AMOUNT,
    --PAA.AMOUNT_EXCLUDING_TAX,
    --PAA.AMOUNT_INCLUDING_TAX,
    --PAA.DISCOUNT_AMOUNT_INCLUDING_TAX,
    PAA.TAX_RATE,
    PAA.MOP,
    PAA.TNT_TENDER_GROUP
;
------------------------------------------------------------------

--ajout pour gérer l'affichage des valeurs TO_CHAR(XXXXXXXXXXXXX, '999 999 990D999')
DROP TABLE IF EXISTS TMP_CASH_FRANCHISE_FORM  
CREATE TEMP TABLE TMP_CASH_FRANCHISE_FORM AS
SELECT
    PAA.YEAR,
    PAA.MONTH,
    PAA.WEEK, 
    PAA.THE_TRANSACTION_ID,
    PAA.CASHIER_ID,
    PAA.CNT_COUNTRY_CODE,
    PAA.STORE_NAME,
    PAA.STORE_NUMBER,
    PAA.THE_DATE_TRANSACTION, 
    PAA.TYPE_CANAL,
    PAA.ITEM_CODE,
    SUM(PAA.ITEM_QUANTITY) AS ITEM_QUANTITY, --
    PAA.SKU_EAN_NUM,--
    PAA.MDL_NUM_MODEL,--
    PAA.MODEL_LABEL,
    PAA.FAM_IDR_FAMILY,
    PAA.FAMILY_LABEL,
    PAA.UNV_NUM_UNIVERS,
    PAA.UNV_LABEL,  
    PAA.TDT_SERIAL_NUMBER_RFID,  
    PAA.CUR_CODE_CURRENCY,
    TO_CHAR(SUM(PAA.TAX_AMOUNT), '999 999 990D999') AS TAX_AMOUNT, --
    TO_CHAR(SUM(PAA.AMOUNT_EXCLUDING_TAX), '999 999 990D999') AS AMOUNT_EXCLUDING_TAX, --
    TO_CHAR(SUM(PAA.AMOUNT_INCLUDING_TAX), '999 999 990D999') AS AMOUNT_INCLUDING_TAX, --
    TO_CHAR(SUM(PAA.DISCOUNT_AMOUNT_INCLUDING_TAX), '999 999 990D999') AS DISCOUNT_AMOUNT_INCLUDING_TAX, --
    PAA.TAX_RATE
FROM TMP_CASH_FRANCHISE PAA
GROUP BY 
    PAA.YEAR,
    PAA.MONTH,
    PAA.WEEK, 
    PAA.THE_TRANSACTION_ID,
    PAA.CASHIER_ID,
    PAA.CNT_COUNTRY_CODE,
    PAA.STORE_NAME,
    PAA.STORE_NUMBER,
    PAA.THE_DATE_TRANSACTION, 
    PAA.TYPE_CANAL,
    PAA.ITEM_CODE,
    --PAA.ITEM_QUANTITY,
    PAA.SKU_EAN_NUM,--
    PAA.MDL_NUM_MODEL,--
    PAA.MODEL_LABEL,
    PAA.FAM_IDR_FAMILY,
    PAA.FAMILY_LABEL,
    PAA.UNV_NUM_UNIVERS,
    PAA.UNV_LABEL,  
    PAA.TDT_SERIAL_NUMBER_RFID,  
    PAA.CUR_CODE_CURRENCY,
    --PAA.TAX_AMOUNT,
    --PAA.AMOUNT_EXCLUDING_TAX,
    --PAA.AMOUNT_INCLUDING_TAX,
    --PAA.DISCOUNT_AMOUNT_INCLUDING_TAX,
    PAA.TAX_RATE
;

------------------------------------------------------------------

    --TMP_REF_CASH
DROP TABLE IF EXISTS TMP_REF_CASH 
CREATE TEMP TABLE TMP_REF_CASH AS 
WITH MAGASINS AS (
    SELECT
        DBU.STORE_NAME,
        DBU.STORE_NUMBER, 
        DBU.CNT_COUNTRY_CODE,
        DBU.CUR_CODE_CURRENCY,
        'INSTORE' AS TYPE_CANAL
    FROM TMP_CASH_FRANCHISE DBU
    GROUP BY
        DBU.STORE_NAME,
        DBU.STORE_NUMBER, 
        DBU.CNT_COUNTRY_CODE,
        DBU.CUR_CODE_CURRENCY
    UNION ALL 
    SELECT
        DBU.STORE_NAME,
        DBU.STORE_NUMBER, 
        DBU.CNT_COUNTRY_CODE,
        DBU.CUR_CODE_CURRENCY,
        'OUTSTORE' AS TYPE_CANAL
    FROM TMP_CASH_FRANCHISE DBU
    GROUP BY 
        DBU.STORE_NAME,
        DBU.STORE_NUMBER, 
        DBU.CNT_COUNTRY_CODE,
        DBU.CUR_CODE_CURRENCY
),
MEAN_OF_PAYMENT AS (
    SELECT
        MOP
    FROM TMP_CASH_FRANCHISE
    GROUP BY
        MOP
),

UNV_LABEL AS (
SELECT UNV_LABEL
FROM TMP_CASH_FRANCHISE
GROUP BY 
UNV_LABEL
)

SELECT
    EXTRACT(YEAR FROM DD.DAY_ID_DAY) AS YEAR,
    DATE_PART(MONTH, DD.DAY_ID_DAY) AS MONTH,
    DATE_PART(W, DD.DAY_ID_DAY) AS WEEK,
    MAG.CNT_COUNTRY_CODE,
    MAG.STORE_NAME,
    MAG.STORE_NUMBER,
    MAG.CUR_CODE_CURRENCY,
    MAG.TYPE_CANAL,
    U.UNV_LABEL,
    M.MOP,
    DD.DAY_ID_DAY AS THE_DATE_TRANSACTION,
    DD.DAY_ID_DAY_COMP AS THE_DATE_TRANSACTION_COMP
FROM CDS.D_DAY DD, MAGASINS MAG , MEAN_OF_PAYMENT M, UNV_LABEL U
WHERE 1=1
    AND DAY_ID_DAY BETWEEN CAST(DATE_TRUNC('YEAR', GETDATE()) AS DATE) AND GETDATE()
ORDER BY
    DD.DAY_ID_DAY,
    DD.DAY_ID_DAY_COMP,
    MAG.CNT_COUNTRY_CODE,
    MAG.STORE_NUMBER,
    MAG.STORE_NAME,
    MAG.CUR_CODE_CURRENCY,
    MAG.TYPE_CANAL
;

--------------------------------------------------------------------

--TMP_PERF_CASH_GLO
DROP TABLE TMP_PERF_CASH_GLO ;
CREATE TEMP TABLE TMP_PERF_CASH_GLO AS 
SELECT 
    TMP.YEAR,
    TMP.MONTH,
    TMP.WEEK,
    TMP.CNT_COUNTRY_CODE,
    TMP.CUR_CODE_CURRENCY, 
    TMP.STORE_NAME,
    TMP.STORE_NUMBER,
    TMP.TYPE_CANAL,
    TMP.THE_DATE_TRANSACTION,
    TMP.MOP,
    TMP.UNV_LABEL,
    NVL(SUM(N.ITEM_QUANTITY), 0) AS ITEM_QUANTITY_N,
    NVL(SUM(N_1.ITEM_QUANTITY), 0) AS ITEM_QUANTITY_N_1,
    NVL(SUM(N.TAX_AMOUNT), 0) AS TAX_AMOUNT_N, --
    NVL(SUM(N_1.TAX_AMOUNT), 0) AS TAX_AMOUNT_N_1, --
    NVL(SUM(N.AMOUNT_EXCLUDING_TAX), 0) AS AMOUNT_EXCLUDING_TAX_N, --
    NVL(SUM(N_1.AMOUNT_EXCLUDING_TAX), 0) AS AMOUNT_EXCLUDING_TAX_N_1, --
    NVL(SUM(N.AMOUNT_INCLUDING_TAX), 0) AS AMOUNT_INCLUDING_TAX_N, --
    NVL(SUM(N_1.AMOUNT_INCLUDING_TAX), 0) AS AMOUNT_INCLUDING_TAX_N_1, --
    NVL(SUM(N.DISCOUNT_AMOUNT_INCLUDING_TAX), 0) AS DISCOUNT_AMOUNT_INCLUDING_TAX_N, --
    NVL(SUM(N_1.DISCOUNT_AMOUNT_INCLUDING_TAX), 0) AS DISCOUNT_AMOUNT_INCLUDING_TAX_N_1 --
FROM TMP_REF_CASH TMP
LEFT OUTER JOIN TMP_CASH_FRANCHISE N
    ON N.STORE_NAME = TMP.STORE_NAME
    AND N.STORE_NUMBER = TMP.STORE_NUMBER
    AND N.TYPE_CANAL = TMP.TYPE_CANAL
    AND N.THE_DATE_TRANSACTION = TMP.THE_DATE_TRANSACTION
    AND N.MOP=TMP.MOP
    AND N.CNT_COUNTRY_CODE = TMP.CNT_COUNTRY_CODE
    AND N.UNV_LABEL = TMP.UNV_LABEL
LEFT OUTER JOIN TMP_CASH_FRANCHISE N_1 
    ON N_1.STORE_NAME = TMP.STORE_NAME
    AND N_1.STORE_NUMBER = TMP.STORE_NUMBER
    AND N_1.TYPE_CANAL = TMP.TYPE_CANAL
    AND N_1.THE_DATE_TRANSACTION=TMP.THE_DATE_TRANSACTION_COMP
    AND N_1.MOP=TMP.MOP
    AND N_1.CNT_COUNTRY_CODE = TMP.CNT_COUNTRY_CODE
    AND N_1.UNV_LABEL = TMP.UNV_LABEL
GROUP BY
    TMP.YEAR,
    TMP.MONTH,
    TMP.WEEK,
    TMP.CNT_COUNTRY_CODE,
    TMP.STORE_NAME,
    TMP.STORE_NUMBER,
    TMP.TYPE_CANAL,
    TMP.CUR_CODE_CURRENCY,
    TMP.THE_DATE_TRANSACTION,
    TMP.UNV_LABEL,
    TMP.MOP
;
------------------------------------------------------------
SELECT MOP
FROM TMP_PERF_CASH_GLO
WHERE 1=1
    AND ITEM_QUANTITY_N <> 0
LIMIT 1000 
;