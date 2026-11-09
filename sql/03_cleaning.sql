-- =====================================================================
-- 03_cleaning.sql  |  ServiceMaster: staging -> clean   (MySQL 8+)
-- Input : stg_customers, stg_technicians, stg_service_types,
--         stg_calendar, stg_service_requests
-- Output: clean_* tables, dq_log (cleaning log)
-- Run after 01_create_staging_tables.sql and loading the raw CSVs.
-- =====================================================================
USE servicemaster;

-- Blank dates (e.g. open tickets have no closed_date) must become NULL, not an error
SET SESSION sql_mode = REPLACE(REPLACE(@@sql_mode,'STRICT_TRANS_TABLES',''),'STRICT_ALL_TABLES','');

-- 0. Lookup tables for standardization (extend as you find new variants)
DROP TABLE IF EXISTS map_city;
CREATE TABLE map_city (raw_value VARCHAR(50) PRIMARY KEY, std_value VARCHAR(50));
INSERT INTO map_city VALUES
 ('delhi','Delhi'),('new delhi','Delhi'),
 ('mumbai','Mumbai'),('bombay','Mumbai'),
 ('bengaluru','Bengaluru'),('bangalore','Bengaluru'),('bengalore','Bengaluru'),
 ('hyderabad','Hyderabad'),('hyderbad','Hyderabad'),
 ('pune','Pune');

DROP TABLE IF EXISTS map_category;
CREATE TABLE map_category (raw_value VARCHAR(50) PRIMARY KEY, std_value VARCHAR(50));
INSERT INTO map_category VALUES
 ('electrical','Electrical'),('plumbing','Plumbing'),
 ('ac repair','AC Repair'),('ac','AC Repair'),('a.c. repair','AC Repair'),
 ('washing machine','Washing Machine'),
 ('ro service','RO Service'),('ro','RO Service');

DROP TABLE IF EXISTS map_status;
CREATE TABLE map_status (raw_value VARCHAR(50) PRIMARY KEY, std_value VARCHAR(50));
INSERT INTO map_status VALUES
 ('closed','Closed'),('close','Closed'),('resolved','Closed'),('completed','Closed'),
 ('open','Open'),('opened','Open'),('new','Open'),
 ('in progress','In Progress'),('in-progress','In Progress'),('inprogress','In Progress'),('wip','In Progress'),
 ('cancelled','Cancelled'),('canceled','Cancelled');

-- SLA rules from the README (fallback when sla_hours is missing/invalid)
DROP TABLE IF EXISTS map_sla;
CREATE TABLE map_sla (category VARCHAR(50) PRIMARY KEY, sla_hours INT);
INSERT INTO map_sla VALUES
 ('Electrical',24),('Plumbing',24),('AC Repair',48),('Washing Machine',48),('RO Service',72);

-- 1. Dimension tables ---------------------------------------------------
DROP TABLE IF EXISTS clean_customers;
CREATE TABLE clean_customers AS
SELECT customer_id, customer_name, city, segment
FROM (
    SELECT TRIM(c.customer_id)   AS customer_id,
           TRIM(c.customer_name) AS customer_name,
           COALESCE(m.std_value, TRIM(c.city)) AS city,
           CONCAT(UPPER(LEFT(TRIM(c.segment),1)), LOWER(SUBSTRING(TRIM(c.segment),2))) AS segment,
           ROW_NUMBER() OVER (PARTITION BY TRIM(c.customer_id) ORDER BY c.customer_name) AS rn
    FROM stg_customers c
    LEFT JOIN map_city m ON m.raw_value = LOWER(TRIM(c.city))
    WHERE NULLIF(TRIM(c.customer_id),'') IS NOT NULL
) x
WHERE rn = 1;
ALTER TABLE clean_customers ADD PRIMARY KEY (customer_id);

DROP TABLE IF EXISTS clean_technicians;
CREATE TABLE clean_technicians AS
SELECT technician_id, technician_name, city, team, hire_date
FROM (
    SELECT TRIM(t.technician_id)   AS technician_id,
           TRIM(t.technician_name) AS technician_name,
           COALESCE(m.std_value, TRIM(t.city)) AS city,
           TRIM(t.team) AS team,
           COALESCE(STR_TO_DATE(TRIM(t.hire_date),'%Y-%m-%d'),
                    STR_TO_DATE(TRIM(t.hire_date),'%d-%m-%Y'),
                    STR_TO_DATE(TRIM(t.hire_date),'%d/%m/%Y')) AS hire_date,
           ROW_NUMBER() OVER (PARTITION BY TRIM(t.technician_id) ORDER BY t.technician_name) AS rn
    FROM stg_technicians t
    LEFT JOIN map_city m ON m.raw_value = LOWER(TRIM(t.city))
    WHERE NULLIF(TRIM(t.technician_id),'') IS NOT NULL
) x
WHERE rn = 1;
ALTER TABLE clean_technicians ADD PRIMARY KEY (technician_id);

DROP TABLE IF EXISTS clean_service_types;
CREATE TABLE clean_service_types AS
SELECT service_type_id, category, sla_hours
FROM (
    SELECT TRIM(s.service_type_id) AS service_type_id,
           COALESCE(mc.std_value, TRIM(s.category)) AS category,
           COALESCE(CASE WHEN TRIM(s.sla_hours) REGEXP '^[0-9]+$' AND TRIM(s.sla_hours) > 0
                         THEN CAST(TRIM(s.sla_hours) AS UNSIGNED) END,
                    ms.sla_hours) AS sla_hours,
           ROW_NUMBER() OVER (PARTITION BY TRIM(s.service_type_id) ORDER BY s.category) AS rn
    FROM stg_service_types s
    LEFT JOIN map_category mc ON mc.raw_value = LOWER(TRIM(s.category))
    LEFT JOIN map_sla ms      ON ms.category  = COALESCE(mc.std_value, TRIM(s.category))
    WHERE NULLIF(TRIM(s.service_type_id),'') IS NOT NULL
) x
WHERE rn = 1;
ALTER TABLE clean_service_types ADD PRIMARY KEY (service_type_id);

DROP TABLE IF EXISTS clean_calendar;
CREATE TABLE clean_calendar AS
SELECT DISTINCT
       COALESCE(STR_TO_DATE(TRIM(`date`),'%Y-%m-%d'),
                STR_TO_DATE(TRIM(`date`),'%d-%m-%Y'),
                STR_TO_DATE(TRIM(`date`),'%d/%m/%Y')) AS `date`,
       CAST(year AS UNSIGNED)  AS year,
       TRIM(quarter)           AS quarter,
       CAST(month AS UNSIGNED) AS month,
       TRIM(month_name)        AS month_name,
       TRIM(weekday)           AS weekday
FROM stg_calendar
WHERE COALESCE(STR_TO_DATE(TRIM(`date`),'%Y-%m-%d'),
               STR_TO_DATE(TRIM(`date`),'%d-%m-%Y'),
               STR_TO_DATE(TRIM(`date`),'%d/%m/%Y')) IS NOT NULL;

-- 2. Fact table: step A - parse and standardize ---------------------------
-- NOTE: tries datetime formats first, then date-only. Add a format if your
-- raw files use a different one.
DROP TABLE IF EXISTS tmp_requests;
CREATE TABLE tmp_requests AS
SELECT
    NULLIF(TRIM(r.ticket_id),'')       AS ticket_id,
    -- IDs may arrive as '24.0'; convert to '24' so joins match
    CASE WHEN TRIM(r.customer_id) REGEXP '^[0-9]+\\.0+$'
         THEN CAST(CAST(CAST(TRIM(r.customer_id) AS DECIMAL(12,1)) AS UNSIGNED) AS CHAR)
         ELSE NULLIF(TRIM(r.customer_id),'') END AS customer_id,
    CASE WHEN TRIM(r.technician_id) REGEXP '^[0-9]+\\.0+$'
         THEN CAST(CAST(CAST(TRIM(r.technician_id) AS DECIMAL(12,1)) AS UNSIGNED) AS CHAR)
         ELSE NULLIF(TRIM(r.technician_id),'') END AS technician_id,
    CASE WHEN TRIM(r.service_type_id) REGEXP '^[0-9]+\\.0+$'
         THEN CAST(CAST(CAST(TRIM(r.service_type_id) AS DECIMAL(12,1)) AS UNSIGNED) AS CHAR)
         ELSE NULLIF(TRIM(r.service_type_id),'') END AS service_type_id,
    COALESCE(STR_TO_DATE(TRIM(r.created_date),'%Y-%m-%d %H:%i:%s'),
             STR_TO_DATE(TRIM(r.created_date),'%Y-%m-%d'),
             STR_TO_DATE(TRIM(r.created_date),'%d-%m-%Y'),
             STR_TO_DATE(TRIM(r.created_date),'%d/%m/%Y')) AS created_date,
    COALESCE(STR_TO_DATE(TRIM(r.assigned_date),'%Y-%m-%d %H:%i:%s'),
             STR_TO_DATE(TRIM(r.assigned_date),'%Y-%m-%d'),
             STR_TO_DATE(TRIM(r.assigned_date),'%d-%m-%Y'),
             STR_TO_DATE(TRIM(r.assigned_date),'%d/%m/%Y')) AS assigned_date,
    COALESCE(STR_TO_DATE(TRIM(r.closed_date),'%Y-%m-%d %H:%i:%s'),
             STR_TO_DATE(TRIM(r.closed_date),'%Y-%m-%d'),
             STR_TO_DATE(TRIM(r.closed_date),'%d-%m-%Y'),
             STR_TO_DATE(TRIM(r.closed_date),'%d/%m/%Y')) AS closed_date,
    CONCAT(UPPER(LEFT(TRIM(r.priority),1)), LOWER(SUBSTRING(TRIM(r.priority),2))) AS priority,
    COALESCE(ms.std_value, TRIM(r.status)) AS status,
    CASE WHEN TRIM(r.visit_count) REGEXP '^[0-9]+(\\.0+)?$'
          AND CAST(TRIM(r.visit_count) AS DECIMAL(5,1)) >= 1
         THEN CAST(CAST(TRIM(r.visit_count) AS DECIMAL(5,1)) AS UNSIGNED) END AS visit_count,
    CASE WHEN TRIM(r.cost) REGEXP '^[0-9]+(\\.[0-9]+)?$'
         THEN CAST(TRIM(r.cost) AS DECIMAL(10,2)) END AS cost,
    CASE WHEN TRIM(r.csat_score) REGEXP '^[0-9]+(\\.0+)?$'
          AND CAST(TRIM(r.csat_score) AS DECIMAL(5,1)) BETWEEN 1 AND 5
         THEN CAST(CAST(TRIM(r.csat_score) AS DECIMAL(5,1)) AS UNSIGNED) END AS csat_score,
    -- raw values kept only to measure what was fixed
    r.created_date AS raw_created, r.closed_date AS raw_closed,
    r.visit_count AS raw_visit, r.cost AS raw_cost, r.csat_score AS raw_csat
FROM stg_service_requests r
LEFT JOIN map_status ms ON ms.raw_value = LOWER(TRIM(r.status));

-- 3. Fact table: step B - dedupe, join, derive metrics and flags ----------
DROP TABLE IF EXISTS clean_service_requests;
CREATE TABLE clean_service_requests AS
SELECT y.*,
       CASE WHEN y.resolution_hours IS NULL OR y.sla_hours IS NULL THEN NULL
            WHEN y.resolution_hours <= y.sla_hours THEN 1 ELSE 0 END AS sla_met
FROM (
    SELECT
        t.ticket_id, t.customer_id, t.technician_id, t.service_type_id,
        st.category,
        c.city AS customer_city,
        te.city AS technician_city,
        t.priority, t.created_date, t.assigned_date, t.closed_date,
        t.status, t.visit_count, t.cost, t.csat_score,
        st.sla_hours,
        CASE WHEN t.status = 'Closed' AND t.visit_count IS NOT NULL
             THEN (t.visit_count = 1) END                           AS first_time_fix,
        CASE WHEN t.closed_date IS NOT NULL AND t.created_date IS NOT NULL
              AND t.closed_date >= t.created_date
             THEN ROUND(TIMESTAMPDIFF(SECOND, t.created_date, t.closed_date)/3600, 2)
        END                                                         AS resolution_hours,
        -- data quality flags
        (t.closed_date   < t.created_date)                          AS is_invalid_time,
        (t.assigned_date < t.created_date)                          AS is_assign_before_create,
        (t.status = 'Closed' AND t.closed_date IS NULL)             AS is_missing_close_date,
        (t.status IN ('Open','In Progress') AND t.closed_date IS NOT NULL) AS is_open_with_close_date,
        (t.customer_id IS NOT NULL AND c.customer_id IS NULL)       AS is_orphan_customer,
        (t.technician_id IS NOT NULL AND te.technician_id IS NULL)  AS is_orphan_technician,
        (t.service_type_id IS NOT NULL AND st.service_type_id IS NULL) AS is_orphan_service_type
    FROM (
        SELECT tmp.*,
               ROW_NUMBER() OVER (PARTITION BY ticket_id ORDER BY created_date) AS rn
        FROM tmp_requests tmp
        WHERE ticket_id IS NOT NULL
    ) t
    LEFT JOIN clean_customers     c  ON c.customer_id      = t.customer_id
    LEFT JOIN clean_technicians   te ON te.technician_id   = t.technician_id
    LEFT JOIN clean_service_types st ON st.service_type_id = t.service_type_id
    WHERE t.rn = 1
) y;

ALTER TABLE clean_service_requests ADD PRIMARY KEY (ticket_id);
CREATE INDEX idx_csr_cust_type ON clean_service_requests (customer_id, service_type_id, created_date);

-- 4. Cleaning log ----------------------------------------------------------
DROP TABLE IF EXISTS dq_log;
CREATE TABLE dq_log (
    rule_id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(40), issue VARCHAR(150), rows_found INT, action_taken VARCHAR(200)
);

INSERT INTO dq_log (table_name, issue, rows_found, action_taken)
SELECT 'service_requests','Duplicate ticket_id (extra copies)',
       (SELECT COUNT(*) FROM tmp_requests WHERE ticket_id IS NOT NULL) - (SELECT COUNT(*) FROM clean_service_requests),
       'Kept earliest-created copy';
INSERT INTO dq_log (table_name, issue, rows_found, action_taken)
SELECT 'service_requests','Missing ticket_id', COUNT(*), 'Row removed' FROM tmp_requests WHERE ticket_id IS NULL;
INSERT INTO dq_log (table_name, issue, rows_found, action_taken)
SELECT 'service_requests','Unparseable created_date', COUNT(*), 'Left NULL; row kept' FROM tmp_requests
WHERE created_date IS NULL;
INSERT INTO dq_log (table_name, issue, rows_found, action_taken)
SELECT 'service_requests','closed_date earlier than created_date', COUNT(*),
       'Flagged is_invalid_time; resolution_hours NULL' FROM clean_service_requests WHERE is_invalid_time = 1;
INSERT INTO dq_log (table_name, issue, rows_found, action_taken)
SELECT 'service_requests','assigned_date earlier than created_date', COUNT(*),
       'Flagged is_assign_before_create' FROM clean_service_requests WHERE is_assign_before_create = 1;
INSERT INTO dq_log (table_name, issue, rows_found, action_taken)
SELECT 'service_requests','Status Closed but closed_date missing', COUNT(*),
       'Flagged; excluded from resolution and SLA metrics' FROM clean_service_requests WHERE is_missing_close_date = 1;
INSERT INTO dq_log (table_name, issue, rows_found, action_taken)
SELECT 'service_requests','Open/In Progress but has closed_date', COUNT(*),
       'Flagged is_open_with_close_date' FROM clean_service_requests WHERE is_open_with_close_date = 1;
INSERT INTO dq_log (table_name, issue, rows_found, action_taken)
SELECT 'service_requests','Invalid csat_score (not 1-5)', COUNT(*),
       'Set to NULL' FROM tmp_requests WHERE NULLIF(TRIM(raw_csat),'') IS NOT NULL AND csat_score IS NULL;
INSERT INTO dq_log (table_name, issue, rows_found, action_taken)
SELECT 'service_requests','Invalid visit_count (non-numeric or < 1)', COUNT(*),
       'Set to NULL' FROM tmp_requests WHERE NULLIF(TRIM(raw_visit),'') IS NOT NULL AND visit_count IS NULL;
INSERT INTO dq_log (table_name, issue, rows_found, action_taken)
SELECT 'service_requests','Invalid or negative cost', COUNT(*),
       'Set to NULL' FROM tmp_requests WHERE NULLIF(TRIM(raw_cost),'') IS NOT NULL AND cost IS NULL;
INSERT INTO dq_log (table_name, issue, rows_found, action_taken)
SELECT 'service_requests','Orphan customer_id / technician_id / service_type_id', COUNT(*),
       'Flagged is_orphan_*; row kept'
FROM clean_service_requests WHERE is_orphan_customer = 1 OR is_orphan_technician = 1 OR is_orphan_service_type = 1;
INSERT INTO dq_log (table_name, issue, rows_found, action_taken)
SELECT 'service_requests','Blank technician_id (unassigned ticket)', COUNT(*),
       'Kept as NULL; not treated as orphan' FROM clean_service_requests WHERE technician_id IS NULL;
INSERT INTO dq_log (table_name, issue, rows_found, action_taken)
SELECT 'customers','Duplicate customer_id', COUNT(*) - (SELECT COUNT(*) FROM clean_customers),
       'Kept one row per id' FROM stg_customers WHERE NULLIF(TRIM(customer_id),'') IS NOT NULL;
INSERT INTO dq_log (table_name, issue, rows_found, action_taken)
SELECT 'customers/technicians','City variants (e.g. Bangalore, Bombay)',
       (SELECT COUNT(*) FROM stg_customers  WHERE TRIM(city) <> (SELECT std_value FROM map_city m WHERE m.raw_value = LOWER(TRIM(city))) COLLATE utf8mb4_bin)
     + (SELECT COUNT(*) FROM stg_technicians WHERE TRIM(city) <> (SELECT std_value FROM map_city m WHERE m.raw_value = LOWER(TRIM(city))) COLLATE utf8mb4_bin),
       'Mapped to 5 standard cities via map_city';
INSERT INTO dq_log (table_name, issue, rows_found, action_taken)
SELECT 'technicians','Duplicate technician_id', COUNT(*) - (SELECT COUNT(*) FROM clean_technicians),
       'Kept one row per id' FROM stg_technicians WHERE NULLIF(TRIM(technician_id),'') IS NOT NULL;
INSERT INTO dq_log (table_name, issue, rows_found, action_taken)
SELECT 'service_types','Missing/invalid sla_hours', COUNT(*),
       'Filled from README SLA rules (map_sla)'
FROM stg_service_types WHERE NOT (TRIM(sla_hours) REGEXP '^[0-9]+$') OR TRIM(sla_hours) = '0';

DROP TABLE tmp_requests;

SELECT * FROM dq_log ORDER BY rule_id;