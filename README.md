# Sentinel AML — hackathon prototype

Spring Boot 3 / Java 17 transaction-monitoring API for MeridianTrust. It ingests KYC, accounts and transactions, evaluates rules synchronously, produces risk-scored de-duplicated alerts, and records immutable case/alert audit events.

## Run

1. Set the credentials in your shell (see `.env.example`). PowerShell: `$env:SENTINEL_API_USERNAME='analyst'; $env:SENTINEL_API_PASSWORD='your-password'`.
2. Run `mvn spring-boot:run` (or import as a Maven project in IntelliJ).
3. Open `http://localhost:8080/swagger-ui.html`; use HTTP Basic credentials from step 1.

It starts on H2 for a zero-setup demo. For PostgreSQL set `DATABASE_URL`, `DATABASE_USERNAME`, and `DATABASE_PASSWORD`; `src/main/resources/db/migration/V1__sentinel_schema.sql` is the documented initial schema.

## Demo flow
Main API flow
1. Create customer → POST /api/v1/customers
   {
   "externalId": "CUST-1002",
   "fullName": "Priya Sharma",
   "kycRisk": "HIGH",
   "country": "IN"
   }
2. Create account → POST /api/v1/accounts
   {
   "accountNumber": "IN-ACC-1002",
   "customerExternalId": "CUST-1002",
   "type": "CURRENT",
   "currency": "INR",
   "riskRating": "HIGH"
   }
3. Ingest a transaction → POST /api/v1/transactions
   {
   "externalId": "TXN-10001",
   "accountNumber": "IN-ACC-1002",
   "amount": 15000,
   "currency": "INR",
   "direction": "CREDIT",
   "counterparty": "Example Trading Pvt Ltd",
   "jurisdiction": "IN",
   "channel": "NEFT",
   "timestamp": "2026-09-19T10:00:00Z"
   }
   This returns 202 Accepted and evaluates all enabled AML rules immediately.
   Alert APIs
   GET /api/v1/alerts
   Shows the prioritized analyst queue. Customer name and account number are masked.
   GET /api/v1/alerts/{id}
   Shows full alert evidence and explanation.
   PATCH /api/v1/alerts/{id}/disposition
   Closes/escalates an alert while preserving audit history.
   {
   "status": "CLEARED",
   "reason": "Analyst verified legitimate salary payment."
   }
   Supported statuses: OPEN, IN_REVIEW, CLEARED, ESCALATED.
   POST /api/v1/alerts/{id}/cases
   Creates an investigation case from an alert.
   Rule configuration APIs
   GET /api/v1/rules
   Lists rule settings.
   PUT /api/v1/rules/{code}
   Updates a rule without redeploying. Requires the ADMIN role.
   {
   "enabled": true,
   "threshold": 10000,
   "windowHours": 24,
   "score": 90
   }
   Rule codes:
- CTR — transaction of INR 10,000+
- STRUCTURING — 3+ INR 9,000–9,999 transactions in 24 hours
- RAPID_MOVEMENT — 80%+ funds moved out within 48 hours
- HIGH_RISK — configured high-risk jurisdiction (IR, KP, SY, AF)
- BEHAVIOR — daily activity above 3× historical baseline
  GET /api/v1/fx-rates
  Lists configured currency-to-INR normalization rates.
  Quick Swagger demo: structuring
  The seeded account is IN-DEMO-1001. Submit these three transaction payloads within the same day, changing externalId each time:
  {
  "externalId": "STRUCT-DEMO-1",
  "accountNumber": "IN-DEMO-1001",
  "amount": 9500,
  "currency": "INR",
  "direction": "CREDIT",
  "counterparty": "Walk-in Cash Deposit",
  "jurisdiction": "IN",
  "channel": "BRANCH",
  "timestamp": "2026-09-19T09:00:00Z"
  }
  Use STRUCT-DEMO-2 at 10:00:00Z, then STRUCT-DEMO-3 at 11:00:00Z. Finally call GET /api/v1/alerts; the queue will contain a STRUCTURING alert with the transaction IDs in its evidence.
The application seeds `CUST-DEMO-001` and account `IN-DEMO-1001`. POST three INR 9,500 credits during the same 24 hours to `/api/v1/transactions`; the third creates a **STRUCTURING** alert. Post an INR 10,000+ transaction for **CTR**, a debit at least 80% of recent credits for **RAPID_MOVEMENT**, or a transaction whose jurisdiction is `IR`, `KP`, `SY`, or `AF` for **HIGH_RISK**. Then GET `/api/v1/alerts`, POST `/api/v1/alerts/{id}/cases`, and PATCH `/api/v1/alerts/{id}/disposition` with `{"status":"CLEARED","reason":"review complete"}`.

## Architecture / safeguards

`controller → SentinelService → Spring Data JPA` keeps detection in one transactional write path, making transaction ingestion and alert de-duplication atomic (unique `(account, rule, dedupeKey)`). Rules and INR FX rates live in DB tables and are adjustable through `/api/v1/rules` (ADMIN). List views mask PII/account numbers; full alert detail requires authenticated access. API errors use a stable JSON envelope, validation is Bean Validation-based, and alert/case transitions append `audit_events` rather than deleting history.

Rules shipped: CTR threshold, 24-hour structuring, 48-hour rapid movement, high-risk jurisdiction, and 90-day behavioral deviation. Default scores are configurable and alerts are sorted by risk score.

## ERD

`Customer 1—* Account 1—* Transaction`; `Account 1—* Alert`; `Customer 1—* Case`; `Alert/Case 1—* AuditEvent`. Supporting tables: `rule_configs`, `exchange_rates`.
