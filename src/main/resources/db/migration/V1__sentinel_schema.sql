-- Production PostgreSQL migration reference. Hibernate creates the hackathon H2 schema.
CREATE TABLE IF NOT EXISTS exchange_rates (currency varchar(3) primary key, inr_rate numeric(19,4) not null);
CREATE TABLE IF NOT EXISTS rule_configs (code varchar(40) primary key, enabled boolean not null, threshold numeric(19,2), window_hours integer, score integer);
CREATE TABLE IF NOT EXISTS customers (id bigserial primary key, external_id varchar(80) unique not null, full_name varchar(200), kyc_risk varchar(20), country varchar(3));
CREATE TABLE IF NOT EXISTS accounts (id bigserial primary key, account_number varchar(80) unique not null, customer_id bigint references customers(id), type varchar(30), currency varchar(3), opened_on date, risk_rating varchar(20));
CREATE TABLE IF NOT EXISTS transactions (id bigserial primary key, external_id varchar(80) unique not null, account_id bigint references accounts(id), direction varchar(10), amount numeric(19,2), normalized_amount numeric(19,2), currency varchar(3), counterparty varchar(200), jurisdiction varchar(3), channel varchar(30), timestamp timestamptz);
CREATE INDEX IF NOT EXISTS idx_tx_account_time ON transactions(account_id,timestamp);
CREATE TABLE IF NOT EXISTS alerts (id bigserial primary key, account_id bigint not null references accounts(id), rule_code varchar(40), dedupe_key varchar(100), risk_score integer, status varchar(20), explanation varchar(4000), evidence varchar(4000), created_at timestamptz, disposition_reason varchar(1000), disposition_by varchar(100));
CREATE UNIQUE INDEX IF NOT EXISTS uk_alert_dedupe ON alerts(account_id,rule_code,dedupe_key);
CREATE TABLE IF NOT EXISTS cases (id bigserial primary key, customer_id bigint not null references customers(id), title varchar(300), status varchar(20), owner varchar(100), created_at timestamptz);
CREATE TABLE IF NOT EXISTS audit_events (id bigserial primary key, entity_type varchar(30), entity_id bigint, action varchar(40), actor varchar(100), occurred_at timestamptz, detail varchar(2000));
