-- =====================================================================
-- 04_validation.sql  |  Reconciliation and post-clean checks (MySQL 8+)
-- Run after 03_cleaning.sql. Every check_result should be PASS.
-- =====================================================================
USE servicemaster;

-- 1. Row counts: staging vs clean ----------------------------------------
SELECT 'customers' AS tbl, (SELECT COUNT(*) FROM stg_customers) AS staging_rows,
       (SELECT COUNT(*) FROM clean_customers) AS clean_rows
UNION ALL SELECT 'technicians', (SELECT COUNT(*) FROM stg_technicians), (SELECT COUNT(*) FROM clean_technicians)
UNION ALL SELECT 'service_types', (SELECT COUNT(*) FROM stg_service_types), (SELECT COUNT(*) FROM clean_service_types)
UNION ALL SELECT 'calendar', (SELECT COUNT(*) FROM stg_calendar), (SELECT COUNT(*) FROM clean_calendar)
UNION ALL SELECT 'service_requests', (SELECT COUNT(*) FROM stg_service_requests), (SELECT COUNT(*) FROM clean_service_requests);

-- Fact reconciliation: staging = clean + duplicates removed + missing ids
SELECT s.staging_rows, c.clean_rows, (s.staging_rows - c.clean_rows) AS rows_removed,
       d.dups_removed, d.missing_ids,
       CASE WHEN s.staging_rows - c.clean_rows = d.dups_removed + d.missing_ids
            THEN 'PASS' ELSE 'FAIL' END AS reconciliation
FROM (SELECT COUNT(*) AS staging_rows FROM stg_service_requests) s,
     (SELECT COUNT(*) AS clean_rows   FROM clean_service_requests) c,
     (SELECT
        (SELECT rows_found FROM dq_log WHERE issue LIKE 'Duplicate ticket_id%')  AS dups_removed,
        (SELECT rows_found FROM dq_log WHERE issue = 'Missing ticket_id')        AS missing_ids) d;

-- 2. Rule checks on clean data --------------------------------------------
SELECT 'No duplicate ticket_id' AS check_name,
       CASE WHEN COUNT(*) = COUNT(DISTINCT ticket_id) THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM clean_service_requests
UNION ALL SELECT 'Only 5 valid cities (customers)',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean_customers WHERE city NOT IN ('Delhi','Mumbai','Bengaluru','Hyderabad','Pune')
UNION ALL SELECT 'Only 5 valid cities (technicians)',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean_technicians WHERE city NOT IN ('Delhi','Mumbai','Bengaluru','Hyderabad','Pune')
UNION ALL SELECT 'Only 5 valid categories',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean_service_types WHERE category NOT IN ('Electrical','Plumbing','AC Repair','Washing Machine','RO Service')
UNION ALL SELECT 'SLA hours match README rules',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean_service_types st JOIN map_sla m ON m.category = st.category WHERE st.sla_hours <> m.sla_hours
UNION ALL SELECT 'Only known statuses',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean_service_requests WHERE status NOT IN ('Open','In Progress','Closed','Cancelled')
UNION ALL SELECT 'CSAT between 1 and 5 (or NULL)',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean_service_requests WHERE csat_score IS NOT NULL AND csat_score NOT BETWEEN 1 AND 5
UNION ALL SELECT 'No negative resolution_hours',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean_service_requests WHERE resolution_hours < 0
UNION ALL SELECT 'No negative cost',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean_service_requests WHERE cost < 0
UNION ALL SELECT 'created_date never NULL',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean_service_requests WHERE created_date IS NULL
UNION ALL SELECT 'Every ticket has sla_hours',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean_service_requests WHERE sla_hours IS NULL
UNION ALL SELECT 'No orphan customers',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean_service_requests WHERE is_orphan_customer = 1
UNION ALL SELECT 'No orphan technicians',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean_service_requests WHERE is_orphan_technician = 1
UNION ALL SELECT 'No orphan service types',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean_service_requests WHERE is_orphan_service_type = 1;

-- 3. Flagged rows still in the table (informational, not failures) --------
SELECT SUM(is_invalid_time)          AS invalid_time,
       SUM(is_assign_before_create)  AS assign_before_create,
       SUM(is_missing_close_date)    AS missing_close_date,
       SUM(is_open_with_close_date)  AS open_with_close_date,
       SUM(is_orphan_customer)       AS orphan_customer,
       SUM(is_orphan_technician)     AS orphan_technician,
       SUM(is_orphan_service_type)   AS orphan_service_type
FROM clean_service_requests;

-- 4. Profile after cleaning ------------------------------------------------
SELECT status, COUNT(*) AS tickets FROM clean_service_requests GROUP BY status;
SELECT category, COUNT(*) AS tickets, ROUND(AVG(resolution_hours),1) AS avg_hours
FROM clean_service_requests GROUP BY category ORDER BY tickets DESC;
SELECT customer_city, COUNT(*) AS tickets FROM clean_service_requests GROUP BY customer_city ORDER BY tickets DESC;

-- 5. Cleaning log (copy into docs/cleaning_log.md) --------------------------
SELECT rule_id, table_name, issue, rows_found, action_taken FROM dq_log ORDER BY rule_id;