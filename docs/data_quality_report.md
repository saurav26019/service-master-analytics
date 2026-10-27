# Data Quality Report

Source: 8,100 raw rows in `stg_service_requests`, 600 in `stg_customers`.

| # | Issue | Rows affected | Fix applied |
|---|-------|---------------|-------------|
| 1 | Duplicate ticket rows | 100 | Kept one row per ticket_id |
| 2 | Closed date earlier than created date | 80 | Closed date set to NULL and flagged |
| 3 | Missing technician_id | 152 | Kept as NULL (unassigned) and flagged |
| 4 | Negative cost | 52 | Converted to absolute value and flagged |
| 5 | CSAT score outside 1 to 5 | 40 | Set to NULL and flagged |
| 6 | Closed ticket with no closed_date | 40 | Kept and flagged, excluded from resolution time |
| 7 | Orphan customer_id | 31 | customer_id set to NULL and flagged |
| 8 | Status in wrong case | 60 | Standardized to Closed / Open / In Progress |
| 9 | Non-standard city spelling | 72 | Mapped to Delhi, Mumbai, Bengaluru, Hyderabad, Pune |

Result: 8,000 unique tickets in the clean `service_requests` table. Each repaired row carries a `dq_flag` note.
