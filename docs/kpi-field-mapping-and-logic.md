# KPI to Field Mapping & Logic Document (v2)

## Fluidra Pro Analytics — Dashboard KPI Definitions (Aligned to Business Spec)

**Last Updated:** July 2026  
**Source of Truth:** Fluidra-PRO-KPI-Document-KPI-1-to-18  
**Database:** `ANALYTICS_DB_PROD`  
**Schemas:** STAGING → DIMENSIONS → FACTS → MARTS

---

## KPI 01 — Total Active Dealer Accounts

| Attribute | Detail |
|-----------|--------|
| **Definition** | Number of distinct dealer accounts whose lastLoginDate falls within the selected reporting period (30, 90, 365 days) |
| **Target** | 90% of total registered dealer accounts |
| **Source Model** | `fct_pro_business_master_snapshot` |
| **Mart Column** | `active_dealers_30d`, `active_dealers_90d`, `active_dealers_1y` |
| **Required Fields** | `pro_business_id`, `business_status`, `last_contact_login_date` |
| **Calculation** | `business_status = 'ACTIVE' AND last_contact_login_date >= CURRENT_DATE - N` |
| **Filters** | isPrimaryKeyAccount, primaryBusinessType, achieverLevel, Distributor, Region |

```sql
-- In fct_pro_business_master_snapshot:
CASE WHEN business_status = 'ACTIVE' AND last_contact_login_date >= DATEADD('day', -30, CURRENT_DATE()) THEN TRUE ELSE FALSE END AS is_active_30d
```

**Note:** lastLoginDate cannot support DAU, WAU, MAU, Stickiness, or First Login Rate (stores only latest login).

---

## KPI 02 — Total Enrolled Dealers

| Attribute | Detail |
|-----------|--------|
| **Definition** | Number of unique dealer accounts that have status='ACTIVE' AND loginStatus='ACTIVE' |
| **Source Model** | `fct_pro_business_master_snapshot` |
| **Mart Column** | `total_enrolled_dealers` |
| **Required Fields** | `pro_business_id`, `business_status`, `login_status` |
| **Calculation** | `business_status = 'ACTIVE' AND login_status = 'ACTIVE'` |

```sql
CASE WHEN business_status = 'ACTIVE' AND login_status = 'ACTIVE' THEN TRUE ELSE FALSE END AS is_enrolled
```

**Current Value:** 19 enrolled dealers

---

## KPI 03 — Total Dealer Accounts Not Set Up for Login

| Attribute | Detail |
|-----------|--------|
| **Definition** | Number of distinct dealer accounts created/approved but login not completed |
| **Source Model** | `fct_pro_business_master_snapshot` |
| **Mart Column** | `dealers_not_setup` |
| **Required Fields** | `pro_business_id`, `business_status`, `login_status` |
| **Calculation** | `business_status = 'ACTIVE' AND login_status IN ('PENDING', 'NOLOGIN')` |

**Login Status Mapping:**
| loginStatus | Meaning | Include |
|-------------|---------|---------|
| ACTIVE | Login setup complete | No |
| PENDING | Setup in progress | Yes |
| NOLOGIN | Login not created | Yes |
| DISABLED | Previously setup but disabled | No |
| DISABLE_PENDING | Disable in progress | No |

```sql
CASE WHEN business_status = 'ACTIVE' AND login_status IN ('PENDING', 'NOLOGIN') THEN TRUE ELSE FALSE END AS is_not_setup
```

**Current Value:** 3 dealers not set up

---

## KPI 04 — Total Inactive Dealers

| Attribute | Detail |
|-----------|--------|
| **Definition** | Approved dealers with completed account setup who have NOT logged in within the reporting period |
| **Source Model** | `fct_pro_business_master_snapshot` |
| **Mart Columns** | `inactive_dealers_30d`, `inactive_dealers_90d`, `inactive_dealers_365d` |
| **Required Fields** | `pro_business_id`, `business_status`, `login_status`, `last_contact_login_date` |
| **Calculation** | `business_status = 'ACTIVE' AND login_status = 'ACTIVE' AND last_contact_login_date < CURRENT_DATE - N` |

```sql
CASE WHEN business_status = 'ACTIVE' AND login_status = 'ACTIVE'
     AND last_contact_login_date < DATEADD('day', -30, CURRENT_DATE()) THEN TRUE ELSE FALSE END AS is_inactive_30d
```

**Key Dependency:** Requires lastLoginDate. Without it, inactivity cannot be determined.

---

## KPI 05 — New Dealer Accounts Created

| Attribute | Detail |
|-----------|--------|
| **Definition** | Number of new dealer accounts (Lead and Guest) created during the reporting period |
| **Target** | 10% YoY growth |
| **Source Model** | `fct_lead_funnel` |
| **Mart Columns** | `new_dealers_30d`, `new_dealers_60d`, `new_dealers_365d` |
| **Required Fields** | `pro_business_id`, `funnel_stage`, `event_date` |
| **Calculation** | `funnel_stage IN ('LEAD_CREATED', 'GUEST') AND event_date >= CURRENT_DATE - N` |

**Dealer Status Mapping:**
| Status | Include | Reason |
|--------|---------|--------|
| LEAD | Yes | New lead account |
| GUEST | Yes | New guest account |
| ACTIVE | No | Created earlier |
| REJECTED | No | Rejected |

```sql
COUNT(DISTINCT CASE WHEN funnel_stage IN ('LEAD_CREATED', 'GUEST') AND event_date >= DATEADD('day', -30, CURRENT_DATE()) THEN pro_business_id END) AS new_dealers_30d
```

**Architectural Note:** Derived from creation events (metadata.eventType='created') with status at creation time for historical accuracy.

---

## KPI 06 — New Technician Accounts Created

| Attribute | Detail |
|-----------|--------|
| **Definition** | Number of new technician accounts (Associated + Guest) created during the period |
| **Target** | 15% YoY growth |
| **Source Model** | `fct_pro_contact_master_snapshot` |
| **Mart Columns** | `new_technicians_30d`, `new_technicians_60d`, `new_technicians_365d` |
| **Required Fields** | `pro_contact_id`, `contact_type`, `contact_status`, `first_created_at` |
| **Calculation** | `contact_type = 'TECHNICIAN' AND contact_status IN ('ACTIVE', 'GUEST') AND first_created_at >= CURRENT_DATE - N` |

**Contact Type Mapping:** Only TECHNICIAN included. OWNER, CO-OWNER, OFFICE ADMIN, CSC, OTHER excluded.

```sql
COUNT(CASE WHEN is_technician AND contact_status IN ('ACTIVE','GUEST') AND first_created_at >= DATEADD('day', -30, CURRENT_DATE()) THEN 1 END) AS new_technicians_30d
```

**Architectural Note:** Uses pro-contact-master.created events with technician status at creation for historical accuracy.

---

## KPI 07 — Time to Approve Lead

| Attribute | Detail |
|-----------|--------|
| **Definition** | Average number of days between Lead Submission and Lead Approval |
| **Target** | < 24 hours |
| **Source Model** | `fct_pro_business_master_snapshot`, `mart_lead_funnel_kpi` |
| **Mart Columns** | `avg_hours_to_approve`, `avg_days_to_approve` |
| **Required Fields** | `pro_business_id`, `first_created_at`, `first_approved_at` |
| **Formula** | `AVG(DATEDIFF('second', first_created_at, first_approved_at)) / 3600` |

```sql
Lead Submitted: MIN(event_time) WHERE metadata_event_type = 'created'
Lead Approved: MIN(event_time) WHERE is_approved_event = 1 OR is_lead_approved = 1
KPI: AVG(DATEDIFF('second', first_created_at, first_approved_at)) / 3600.0
```

**Current Value:** 0.01 hours (< 1 minute average in test data)

---

## KPI 08 — Approved Leads to Rewards Activated

| Attribute | Detail |
|-----------|--------|
| **Definition** | Average days between Lead Approval and Rewards Account Activation |
| **Target** | < 24 hours |
| **Source Model** | `mart_lead_funnel_kpi`, `mart_kpi_dashboard` |
| **Mart Columns** | `avg_days_approved_to_rewards`, `dealers_with_rewards_activated` |
| **Required Fields** | `pro_business_id`, `lead_approved_at`, `rewards_created_at` (from `rewardsAccount.createdAt`) |
| **Formula** | `AVG(DATEDIFF('day', lead_approved_at, rewards_activated_date))` |
| **Inclusion** | Only approved leads where `rewards_activated_date >= lead_approved_at` |

**Lead Approved Date:**
```sql
-- From mart_lead_funnel_kpi (derived from fct_lead_funnel):
MIN(event_time) WHERE funnel_stage = 'LEAD_APPROVED' per pro_business_id
```

**Rewards Activated Date:**
```sql
-- From stg_pro_business_master_events:
SELECT pro_business_id, MIN(rewards_created_at) AS rewards_activated_date
FROM stg_pro_business_master_events
WHERE rewards_created_at IS NOT NULL
GROUP BY pro_business_id;
```

**Combined KPI:**
```sql
SELECT AVG(DATEDIFF('day', lead_approved_at, rewards_activated_date)) AS avg_days_approved_to_rewards
FROM mart_lead_funnel_kpi
WHERE lead_approved_at IS NOT NULL
  AND rewards_activated_date IS NOT NULL
  AND rewards_activated_date >= lead_approved_at;
```

**Per-dealer detail in `mart_lead_funnel_kpi`:**
- `rewards_activated_date` — timestamp of rewards activation
- `seconds_approved_to_rewards` — seconds between approval and rewards activation
- `days_approved_to_rewards` — days (seconds / 86400.0, rounded to 2 decimals)

**Inclusion Rules:**
| Condition | Include |
|-----------|---------|
| Approved lead with rewards activated after approval | Yes |
| Approved lead without rewards activation | No |
| Rewards activated before approval | No |
| Rejected/Pending lead | No |

**Current Value:** NULL (0 dealers) — `rewardsAccount.createdAt` not present in test data. Will calculate in prod.

**Source Field:** `payload:detail.data.rewardsAccount.createdAt` → parsed as `rewards_created_at` in staging

---

## KPI 09 — First Login Rate

| Attribute | Detail |
|-----------|--------|
| **Definition** | % of new accounts that log in at least once within 14 days from lead submission |
| **Target** | > 75% within 7 days |
| **Source Model** | `fct_pro_contact_master_snapshot` |
| **Mart Columns** | `first_login_rate_7d_pct`, `first_login_rate_14d_pct` |
| **Required Fields** | `first_created_at`, `first_login_created_at` |
| **Formula** | `COUNT(logins within 14d) / COUNT(total created) * 100` |

```sql
-- In fct_pro_contact_master_snapshot:
CASE WHEN first_login_created_at IS NOT NULL
     AND DATEDIFF('day', first_created_at, first_login_created_at) <= 14
     THEN TRUE ELSE FALSE END AS first_login_within_14d

-- In mart_kpi_dashboard:
ROUND(logins_within_14d * 100.0 / total_created_users, 1) AS first_login_rate_14d_pct
```

**Business Assumption:** First Login Date = first `login-created` event timestamp per contact.

**Current Value:** 54.5% (both 7d and 14d)

---

## KPI 10 — Total Active Users (TAU)

| Attribute | Detail |
|-----------|--------|
| **Definition** | Number of individual users who logged in within 30/90/365 days |
| **Target** | 15% YoY growth |
| **Source Model** | `fct_pro_contact_master_snapshot` |
| **Mart Columns** | `tau_30d`, `tau_90d`, `tau_1y` |
| **Required Fields** | `pro_contact_id`, `login_status`, `last_login_date` |
| **Calculation** | `login_status = 'ACTIVE' AND last_login_date >= CURRENT_DATE - N` |

**User Status Mapping:** Only loginStatus='ACTIVE' included. PENDING, NOLOGIN, DISABLED, DISABLE_PENDING excluded.

**Contact Types Included:** OWNER, CO-OWNER, OFFICE ADMIN, TECHNICIAN, CSC, OTHER — all included.

```sql
CASE WHEN login_status = 'ACTIVE' AND last_login_date >= DATEADD('day', -30, CURRENT_DATE()) THEN TRUE ELSE FALSE END AS is_active_30d
```

**Future:** When Login Activity events are integrated, use `fact_login_activity` for DAU/WAU/MAU.

---

## KPI 11 — Total User Accounts Not Set Up for Login

| Attribute | Detail |
|-----------|--------|
| **Definition** | Users that have never completed login setup |
| **Source Model** | `fct_pro_contact_master_snapshot` |
| **Mart Column** | `users_not_setup` |
| **Required Fields** | `pro_contact_id`, `login_status`, `contact_status` |
| **Calculation** | `login_status IN ('PENDING', 'NOLOGIN') AND contact_status IN ('ACTIVE', 'GUEST')` |

```sql
CASE WHEN login_status IN ('PENDING', 'NOLOGIN') AND contact_status IN ('ACTIVE', 'GUEST') THEN TRUE ELSE FALSE END AS is_not_setup
```

**Current Value:** 18 users not set up

---

## KPI 12 — Total Inactive Users

| Attribute | Detail |
|-----------|--------|
| **Definition** | Users with completed account setup who haven't logged in within the period |
| **Source Model** | `fct_pro_contact_master_snapshot` |
| **Mart Columns** | `inactive_users_30d`, `inactive_users_90d` |
| **Required Fields** | `pro_contact_id`, `login_status`, `last_login_date` |
| **Calculation** | `login_status = 'ACTIVE' AND last_login_date < CURRENT_DATE - N` |

```sql
CASE WHEN login_status = 'ACTIVE' AND last_login_date < DATEADD('day', -30, CURRENT_DATE()) THEN TRUE ELSE FALSE END AS is_inactive_30d
```

**Relationship:** KPI10 = Active users; KPI11 = Not set up; KPI12 = Inactive users

---

## KPI 13 — TAU per Dealer Account

| Attribute | Detail |
|-----------|--------|
| **Definition** | Average number of active users per active dealer account |
| **Target** | ≥ 3 active users per dealer |
| **Source Model** | `fct_pro_business_master_snapshot` |
| **Mart Columns** | `avg_tau_per_dealer_30d`, `avg_tau_per_dealer_90d`, `avg_tau_per_dealer_1y` |
| **Formula** | `AVG(active_users_per_dealer)` where active = `loginStatus='ACTIVE' AND lastLoginDate >= period` |

```sql
-- In fct_pro_business_master_snapshot (contact_activity CTE):
COUNT(DISTINCT CASE WHEN login_status = 'ACTIVE' AND last_login_date >= DATEADD('day', -30, CURRENT_DATE()) THEN pro_contact_id END) AS active_users_30d

-- In mart_kpi_dashboard:
AVG(active_users_30d) AS avg_active_users_per_dealer_30d
ROUND(avg_active_users_per_dealer_30d, 1) AS avg_tau_per_dealer_30d
```

**Login Status:** Include ACTIVE only.  
**Contact Types:** OWNER, CO-OWNER, OFFICE ADMIN, TECHNICIAN, CSC, OTHER — all included.

**Per-dealer detail:** `mart_dealer_kpi_summary` provides `active_users_30d/90d/1y` per dealer for drill-down.

---

## KPI 14 — Lead Rejection Rate

| Attribute | Detail |
|-----------|--------|
| **Definition** | % of dealer leads created that were rejected by Sales Rep |
| **Target** | Current = 70%, Target < 5% |
| **Source Model** | `fct_lead_funnel` |
| **Mart Column** | `leads_rejection_rate_pct` |
| **Formula** | `Rejected Leads / Total Leads Created × 100` |

```sql
-- In mart_kpi_dashboard:
total_leads_created = COUNT(DISTINCT CASE WHEN funnel_stage IN ('LEAD_CREATED', 'GUEST') THEN pro_business_id END)
total_rejected = COUNT(DISTINCT CASE WHEN funnel_stage IN ('LEAD_REJECTED', 'BUSINESS_REJECTED') THEN pro_business_id END)
leads_rejection_rate_pct = ROUND(total_rejected * 100.0 / NULLIF(total_leads_created, 0), 1)
```

**Current Value:** 14.3% (2 rejected / 14 created)

---

## KPI 15 — Total Revenue Associated to Active Dealers

| Attribute | Detail |
|-----------|--------|
| **Definition** | Total revenue from FCT_SALES for active dealers |
| **Status** | ⚠️ **NOT YET IMPLEMENTED** — requires FCT_SALES data source |
| **Join Logic** | `dim_pro_business_master.fluidra_account_number = fct_sales.customer_number` |
| **Active Filter** | `status='ACTIVE' AND loginStatus='ACTIVE'` |
| **Period Filter** | `lastLoginDate` window applied dynamically by Power BI dashboard slicer |

**Recommendation:** Do not hardcode 30/90/365-day filter in SQL. Let Power BI dynamically filter lastLoginDate.

---

## KPI 16 — Revenue Growth Comparison

| Attribute | Detail |
|-----------|--------|
| **Definition** | % change in revenue between current and previous reporting period |
| **Status** | ⚠️ **NOT YET IMPLEMENTED** — same dependency as KPI 15 |
| **Formula** | `((Current Revenue - Previous Revenue) / Previous Revenue) * 100` |

**Recommendation:** Implement as dynamic DAX measure in Power BI using Date dimension. Do not store in fact table.

---

## KPI 17 — Time to First Login

| Attribute | Detail |
|-----------|--------|
| **Definition** | Average time from contact account creation to first login-created event |
| **Source Model** | `fct_pro_contact_master_snapshot` |
| **Mart Column** | `avg_days_to_first_login` |
| **Required Fields** | `pro_contact_id`, `first_created_at` (from contact-created.auditInfo.createdAt), `first_login_created_at` (from login-created.time) |
| **Formula** | `AVG(DATEDIFF('second', contact_created_at, first_login_at) / 86400.0)` |

```sql
-- In fct_pro_contact_master_snapshot:
DATEDIFF('second', fc.first_created_at, fl.first_login_created_at) AS seconds_to_first_login

-- In mart_kpi_dashboard (seconds precision):
AVG(seconds_to_first_login / 86400.0) AS avg_days_to_first_login
```

**Inclusion Rules:**
| Condition | Include |
|-----------|---------|
| Contact has both creation and login-created events | Yes |
| Contact has no login-created event | No (excluded from average) |
| First login before contact creation | No (flag as data quality issue) |

**Important:** Users who never logged in are NOT assigned zero days — they're handled by KPI 09 (First Login Rate) and KPI 11 (Not Set Up).

---

## KPI 18 — Guest-to-Lead Conversion Rate

| Attribute | Detail |
|-----------|--------|
| **Definition** | % of dealers whose earliest event was status='GUEST' that later had status='LEAD' |
| **Source Model** | `mart_guest_to_lead_conversion` |
| **Mart Column** | `guest_to_lead_conversion_rate_pct` |
| **Required Fields** | `pro_business_id`, `business_status`, `event_time` |
| **Formula** | `Converted Guests / Total Guests * 100` |

```sql
-- Step 1: Find earliest event per business, filter where status = 'GUEST'
-- Step 2: Check if any later event has status = 'LEAD'
-- Step 3: Conversion Rate = converted / total * 100

WITH first_status AS (
    SELECT pro_business_id, business_status,
           ROW_NUMBER() OVER (PARTITION BY pro_business_id ORDER BY event_time ASC) AS rn
    FROM stg_pro_business_master_events
),
guest_accounts AS (SELECT pro_business_id FROM first_status WHERE rn = 1 AND business_status = 'GUEST'),
lead_accounts AS (SELECT DISTINCT pro_business_id FROM stg_pro_business_master_events WHERE business_status = 'LEAD')
SELECT COUNT(DISTINCT la.pro_business_id) * 100.0 / NULLIF(COUNT(DISTINCT ga.pro_business_id), 0)
FROM guest_accounts ga LEFT JOIN lead_accounts la ON ga.pro_business_id = la.pro_business_id;
```

**Note:** guest_created_date is NOT required for this KPI. Only needed if future reporting requires conversion time analysis.

---

## Stickiness Ratios (KPI 14a/14b — Dashboard Scope)

| KPI | Definition | Formula | Source |
|-----|-----------|---------|--------|
| Stickiness - Dealers | WAU ÷ MAU | Dealers with login in 7d / Dealers with login in 30d | `fct_pro_contact_master_events` |
| Stickiness - Technicians | DAU ÷ MAU | Technicians with login today / Technicians with login in 30d | `fct_pro_contact_master_events` |

**Implementation:** Best computed dynamically in Power BI against `fct_pro_contact_master_events` time-series data. A future `fact_login_activity` table will enable precise calculation.

---

## Segmentation Fields Available (All KPIs)

| Filter | Field | Source |
|--------|-------|--------|
| Key Account | `is_primary_key_account` | dim_pro_business_master |
| Primary Business Type | `primary_business_type` | dim_pro_business_master |
| Achiever Level | `rewards_achiever_level` | dim_pro_business_master |
| Region | `billing_state`, `billing_city` | dim_pro_business_master |
| Registration Source | `registration_source` | dim_pro_business_master |
| Dealer Status | `business_status` | dim_pro_business_master |
| Business Segment | `business_segment` | dim_pro_business_master |
| Contact Role | `contact_type` | dim_pro_contact_master |
| Distributor | `distributor_name` | dim_pro_associated_distributor |
| Date Period | 30 / 60 / 90 / 365 days | Dashboard slicer |

---

## Data Flow Summary

```
RAW_DB_PROD.FLUIDRAPRO_RAW.RAW_DEALERS_DATA (363 events)
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  STAGING (ANALYTICS_DB_PROD.STAGING)                        │
│  • stg_pro_business_master_events  (177 rows, 43 biz)      │
│  • stg_pro_contact_master_events   (70 rows, 40 contacts)  │
│  • stg_pro_business_distributors   (99 rows)               │
│  • stg_pro_business_program_optins (33 rows)               │
│  • stg_pro_business_subscriptions  (8 rows)                │
│  • stg_pro_business_location_master(4 rows)                │
│  • stg_pro_key_account_types       (0 rows — pending data) │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  DIMENSIONS (ANALYTICS_DB_PROD.DIMENSIONS)                  │
│  • dim_pro_business_master         (39 rows)                │
│  • dim_pro_contact_master          (40 rows)                │
│  • dim_pro_associated_distributor  (99 rows)                │
│  • dim_pro_program_opt_in          (33 rows)                │
│  • dim_pro_subscription_master     (8 rows)                 │
│  • dim_pro_business_location_master(4 rows)                 │
│  • dim_key_account_type            (0 rows)                 │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  FACTS (ANALYTICS_DB_PROD.FACTS)                            │
│  • fct_pro_business_master_events        (per business event)            │
│  • fct_lead_funnel           (per funnel stage transition)  │
│  • fct_pro_contact_master_events        (per contact event)            │
│  • fct_pro_business_master_snapshot       (1 per dealer — snapshot)      │
│  • fct_pro_contact_master_snapshot         (1 per user — snapshot)        │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  MARTS (ANALYTICS_DB_PROD.MARTS)                            │
│  • mart_kpi_dashboard             (1 row — all KPIs)        │
│  • mart_dealer_kpi_summary        (1 per dealer)            │
│  • mart_user_kpi_summary          (1 per user)              │
│  • mart_lead_funnel_kpi           (1 per business lifecycle)│
│  • mart_guest_to_lead_conversion  (1 per guest account)     │
└─────────────────────────────────────────────────────────────┘
```

---

## Current KPI Values (from mart_kpi_dashboard)

| # | KPI | Value | Target |
|---|-----|-------|--------|
| 01 | Active Dealers (30d / 90d / 1y) | 0 / 0 / 0 | 90% of registered |
| 02 | Total Enrolled Dealers | 19 | — |
| 03 | Dealers Not Set Up | 3 | — |
| 04 | Inactive Dealers (30d / 90d) | 0 / 0 | — |
| 05 | New Dealers (30d / 60d / 365d) | 3 / 12 / 14 | 10% YoY |
| 06 | New Technicians (30d / 60d) | 3 / 7 | 15% YoY |
| 07 | Avg Time to Approve | 0.01 hours | < 24 hours |
| 09 | First Login Rate (7d / 14d) | 54.5% / 54.5% | > 75% |
| 10 | TAU (30d / 90d / 1y) | 0 / 1 / 1 | 15% YoY |
| 11 | Users Not Set Up | 18 | — |
| 12 | Inactive Users (30d) | 1 | — |
| 13 | TAU per Dealer | 0.0 | ≥ 3 |
| 14 | Lead Rejection Rate | 14.3% | < 5% |
| 17 | Avg Days to First Login | 0.0 | — |
| 18 | Guest-to-Lead Conversion | 0.0% | — |
| 15 | Revenue (Active Dealers) | ⚠️ Pending FCT_SALES | — |
| 16 | Revenue Growth | ⚠️ Pending FCT_SALES | — |

---

## Implementation Status

| KPI | Status | Notes |
|-----|--------|-------|
| 01-14 | ✅ Implemented | Aligned to business definitions doc |
| 15-16 | ⚠️ Pending | Requires FCT_SALES data source |
| 17 | ✅ Implemented | Using seconds precision / 86400 |
| 18 | ✅ Implemented | New mart_guest_to_lead_conversion model |
| Stickiness | ⏳ Partial | Best computed in Power BI; needs login activity fact |
