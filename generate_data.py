import os
import numpy as np
import pandas as pd

rng = np.random.default_rng(42)
OUT = "data/raw"
os.makedirs(OUT, exist_ok=True)

N_CUSTOMERS = 600
N_TECHS = 40
N_TICKETS = 8000
CITIES = ["Delhi", "Mumbai", "Bengaluru", "Hyderabad", "Pune"]

# ---------- service_types ----------
service_types = pd.DataFrame({
    "service_type_id": [1, 2, 3, 4, 5],
    "category": ["Electrical", "Plumbing", "AC Repair", "Washing Machine", "RO Service"],
    "sla_hours": [24, 24, 48, 48, 72],
})

# ---------- customers ----------
first = ["Aarav", "Riya", "Vivaan", "Anaya", "Kabir", "Isha", "Rohan", "Meera",
         "Arjun", "Sneha", "Dev", "Pooja", "Karan", "Neha", "Aditya", "Kavya"]
last = ["Sharma", "Verma", "Singh", "Patel", "Reddy", "Iyer", "Gupta", "Khan",
        "Joshi", "Nair", "Mehta", "Das"]
customers = pd.DataFrame({
    "customer_id": np.arange(1, N_CUSTOMERS + 1),
    "customer_name": [f"{rng.choice(first)} {rng.choice(last)}" for _ in range(N_CUSTOMERS)],
    "city": rng.choice(CITIES, N_CUSTOMERS, p=[0.28, 0.24, 0.2, 0.15, 0.13]),
    "segment": rng.choice(["Residential", "Commercial"], N_CUSTOMERS, p=[0.8, 0.2]),
})

# ---------- technicians ----------
technicians = pd.DataFrame({
    "technician_id": np.arange(1, N_TECHS + 1),
    "technician_name": [f"{rng.choice(first)} {rng.choice(last)}" for _ in range(N_TECHS)],
    "city": rng.choice(CITIES, N_TECHS),
    "team": rng.choice(["Team A", "Team B", "Team C"], N_TECHS),
    "hire_date": pd.to_datetime("2018-01-01") + pd.to_timedelta(rng.integers(0, 2200, N_TECHS), unit="D"),
})
technicians["hire_date"] = technicians["hire_date"].dt.date
tech_speed = dict(zip(technicians["technician_id"], rng.uniform(0.7, 1.4, N_TECHS)))

# ---------- calendar ----------
dates = pd.date_range("2025-01-01", "2026-06-30")
calendar = pd.DataFrame({
    "date": dates.date,
    "year": dates.year,
    "quarter": dates.quarter,
    "month": dates.month,
    "month_name": dates.strftime("%b"),
    "weekday": dates.strftime("%a"),
})

# ---------- service_requests ----------
tickets = pd.DataFrame({"ticket_id": np.arange(100001, 100001 + N_TICKETS)})
tickets["customer_id"] = rng.integers(1, N_CUSTOMERS + 1, N_TICKETS)
tickets["technician_id"] = rng.integers(1, N_TECHS + 1, N_TICKETS)
tickets["service_type_id"] = rng.choice([1, 2, 3, 4, 5], N_TICKETS, p=[0.2, 0.18, 0.27, 0.2, 0.15])

start = pd.Timestamp("2025-01-01")
span_minutes = int((pd.Timestamp("2026-05-31") - start).total_seconds() // 60)
tickets["created_date"] = start + pd.to_timedelta(rng.integers(0, span_minutes, N_TICKETS), unit="m")
tickets["priority"] = rng.choice(["High", "Medium", "Low"], N_TICKETS, p=[0.2, 0.5, 0.3])
tickets["assigned_date"] = tickets["created_date"] + pd.to_timedelta(rng.integers(10, 360, N_TICKETS), unit="m")

sla = tickets["service_type_id"].map(service_types.set_index("service_type_id")["sla_hours"])
speed = tickets["technician_id"].map(tech_speed)
prio_factor = tickets["priority"].map({"High": 0.7, "Medium": 1.0, "Low": 1.2})
res_hours = rng.gamma(shape=4, scale=sla / 4 * 0.9, size=N_TICKETS) * speed * prio_factor
tickets["closed_date"] = tickets["created_date"] + pd.to_timedelta(res_hours, unit="h")

tickets["status"] = rng.choice(["Closed", "In Progress", "Open"], N_TICKETS, p=[0.88, 0.07, 0.05])
open_mask = tickets["status"] != "Closed"
tickets.loc[open_mask, "closed_date"] = pd.NaT

tickets["visit_count"] = rng.choice([1, 2, 3], N_TICKETS, p=[0.72, 0.22, 0.06])
tickets["cost"] = (rng.normal(1200, 450, N_TICKETS).clip(200, 4000)
                   * tickets["service_type_id"].map({1: 0.8, 2: 0.9, 3: 1.4, 4: 1.1, 5: 0.7})).round(2)
tickets["csat_score"] = rng.choice([1, 2, 3, 4, 5], N_TICKETS, p=[0.04, 0.08, 0.18, 0.4, 0.3]).astype(float)
tickets.loc[open_mask, "csat_score"] = np.nan

for c in ["created_date", "assigned_date", "closed_date"]:
    tickets[c] = tickets[c].dt.floor("s")

# ---------- dirty data ----------
def pick(n):
    return rng.choice(tickets.index, n, replace=False)

# closed_date before created_date
idx = [i for i in pick(300) if tickets.loc[i, "status"] == "Closed"][:80]
tickets.loc[idx, "closed_date"] = tickets.loc[idx, "created_date"] - pd.to_timedelta(rng.integers(1, 48, len(idx)), unit="h")

# missing technician
tickets["technician_id"] = tickets["technician_id"].astype("float")
tickets.loc[pick(150), "technician_id"] = np.nan

# negative cost
tickets.loc[pick(50), "cost"] *= -1

# csat out of range
idx = [i for i in pick(400) if tickets.loc[i, "status"] == "Closed"][:40]
tickets.loc[idx, "csat_score"] = rng.choice([0, 6, 7, 10], len(idx))

# orphan customer ids
tickets.loc[pick(30), "customer_id"] = rng.integers(9000, 9999, 30)

# missing closed_date on closed tickets
idx = [i for i in pick(400) if tickets.loc[i, "status"] == "Closed"][:40]
tickets.loc[idx, "closed_date"] = pd.NaT

# duplicates
dups = tickets.sample(100, random_state=1)
tickets = pd.concat([tickets, dups], ignore_index=True).sample(frac=1, random_state=2).reset_index(drop=True)

# inconsistent city names
variants = {
    "Delhi": ["delhi", "New Delhi", "DELHI", "Delhi "],
    "Mumbai": ["mumbai", "Bombay", "MUMBAI"],
    "Bengaluru": ["Bangalore", "bengaluru", "BANGALORE"],
    "Hyderabad": ["hyderabad", "Hyd"],
    "Pune": ["pune", "PUNE"],
}
dirty_idx = rng.choice(customers.index, int(0.12 * N_CUSTOMERS), replace=False)
for i in dirty_idx:
    customers.loc[i, "city"] = rng.choice(variants[customers.loc[i, "city"]])

# status casing
bad_status = rng.choice(tickets.index, 60, replace=False)
tickets.loc[bad_status, "status"] = tickets.loc[bad_status, "status"].str.upper()

# ---------- save ----------
customers.to_csv(f"{OUT}/customers.csv", index=False)
technicians.to_csv(f"{OUT}/technicians.csv", index=False)
service_types.to_csv(f"{OUT}/service_types.csv", index=False)
calendar.to_csv(f"{OUT}/calendar.csv", index=False)
tickets.to_csv(f"{OUT}/service_requests.csv", index=False)

print("Files saved in", OUT)
print("service_requests rows:", len(tickets))