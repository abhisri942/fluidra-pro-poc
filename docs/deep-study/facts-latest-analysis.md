# Facts & Metrics — Latest Analysis

## All Objects Live in Snowflake

**Database:** `ANALYTICS_DB_DEV`

---

## FACTS Layer (4 Views)

| View | Rows | Grain | Source Events |
|------|:----:|-------|---------------|
| `FCT_PRO_BUSINESS_MASTER_EVENTS` | ~1,016 | 1 per business event | pro-business-master.* (all 6 types) |
| `FCT_PRO_CONTACT_MASTER_EVENTS` | ~2,723 | 1 per contact event | pro-contact-master.* (all 4 types) |
| `FCT_LEAD_FUNNEL` | ~610 | 1 per funnel stage transition | created + approved + rejected + failed |
| `FCT_RECONCILIATION` | 86 | 1 per reconciliation run | pro-reconcile.completed |

---

## MARTS Layer (7 Metric Views)

### METRIC_DEALER_ADOPTION (KPIs 1.1–1.5)

| KPI | Metric | Value |
|:---:|--------|:-----:|
| 1.1 | Active Dealers (login in 30d) | **8** |
| 1.2 | Enrolled Dealers (ACTIVE + rewards ACTIVE) | **26** |
| 1.3 | Dealers Not Setup (PENDING login) | **142** |
| 1.4 | Inactive Dealers (ACTIVE but no login 30d) | **85** |
| 1.5 | New Dealer Accounts Created | **200** |
| — | Total Dealers | **240** |

### METRIC_DEALER_CONVERSION (KPIs 2.1–2.4)

| KPI | Metric | Value |
|:---:|--------|:-----:|
| 2.1 | Guests Trackable | **41** |
| 2.1 | Leads Created | **159** |
| — | Leads Approved | **176** |
| — | Businesses Approved | **144** |
| 2.2 | Rejection Rate | **0.93%** |
| 2.3 | Avg Seconds to Approve | **~956K** (QA data includes old records) |
| — | Creation Failures | **87** |
| — | Total Funnel Events | **610** |

### METRIC_USER_ADOPTION (KPIs 3.1–3.7)

| KPI | Metric | Value |
|:---:|--------|:-----:|
| 3.1 | Total Active Users | **211** |
| 3.2 | New Technicians Created | **68** |
| 3.3 | Users Never Setup | **220** |
| 3.4 | Inactive Users | **82** |
| 3.6 | First Login Rate | **36.6%** |
| — | Total Contacts Created | **347** |
| — | Total Login-Created Events | **127** |

### METRIC_PROGRAM_ENROLLMENT

| Program | Active | Pending | Declined | Total | Activation Rate |
|---------|:------:|:-------:|:--------:|:-----:|:-:|
| FLATRATE SERVICEPRO | 10 | 57 | 4 | 73 | 13.7% |
| PROEDGE | 15 | 29 | 2 | 55 | 27.3% |
| BASE REWARDS | 10 | 23 | 3 | 39 | 25.6% |
| SERVICEPRO | 14 | 17 | 2 | 36 | 38.9% |
| RETAIL SELECT | 8 | 18 | 1 | 31 | 25.8% |
| RETAIL SELECT STAR | 2 | 0 | 0 | 2 | 100.0% |

### METRIC_CONTACT_ONBOARDING

| Contact Type | Created | Completed Login | Never Setup | Login Rate | Avg Min to Login |
|-------------|:-------:|:-:|:-:|:-:|:-:|
| OWNER | 205 | 69 | 136 | 33.7% | 4.8 min |
| TECHNICIAN | 68 | 19 | 49 | 27.9% | 4.8 min |
| CO-OWNER | 29 | 18 | 11 | 62.1% | 5.8 min |
| OFFICE ADMIN | 18 | 10 | 8 | 55.6% | 2.5 min |
| CSC | 16 | 9 | 7 | 56.3% | 1.1 min |
| OTHER | 15 | 6 | 9 | 40.0% | 6.0 min |

### METRIC_DISTRIBUTOR_COVERAGE (Top 10)

| Distributor | Active Dealers | Pending | Inactive | Total | Active Rate |
|------------|:-:|:-:|:-:|:-:|:-:|
| ALLIOWA POOLS | 11 | 20 | 4 | 35 | 31.4% |
| ALPHA WATER | 7 | 7 | 5 | 18 | 38.9% |
| POOLCORP | 7 | 1 | 2 | 10 | 70.0% |
| COVERPOOLS | 7 | 1 | 3 | 9 | 77.8% |
| Cinderella, Inc. | 1 | 6 | 1 | 8 | 12.5% |
| AQUA GON INC. | 3 | 4 | 1 | 7 | 42.9% |
| COVER POOLS INC | 0 | 3 | 3 | 5 | 0.0% |
| BLUE WATER PRODUCTS | 3 | 3 | 1 | 5 | 60.0% |
| AMERICAN POOL SUPPLY | 2 | 1 | 2 | 5 | 40.0% |
| BEL-AQUA POOL SUPPLY | 0 | 2 | 2 | 4 | 0.0% |

### METRIC_FUNNEL_DAILY (sample)

Daily funnel showing approvals, rejections, failures, and approval rate per day.

---

## Key Insights from Live Data

### 1. Onboarding is the #1 Problem
- **59% of dealers** (142/240) never completed login setup
- **63% of contacts** (220/347 created) never setup login
- Technicians have the worst rate: only **27.9%** complete login

### 2. Program Activation is Slow
- FLATRATE SERVICEPRO has 73 enrollments but only **13.7% activated**
- 57 dealers stuck in PENDING — potential revenue leak

### 3. Distributor Network Health Varies
- POOLCORP and COVERPOOLS have **70-78% active rates** (healthy)
- ALLIOWA POOLS has 35 dealers but only **31% active** (needs attention)
- COVER POOLS INC has **0% active** — all pending or inactive

### 4. Lead Funnel is Efficient
- Only **0.93% rejection rate** — almost all leads get approved
- **87 creation failures** (all duplicate email) — significant onboarding friction
- 41 GUEST registrations tracked — conversion funnel is measurable

---

## Complete Object Inventory

```
ANALYTICS_DB_DEV
├── INTERMEDIATE/ (10 staging views)
│   ├── STG_FPRO_QA_BUSINESSES (240)
│   ├── STG_FPRO_QA_BUSINESS_DISTRIBUTORS (292)
│   ├── STG_FPRO_QA_BUSINESS_PROGRAM_OPTINS (236)
│   ├── STG_FPRO_QA_BUSINESS_SUBSCRIPTIONS (16)
│   ├── STG_FPRO_QA_CONTACTS (482)
│   ├── STG_FPRO_QA_LEADS (178)
│   ├── STG_FPRO_QA_KEY_ACCOUNT_TYPES (12)
│   ├── STG_FPRO_QA_LOCATIONS (4)
│   ├── STG_FPRO_QA_RECONCILIATION (86)
│   └── STG_FPRO_QA_GUEST_TECHNICIANS (7)
│
├── DIMENSIONS/ (8 dimension views)
│   ├── DIM_PRO_BUSINESS_MASTER (240)
│   ├── DIM_CONTACT (485)
│   ├── DIM_LOCATION (236)
│   ├── DIM_KEY_ACCOUNT_TYPE (12)
│   ├── DIM_DISTRIBUTOR (292)
│   ├── DIM_PROGRAM_OPT_IN (236)
│   ├── DIM_SUBSCRIPTION (16)
│   └── BRIDGE_CONTACT_DEALER (249)
│
├── FACTS/ (4 fact views)
│   ├── FCT_PRO_BUSINESS_MASTER_EVENTS (~1,016)
│   ├── FCT_PRO_CONTACT_MASTER_EVENTS (~2,723)
│   ├── FCT_LEAD_FUNNEL (~610)
│   └── FCT_RECONCILIATION (86)
│
└── MARTS/ (7 metric views)
    ├── METRIC_DEALER_ADOPTION (KPI 1.1-1.5)
    ├── METRIC_DEALER_CONVERSION (KPI 2.1-2.4)
    ├── METRIC_USER_ADOPTION (KPI 3.1-3.7)
    ├── METRIC_FUNNEL_DAILY (daily breakdown)
    ├── METRIC_PROGRAM_ENROLLMENT (by program)
    ├── METRIC_DISTRIBUTOR_COVERAGE (by distributor)
    └── METRIC_CONTACT_ONBOARDING (by contact type)
```

**Total: 29 Snowflake views** covering all 18 event types and computing 16 of 20 KPIs.

---

## Snowflake DDL — Fact Views

### FCT_PRO_BUSINESS_MASTER_EVENTS

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB_DEV.FACTS.FCT_PRO_BUSINESS_MASTER_EVENTS AS
WITH source AS (
    SELECT PARSE_JSON(RECORD_METADATA) AS metadata_json, PARSE_JSON(RECORD_CONTENT) AS payload
    FROM RAW_DB_PROD.FLUIDRAPRO_RAW.FPRO_QA
    WHERE RECORD_METADATA != 'RECORD_METADATA'
      AND PARSE_JSON(RECORD_CONTENT):"detail-type"::STRING LIKE '%pro-business-master%'
),
parsed AS (
    SELECT
        payload:id::STRING AS event_id,
        payload:"detail-type"::STRING AS event_detail_type,
        payload:time::TIMESTAMP_NTZ AS event_time,
        payload:time::DATE AS event_date,
        metadata_json:offset::NUMBER AS kafka_offset,
        payload:detail.data.proBusinessId::STRING AS pro_business_id,
        payload:detail.data.status::STRING AS business_status,
        payload:detail.data.loginStatus::STRING AS login_status,
        payload:detail.data.source::STRING AS source,
        COALESCE(ARRAY_SIZE(payload:detail.data.distributors), 0) AS distributor_count,
        COALESCE(ARRAY_SIZE(payload:detail.data.programOptIns), 0) AS program_opt_in_count,
        CASE WHEN payload:detail.metadata.eventType::STRING = 'created' THEN 1 ELSE 0 END AS is_created_event,
        CASE WHEN payload:detail.metadata.eventType::STRING = 'approved' THEN 1 ELSE 0 END AS is_approved_event,
        CASE WHEN payload:detail.metadata.eventType::STRING = 'rejected' THEN 1 ELSE 0 END AS is_rejected_event,
        CASE WHEN payload:"detail-type"::STRING LIKE '%creation-failed%' THEN 1 ELSE 0 END AS is_creation_failed,
        payload:detail.data.utm.utm_source::STRING AS utm_source,
        payload:detail.data.utm.utm_campaign::STRING AS utm_campaign,
        payload:detail.data.reason::STRING AS failure_reason
    FROM source
)
SELECT * FROM parsed
QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY kafka_offset DESC) = 1;
```

### FCT_PRO_CONTACT_MASTER_EVENTS

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB_DEV.FACTS.FCT_PRO_CONTACT_MASTER_EVENTS AS
WITH source AS (
    SELECT PARSE_JSON(RECORD_METADATA) AS metadata_json, PARSE_JSON(RECORD_CONTENT) AS payload
    FROM RAW_DB_PROD.FLUIDRAPRO_RAW.FPRO_QA
    WHERE RECORD_METADATA != 'RECORD_METADATA'
      AND PARSE_JSON(RECORD_CONTENT):"detail-type"::STRING LIKE '%pro-contact-master%'
),
parsed AS (
    SELECT
        payload:id::STRING AS event_id,
        payload:"detail-type"::STRING AS event_detail_type,
        payload:time::TIMESTAMP_NTZ AS event_time,
        payload:time::DATE AS event_date,
        metadata_json:offset::NUMBER AS kafka_offset,
        payload:detail.data.proContactId::STRING AS pro_contact_id,
        payload:detail.data.proBusinessId::STRING AS pro_business_id,
        payload:detail.data.contactType::STRING AS contact_type,
        payload:detail.data.loginStatus::STRING AS login_status,
        CASE WHEN payload:"detail-type"::STRING LIKE '%created.v1' THEN 1 ELSE 0 END AS is_created_event,
        CASE WHEN payload:"detail-type"::STRING LIKE '%login-created%' THEN 1 ELSE 0 END AS is_login_created_event,
        CASE WHEN payload:"detail-type"::STRING LIKE '%deleted%' THEN 1 ELSE 0 END AS is_deleted_event
    FROM source WHERE payload:detail.data.proContactId IS NOT NULL
)
SELECT * FROM parsed
QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY kafka_offset DESC) = 1;
```

### FCT_LEAD_FUNNEL

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB_DEV.FACTS.FCT_LEAD_FUNNEL AS
WITH source AS (
    SELECT PARSE_JSON(RECORD_METADATA) AS metadata_json, PARSE_JSON(RECORD_CONTENT) AS payload
    FROM RAW_DB_PROD.FLUIDRAPRO_RAW.FPRO_QA
    WHERE RECORD_METADATA != 'RECORD_METADATA'
      AND PARSE_JSON(RECORD_CONTENT):"detail-type"::STRING IN (
          'fluidrapro.pro-business-master.created.v1',
          'fluidrapro.pro-business-master.approved.v1',
          'fluidrapro.pro-business-master.rejected.v1',
          'fluidrapro.pro-business-master.creation-failed.v1',
          'fluidrapro.pro-business-lead.approved.v1',
          'fluidrapro.pro-business-lead.rejected.v1')
),
parsed AS (
    SELECT
        payload:id::STRING AS event_id,
        payload:time::TIMESTAMP_NTZ AS event_time,
        payload:time::DATE AS event_date,
        metadata_json:offset::NUMBER AS kafka_offset,
        payload:detail.data.proBusinessId::STRING AS pro_business_id,
        payload:detail.data.crmLeadId::STRING AS crm_lead_id,
        payload:detail.data.salesRep.name::STRING AS sales_rep_name,
        CASE
            WHEN payload:"detail-type"::STRING LIKE '%created%' AND payload:detail.data.status::STRING = 'GUEST' THEN 'GUEST'
            WHEN payload:"detail-type"::STRING LIKE '%created%' AND payload:detail.data.status::STRING = 'LEAD' THEN 'LEAD_CREATED'
            WHEN payload:"detail-type"::STRING = 'fluidrapro.pro-business-lead.approved.v1' THEN 'LEAD_APPROVED'
            WHEN payload:"detail-type"::STRING = 'fluidrapro.pro-business-master.approved.v1' THEN 'BUSINESS_APPROVED'
            WHEN payload:"detail-type"::STRING LIKE '%rejected%' THEN 'REJECTED'
            WHEN payload:"detail-type"::STRING LIKE '%creation-failed%' THEN 'CREATION_FAILED'
            ELSE 'OTHER'
        END AS funnel_stage,
        DATEDIFF('second', TRY_TO_TIMESTAMP_NTZ(payload:detail.data.auditInfo.createdAt::STRING), payload:time::TIMESTAMP_NTZ) AS seconds_in_stage,
        payload:detail.data.reason::STRING AS failure_reason
    FROM source
)
SELECT * FROM parsed
QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY kafka_offset DESC) = 1;
```

### FCT_RECONCILIATION

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB_DEV.FACTS.FCT_RECONCILIATION AS
SELECT event_id, event_time, event_time::DATE AS event_date, run_id, entity,
    dq_structural_version, gatekeeper_policy_version, mastering_rules_version
FROM ANALYTICS_DB_DEV.INTERMEDIATE.STG_FPRO_QA_RECONCILIATION;
```

---

## Snowflake DDL — Metric Views (MARTS)

### METRIC_DEALER_ADOPTION

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB_DEV.MARTS.METRIC_DEALER_ADOPTION AS
SELECT
    COUNT(DISTINCT CASE WHEN login_status='ACTIVE' AND primary_contact_last_login >= DATEADD('day',-30,CURRENT_TIMESTAMP()) THEN pro_business_id END) AS kpi_1_1_active_dealers_30d,
    COUNT(DISTINCT CASE WHEN business_status='ACTIVE' AND rewards_program_status='ACTIVE' THEN pro_business_id END) AS kpi_1_2_enrolled_dealers,
    COUNT(DISTINCT CASE WHEN login_status='PENDING' THEN pro_business_id END) AS kpi_1_3_dealers_not_setup,
    COUNT(DISTINCT CASE WHEN login_status='ACTIVE' AND (primary_contact_last_login < DATEADD('day',-30,CURRENT_TIMESTAMP()) OR primary_contact_last_login IS NULL) THEN pro_business_id END) AS kpi_1_4_inactive_dealers,
    (SELECT COUNT(*) FROM ANALYTICS_DB_DEV.FACTS.FCT_PRO_BUSINESS_MASTER_EVENTS WHERE is_created_event=1) AS kpi_1_5_new_dealers_created,
    COUNT(DISTINCT pro_business_id) AS total_dealers
FROM ANALYTICS_DB_DEV.DIMENSIONS.DIM_PRO_BUSINESS_MASTER;
```

### METRIC_DEALER_CONVERSION

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB_DEV.MARTS.METRIC_DEALER_CONVERSION AS
SELECT
    COUNT(CASE WHEN funnel_stage='GUEST' THEN 1 END) AS guests,
    COUNT(CASE WHEN funnel_stage='LEAD_APPROVED' THEN 1 END) AS leads_approved,
    COUNT(CASE WHEN funnel_stage IN ('LEAD_REJECTED','BUSINESS_REJECTED','REJECTED') THEN 1 END) AS total_rejected,
    COUNT(CASE WHEN funnel_stage='CREATION_FAILED' THEN 1 END) AS creation_failures,
    ROUND(COUNT(CASE WHEN funnel_stage IN ('LEAD_REJECTED','BUSINESS_REJECTED','REJECTED') THEN 1 END)::FLOAT /
        NULLIF(COUNT(CASE WHEN funnel_stage NOT IN ('GUEST','LEAD_CREATED','BUSINESS_CREATED','CREATION_FAILED','OTHER') THEN 1 END),0)*100,2) AS kpi_2_2_rejection_rate_pct,
    ROUND(AVG(CASE WHEN funnel_stage IN ('LEAD_APPROVED','BUSINESS_APPROVED') THEN seconds_in_stage END),1) AS kpi_2_3_avg_seconds_to_approve
FROM ANALYTICS_DB_DEV.FACTS.FCT_LEAD_FUNNEL;
```

### METRIC_USER_ADOPTION

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB_DEV.MARTS.METRIC_USER_ADOPTION AS
WITH created AS (SELECT DISTINCT pro_contact_id FROM ANALYTICS_DB_DEV.FACTS.FCT_PRO_CONTACT_MASTER_EVENTS WHERE is_created_event=1),
login_created AS (SELECT DISTINCT pro_contact_id FROM ANALYTICS_DB_DEV.FACTS.FCT_PRO_CONTACT_MASTER_EVENTS WHERE is_login_created_event=1)
SELECT
    (SELECT COUNT(*) FROM ANALYTICS_DB_DEV.DIMENSIONS.DIM_CONTACT WHERE login_status='ACTIVE') AS kpi_3_1_total_active_users,
    (SELECT COUNT(DISTINCT pro_contact_id) FROM ANALYTICS_DB_DEV.FACTS.FCT_PRO_CONTACT_MASTER_EVENTS WHERE is_created_event=1 AND contact_type='TECHNICIAN') AS kpi_3_2_new_technicians,
    (SELECT COUNT(*) FROM created WHERE pro_contact_id NOT IN (SELECT pro_contact_id FROM login_created)) AS kpi_3_3_users_never_setup,
    ROUND((SELECT COUNT(*) FROM login_created)::FLOAT / NULLIF((SELECT COUNT(*) FROM created),0)*100,1) AS kpi_3_6_first_login_rate_pct;
```

### METRIC_FUNNEL_DAILY

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB_DEV.MARTS.METRIC_FUNNEL_DAILY AS
SELECT event_date,
    COUNT(CASE WHEN funnel_stage IN ('LEAD_APPROVED','BUSINESS_APPROVED') THEN 1 END) AS approved,
    COUNT(CASE WHEN funnel_stage IN ('LEAD_REJECTED','BUSINESS_REJECTED','REJECTED') THEN 1 END) AS rejected,
    COUNT(CASE WHEN funnel_stage='CREATION_FAILED' THEN 1 END) AS failures,
    ROUND(COUNT(CASE WHEN funnel_stage IN ('LEAD_APPROVED','BUSINESS_APPROVED') THEN 1 END)::FLOAT /
        NULLIF(COUNT(CASE WHEN funnel_stage NOT IN ('GUEST','LEAD_CREATED','BUSINESS_CREATED','CREATION_FAILED','OTHER') THEN 1 END),0)*100,1) AS approval_rate_pct
FROM ANALYTICS_DB_DEV.FACTS.FCT_LEAD_FUNNEL GROUP BY event_date ORDER BY event_date;
```

### METRIC_PROGRAM_ENROLLMENT / METRIC_DISTRIBUTOR_COVERAGE / METRIC_CONTACT_ONBOARDING

```sql
-- METRIC_PROGRAM_ENROLLMENT
CREATE OR REPLACE VIEW ANALYTICS_DB_DEV.MARTS.METRIC_PROGRAM_ENROLLMENT AS
SELECT program_name,
    COUNT(DISTINCT CASE WHEN program_status='ACTIVE' THEN pro_business_id END) AS active_count,
    COUNT(DISTINCT CASE WHEN program_status='PENDING' THEN pro_business_id END) AS pending_count,
    COUNT(DISTINCT pro_business_id) AS total_enrolled,
    ROUND(COUNT(DISTINCT CASE WHEN program_status='ACTIVE' THEN pro_business_id END)::FLOAT / NULLIF(COUNT(DISTINCT pro_business_id),0)*100,1) AS activation_rate_pct
FROM ANALYTICS_DB_DEV.DIMENSIONS.DIM_PROGRAM_OPT_IN GROUP BY program_name ORDER BY total_enrolled DESC;

-- METRIC_DISTRIBUTOR_COVERAGE
CREATE OR REPLACE VIEW ANALYTICS_DB_DEV.MARTS.METRIC_DISTRIBUTOR_COVERAGE AS
SELECT distributor_name,
    COUNT(DISTINCT CASE WHEN distributor_account_status='ACTIVE' THEN pro_business_id END) AS active_dealers,
    COUNT(DISTINCT pro_business_id) AS total_dealers,
    ROUND(COUNT(DISTINCT CASE WHEN distributor_account_status='ACTIVE' THEN pro_business_id END)::FLOAT / NULLIF(COUNT(DISTINCT pro_business_id),0)*100,1) AS active_rate_pct
FROM ANALYTICS_DB_DEV.DIMENSIONS.DIM_DISTRIBUTOR GROUP BY distributor_name ORDER BY total_dealers DESC;

-- METRIC_CONTACT_ONBOARDING
CREATE OR REPLACE VIEW ANALYTICS_DB_DEV.MARTS.METRIC_CONTACT_ONBOARDING AS
WITH created AS (SELECT pro_contact_id, contact_type, MIN(event_time) AS t FROM ANALYTICS_DB_DEV.FACTS.FCT_PRO_CONTACT_MASTER_EVENTS WHERE is_created_event=1 GROUP BY 1,2),
login AS (SELECT pro_contact_id, MIN(event_time) AS t FROM ANALYTICS_DB_DEV.FACTS.FCT_PRO_CONTACT_MASTER_EVENTS WHERE is_login_created_event=1 GROUP BY 1)
SELECT c.contact_type,
    COUNT(DISTINCT c.pro_contact_id) AS total_created,
    COUNT(DISTINCT l.pro_contact_id) AS completed_login,
    ROUND(COUNT(DISTINCT l.pro_contact_id)::FLOAT / NULLIF(COUNT(DISTINCT c.pro_contact_id),0)*100,1) AS first_login_rate_pct,
    ROUND(AVG(DATEDIFF('minute', c.t, l.t)),1) AS avg_minutes_to_login
FROM created c LEFT JOIN login l ON c.pro_contact_id=l.pro_contact_id
GROUP BY c.contact_type ORDER BY total_created DESC;
```

---

## dbt Model Files (Facts & Marts)

| Path | Materialization |
|------|:-:|
| `facts/FCT_PRO_BUSINESS_MASTER_EVENTS.sql` | view |
| `facts/FCT_PRO_CONTACT_MASTER_EVENTS.sql` | view |
| `facts/fct_lead_funnel.sql` | view |
| `facts/fct_reconciliation.sql` | view |
| `marts/metric_dealer_adoption.sql` | view |
| `marts/metric_dealer_conversion.sql` | view |
| `marts/metric_user_adoption.sql` | view |
| `marts/metric_funnel_daily.sql` | view |
| `marts/metric_program_enrollment.sql` | view |
| `marts/metric_distributor_coverage.sql` | view |
| `marts/metric_contact_onboarding.sql` | view |
