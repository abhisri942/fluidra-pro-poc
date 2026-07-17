# Model Data Dictionary — Fluidra Pro Analytics

**Database:** `ANALYTICS_DB_PROD`  
**Repository:** `abhisri942/fluidra-pro-analytics`  
**Last Updated:** July 2026

---

## Summary

| Layer | Models | Materialization | Total Fields |
|-------|--------|----------------|--------------|
| Staging | 7 | View | 181 |
| Dimensions | 7 | View | 127 |
| Facts | 5 | View | 126 |
| Marts | 5 | Table | 117 |
| **Total** | **24** | | **551** |

---

## Staging Layer (`ANALYTICS_DB_PROD.STAGING`)

| # | Model | SCD Type | Incremental | Fields | Grain | Purpose |
|---|-------|----------|-------------|--------|-------|---------|
| 1 | `stg_pro_business_master_events` | N/A (event log) | No (view) | 68 | 1 per event_id | Parse all business events from RAW, dedup Kafka duplicates. Foundation for all business KPIs. |
| 2 | `stg_pro_contact_master_events` | N/A (event log) | No (view) | 28 | 1 per event_id | Parse all contact events from RAW, dedup Kafka duplicates. Foundation for user/TAU KPIs. |
| 3 | `stg_pro_business_distributors` | Type 1 | No (view) | 14 | 1 per (business, distributor, account#) | Flatten distributors[] array, keep latest state per business-distributor combination. |
| 4 | `stg_pro_business_program_optins` | Type 1 | No (view) | 15 | 1 per (business, program_name) | Flatten programOptIns[] array, keep latest state per business-program. |
| 5 | `stg_pro_business_subscriptions` | Type 1 | No (view) | 14 | 1 per (business, subscription_id) | Flatten subscriptions[] array, keep latest state per business-subscription. |
| 6 | `stg_pro_business_location_master` | Type 1 | No (view) | 25 | 1 per pro_location_id | Parse location events, keep latest state per location. |
| 7 | `stg_pro_key_account_types` | Type 1 | No (view) | 17 | 1 per key_account_type_id | Parse key account type events, keep latest state per type. |

---

## Dimensions Layer (`ANALYTICS_DB_PROD.DIMENSIONS`)

| # | Model | SCD Type | Incremental | Fields | Grain | Purpose |
|---|-------|----------|-------------|--------|-------|---------|
| 8 | `dim_pro_business_master` | Type 1 | No (view) | 44 | 1 per pro_business_id | Latest-state dealer dimension. Thin attributes only — business identity, classification, rewards, location, sales rep, UTM. Supports all dealer segmentation filters. |
| 9 | `dim_pro_contact_master` | Type 1 | No (view) | 16 | 1 per pro_contact_id | Latest-state user/contact dimension with business linkage (bridge fills missing pro_business_id from business events). |
| 10 | `dim_pro_associated_distributor` | Type 1 | No (view) | 12 | 1 per (business, distributor, account#) | Distributor relationships per dealer business. Supports distributor filter on dashboard. |
| 11 | `dim_pro_program_opt_in` | Type 1 | No (view) | 12 | 1 per (business, program_name) | Program enrollment dimension. Tracks rewards/program opt-in status per dealer. |
| 12 | `dim_pro_subscription_master` | Type 1 | No (view) | 11 | 1 per (business, subscription_id) | Subscription dimension per dealer business. |
| 13 | `dim_pro_business_location_master` | Type 1 | No (view) | 18 | 1 per pro_location_id | Location dimension for dealer business addresses. Supports region/state filtering. |
| 14 | `dim_key_account_type` | Type 1 | No (view) | 14 | 1 per key_account_type_id | Reference dimension for key account type classification (customer_class, sales_channel, program, achiever_level). |

---

## Facts Layer (`ANALYTICS_DB_PROD.FACTS`)

| # | Model | SCD Type | Incremental | Fields | Grain | Purpose |
|---|-------|----------|-------------|--------|-------|---------|
| 15 | `fct_pro_business_master_events` | N/A (event fact) | No (view) | 36 | 1 per business event | All business-master events with dimension keys and event flags. Supports KPI 05 (new dealers), KPI 14 (rejection rate), dealer event trending. |
| 16 | `fct_lead_funnel` | N/A (event fact) | No (view) | 20 | 1 per funnel stage transition | Funnel events only (excludes 'UPDATED'). Supports KPI 05, KPI 07, KPI 08, KPI 14, funnel analysis. |
| 17 | `fct_pro_contact_master_events` | N/A (event fact) | No (view) | 22 | 1 per contact event | All contact events with login flags. Supports KPI 06, KPI 10, stickiness calculations, login trending. |
| 18 | `fct_pro_business_master_snapshot` | Type 1 (snapshot) | No (view) | 26 | 1 per pro_business_id | Current dealer activity snapshot. Supports KPI 01-04, KPI 07, KPI 13. Pre-computes is_active, is_enrolled, is_not_setup, is_inactive flags. |
| 19 | `fct_pro_contact_master_snapshot` | Type 1 (snapshot) | No (view) | 22 | 1 per pro_contact_id | Current user activity snapshot. Supports KPI 06, KPI 09-12, KPI 17. Pre-computes login lifecycle, activity flags, first login timing. |

---

## Marts Layer (`ANALYTICS_DB_PROD.MARTS`)

| # | Model | SCD Type | Incremental | Fields | Grain | Purpose |
|---|-------|----------|-------------|--------|-------|---------|
| 20 | `mart_kpi_dashboard` | N/A (aggregate) | No (full refresh table) | 28 | 1 row (summary) | Executive dashboard — all KPIs pre-aggregated in a single row. Direct binding for Power BI KPI cards. |
| 21 | `mart_dealer_kpi_summary` | Type 1 (snapshot) | No (full refresh table) | 37 | 1 per pro_business_id | Dealer-level KPI detail. Supports drill-down from dashboard KPI cards. Includes activity flags + user counts per dealer. |
| 22 | `mart_user_kpi_summary` | Type 1 (snapshot) | No (full refresh table) | 20 | 1 per pro_contact_id | User-level KPI detail. Supports drill-down for TAU, first login, inactive users. |
| 23 | `mart_lead_funnel_kpi` | Type 1 (snapshot) | No (full refresh table) | 27 | 1 per pro_business_id | Full funnel lifecycle per business with all stage timestamps + KPI 07 & KPI 08 durations. |
| 24 | `mart_guest_to_lead_conversion` | Type 1 (snapshot) | No (full refresh table) | 5 | 1 per guest business | KPI 18: Guest-to-Lead conversion tracking per dealer. |

---

## SCD Type Reference

| SCD Type | Meaning | Used For |
|----------|---------|----------|
| **N/A (event log)** | Immutable append-only events — no updates | Staging event models, event fact tables |
| **Type 1** | Latest state overwrites previous — no history retained | Dimensions, snapshot facts, flattened arrays |
| **N/A (aggregate)** | Pre-computed summary — refreshed on each run | Mart KPI dashboard |

---

## Incremental Strategy

All models are currently **full-refresh views or tables** (not incremental). This is appropriate for the current data volume (363 events). When data volume grows:

| Model | Recommended Incremental Strategy |
|-------|----------------------------------|
| `stg_pro_business_master_events` | Incremental on `_loaded_at` or `kafka_offset` |
| `stg_pro_contact_master_events` | Incremental on `_loaded_at` or `kafka_offset` |
| `fct_pro_business_master_events` | Incremental on `event_time` |
| `fct_pro_contact_master_events` | Incremental on `event_time` |
| Mart tables | Full refresh (small — aggregated) |
| Dimensions | Full refresh (SCD Type 1 — latest state) |

---

## Future Models (Not Yet Implemented)

| Model | SCD Type | Fields | Grain | Purpose | Blocker |
|-------|----------|--------|-------|---------|---------|
| `fct_sales` | Event fact | TBD | 1 per invoice line | Revenue by dealer (KPI 15, 16) | Requires Oracle ERP / Salesforce data source |
| `fct_login_activity` | Event fact | TBD | 1 per login event | DAU/WAU/MAU, stickiness, login trends | Requires login activity event stream |
| `dim_date` | Type 0 | ~10 | 1 per calendar date | Date dimension for time intelligence | Standard calendar table |
