-- =====================================================================
-- 05_analysis.sql  |  ServiceMaster analysis views (MySQL 8+)
-- Source: clean_service_requests (built by 03_cleaning.sql)
--
-- Metric rules (document these in README):
--  * Resolution time and SLA use only Closed tickets with a valid
--    resolution time (excludes the 79 closed-before-created and the
--    40 closed-without-date rows flagged in dq_log).
--  * City = customer's city (where the service happened). Tickets whose
--    customer ID is not in the customer master show as 'Unknown'.
--  * Customer-level analysis (repeat complaints) excludes orphan customers.
-- =====================================================================
USE servicemaster;

-- Base view: closed tickets with trustworthy timing ---------------------
CREATE OR REPLACE VIEW v_closed_valid AS
SELECT *, COALESCE(customer_city, 'Unknown') AS city
FROM clean_service_requests
WHERE status = 'Closed' AND resolution_hours IS NOT NULL;

-- Q1. Open vs closed tickets ---------------------------------------------
CREATE OR REPLACE VIEW v_ticket_status AS
SELECT status,
       COUNT(*) AS tickets,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_total
FROM clean_service_requests
GROUP BY status;

-- Q2. Average resolution time (hours) -------------------------------------
CREATE OR REPLACE VIEW v_resolution_by_category AS
SELECT category,
       COUNT(*)                         AS closed_tickets,
       ROUND(AVG(resolution_hours), 1)  AS avg_resolution_hours,
       MAX(sla_hours)                   AS sla_hours
FROM v_closed_valid
GROUP BY category;

-- Q3. SLA compliance % (overall, by category, by city) ---------------------
CREATE OR REPLACE VIEW v_sla_by_category AS
SELECT category,
       COUNT(*)                          AS closed_tickets,
       SUM(sla_met)                      AS met,
       COUNT(*) - SUM(sla_met)           AS breached,
       ROUND(100 * AVG(sla_met), 1)      AS sla_compliance_pct
FROM v_closed_valid
GROUP BY category;

CREATE OR REPLACE VIEW v_sla_by_city AS
SELECT city,
       COUNT(*)                          AS closed_tickets,
       SUM(sla_met)                      AS met,
       COUNT(*) - SUM(sla_met)           AS breached,
       ROUND(100 * AVG(sla_met), 1)      AS sla_compliance_pct
FROM v_closed_valid
GROUP BY city;

-- Q4. Which city / category breaches SLA most (ranked) ---------------------
CREATE OR REPLACE VIEW v_sla_breach_city_category AS
SELECT city, category,
       COUNT(*)                                   AS closed_tickets,
       COUNT(*) - SUM(sla_met)                    AS breached,
       ROUND(100 * (1 - AVG(sla_met)), 1)         AS breach_rate_pct,
       RANK() OVER (ORDER BY (1 - AVG(sla_met)) DESC) AS breach_rank
FROM v_closed_valid
GROUP BY city, category;

-- Q5. Technician productivity ----------------------------------------------
CREATE OR REPLACE VIEW v_technician_productivity AS
SELECT t.technician_id,
       t.technician_name,
       t.team,
       t.city                               AS technician_city,
       COUNT(*)                             AS tickets_closed,
       ROUND(AVG(v.resolution_hours), 1)    AS avg_resolution_hours,
       ROUND(100 * AVG(v.first_time_fix), 1) AS first_time_fix_pct,
       ROUND(100 * AVG(v.sla_met), 1)       AS sla_compliance_pct,
       ROUND(AVG(v.csat_score), 2)          AS avg_csat,
       RANK() OVER (ORDER BY COUNT(*) DESC) AS productivity_rank
FROM v_closed_valid v
JOIN clean_technicians t ON t.technician_id = v.technician_id
GROUP BY t.technician_id, t.technician_name, t.team, t.city;

-- Q6. CSAT trend (by month the ticket closed) -------------------------------
CREATE OR REPLACE VIEW v_csat_trend AS
SELECT month_closed, rated_tickets, avg_csat,
       ROUND(avg_csat - LAG(avg_csat) OVER (ORDER BY month_closed), 2) AS change_vs_prev_month
FROM (
    SELECT DATE_FORMAT(closed_date, '%Y-%m') AS month_closed,
           COUNT(csat_score)                 AS rated_tickets,
           ROUND(AVG(csat_score), 2)         AS avg_csat
    FROM clean_service_requests
    WHERE status = 'Closed' AND csat_score IS NOT NULL AND closed_date IS NOT NULL
    GROUP BY DATE_FORMAT(closed_date, '%Y-%m')
) m;

-- Q7. Repeat complaints: same customer + same service within 30 days -------
CREATE OR REPLACE VIEW v_repeat_tickets AS
SELECT ticket_id, customer_id, service_type_id, category, created_date,
       prev_created,
       DATEDIFF(created_date, prev_created)  AS days_since_prev,
       CASE WHEN prev_created IS NOT NULL
             AND DATEDIFF(created_date, prev_created) <= 30 THEN 1 ELSE 0 END AS is_repeat
FROM (
    SELECT ticket_id, customer_id, service_type_id, category, created_date,
           LAG(created_date) OVER (PARTITION BY customer_id, service_type_id
                                   ORDER BY created_date) AS prev_created
    FROM clean_service_requests
    WHERE is_orphan_customer = 0 AND customer_id IS NOT NULL AND created_date IS NOT NULL
) x;

CREATE OR REPLACE VIEW v_repeat_summary AS
SELECT COUNT(*)                                   AS tickets_analysed,
       SUM(is_repeat)                             AS repeat_tickets,
       ROUND(100 * AVG(is_repeat), 1)             AS repeat_ticket_rate_pct,
       COUNT(DISTINCT customer_id)                AS customers,
       COUNT(DISTINCT CASE WHEN is_repeat = 1 THEN customer_id END) AS customers_with_repeat,
       ROUND(100 * COUNT(DISTINCT CASE WHEN is_repeat = 1 THEN customer_id END)
                 / COUNT(DISTINCT customer_id), 1) AS customers_with_repeat_pct
FROM v_repeat_tickets;

CREATE OR REPLACE VIEW v_repeat_by_category AS
SELECT category, COUNT(*) AS tickets, SUM(is_repeat) AS repeat_tickets,
       ROUND(100 * AVG(is_repeat), 1) AS repeat_rate_pct
FROM v_repeat_tickets
GROUP BY category;

-- KPI summary: one row, feeds README and Power BI cards ---------------------
CREATE OR REPLACE VIEW v_kpi_summary AS
SELECT
  (SELECT COUNT(*) FROM clean_service_requests)                                   AS total_tickets,
  (SELECT COUNT(*) FROM clean_service_requests WHERE status = 'Closed')           AS closed_tickets,
  (SELECT COUNT(*) FROM clean_service_requests WHERE status IN ('Open','In Progress')) AS open_tickets,
  (SELECT ROUND(AVG(resolution_hours), 1) FROM v_closed_valid)                    AS avg_resolution_hours,
  (SELECT ROUND(100 * AVG(sla_met), 1) FROM v_closed_valid)                       AS sla_compliance_pct,
  (SELECT ROUND(100 * AVG(first_time_fix), 1) FROM v_closed_valid)                AS first_time_fix_pct,
  (SELECT ROUND(AVG(csat_score), 2) FROM clean_service_requests)                  AS avg_csat,
  (SELECT repeat_ticket_rate_pct FROM v_repeat_summary)                           AS repeat_complaint_rate_pct;

-- =====================================================================
-- RUN THESE to see results (select one line, then click the lightning bolt
-- with the ONE-line icon, or run the whole file and use these in a new tab)
-- =====================================================================
-- SELECT * FROM v_kpi_summary;
-- SELECT * FROM v_ticket_status;
-- SELECT * FROM v_resolution_by_category;
-- SELECT * FROM v_sla_by_category   ORDER BY sla_compliance_pct;
-- SELECT * FROM v_sla_by_city       ORDER BY sla_compliance_pct;
-- SELECT * FROM v_sla_breach_city_category ORDER BY breach_rank LIMIT 10;
-- SELECT * FROM v_technician_productivity ORDER BY productivity_rank;
-- SELECT * FROM v_csat_trend ORDER BY month_closed;
-- SELECT * FROM v_repeat_summary;
-- SELECT * FROM v_repeat_by_category ORDER BY repeat_rate_pct DESC;
