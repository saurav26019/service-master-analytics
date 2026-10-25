# Data Model (Star Schema)

## service_requests (Fact)
| Column | Type | Meaning |
|---|---|---|
| ticket_id | INT (PK) | Unique ticket number |
| customer_id | INT (FK) | Customer |
| technician_id | INT (FK) | Assigned technician |
| service_type_id | INT (FK) | Service category |
| created_date | DATETIME | Ticket raised |
| assigned_date | DATETIME | Technician assigned |
| closed_date | DATETIME | Ticket closed |
| status | VARCHAR | Open / In Progress / Closed |
| priority | VARCHAR | High / Medium / Low |
| visit_count | INT | 1 = first-time fix |
| cost | DECIMAL | Service charge |
| csat_score | INT | Rating 1 to 5 |

## customers
customer_id (PK), customer_name, city, segment

## technicians
technician_id (PK), technician_name, city, team, hire_date

## service_types
service_type_id (PK), category, sla_hours

## calendar
date (PK), year, quarter, month, month_name, weekday

## Relationships (one-to-many)
- customers (1) to service_requests (many) on customer_id
- technicians (1) to service_requests (many) on technician_id
- service_types (1) to service_requests (many) on service_type_id
- calendar (1) to service_requests (many) on created_date
