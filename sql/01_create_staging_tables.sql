CREATE DATABASE IF NOT EXISTS servicemaster;
USE servicemaster;

CREATE TABLE stg_customers (
    customer_id     VARCHAR(50),
    customer_name   VARCHAR(100),
    city            VARCHAR(50),
    segment         VARCHAR(50)
);

CREATE TABLE stg_technicians (
    technician_id   VARCHAR(50),
    technician_name VARCHAR(100),
    city            VARCHAR(50),
    team            VARCHAR(50),
    hire_date       VARCHAR(50)
);

CREATE TABLE stg_service_types (
    service_type_id VARCHAR(50),
    category        VARCHAR(50),
    sla_hours       VARCHAR(50)
);

CREATE TABLE stg_calendar (
    `date`          VARCHAR(50),
    year            VARCHAR(10),
    quarter         VARCHAR(10),
    month           VARCHAR(10),
    month_name      VARCHAR(10),
    weekday         VARCHAR(10)
);

CREATE TABLE stg_service_requests (
    ticket_id       VARCHAR(50),
    customer_id     VARCHAR(50),
    technician_id   VARCHAR(50),
    service_type_id VARCHAR(50),
    created_date    VARCHAR(50),
    priority        VARCHAR(20),
    assigned_date   VARCHAR(50),
    closed_date     VARCHAR(50),
    status          VARCHAR(20),
    visit_count     VARCHAR(10),
    cost            VARCHAR(20),
    csat_score      VARCHAR(10)
);


