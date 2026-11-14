# Service Master: Service Operations Analytics

## Overview
ServiceMaster Pvt. Ltd. is a home and appliance service company operating in
Delhi, Mumbai, Bengaluru, Hyderabad and Pune. This project analyzes service
ticket data using SQL, Excel and Power BI to track performance and data quality.

## Business Questions
1. How many tickets are open vs closed?
2. What is the average resolution time?
3. What percentage of tickets meet SLA?
4. Which city or category breaches SLA most?
5. Which technicians are most productive?
6. What is the CSAT trend?
7. How many customers raise repeat complaints?

## KPIs
| KPI | Definition |
|-----|------------|
| Total Tickets | Count of all tickets raised |
| Avg Resolution Time | Hours from created to closed |
| SLA Compliance % | SLA-met tickets / closed tickets |
| First-Time Fix Rate | Resolved in first visit / closed |
| Avg CSAT | Average rating (1 to 5) |
| Repeat Complaint Rate | Same customer + service within 30 days |

## SLA Rules
| Category | SLA (hours) |
|----------|-------------|
| Electrical | 24 |
| Plumbing | 24 |
| AC Repair | 48 |
| Washing Machine | 48 |
| RO Service | 72 |

## Tech Stack
SQL (MySQL/PostgreSQL), Excel, Power BI, Python (data generation)

## Project Structure
- `data/` raw and cleaned datasets
- `sql/` schema, validation and analysis scripts
- `excel/` pivot reports and reconciliation
- `powerbi/` .pbix file and screenshots

## Status
- [x] Step 1: Business scenario and KPIs
- [x] Step 2: Data model
- [x] Step 3: Sample data generated
- [x] Step 4: Database and staging tables created     
- [x] Step 5: Data cleaning and validation
- [x] Step 6: SQL analysis views
- [ ] Step 7: Excel reports
- [ ] Step 8: Power BI dashboard
- [ ] Step 9: Insights and final documentation

## How to Reproduce
1. Run `sql/01_create_staging_tables.sql` and load the CSVs from `data/raw` into the `stg_` tables
2. Run `sql/03_cleaning.sql`
3. Run `sql/04_validation.sql`
4. Run `sql/05_analysis.sql`

   ## Key Findings

- SLA compliance is 65.0%: about 1 in 3 closed tickets misses its SLA.
- The SLA gap is company-wide: only about 3 points between cities and between categories.
- Technician performance varies far more: SLA compliance ranges from 40.9% to 86.9% across technicians.
- AC Repair has the highest repeat complaint rate (17.3%) against 13.9% overall.
- CSAT is flat at about 3.8 to 3.9 and does not change with SLA or first-time fix.

Full analysis: [docs/insights.md](docs/insights.md) | Cleaning rules: [docs/cleaning_log.md](docs/cleaning_log.md)
