# Key Insights: ServiceMaster Service Operations

Source: `clean_service_requests` and the views in `sql/05_analysis.sql`.
Resolution time and SLA use closed tickets with valid timing only (6,924 of 7,043 closed tickets; the other 119 are flagged in `docs/cleaning_log.md`).

## Headline KPIs

| KPI | Value |
|---|---|
| Total tickets | 8,000 |
| Closed / Open | 7,043 / 957 (12% open) |
| Avg resolution time | 38.4 hours |
| SLA compliance | 65.0% |
| First-time fix rate | 71.4% |
| Avg CSAT | 3.84 / 5 |
| Repeat complaint rate | 13.9% |

## 1. About 1 in 3 tickets breaches its SLA

2,425 of 6,924 closed tickets (35.0%) missed their SLA; compliance is 65.0%.

**Recommendation:** make SLA compliance the primary operations target and set a 75% goal as a first milestone.

## 2. The SLA problem is company-wide, not local to one city or category

- By city, compliance ranges only from 63.2% (Hyderabad) to 66.4% (Mumbai).
- By category, it ranges from 63.3% (Plumbing) to 66.7% (RO Service).
- The single worst city and category combination is Hyderabad Plumbing (41.0% breach rate on 217 tickets), but the top 10 combinations all sit between 35% and 41%.

**Recommendation:** fix process-level causes (assignment speed, scheduling, parts availability) that apply everywhere, rather than adding capacity in one city. Hyderabad is the first place to pilot changes since it is the weakest on average.

## 3. AC Repair has the most repeat complaints

Repeat rate (same customer and service type within 30 days): AC Repair 17.3%, Electrical 14.7%, Washing Machine 12.9%, Plumbing 11.5%, RO Service 11.0%. AC Repair is also the highest-volume category (2,131 tickets).

**Recommendation:** review AC Repair repeat tickets for common causes (parts, diagnosis, seasonal load) and add a quality check before closing AC jobs. The data shows where repeats are high, not why.

## 4. CSAT is flat and does not move with SLA, fix quality or category

- CSAT stayed between 3.77 and 3.92 for 17 full months (Jan 2025 to May 2026), with no trend. June 2026 is a partial month (13 rated tickets) and is excluded.
- SLA met vs breached: 3.85 vs 3.84.
- First-time fix vs not: 3.86 vs 3.82.
- By category: 3.78 (Plumbing) to 3.90 (Electrical).

**Recommendation:** do not justify SLA improvements by CSAT alone, since this data shows no link. Collect richer feedback (reason codes, comments) to learn what drives satisfaction.

## 5. Technician performance varies far more than city or category

Across all technicians, average resolution time ranges from 24.5 to 53.3 hours and SLA compliance from 40.9% to 86.9%. That is a 46-point SLA gap between the weakest and strongest technician, compared with about 3 points between cities and about 3 points between categories.

**Recommendation:** individual technician performance is the biggest lever on SLA. Review the technicians with the lowest compliance, pair them with the fastest for coaching, and track resolution time and SLA per technician every month.

## Limitations

- The dataset is synthetic, so some relationships (for example CSAT versus SLA) may be weaker than in real operations.
- 30 tickets reference customers not in the customer master; they are excluded from customer-level analysis (repeat complaints) and show as "Unknown" city.
- Ranking technicians by ticket count alone is not a full productivity measure; resolution time and SLA should be read alongside it.
