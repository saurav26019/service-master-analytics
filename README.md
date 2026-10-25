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
