# Requirement Coverage — Latest Gap Analysis

## Source: FPro Program Dashboard KPIs (MVP)

This analysis maps the official MVP KPI requirements against our current data model to determine coverage, gaps, and actions needed.

---

## KPI Coverage Matrix

| # | KPI | Target | Status | Source | Gap |
|---|-----|--------|:------:|--------|-----|
| 1 | Total Active Dealer Accounts (30d/90d/year) | 90% of registered | ✅ FULL | DIM_PRO_BUSINESS_MASTER + DAX (`last_login_date` within period) | None |
| 2 | Total Enrolled Dealers (set up account) | — | ✅ FULL | DIM_PRO_BUSINESS_MASTER (`login_status=ACTIVE`) | None |
| 3 | Total Dealer Accounts Not Set Up | — | ✅ FULL | DIM_PRO_BUSINESS_MASTER (`login_status=PENDING`) | None |
| 4 | Total Inactive Dealers | — | ✅ FULL | DIM + DAX (`login_status=ACTIVE` but `last_login_date` stale) | None |
| 5 | New Dealer Accounts Created (30d/60d/year) | 10% YoY growth | ✅ FULL | FCT_PRO_BUSINESS_MASTER_EVENTS (`is_created_event=1`) | None |
| 6 | New Technician Accounts Created | 15% YoY growth | ✅ FULL | FCT_PRO_CONTACT_MASTER_EVENTS (`is_created_event=1 AND contact_type='TECHNICIAN'`) | None |
| 7 | Time to Approve Lead | < 24 hours | ✅ FULL | FCT_LEAD_FUNNEL (`seconds_in_stage` for LEAD_APPROVED) | None |
| 8 | Approved Leads to Rewards Activated | < 24 hours | ⚠️ PARTIAL | FCT_LEAD_FUNNEL approval time → DIM `rewards_signup_date` | Gap: `rewards_signup_date` is NULL on many records in QA. Works when populated. |
| 9 | First Login Rate (within 14 days) | > 75% in 7 days | ✅ FULL | FCT_PRO_CONTACT_MASTER_EVENTS (created → login-created time gap) | None — can filter by 7d/14d window |
| 10 | Total Active Users (TAU) (30d/90d/year) | 15% YoY growth | ⚠️ PARTIAL | DIM_PRO_CONTACT_MASTER (`login_status=ACTIVE`) | Gap: `last_login_date` is a snapshot, not real-time. Can approximate but not precise per-period without login event stream. |
| 11 | Total Users Not Set Up | — | ✅ FULL | FCT_PRO_CONTACT_MASTER_EVENTS (created contacts with no login-created event) | None |
| 12 | Total Inactive Users | — | ⚠️ PARTIAL | DIM_PRO_CONTACT_MASTER (`login_status=ACTIVE` + stale `last_login_date`) | Same gap as #10 — snapshot-based |
| 13 | TAU per Dealer Account | ≥ 3 active users | ✅ FULL | BRIDGE + DIM_PRO_CONTACT_MASTER → COUNT per dealer in Power BI | None |
| 14 | Stickiness Ratio — Dealers (WAU/MAU) | > 20% | ❌ GAP | No login frequency data | Need Cognito/Auth0 session events |
| 15 | Stickiness Ratio — Technicians (DAU/MAU) | > 40% | ❌ GAP | No login frequency data | Same as above |
| 16 | Leads Rejection Rate | < 5% (current 70%) | ✅ FULL | FCT_LEAD_FUNNEL (REJECTED / total decisions) | None |
| 17 | Total Revenue — Active Dealers | — | ❌ GAP | No revenue data in Snowflake | Need PSOT revenue feed |
| 18 | Revenue Growth Comparison (Aug 2025 baseline) | — | ❌ GAP | No revenue data | Same as above |

---

## Scope Requirements Coverage

| Requirement | Status | How |
|-------------|:------:|-----|
| Total Active Dealer Accounts | ✅ | DIM + DAX |
| Total Active Users by Contact Role | ✅ | DIM_PRO_CONTACT_MASTER grouped by `contact_type` |
| New Dealer Accounts Created vs Guest | ✅ | FCT_LEAD_FUNNEL (`funnel_stage` = GUEST vs LEAD_CREATED vs BUSINESS_CREATED) |
| Converting Guest to Lead | ✅ | FCT_LEAD_FUNNEL (track same `pro_business_id` from GUEST → LEAD) |
| New Technician Accounts Created vs Guest | ⚠️ | Technician accounts in FCT_PRO_CONTACT_MASTER_EVENTS. Guest technicians in `stg_pro_guest_technicians`. Need to link. |
| Time to First Login | ✅ | FCT_PRO_CONTACT_MASTER_EVENTS (created → login-created gap) |
| First Login Rate (within X days) | ✅ | Same — filter by DATEDIFF ≤ X |
| Total Active Users (all associated) | ✅ | DIM_PRO_CONTACT_MASTER via BRIDGE |
| Stickiness (DAU/WAU/MAU) | ❌ GAP | No session/login frequency data |
| Filter by Key Account vs Non-Key Account | ✅ | DIM_PRO_BUSINESS_MASTER (`key_account_type_name IS NOT NULL`) |
| Filter by Primary Business Type | ✅ | DIM_PRO_BUSINESS_MASTER (`primary_business_type`) |
| Filter by Achiever Level | ✅ | DIM_PRO_BUSINESS_MASTER (`rewards_achiever_level`) |
| Trend analysis (time series) | ✅ | FCT_PRO_BUSINESS_MASTER_EVENTS + FCT_PRO_CONTACT_MASTER_EVENTS have `event_date` |
| Target/benchmark comparisons | ✅ | Power BI reference lines against target values |
| Drill-down capability | ✅ | OBT_DEALER_PROFILE or dim-to-fact drill-through |
| Tooltip with KPI description | ✅ | Power BI tooltip configuration |
| Benchmarking (Green/Red coding) | ✅ | Conditional formatting in Power BI |

---

## Nice-to-Have Requirements

| Requirement | Status | Gap |
|-------------|:------:|-----|
| Separate by Platform (web vs mobile) | ❌ GAP | No platform/device field in events |
| Sales Region (from Oracle) | ❌ GAP | No Oracle region data integrated |
| Source (from Salesforce) | ✅ PARTIAL | `registration_source` field exists (PROWEB/SALESFORCE). But Salesforce Lead Source detail not available. |
| Status of the account | ✅ | `business_status` in DIM |
| LTM Active dealers | ✅ | DAX with 12-month `last_login_date` filter |

---

## Out-of-Scope (confirmed excluded)

| Item | Status | Notes |
|------|:------:|-------|
| Usage Coverage (module adoption) | ❌ Not available | No feature-usage/clickstream data |
| Time to First Value/Action | ❌ Not available | No in-app action tracking |
| Accounts with data discrepancies | ✅ Possible | FCT_RECONCILIATION tracks reconciliation runs. Can derive. |
| Health of EventBus Integration | ✅ Possible | Event volume trends + duplicate rates from staging |

---

## Gap Summary

### Hard Gaps (Cannot Solve with Current Data)

| Gap | KPIs Blocked | Data Needed | Integration Path |
|-----|:------------:|-------------|-----------------|
| **Login session frequency** | 14, 15 (Stickiness) | Per-login timestamps with user ID | Cognito CloudWatch → S3 → Snowpipe. Join on `cognito_sub_id`. |
| **Revenue/PSOT data** | 17, 18 (Revenue) | Transaction amounts by dealer | Oracle/PSOT extract → S3 → Snowpipe. Join on `fluidra_account_number`. |
| **Platform/device** | Nice-to-have | Web vs mobile identifier | App-level logging or user-agent capture |
| **Sales region** | Nice-to-have | Oracle region assignment | Oracle region table → Snowflake |

### Soft Gaps (Approximation Available)

| Gap | KPIs Affected | Current Approximation | Limitation |
|-----|:------------:|----------------------|-----------|
| `last_login_date` is snapshot | 1, 4, 10, 12 (Active/Inactive) | Use timestamp from business-master events | Only updates when a new event is emitted — not real-time login tracking |
| `rewards_signup_date` sometimes NULL | 8 (Approved → Activation) | Calculate only for records where date exists | Incomplete coverage |
| Guest technician vs regular technician | Scope item | `stg_pro_guest_technicians` exists separately | Need logic to distinguish guest-created vs regular-created |

---

## Revised Feasibility Scorecard

| Category | Total KPIs | Fully Computable | Partial | Gap |
|----------|:----------:|:----------------:|:-------:|:---:|
| Dealer Adoption (1-5) | 5 | **5** | 0 | 0 |
| User Metrics (6, 9-13) | 6 | **4** | 2 | 0 |
| Lead/Conversion (7, 8, 16) | 3 | **2** | 1 | 0 |
| Engagement/Stickiness (14-15) | 2 | 0 | 0 | **2** |
| Revenue (17-18) | 2 | 0 | 0 | **2** |
| **Total** | **18** | **11 (61%)** | **3 (17%)** | **4 (22%)** |

---

## Filters & Segmentation Coverage

| Filter Dimension | Available? | Source |
|-----------------|:----------:|--------|
| Key Account vs Non-Key Account | ✅ | `dim_pro_business_master.key_account_type_name` |
| Primary Business Type (BUILDER/SERVICE/RETAILER) | ✅ | `dim_pro_business_master.primary_business_type` |
| Achiever Level (PARTNER/ELITE/MEMBER) | ✅ | `dim_pro_business_master.rewards_achiever_level` |
| Business Segment (BUILD/SERVICE/RETAIL) | ✅ | `dim_pro_business_master.business_segment` |
| Channel (NEW CONSTRUCTION/AFTERMARKET) | ✅ | `dim_pro_business_master.channel` |
| Customer Class | ✅ | `dim_pro_business_master.customer_class` |
| Time Period (30d/60d/90d/year) | ✅ | DIM_DATE + Power BI date slicer |
| Geography (State/City) | ✅ | `dim_pro_business_master.billing_state/city` |
| Registration Source (PROWEB/SALESFORCE) | ✅ | `dim_pro_business_master.registration_source` |
| Contact Type (OWNER/TECHNICIAN/etc.) | ✅ | `dim_pro_contact_master.contact_type` |
| Distributor | ✅ | `dim_pro_associated_distributor.distributor_name` |
| Program | ✅ | `dim_pro_program_opt_in.program_name` |

---

## Requirement vs Target Comparison

| KPI | Target | Current Measured Value (QA) | Delta |
|-----|--------|:-:|---|
| Active Dealers | 90% of registered | 3% (8/240) | ⚠️ QA data — not representative |
| New Dealers Growth | 10% YoY | N/A (no prior year) | Need baseline |
| New Technicians Growth | 15% YoY | N/A | Need baseline |
| Time to Approve | < 24 hours | 26 seconds avg | ✅ Well within target (QA auto-approve) |
| Approved → Rewards | < 24 hours | Derivable | Need production data |
| First Login Rate | > 75% in 7 days | 36.6% overall | ⚠️ Below target — onboarding friction |
| TAU per Dealer | ≥ 3 users | ~1-2 | ⚠️ Below target |
| Stickiness Dealers | > 20% | N/A (GAP) | Need login stream |
| Stickiness Technicians | > 40% | N/A (GAP) | Need login stream |
| Rejection Rate | < 5% (current 70%) | 0.93% | ✅ Well within target (QA data) |

---

## Actions Required

| Priority | Action | Owner | Enables |
|:--------:|--------|-------|---------|
| 🔴 HIGH | Integrate Cognito login events (S3 → Snowpipe) | Platform Engineering | KPIs 14, 15 (Stickiness) + precise TAU |
| 🔴 HIGH | Integrate PSOT revenue data | Finance/Data Team | KPIs 17, 18 (Revenue) |
| 🟡 MEDIUM | Validate `rewards_signup_date` population in production | Platform Team | KPI 8 accuracy |
| 🟡 MEDIUM | Define Guest Technician → Regular Technician mapping | Product Owner | "New Tech vs Guest" scope item |
| 🟢 LOW | Integrate Oracle sales region | Data Engineering | Nice-to-have filter |
| 🟢 LOW | Add platform/device field to events | Platform Engineering | Nice-to-have segmentation |
