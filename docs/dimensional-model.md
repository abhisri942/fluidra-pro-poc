# FluidraPro Dimensional Model

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            RAW SOURCE (Event Stream)                             │
│                                                                                 │
│   RAW_DB_PROD.FLUIDRAPRO_RAW.RAW_DEALERS_DATA (Kafka append-only CDC stream)    │
└────────────────────────────────────────┬────────────────────────────────────────┘
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           STAGING (Parsed + Deduped)                             │
│                                                                                 │
│  stg_pro_business_master_events     (grain: 1 row per event_id)                 │
│  stg_pro_contact_master_events      (grain: 1 row per event_id)                 │
│  stg_pro_business_distributors      (grain: 1 row per business+distributor)     │
│  stg_pro_business_location_master   (grain: 1 row per location_id)              │
│  stg_pro_business_subscriptions     (grain: 1 row per business+subscription)    │
│  stg_pro_business_program_optins    (grain: 1 row per business+program)         │
│  stg_pro_key_account_types          (grain: 1 row per key_account_type_id)      │
└────────────────────────────────────────┬────────────────────────────────────────┘
                                         │
                          ┌──────────────┼──────────────┐
                          ▼              ▼              ▼
┌──────────────────────────┐ ┌─────────────────────┐ ┌──────────────────────────┐
│       DIMENSIONS         │ │        FACTS        │ │         MARTS            │
│   (Current State)        │ │  (Event History)    │ │  (Pre-aggregated KPIs)   │
└──────────────────────────┘ └─────────────────────┘ └──────────────────────────┘
```

---

## History Preservation Strategy: Event Sourcing

This project does **not** use SCD Type 2. Instead, it preserves full history through an **event-sourced pattern**:

1. **Raw source is an append-only Kafka event stream** — every state change arrives as a new immutable event row. Nothing is ever overwritten or deleted.

2. **Staging models = deduplicated event log (full history)** — deduplicate by `event_id` (removing duplicate Kafka deliveries) but keep every distinct event.

3. **Fact tables = full event history** — expose the entire event stream for querying at any point in time.

4. **Dimensions = "latest state" via windowing** — derive current snapshot by picking the most recent event per entity using `row_number() over (partition by entity_id order by event_time desc)`.

5. **Point-in-time reconstruction** — query the staging/fact layer with a time filter:
   ```sql
   -- Business state as of a specific date
   SELECT *
   FROM stg_pro_business_master_events
   WHERE pro_business_id = 'xyz'
     AND event_time <= '2025-06-01'
   QUALIFY ROW_NUMBER() OVER (
       PARTITION BY pro_business_id
       ORDER BY event_time DESC
   ) = 1
   ```

---

## Dimension Tables (Type 1 — Latest State Only)

| Dimension | Grain | Primary Key | Purpose |
|-----------|-------|-------------|---------|
| `dim_pro_business_master` | 1 row per business | `pro_business_id` | Dealer/business attributes (status, segment, rewards, UTM) |
| `dim_pro_contact_master` | 1 row per contact | `pro_contact_id` | User/contact attributes (type, login status, email) |
| `dim_pro_business_location_master` | 1 row per location | `pro_location_id` | Physical location (address, service zips) |
| `dim_pro_associated_distributor` | 1 row per business × distributor | `pro_business_id` + `distributor_account_number` | Distributor relationships |
| `dim_pro_subscription_master` | 1 row per business × subscription | `pro_business_id` + `subscription_id` | Subscriptions per dealer |
| `dim_pro_program_opt_in` | 1 row per business × program | `pro_business_id` + `program_name` | Program enrollments |
| `dim_key_account_type` | 1 row per account type | `key_account_type_id` | Reference/lookup for key account classification |

---

## Fact Tables

| Fact | Grain | Type | Purpose |
|------|-------|------|---------|
| `fct_pro_business_master_events` | 1 row per business event | Transaction (event stream) | Every business lifecycle event — created, updated, approved, rejected |
| `fct_pro_contact_master_events` | 1 row per contact event | Transaction (event stream) | Every contact lifecycle event — created, login-created, updated, deleted |
| `fct_lead_funnel` | 1 row per funnel stage transition | Transaction (filtered events) | Funnel-specific events only (excludes generic updates) |
| `fct_pro_business_master_snapshot` | 1 row per business | Periodic snapshot | Current activity state — active/inactive/enrolled flags |
| `fct_pro_contact_master_snapshot` | 1 row per contact | Periodic snapshot | Current user activity state — active/inactive/login timing |

---

## Star Schema Relationships

```
                        ┌──────────────────────────┐
                        │   dim_key_account_type   │
                        │   PK: key_account_type_id│
                        └────────────┬─────────────┘
                                     │ key_account_type_name
                                     │
┌───────────────────┐   ┌────────────┴─────────────────────┐   ┌───────────────────────┐
│dim_pro_associated │   │      dim_pro_business_master     │   │dim_pro_subscription   │
│_distributor       │◄──┤      PK: pro_business_id         ├──►│_master                │
│FK: pro_business_id│   │                                  │   │FK: pro_business_id    │
└───────────────────┘   │  business_status                 │   └───────────────────────┘
                        │  primary_business_type            │
┌───────────────────┐   │  business_segment                │   ┌───────────────────────┐
│dim_pro_program    │   │  registration_source             │   │dim_pro_business       │
│_opt_in            │◄──┤  is_primary_key_account          ├──►│_location_master       │
│FK: pro_business_id│   │  rewards_program_level           │   │FK: pro_business_id    │
└───────────────────┘   │  channel / customer_class        │   │PK: pro_location_id    │
                        └────────────┬─────────────────────┘   └───────────────────────┘
                                     │
                                     │ pro_business_id
                                     │
              ┌──────────────────────┼──────────────────────┐
              │                      │                      │
              ▼                      ▼                      ▼
┌─────────────────────┐ ┌───────────────────────┐ ┌─────────────────────┐
│  fct_pro_business_master_events  │ │   fct_lead_funnel     │ │ fct_pro_business_master_snapshot │
│  (event stream)     │ │   (funnel events)     │ │ (snapshot)          │
│                     │ │                       │ │                     │
│ FK: pro_business_id │ │ FK: pro_business_id   │ │ PK: pro_business_id │
│ FK: primary_contact │ │ FK: primary_contact_id│ │                     │
│     _id             │ │                       │ │ is_enrolled         │
│ FK: billing_location│ │ funnel_stage          │ │ is_active_30d       │
│     _id             │ │ seconds_in_stage      │ │ is_active_90d       │
│                     │ │ failure_reason        │ │ total_contacts      │
│ is_created_event    │ │                       │ │ seconds_to_approve  │
│ is_approved_event   │ └───────────────────────┘ └─────────────────────┘
│ is_rejected_event   │
│ distributor_count   │
└─────────────────────┘
              │
              │ primary_contact_id
              ▼
┌─────────────────────────────────┐
│    dim_pro_contact_master       │
│    PK: pro_contact_id           │
│    FK: pro_business_id          │
│                                 │
│    contact_type (DEALER/TECH)   │
│    login_status                 │
│    last_login_date              │
└────────────┬────────────────────┘
             │
             │ pro_contact_id
             │
      ┌──────┴──────┐
      ▼             ▼
┌─────────────────────┐ ┌──────────────┐
│fct_pro_contact      │ │fct_user      │
│_master_events       │ │_activity     │
│(stream)   │ │(snapshot)    │
│           │ │              │
│is_created │ │is_active_30d │
│is_login   │ │is_active_90d │
│ _created  │ │has_login_setup│
│is_updated │ │is_inactive   │
│is_deleted │ │first_login   │
│           │ │ _within_14d  │
└───────────┘ └──────────────┘
```

---

## Mart Layer (Pre-aggregated for Dashboards)

| Mart | Grain | Feeds |
|------|-------|-------|
| `mart_kpi_dashboard` | Single row (global totals) | Executive dashboard top-line metrics |
| `mart_dealer_kpi_summary` | 1 row per business | Dealer-level KPIs with user counts |
| `mart_user_kpi_summary` | 1 row per contact | User-level activity and login KPIs |
| `mart_lead_funnel_kpi` | 1 row per business | Lead lifecycle funnel with time-to-approve |

---

## Detailed Dimension Descriptions

### dim_pro_business_master
The central business/dealer dimension. Contains all descriptive attributes for a dealer account:
- **Identity**: business name, doing-business-as
- **Classification**: business_status, primary_business_type, business_segment, channel, customer_class, sales_channel
- **Key Account**: is_primary_key_account, key_account_type_name
- **Rewards**: program_level, achiever_level, program_status, rebate_pay_type
- **Registration**: registration_source, UTM attributes
- **Contact**: primary_contact_id (embedded 1:1 relationship)
- **Location**: billing_location_id, billing_city, billing_state
- **Sales Rep**: name, email

### dim_pro_contact_master
The user/contact dimension. Each contact belongs to one business:
- **Identity**: first_name, last_name, email, phone, username
- **Type**: contact_type (DEALER, TECHNICIAN)
- **Status**: login_status, contact_status, last_login_date
- **External IDs**: cognito_sub_id, web_user_id
- **Bridge**: pro_business_id (filled from business events when missing in contact events)

### dim_pro_business_location_master
Physical locations associated with a dealer business:
- **Address**: street, city, state, zip, country
- **Attributes**: location_type, location_status, lead_management_email
- **Measures**: service_zip_count
- **Privacy**: hide_address, hide_location flags

### dim_pro_associated_distributor
Many-to-many relationship between dealers and their distributors:
- **Relationship**: distributor_name, distributor_account_number, distributor_account_status
- **Linkage**: fluidra_account_number, source

### dim_pro_subscription_master
Subscriptions held by each dealer:
- **Identity**: subscription_id, subscription_name
- **Status**: subscription_status, program_start_date, source

### dim_pro_program_opt_in
Program enrollments per dealer:
- **Identity**: program_name, program_status
- **Dates**: program_opt_in_date, program_start_date

### dim_key_account_type
Reference dimension for account type classification:
- **Attributes**: key_account_type_name, key_account_type_role, customer_class, sales_channel
- **Program**: program_name, achiever_level
- **Flags**: enable_zodiac_premium, override_achiever_level_role, e_statement_enabled

---

## Detailed Fact Descriptions

### fct_pro_business_master_events (Transaction Fact)
Every business lifecycle event in the system. Supports:
- New Dealer Accounts Created (`is_created_event`)
- Total Active Dealer Accounts (via login events)
- Total Enrolled Dealers (`is_approved_event`)
- Leads Rejection Rate (`is_rejected_event`, `is_lead_rejected`)

**Measures**: distributor_count, program_opt_in_count, subscription_count, event type flags (additive)

### fct_pro_contact_master_events (Transaction Fact)
Every contact lifecycle event. Supports:
- Total Active Users (TAU) — login-created events + last_login_date
- New Technician Accounts Created (is_created_event where contact_type = TECHNICIAN)
- TAU per Dealer Account (join to dim_pro_business_master)
- Stickiness Ratio (DAU/WAU/MAU from login events)

**Measures**: assigned_location_count, user_subscription_count, event type flags

### fct_lead_funnel (Transaction Fact — Filtered)
Funnel stage transitions only (excludes generic UPDATE events). Supports:
- Time to Approve Lead (seconds_in_stage)
- Approved Leads to Rewards Activated (stage transitions)
- First Login Rate (GUEST → LEAD_CREATED → LEAD_APPROVED timeline)
- Leads Rejection Rate (LEAD_REJECTED / total leads)
- New Dealer Accounts Created (BUSINESS_CREATED, LEAD_CREATED, GUEST stages)

**Measures**: funnel_stage (degenerate dimension), seconds_in_stage, failure_reason

### fct_pro_business_master_snapshot (Periodic Snapshot Fact)
One row per business — current activity state. Supports:
- Total Active Dealer Accounts (30d/90d/1y)
- Total Enrolled Dealers
- Total Dealer Accounts Not Set Up
- Total Inactive Dealers
- TAU per Dealer Account
- Time to Approve

**Measures**: is_enrolled, has_login_setup, is_active_30d/90d/1y, is_inactive, seconds_to_approve, total_contacts

### fct_pro_contact_master_snapshot (Periodic Snapshot Fact)
One row per contact — current user activity state. Supports:
- Total Active Users (TAU) — 30d/90d/year
- Total Users Not Set Up Login
- Total Inactive Users
- New Technician Accounts Created
- First Login Rate (within 7d/14d)
- Stickiness Ratio Technicians (DAU/MAU)

**Measures**: is_active_30d/90d/1y, has_login_setup, is_inactive, first_login_within_7d/14d, seconds_to_first_login

---

## Key Design Characteristics

### 1. Event-Sourced, Not SCD Type 2
- History lives in the immutable event stream (staging/fact layers)
- Dimensions always show "latest state" via `row_number() ... order by event_time desc`
- Point-in-time reconstruction requires filtering the event stream

### 2. Two Types of Fact Tables
- **Transaction facts** (`fct_pro_business_master_events`, `fct_pro_contact_master_events`, `fct_lead_funnel`) — one row per event, full history
- **Periodic snapshot facts** (`fct_pro_business_master_snapshot`, `fct_pro_contact_master_snapshot`) — one row per entity, current state with derived flags

### 3. Conformed Dimensions
- `pro_business_id` is the primary join key linking business dimensions ↔ facts
- `pro_contact_id` links contacts to their events
- `pro_business_id` bridges contacts back to their parent business (with a fallback bridge for missing IDs)

### 4. Degenerate Dimensions
Many descriptive attributes (business_status, funnel_stage, registration_source) are stored directly on fact tables to avoid excessive joins during query time.

### 5. Multi-Valued Relationships (Outriggers)
- `dim_pro_associated_distributor` — many distributors per business
- `dim_pro_subscription_master` — many subscriptions per business
- `dim_pro_program_opt_in` — many programs per business
- `dim_pro_business_location_master` — many locations per business

These are bridge/outrigger patterns joined to the business dimension via `pro_business_id`, not to the fact tables directly.

### 6. Materialization Strategy
- **Staging & Dimensions**: Views (always fresh, no storage cost)
- **Facts**: Views (query the raw stream directly)
- **Marts**: Tables (pre-aggregated for dashboard performance)

---

## Comparison: Event Sourcing vs SCD Type 2

| Concern | SCD Type 2 | This Project (Event Sourcing) |
|---------|------------|-------------------------------|
| Where is history stored? | Dimension table (valid_from/valid_to) | Raw/staging event log (append-only) |
| How many rows per entity? | One per version | One per event (every change) |
| Current state | `is_current = true` | `row_number() ... order by event_time desc` |
| Point-in-time query | Filter on valid_from/valid_to | Filter `event_time <= X` + window |
| Deletes/overwrites | Never (adds new version row) | Never (new event row appended) |
| Dimension join complexity | Simple (join on surrogate key) | Simple (join on natural key) |
| Storage overhead | Moderate (version rows in dims) | High (all events retained in raw) |
| Query performance on history | Optimized (indexed date ranges) | Requires window functions |
