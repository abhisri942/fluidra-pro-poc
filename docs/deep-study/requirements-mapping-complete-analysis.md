# Requirements Mapping — Complete Analysis

## Executive Summary

This document maps **Fluidra's public business model** (from fluidra.com/fluidrapro.com) against the **analytics requirements** (20 KPIs across 5 categories) and the **available data sources** (100 CDC events + Salesforce/Oracle feeds) to produce a complete traceability matrix with gap identification and recommendations.

---

## 1. Business Context → Requirements Alignment

### 1.1 Fluidra's Business Goals (Public Sources)

| Business Goal | How Measured | KPI Category |
|---------------|-------------|--------------|
| Grow dealer network | New signups, conversion rates | Dealer Adoption |
| Retain existing dealers | Active accounts, login frequency | Dealer Adoption |
| Drive program enrollment | ProEdge/ServicePro/Retail Select adoption | Dealer Conversion |
| Increase platform usage | Logins, feature usage, stickiness | User Adoption & Engagement |
| Maximize revenue per dealer | Purchase volume, tier upgrades | Revenue |
| Support technician adoption | Technician accounts, activity | User Adoption |
| Optimize lead funnel | Lead→Approved→Active conversion | Dealer Conversion |

### 1.2 Loyalty Programs → Data Requirements

| Program (Public Source) | Required Data | Available? |
|------------------------|---------------|-----------|
| **ProEdge** (Builders) | programLevel="PROEDGE", achieverLevel, purchases | PARTIAL — level available, no purchases |
| **ServicePro** (Service Pros) | programLevel="SERVICEPRO", signup date, rewards earned | PARTIAL — level available, no reward amounts |
| **Retail Select** (Retailers) | programLevel="RETAIL SELECT", store traffic, promotions | PARTIAL — level available, no traffic/promos |
| **MyPerks** (Cash Back) | purchases of Jandy/Polaris/Zodiac, cash back amounts | GAP — no purchase data |
| **Club-P** | programOptIns containing "CLUB-P" | PARTIAL — opt-in visible, no activity |

---

## 2. Complete KPI → Data Source Mapping

### 2.1 Dealer Adoption KPIs (5)

| # | KPI | Business Need | Platform Event | Salesforce | Oracle | Status |
|---|-----|--------------|---------------|-----------|--------|--------|
| 1.1 | Total Active Dealer Accounts | Measure network health | `lastLoginDate` on primaryContact | — | — | **PARTIAL** — need login events |
| 1.2 | Total Enrolled Dealers | Track program growth | `status=ACTIVE` + `rewardsAccount.programStatus=ACTIVE` | — | — | **FULL** |
| 1.3 | Dealers Not Set Up | Identify onboarding blockers | `loginStatus=PENDING` + no `login-created` event | — | — | **PARTIAL** |
| 1.4 | Total Inactive Dealers | Retention risk | `lastLoginDate` staleness | — | — | **PARTIAL** — need login stream |
| 1.5 | New Dealer Accounts Created | Growth tracking | `pro-business-master.created` events | Lead created date | — | **FULL** |

### 2.2 Dealer Conversion KPIs (4)

| # | KPI | Business Need | Platform Event | Salesforce | Oracle | Status |
|---|-----|--------------|---------------|-----------|--------|--------|
| 2.1 | Guest-to-Lead Conversion | Top-of-funnel effectiveness | — (no guest events) | Lead source = PROWEB | — | **GAP** — need guest registration data |
| 2.2 | Lead Rejection Rate | Sales rep efficiency | — (no rejected events) | Lead status = Rejected + reason | — | **GAP** — need SF lead lifecycle |
| 2.3 | Time to Approve Lead | Process efficiency | `pro-business-lead.approved` timestamp | Lead created → converted dates | — | **PARTIAL** — need submission time |
| 2.4 | Approved to Rewards Activation | Onboarding speed | `lead.approved` → `rewardsAccount.createdAt` | — | Account setup date | **DERIVED** |

### 2.3 User Adoption KPIs (7)

| # | KPI | Business Need | Platform Event | Salesforce | Oracle | Status |
|---|-----|--------------|---------------|-----------|--------|--------|
| 3.1 | Total Active Users (TAU) | Platform engagement | `loginStatus=ACTIVE` + `lastLoginDate` | — | — | **PARTIAL** — need login events |
| 3.2 | New Technician Accounts | Technician adoption | `pro-contact-master.created` WHERE `contactType=TECHNICIAN` | — | — | **FULL** |
| 3.3 | Users Never Set Up | Onboarding friction | `loginStatus=PENDING` + no `login-created` | — | — | **FULL** |
| 3.4 | Inactive Users | Churn risk | `lastLoginDate` staleness | — | — | **PARTIAL** — need login stream |
| 3.5 | Time to First Login | Onboarding speed | `contact.created` → `login-created` timestamps | — | — | **DERIVED** |
| 3.6 | First Login Rate | Activation rate | `login-created` count / `created` count | — | — | **DERIVED** |
| 3.7 | Active Users per Dealer | Depth of adoption | Contacts per `proBusinessId` with `loginStatus=ACTIVE` | — | — | **PARTIAL** |

### 2.4 Engagement KPIs (2)

| # | KPI | Business Need | Platform Event | Salesforce | Oracle | Status |
|---|-----|--------------|---------------|-----------|--------|--------|
| 4.1 | Dealer Stickiness (WAU/MAU) | Habit formation | — | — | — | **GAP** — need session/clickstream |
| 4.2 | Technician Stickiness (DAU/MAU) | Daily usage | — | — | — | **GAP** — need session/clickstream |

### 2.5 Revenue KPIs (2)

| # | KPI | Business Need | Platform Event | Salesforce | Oracle | Status |
|---|-----|--------------|---------------|-----------|--------|--------|
| 5.1 | Revenue from Active Dealers | ROI of platform | `fluidraAccountNumber` (join key) | — | Revenue transactions by ZP# | **GAP** — need PSOT revenue data |
| 5.2 | Revenue Growth Comparison | Before/after platform | `fluidraAccountNumber` | — | Historical revenue by ZP# | **GAP** — need PSOT + baseline |

---

## 3. Data Source Coverage Matrix

### 3.1 What Each Source Provides

| Data Element | Platform CDC | Salesforce | Oracle | Login Events | Revenue/PSOT |
|-------------|:-----------:|:----------:|:------:|:------------:|:------------:|
| Business identity | ✅ | ✅ | ✅ | — | — |
| Business status | ✅ | ✅ | ✅ | — | — |
| Contact details | ✅ | ✅ | — | — | — |
| Login provisioning | ✅ | — | — | — | — |
| Login activity (actual) | ❌ | — | — | ✅ (needed) | — |
| Session/clickstream | ❌ | — | — | — | ❌ (needed) |
| Lead lifecycle | ✅ (partial) | ✅ (full) | — | — | — |
| Rewards program | ✅ | — | ✅ | — | — |
| Distributor mapping | ✅ | ✅ | — | — | — |
| Location data | ✅ | ✅ | ✅ | — | — |
| Key account flags | ❌ | ✅ | ✅ | — | — |
| Sales region | ❌ | — | ✅ | — | — |
| Revenue/purchases | ❌ | — | — | — | ✅ (needed) |
| Business type/segment | ✅ | ✅ | ✅ | — | — |
| Marketing attribution (UTM) | ✅ | — | — | — | — |

### 3.2 Overall Feasibility Summary

| Status | Count | % | KPIs |
|--------|-------|---|------|
| **FULL** | 4 | 20% | Enrolled Dealers, New Dealers, New Technicians, Users Never Set Up |
| **PARTIAL** | 6 | 30% | Active Dealers, Not Set Up, Inactive Dealers, TAU, Inactive Users, Users per Dealer |
| **DERIVED** | 3 | 15% | Approved→Activation, Time to First Login, First Login Rate |
| **GAP** | 7 | 35% | Guest→Lead, Rejection Rate, Stickiness (2), Revenue (2), Time to Approve |

---

## 4. Missing Data & Information Needed

### 4.1 Critical Gaps (Block Core KPIs)

| Gap | What's Missing | Source Needed | KPIs Blocked | Priority |
|-----|---------------|--------------|-------------|----------|
| **Login/Session Events** | Actual login timestamps, session duration, page views | AWS Cognito logs OR application event stream | Active Dealers, TAU, Inactive, Stickiness (4 KPIs) | 🔴 HIGH |
| **PSOT Revenue Data** | Purchase transactions by dealer (ZP#), amounts, products, dates | Oracle revenue extract OR PSOT data warehouse | Revenue KPIs (2) | 🔴 HIGH |
| **Salesforce Lead Lifecycle** | Lead created date, rejection reason, sales rep, status history | Salesforce CDC or batch export | Guest→Lead, Rejection Rate, Time to Approve (3 KPIs) | 🟡 MEDIUM |

### 4.2 Enhancement Gaps (Improve Existing KPIs)

| Gap | What's Missing | Source Needed | Impact | Priority |
|-----|---------------|--------------|--------|----------|
| **Key Account Classification** | `isPrimaryKeyAccount`, `keyAccountTypeName` | Platform event update OR Salesforce | Cannot filter Key vs Independent | 🟡 MEDIUM |
| **Sales Region** | Geographic region assignment | Oracle `sales_region` table | Cannot do regional analysis | 🟡 MEDIUM |
| **Guest Registration** | Pre-signup activity | Web analytics or guest events | Cannot measure top-of-funnel | 🟡 MEDIUM |
| **Platform/Device** | Web vs mobile usage | Application logs | Cannot segment by device | 🟢 LOW |
| **Reward Amounts** | Cash back earned, redeemed | Loyalty 2.0 system | Cannot measure reward ROI | 🟢 LOW |

### 4.3 Fields Available but Not Yet in Staging Models

| Field in Events | Business Use | Status in dbt |
|----------------|-------------|---------------|
| `distributors[]` | Distributor coverage analysis | ❌ Not parsed |
| `programOptIns[]` | Program enrollment tracking | ❌ Not parsed |
| `secondaryBusinessTypes[]` | Multi-segment dealers | ❌ Not parsed |
| `utm` parameters | Marketing attribution | ❌ Not parsed |
| `fieldsUpdated[]` | Change tracking/audit | ❌ Not parsed |
| `primaryShippingLocation` | Geographic analysis | ❌ Not in business model |
| `userSubscriptions[]` | Subscription tracking | ❌ Not parsed |

---

## 5. Phased Implementation Roadmap

### Phase 1: Build with Current Data (Weeks 1-2)
**7 KPIs achievable immediately**

| KPI | dbt Model | Logic |
|-----|-----------|-------|
| Total Enrolled Dealers | `mart_dealer_adoption` | `status=ACTIVE AND programStatus=ACTIVE` |
| New Dealer Accounts | `mart_dealer_adoption` | Count `created` events by period |
| New Technician Accounts | `mart_user_adoption` | `contactType=TECHNICIAN` created events |
| Users Never Set Up | `mart_user_adoption` | `loginStatus=PENDING` with no login-created |
| Time to First Login | `mart_user_adoption` | `login-created.time - contact.created.time` |
| First Login Rate | `mart_user_adoption` | `login-created / created` per period |
| Approved→Activation | `mart_dealer_conversion` | `rewardsAccount.createdAt - lead.approved.time` |

**Also**: Parse `distributors[]`, `programOptIns[]`, `secondaryBusinessTypes[]`, `utm` in staging models.

### Phase 2: Login Event Integration (Weeks 3-4)
**Unlocks 4 more KPIs**

| Source | Integration Method | KPIs Enabled |
|--------|-------------------|-------------|
| AWS Cognito / Auth0 logs | S3 export → Snowpipe | Active Dealers, TAU, Inactive Dealers, Inactive Users |

### Phase 3: Salesforce Integration (Weeks 5-6)
**Unlocks 3 more KPIs**

| Source | Integration Method | KPIs Enabled |
|--------|-------------------|-------------|
| Salesforce Leads CDC | S3 batch export → Snowpipe (CSV) | Guest→Lead, Lead Rejection, Time to Approve |

### Phase 4: Revenue Integration (Weeks 7-8)
**Unlocks final 2 KPIs**

| Source | Integration Method | KPIs Enabled |
|--------|-------------------|-------------|
| PSOT Revenue Data | S3 batch → Snowpipe (CSV) | Revenue from Dealers, Revenue Growth |

### Phase 5: Engagement (Weeks 9-10)
**Unlocks stickiness KPIs**

| Source | Integration Method | KPIs Enabled |
|--------|-------------------|-------------|
| Application clickstream | S3 events → Snowpipe (JSON) | WAU/MAU Stickiness (2) |

---

## 6. Proposed Data Architecture

### 6.1 Ingestion Layer

```
┌─────────────────────────────────────────────────────────────────┐
│                    S3 DATA LAKE                                   │
│  s3://fluidra-data-lake/raw/                                     │
├─────────────────────────────────────────────────────────────────┤
│  /fluidrapro/   │  /salesforce/  │  /oracle/   │  /revenue/     │
│  (Kafka CDC)    │  (Daily CSV)   │  (Daily CSV)│  (Daily CSV)   │
│  JSON events    │  Leads,Accts   │  Dealers    │  Transactions  │
│  Real-time      │  Contacts      │  Regions    │  By ZP#        │
└────────┬────────┴───────┬────────┴──────┬──────┴───────┬────────┘
         │                │               │              │
         ▼                ▼               ▼              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SNOWFLAKE RAW_DB_PROD                          │
├─────────────────────────────────────────────────────────────────┤
│  FLUIDRAPRO_RAW │ SALESFORCE_RAW │ ORACLE_RAW  │ REVENUE_RAW    │
│  RAW_DEALERS_   │ RAW_LEADS      │ RAW_DEALER_ │ RAW_REVENUE_   │
│  DATA           │ RAW_ACCOUNTS   │ MASTER      │ TRANSACTIONS   │
│  (Snowpipe)     │ RAW_CONTACTS   │ RAW_SALES_  │                │
│                 │                │ REGIONS     │                │
└────────┬────────┴───────┬────────┴──────┬──────┴───────┬────────┘
         │                │               │              │
         ▼                ▼               ▼              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    STAGING_DB_PROD.STAGING                        │
├─────────────────────────────────────────────────────────────────┤
│  stg_fluidrapro_   │ stg_salesforce_ │ stg_oracle_ │ stg_rev_   │
│  businesses        │ leads           │ dealers     │ transactions│
│  contacts          │ accounts        │ regions     │             │
│  locations         │ contacts        │             │             │
│  leads             │                 │             │             │
│  reconcile         │                 │             │             │
└────────┬───────────┴────────┬────────┴──────┬──────┴────┬───────┘
         │                    │               │           │
         ▼                    ▼               ▼           ▼
┌─────────────────────────────────────────────────────────────────┐
│                ANALYTICS_DB_PROD                                  │
├─────────────────────────────────────────────────────────────────┤
│  INTERMEDIATE        │ DIMENSIONS      │ FACTS          │ MARTS  │
│  int_business_       │ dim_dealer      │ fct_pro_biz_   │ mart_  │
│  reconciled          │ dim_contact     │ master_events  │ dealer_│
│  int_contact_        │ dim_location    │ fct_lead_      │ adopt  │
│  enriched            │ dim_program     │ funnel         │ mart_  │
│  int_lead_           │ dim_distributor │ fct_revenue    │ user_  │
│  funnel              │ dim_date        │ fct_login      │ adopt  │
│                      │ dim_region      │                │ mart_  │
│                      │                 │                │ revenue│
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Dimensional Model

**Fact Tables:**

| Fact Table | Grain | Source | Key Measures |
|-----------|-------|--------|-------------|
| `FCT_PRO_BUSINESS_MASTER_EVENTS` | One row per business event | Platform CDC | Event counts, status changes |
| `fct_lead_funnel` | One row per lead stage transition | Platform + SF | Time in stage, conversion flag |
| `fct_login_activity` | One row per login session | Login events (future) | Session count, duration |
| `fct_revenue` | One row per transaction | PSOT Revenue (future) | Revenue amount, product category |

**Dimension Tables:**

| Dimension | Source | Key Attributes |
|-----------|--------|---------------|
| `dim_dealer` | Platform + Oracle + SF | proBusinessId, name, status, type, segment, class, key_account_flag |
| `dim_contact` | Platform | proContactId, name, type, login_status |
| `dim_location` | Platform | proLocationId, city, state, zip, type |
| `dim_program` | Platform | program_level, achiever_level, region, status |
| `dim_distributor` | Platform | distributor_name, account_number, status |
| `dim_date` | Generated | Standard date dimension |
| `dim_region` | Oracle | sales_region, territory |

---

## 7. Key Questions Remaining

| # | Question | Impacts | Who to Ask |
|---|----------|---------|-----------|
| 1 | Can we get Auth0/Cognito login events exported to S3? | Active user KPIs (4) | Platform Engineering |
| 2 | What is the PSOT revenue data format and delivery cadence? | Revenue KPIs (2) | Finance/Data Team |
| 3 | Can Salesforce provide CDC events or is it daily batch only? | Lead funnel KPIs (3) | Salesforce Admin |
| 4 | Are key account flags (`isPrimaryKeyAccount`) in upcoming platform events? | Key account filtering | Platform Product |
| 5 | Is there a guest registration event before lead creation? | Guest→Lead conversion | Product Team |
| 6 | What defines "active" — any login in 30 days? 90 days? | All activity KPIs | Business Stakeholders |
| 7 | Do we need per-product revenue or aggregate per dealer? | Revenue model granularity | Analytics Lead |
| 8 | Is the August 2025 revenue baseline available for comparison? | Revenue growth KPI | Finance |

---

## 8. Summary Scorecard

| Dimension | Available Now | Needs Integration | Total |
|-----------|:------------:|:-----------------:|:-----:|
| **KPIs Buildable** | 7 (35%) | 13 (65%) | 20 |
| **Data Sources Connected** | 1 (Platform CDC) | 4 (SF, Oracle, Login, Revenue) | 5 |
| **Staging Models Active** | 2 (businesses, contacts) | 5 (leads, locations, SF, Oracle, Revenue) | 7 |
| **Fields Parsed** | ~30 | ~20 more available in events | ~50 |

### Bottom Line

The current Platform CDC feed enables **35% of KPIs** immediately. Adding **login events** and **Salesforce** data would bring coverage to **70%**. Full coverage requires **PSOT revenue** and **clickstream** data — achievable within 8-10 weeks with the phased approach above.
