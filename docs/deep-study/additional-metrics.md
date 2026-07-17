# Additional Metrics — Derivable from Current Facts & Dims

## What We Have to Work With

| Table | What It Contains |
|-------|-----------------|
| `FCT_PRO_BUSINESS_MASTER_EVENTS` | Every business event with timestamps, status, counts, UTM |
| `FCT_PRO_CONTACT_MASTER_EVENTS` | Every contact event with type, login status, timestamps |
| `FCT_LEAD_FUNNEL` | Funnel stage transitions with timing, sales rep, failure reason |
| `DIM_PRO_BUSINESS_MASTER` | Dealer profile — type, segment, channel, rewards level |
| `DIM_PRO_CONTACT_MASTER` | Contact profile — type, login status, last login |
| `DIM_PRO_ASSOCIATED_DISTRIBUTOR` | Distributor links — name, status, source |
| `DIM_PRO_PROGRAM_OPT_IN` | Program enrollments — name, status, dates |
| `DIM_PRO_SUBSCRIPTION_MASTER` | IoT subscriptions |
| `DIM_PRO_BUSINESS_LOCATION_MASTER` | Geography — city, state, zip |
| `DIM_KEY_ACCOUNT_TYPE` | Key account classifications |

---

## Dealer Network Metrics

| # | Metric | Logic | Source |
|---|--------|-------|--------|
| 1 | Dealers by Business Type | GROUP BY primary_business_type | DIM_PRO_BUSINESS_MASTER |
| 2 | Dealers by Segment | GROUP BY business_segment | DIM_PRO_BUSINESS_MASTER |
| 3 | Dealers by Channel | GROUP BY channel | DIM_PRO_BUSINESS_MASTER |
| 4 | Dealers by Registration Source | GROUP BY registration_source (PROWEB vs SALESFORCE) | DIM_PRO_BUSINESS_MASTER |
| 5 | Dealers by State / Geography | GROUP BY billing_state | DIM_PRO_BUSINESS_MASTER |
| 6 | Key Account vs Non-Key Account Split | COUNT WHERE key_account_type_name IS NOT NULL | DIM_PRO_BUSINESS_MASTER |
| 7 | Dealers by Rewards Tier | GROUP BY rewards_achiever_level | DIM_PRO_BUSINESS_MASTER |
| 8 | Dealer Growth Rate (WoW) | COUNT created this week / COUNT created last week | FCT_PRO_BUSINESS_MASTER_EVENTS |
| 9 | Dealer Churn Indicator | Dealers who went from ACTIVE → no events in 60+ days | FCT_PRO_BUSINESS_MASTER_EVENTS |
| 10 | Average Dealer Age | AVG(DATEDIFF(created_at, TODAY)) | DIM_PRO_BUSINESS_MASTER |

---

## Distributor Metrics

| # | Metric | Logic | Source |
|---|--------|-------|--------|
| 11 | Avg Distributors per Dealer | AVG(COUNT per pro_business_id) | DIM_PRO_ASSOCIATED_DISTRIBUTOR |
| 12 | Dealers with Zero Distributors | Dealers NOT IN distributor table | DIM minus LEFT JOIN |
| 13 | Distributor Concentration | Top 5 distributors by dealer count / total | DIM_PRO_ASSOCIATED_DISTRIBUTOR |
| 14 | Distributor Activation Rate | ACTIVE / total per distributor | DIM_PRO_ASSOCIATED_DISTRIBUTOR |
| 15 | Single-Distributor vs Multi-Distributor Dealers | COUNT WHERE distributor_count = 1 vs > 1 | FCT_PRO_BUSINESS_MASTER_EVENTS |
| 16 | Distributor Churn | Status changed to INACTIVE over time | FCT_PRO_BUSINESS_MASTER_EVENTS (track array changes) |

---

## Program & Rewards Metrics

| # | Metric | Logic | Source |
|---|--------|-------|--------|
| 17 | Program Penetration Rate | Dealers with 1+ active program / total dealers | DIM_PRO_PROGRAM_OPT_IN + DIM_PRO_BUSINESS_MASTER |
| 18 | Multi-Program Dealers | Dealers with 2+ programs enrolled | DIM_PRO_PROGRAM_OPT_IN |
| 19 | Program Decline Rate | DECLINED / total per program | DIM_PRO_PROGRAM_OPT_IN |
| 20 | Time to Program Activation | AVG(program_opt_in_date → first ACTIVE status event) | DIM_PRO_PROGRAM_OPT_IN |
| 21 | Rewards Tier Distribution | COUNT by achiever_level (PARTNER/ELITE/MEMBER) | DIM_PRO_BUSINESS_MASTER |
| 22 | Rebate Method Preference | AP Voucher vs Debit VISA distribution | DIM_PRO_BUSINESS_MASTER |
| 23 | Zodiac Premium Adoption | COUNT WHERE rewards_auto_zodiac = TRUE | DIM_PRO_BUSINESS_MASTER |

---

## Contact & User Metrics

| # | Metric | Logic | Source |
|---|--------|-------|--------|
| 24 | Contacts per Dealer | AVG contacts per pro_business_id | BRIDGE + DIM_PRO_CONTACT_MASTER |
| 25 | Contact Type Distribution | % OWNER / TECHNICIAN / OFFICE ADMIN / CO-OWNER | DIM_PRO_CONTACT_MASTER |
| 26 | Login Activation by Contact Type | login-created rate per type | FCT_PRO_CONTACT_MASTER_EVENTS |
| 27 | Fastest Onboarding Contact Type | MIN(avg time to first login) by type | FCT_PRO_CONTACT_MASTER_EVENTS |
| 28 | Orphaned Contacts | Contacts with no dealer link (not in bridge) | DIM_PRO_CONTACT_MASTER WHERE pro_business_id IS NULL |
| 29 | Contact Deletion Rate | deleted events / total contacts | FCT_PRO_CONTACT_MASTER_EVENTS |
| 30 | Multi-Contact Dealers | Dealers with 3+ contacts (high adoption depth) | BRIDGE GROUP BY pro_business_id |

---

## Lead Funnel Metrics

| # | Metric | Logic | Source |
|---|--------|-------|--------|
| 31 | Funnel Conversion Rate (end-to-end) | APPROVED / (GUEST + LEAD_CREATED) | FCT_LEAD_FUNNEL |
| 32 | Failure Rate by Reason | GROUP BY failure_reason | FCT_LEAD_FUNNEL |
| 33 | Approval Rate by Business Type | Approved / total per primary_business_type | FCT_LEAD_FUNNEL |
| 34 | Approval Rate by Source | PROWEB vs SALESFORCE approval rates | FCT_LEAD_FUNNEL |
| 35 | Sales Rep Effectiveness | Approvals per sales_rep_name | FCT_LEAD_FUNNEL |
| 36 | Sales Rep Avg Approval Time | AVG(seconds_in_stage) per rep | FCT_LEAD_FUNNEL |
| 37 | Peak Registration Days | Day-of-week analysis of created events | FCT_LEAD_FUNNEL |
| 38 | Guest-to-Lead Drop-off | Guests who never became leads | FCT_LEAD_FUNNEL |
| 39 | Duplicate Registration Attempts | creation-failed events / total attempts | FCT_LEAD_FUNNEL |
| 40 | Lead Velocity (trend) | New leads per week — increasing or decreasing | FCT_LEAD_FUNNEL |

---

## Marketing & Attribution Metrics

| # | Metric | Logic | Source |
|---|--------|-------|--------|
| 41 | Registrations by UTM Source | GROUP BY utm_source | FCT_PRO_BUSINESS_MASTER_EVENTS |
| 42 | Registrations by UTM Campaign | GROUP BY utm_campaign | FCT_PRO_BUSINESS_MASTER_EVENTS |
| 43 | Conversion Rate by Campaign | Approved dealers per campaign / registered per campaign | FCT_PRO_BUSINESS_MASTER_EVENTS + FCT_LEAD_FUNNEL |
| 44 | Top Performing Channel | utm_medium with highest approval rate | FCT_PRO_BUSINESS_MASTER_EVENTS |
| 45 | Campaign ROI Proxy | Enrolled dealers (with rewards ACTIVE) per campaign | Cross-join events + dims |

---

## Subscription & IoT Metrics

| # | Metric | Logic | Source |
|---|--------|-------|--------|
| 46 | IoT Subscription Penetration | Dealers with active subscription / total active dealers | DIM_PRO_SUBSCRIPTION_MASTER + DIM_PRO_BUSINESS_MASTER |
| 47 | Subscription by Dealer Type | IoT adoption rate per business_type | Cross-join dims |
| 48 | Subscription Growth | New subscriptions per month | DIM_PRO_SUBSCRIPTION_MASTER by created_at |

---

## Geographic Metrics

| # | Metric | Logic | Source |
|---|--------|-------|--------|
| 49 | Dealer Density by State | COUNT per billing_state | DIM_PRO_BUSINESS_MASTER |
| 50 | Top Cities by Dealer Count | GROUP BY billing_city | DIM_PRO_BUSINESS_MASTER |
| 51 | Geographic Coverage Gaps | States with < N dealers | DIM_PRO_BUSINESS_MASTER |
| 52 | Regional Onboarding Rate | First login rate per state | Cross-join contact + location |
| 53 | State Code Quality | COUNT(inconsistent state values: CA vs California) | DIM_PRO_BUSINESS_LOCATION_MASTER |

---

## Operational / Data Quality Metrics

| # | Metric | Logic | Source |
|---|--------|-------|--------|
| 54 | Event Volume Trend | Events per day/week | FCT_PRO_BUSINESS_MASTER_EVENTS + FCT_PRO_CONTACT_MASTER_EVENTS |
| 55 | Reconciliation Frequency | Runs per day | FCT_RECONCILIATION |
| 56 | Reconciliation Config Drift | Changed config versions over time | FCT_RECONCILIATION |
| 57 | Duplicate Event Rate | (total raw - distinct event_ids) / total | Raw table query |
| 58 | Null FK Rate | Contacts without pro_business_id / total | DIM_PRO_CONTACT_MASTER |
| 59 | Event Processing Lag | AVG(kafka_create_time - event_time) | Staging metadata |
| 60 | Data Completeness Score | % of non-null key fields per dealer | DIM_PRO_BUSINESS_MASTER |

---

## Summary by Category

| Category | Metrics | Primary Source |
|----------|:-------:|---------------|
| Dealer Network | 10 | DIM_PRO_BUSINESS_MASTER + FCT_PRO_BUSINESS_MASTER_EVENTS |
| Distributor | 6 | DIM_PRO_ASSOCIATED_DISTRIBUTOR |
| Programs & Rewards | 7 | DIM_PRO_PROGRAM_OPT_IN + DIM_PRO_BUSINESS_MASTER |
| Contacts & Users | 7 | DIM_PRO_CONTACT_MASTER + FCT_PRO_CONTACT_MASTER_EVENTS |
| Lead Funnel | 10 | FCT_LEAD_FUNNEL |
| Marketing & Attribution | 5 | FCT_PRO_BUSINESS_MASTER_EVENTS (utm fields) |
| Subscriptions & IoT | 3 | DIM_PRO_SUBSCRIPTION_MASTER |
| Geography | 5 | DIM_PRO_BUSINESS_MASTER + DIM_PRO_BUSINESS_LOCATION_MASTER |
| Operational / Data Quality | 7 | All sources |
| **Total** | **60** | |

---

## Priority for Power BI Dashboards

### Must-Have (add to existing dashboards)

| Metric | Dashboard | Why |
|--------|-----------|-----|
| Dealer Growth Rate (WoW) | Dealer Adoption | Shows momentum |
| Funnel Conversion Rate (end-to-end) | Lead Conversion | The headline number |
| Sales Rep Effectiveness | Lead Conversion | Attribution for sales team |
| Program Penetration Rate | Dealer Health | Are dealers engaging? |
| Contacts per Dealer | User Onboarding | Depth of adoption |

### Nice-to-Have (phase 2)

| Metric | Dashboard | Why |
|--------|-----------|-----|
| Registrations by UTM Campaign | Marketing | Campaign ROI |
| Geographic heatmap | Executive | Coverage visibility |
| Duplicate Registration trend | Operations | Platform friction |
| IoT Subscription Penetration | Product | Connected product adoption |
| Data Completeness Score | Data Quality | Trust in the data |
