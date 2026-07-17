# Architecture & Data Model — Fluidra Pro Analytics Platform

## 1. End-to-End Data Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SOURCE SYSTEMS                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ Pro Platform │  │  Salesforce  │  │  Oracle ERP  │  │   Loyalty    │    │
│  │    (AWS)     │  │    (CRM)     │  │  (Finance)   │  │     2.0      │    │
│  │              │  │              │  │              │  │              │    │
│  │ • Business   │  │ • Leads      │  │ • Accounts   │  │ • Rewards    │    │
│  │ • Contact    │  │ • Accounts   │  │ • Revenue    │  │ • Points     │    │
│  │ • Location   │  │ • Contacts   │  │ • Regions    │  │ • Tiers      │    │
│  │ • Lead       │  │ • Oppty      │  │ • Dealers    │  │              │    │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │
│         │                  │                  │                  │            │
└─────────┼──────────────────┼──────────────────┼──────────────────┼────────────┘
          │                  │                  │                  │
          ▼                  ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TRANSPORT LAYER                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  EventBus → Kafka     Batch CSV Export    Batch CSV Export    API Extract    │
│  (Real-time CDC)      (Daily)             (Daily)            (Daily)        │
│         │                  │                  │                  │            │
│         ▼                  ▼                  ▼                  ▼            │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │              S3 Data Lake: s3://fluidra-data-lake/raw/              │    │
│  │  /fluidrapro/*.json  /salesforce/*.csv  /oracle/*.csv  /revenue/   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │ S3 SQS Notifications
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SNOWFLAKE DATA PLATFORM                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  RAW_DB_PROD (Snowpipe Auto-Ingest)                                 │    │
│  │  ┌─────────────┐ ┌──────────────┐ ┌───────────┐ ┌────────────┐     │    │
│  │  │FLUIDRAPRO_  │ │SALESFORCE_   │ │ORACLE_RAW │ │REVENUE_RAW │     │    │
│  │  │RAW          │ │RAW           │ │           │ │            │     │    │
│  │  │RAW_DEALERS_ │ │RAW_LEADS     │ │RAW_DEALER_│ │RAW_REVENUE_│     │    │
│  │  │DATA         │ │RAW_ACCOUNTS  │ │MASTER     │ │TRANSACTIONS│     │    │
│  │  │(JSON)       │ │RAW_CONTACTS  │ │RAW_SALES_ │ │(CSV)       │     │    │
│  │  │             │ │(CSV)         │ │REGIONS    │ │            │     │    │
│  │  └──────┬──────┘ └──────┬───────┘ └─────┬─────┘ └─────┬──────┘     │    │
│  └─────────┼───────────────┼───────────────┼─────────────┼────────────┘    │
│            │ Streams       │               │             │                  │
│            ▼               ▼               ▼             ▼                  │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  STAGING_DB_PROD.STAGING (dbt views — parse, cast, dedup)           │    │
│  │                                                                     │    │
│  │  stg_fluidrapro_businesses  ┃  stg_salesforce_leads                 │    │
│  │  stg_fluidrapro_contacts    ┃  stg_salesforce_accounts              │    │
│  │  stg_fluidrapro_locations   ┃  stg_salesforce_contacts              │    │
│  │  stg_fluidrapro_leads       ┃  stg_oracle_dealers                   │    │
│  │  stg_fluidrapro_reconcile   ┃  stg_revenue_transactions             │    │
│  └──────────────────────────────┬──────────────────────────────────────┘    │
│                                 │                                            │
│                                 ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  ANALYTICS_DB_PROD                                                  │    │
│  │                                                                     │    │
│  │  INTERMEDIATE          │ DIMENSIONS        │ FACTS                  │    │
│  │  ─────────────         │ ──────────        │ ─────                  │    │
│  │  int_business_         │ dim_dealer        │ FCT_PRO_BUSINESS_MASTER_EVENTS      │    │
│  │    reconciled          │ dim_contact       │ fct_lead_funnel        │    │
│  │  int_contact_          │ dim_location      │ fct_login_activity     │    │
│  │    enriched            │ dim_program       │ fct_revenue            │    │
│  │  int_lead_funnel       │ dim_distributor   │                        │    │
│  │  int_login_activity    │ dim_date          │ MARTS                  │    │
│  │                        │ dim_region        │ ─────                  │    │
│  │                        │                   │ mart_dealer_adoption   │    │
│  │                        │                   │ mart_user_adoption     │    │
│  │                        │                   │ mart_dealer_conversion │    │
│  │                        │                   │ mart_revenue           │    │
│  │                        │                   │ mart_engagement        │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                 │                                            │
│                                 ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  REPORTING (Pre-joined views for BI consumption)                    │    │
│  │  rpt_dealer_health_dashboard                                        │    │
│  │  rpt_program_adoption_metrics                                       │    │
│  │  rpt_conversion_funnel                                              │    │
│  │  rpt_revenue_by_dealer                                              │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CONSUMPTION LAYER                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                       │
│  │  Snowsight   │  │  Power BI    │  │   Tableau    │                       │
│  │  (Dashboards)│  │  (Reports)   │  │  (Analytics) │                       │
│  └──────────────┘  └──────────────┘  └──────────────┘                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Dimensional Data Model (Star Schema)

### 2.1 Core Star Schema

```
                        ┌──────────────────┐
                        │   dim_program    │
                        │────────────────  │
                        │ program_key (PK) │
                        │ program_level    │
                        │ achiever_level   │
                        │ program_status   │
                        │ region           │
                        │ signup_date      │
                        └────────┬─────────┘
                                 │
┌──────────────────┐    ┌────────┴─────────────────────┐    ┌──────────────────┐
│  dim_distributor │    │      FCT_PRO_BUSINESS_MASTER_EVENTS       │    │   dim_location   │
│────────────────  │    │──────────────────────────────│    │────────────────  │
│ distributor_key  │◄───│ event_key (PK)               │───►│ location_key(PK) │
│ distributor_name │    │ dealer_key (FK)               │    │ pro_location_id  │
│ account_number   │    │ contact_key (FK)              │    │ city             │
│ status           │    │ location_key (FK)             │    │ state            │
└──────────────────┘    │ program_key (FK)              │    │ zip              │
                        │ distributor_key (FK)          │    │ country          │
┌──────────────────┐    │ date_key (FK)                 │    │ location_type    │
│   dim_dealer     │    │────────────────────────────── │    │ location_status  │
│────────────────  │    │ event_type                    │    └──────────────────┘
│ dealer_key (PK)  │◄───│ business_status               │
│ pro_business_id  │    │ login_status                  │    ┌──────────────────┐
│ business_name    │    │ is_new_business               │    │   dim_contact    │
│ doing_business_as│    │ is_login_created              │    │────────────────  │
│ status           │    │ is_approval                   │    │ contact_key (PK) │
│ primary_biz_type │    │ days_since_last_login         │───►│ pro_contact_id   │
│ secondary_types  │    │ source_system                 │    │ first_name       │
│ customer_class   │    │ correlation_id                │    │ last_name        │
│ sales_channel    │    └──────────────────────────────┘    │ email            │
│ business_segment │                                        │ contact_type     │
│ customer_type    │    ┌──────────────────────────────┐    │ login_status     │
│ key_account_flag │    │      fct_lead_funnel         │    │ username         │
│ key_account_type │    │──────────────────────────────│    └──────────────────┘
│ key_account_role │    │ funnel_key (PK)              │
│ is_tse_violator  │    │ dealer_key (FK)              │    ┌──────────────────┐
│ fluidra_acct_num │    │ date_key (FK)                │    │    dim_date      │
│ lead_source      │    │──────────────────────────────│    │────────────────  │
│ crm_lead_id      │    │ lead_submitted_at            │    │ date_key (PK)    │
│ crm_account_id   │    │ lead_approved_at             │◄───│ full_date        │
│ created_at       │    │ rewards_activated_at          │    │ year             │
│ updated_at       │    │ first_login_at               │    │ quarter          │
└──────────────────┘    │ time_to_approve_hours        │    │ month            │
                        │ time_to_activate_hours        │    │ week             │
                        │ time_to_first_login_hours    │    │ day_of_week      │
                        │ is_approved                   │    │ is_weekend       │
                        │ is_rejected                   │    └──────────────────┘
                        │ rejection_reason              │
                        └──────────────────────────────┘

                        ┌──────────────────────────────┐
                        │      fct_revenue             │
                        │──────────────────────────────│
                        │ revenue_key (PK)             │
                        │ dealer_key (FK)              │
                        │ date_key (FK)                │
                        │──────────────────────────────│
                        │ revenue_amount               │
                        │ product_category             │
                        │ transaction_count            │
                        │ is_post_platform             │
                        └──────────────────────────────┘
```

---

## 3. dbt Model Lineage (DAG)

```
RAW_DEALERS_DATA
    │
    ├──► stg_fluidrapro_businesses ──┐
    │                                 ├──► int_business_reconciled ──► dim_dealer
    ├──► stg_fluidrapro_contacts ────┤                                    │
    │                                 ├──► int_contact_enriched ──► dim_contact
    ├──► stg_fluidrapro_locations ───┤                                    │
    │                                 └──► int_lead_funnel ──► fct_lead_funnel
    ├──► stg_fluidrapro_leads ───────┘            │
    │                                              ▼
    └──► stg_fluidrapro_reconcile           FCT_PRO_BUSINESS_MASTER_EVENTS
                                                   │
RAW_LEADS ──► stg_salesforce_leads ────────────────┤
RAW_ACCOUNTS ──► stg_salesforce_accounts ──────────┤
                                                   ▼
RAW_DEALER_MASTER ──► stg_oracle_dealers ──► int_business_reconciled
RAW_SALES_REGIONS ──► stg_oracle_regions ──► dim_region
                                                   │
RAW_REVENUE ──► stg_revenue_transactions ──► fct_revenue
                                                   │
                                                   ▼
                                        ┌─── MARTS ───┐
                                        │             │
                            mart_dealer_adoption    mart_revenue
                            mart_user_adoption     mart_engagement
                            mart_dealer_conversion
                                        │
                                        ▼
                                 REPORTING VIEWS
                            rpt_dealer_health_dashboard
                            rpt_program_adoption_metrics
```

---

## 4. RBAC & Security Model

```
ACCOUNTADMIN
├── SECURITYADMIN
└── SYSADMIN
    ├── DATA_ENGINEER_ROLE ──── RAW_DB (ALL), GOVERNANCE_DB (ALL)
    │   ├── DBT_DEV_ROLE ───── STAGING_DB_DEV (ALL), ANALYTICS_DB_DEV (ALL)
    │   ├── DBT_TEST_ROLE ──── STAGING_DB_TEST (ALL), ANALYTICS_DB_TEST (ALL)
    │   └── DBT_PROD_ROLE ──── STAGING_DB_PROD (ALL), ANALYTICS_DB_PROD (ALL)
    └── BI_ROLE ────────────── ANALYTICS_DB_PROD.MARTS (SELECT), .REPORTING (SELECT)
        └── ANALYST_ROLE ───── ANALYTICS_DB_PROD.* (SELECT), STAGING_DB_PROD (SELECT)
```

---

## 5. Warehouse Strategy

| Warehouse | Size | Purpose | Roles |
|-----------|------|---------|-------|
| WH_INGEST | X-SMALL | Snowpipe loads | DATA_ENGINEER_ROLE |
| WH_DBT_DEV | SMALL | dbt dev runs | DBT_DEV_ROLE |
| WH_DBT_TEST | SMALL | dbt test runs | DBT_TEST_ROLE |
| WH_DBT_PROD | MEDIUM | dbt prod scheduled | DBT_PROD_ROLE |
| WH_BI | MEDIUM | Dashboard queries | BI_ROLE, ANALYST_ROLE |
| WH_ADHOC | SMALL | Ad-hoc analysis | ANALYST_ROLE |

---

## 6. Data Flow Timing

| Layer | Latency | Trigger |
|-------|---------|---------|
| Platform → S3 | ~seconds | Kafka CDC (real-time) |
| S3 → RAW (Snowpipe) | ~1 minute | S3 SQS notification |
| RAW → Staging | Real-time (views) | On query |
| Staging → Analytics | Scheduled (dbt) | Hourly/Daily cron |
| Analytics → Reporting | Real-time (views) | On query |
| **End-to-end** | **~5 minutes** (Platform) to **~24 hours** (Oracle/SF batch) |
