# Fact Table Design Rationale — 3 Facts vs 1 Merged Fact

## Executive Summary

This document provides the architectural justification for splitting event data into
**3 separate fact tables** (FCT_PRO_BUSINESS_MASTER_EVENTS, FCT_PRO_CONTACT_MASTER_EVENTS, FCT_LEAD_FUNNEL)
rather than a single merged `FCT_ALL_EVENTS` table. The decision follows Kimball dimensional
modeling principles and is driven by grain clarity, query simplicity, and NULL elimination.

---

## 1. The Question

All 3 fact tables share `event_id` as PK and source from the same raw table
(`EVENTS__RAW_FLUIDRA`). Why not keep a single unified fact table?

---

## 2. The 3 Axes of Separation

### 2.1 Different Grain (What One Row Represents)

| Fact Table | Grain | Primary Entity | Source Event Types |
|-----------|-------|----------------|-------------------|
| FCT_PRO_BUSINESS_MASTER_EVENTS | One business-level event | `pro_business_id` | `pro-business-master.*`, `pro-business-lead.*` |
| FCT_PRO_CONTACT_MASTER_EVENTS | One contact-level event | `pro_contact_id` | `pro-contact-master.*` |
| FCT_LEAD_FUNNEL | One funnel stage transition | `pro_business_id` + stage | `*.created`, `*.approved`, `*.rejected`, `*.creation-failed` |

A dealer creation event is fundamentally NOT a contact login event. They describe
different business processes at different entity levels.

### 2.2 Different Measures (What You Aggregate)

| Fact Table | Measures | Business Domain |
|-----------|----------|-----------------|
| FCT_PRO_BUSINESS_MASTER_EVENTS | `distributor_count`, `program_opt_in_count`, `utm_*`, `is_created/approved/rejected` | Network growth & composition |
| FCT_PRO_CONTACT_MASTER_EVENTS | `is_login_created`, `contact_type`, `is_created_event` | User onboarding & activation |
| FCT_LEAD_FUNNEL | `seconds_in_stage`, `funnel_stage`, `failure_reason`, `sales_rep_name` | Conversion pipeline efficiency |

These measures don't make sense together in one row. You would never
SUM `distributor_count` alongside `seconds_in_stage`.

### 2.3 Different Conforming Dimensions (What You Slice By)

| Fact Table | Primary Dimensions |
|-----------|-------------------|
| FCT_PRO_BUSINESS_MASTER_EVENTS | DIM_DEALER, DIM_LOCATION, DIM_DATE |
| FCT_PRO_CONTACT_MASTER_EVENTS | DIM_CONTACT, DIM_DEALER (via bridge), DIM_DATE |
| FCT_LEAD_FUNNEL | DIM_DEALER, DIM_SALES_REP, DIM_DATE |

---

## 3. What a Single Merged Fact Table Looks Like

### 3.1 Sample Data — FCT_ALL_EVENTS (Merged)

```
| event_id | event_time | pro_business_id | pro_contact_id | event_type                          | distributor_count | program_count | utm_source | is_created | is_approved | contact_type | is_login_created | funnel_stage    | seconds_in_stage | sales_rep      | failure_reason  |
|----------|------------|-----------------|----------------|-------------------------------------|-------------------|---------------|------------|------------|-------------|--------------|-----------------|-----------------|------------------|----------------|-----------------|
| evt-001  | 2026-06-16 | biz-123         | NULL           | pro-business-master.created.v1      | 2                 | 1             | google     | 1          | 0           | NULL         | NULL            | LEAD_CREATED    | 0                | NULL           | NULL            |
| evt-002  | 2026-06-16 | NULL            | con-456        | pro-contact-master.created.v1       | NULL              | NULL          | NULL       | NULL       | NULL        | TECHNICIAN   | 0               | NULL            | NULL             | NULL           | NULL            |
| evt-003  | 2026-06-16 | NULL            | con-456        | pro-contact-master.login-created.v1 | NULL              | NULL          | NULL       | NULL       | NULL        | NULL         | 1               | NULL            | NULL             | NULL           | NULL            |
| evt-004  | 2026-06-17 | biz-123         | NULL           | pro-business-lead.approved.v1       | NULL              | NULL          | NULL       | NULL       | NULL        | NULL         | NULL            | LEAD_APPROVED   | 5                | Jeet Navadhare | NULL            |
| evt-005  | 2026-06-17 | biz-789         | NULL           | pro-business-master.creation-failed | NULL              | NULL          | NULL       | NULL       | NULL        | NULL         | NULL            | CREATION_FAILED | 0                | NULL           | Duplicate email |
```

**Problem: 60-70% of cells are NULL per row.** Every column that doesn't apply to
that event type is wasted storage and confuses consumers.

### 3.2 Same Data — 3 Separate Facts (Clean)

**FCT_PRO_BUSINESS_MASTER_EVENTS:**
```
| event_id | event_time | pro_business_id | event_detail_type              | distributor_count | program_opt_in_count | utm_source | is_created | is_approved | is_rejected |
|----------|------------|-----------------|--------------------------------|-------------------|---------------------|------------|------------|-------------|-------------|
| evt-001  | 2026-06-16 | biz-123         | pro-business-master.created.v1 | 2                 | 1                   | google     | 1          | 0           | 0           |
```

**FCT_PRO_CONTACT_MASTER_EVENTS:**
```
| event_id | event_time | pro_contact_id | pro_business_id | contact_type | is_created_event | is_login_created_event |
|----------|------------|----------------|-----------------|--------------|------------------|------------------------|
| evt-002  | 2026-06-16 | con-456        | biz-123         | TECHNICIAN   | 1                | 0                      |
| evt-003  | 2026-06-16 | con-456        | biz-123         | TECHNICIAN   | 0                | 1                      |
```

**FCT_LEAD_FUNNEL:**
```
| event_id | event_time | pro_business_id | funnel_stage    | seconds_in_stage | sales_rep_name | failure_reason  |
|----------|------------|-----------------|-----------------|------------------|----------------|-----------------|
| evt-004  | 2026-06-17 | biz-123         | LEAD_APPROVED   | 5                | Jeet Navadhare | NULL            |
| evt-005  | 2026-06-17 | biz-789         | CREATION_FAILED | 0                | NULL           | Duplicate email |
```

**Every column is meaningful for every row. No wasted NULLs.**

---

## 4. Query Comparison — Same Metric, Two Approaches

### Query 1: "New dealers created per week"

**With 1 Merged Fact (filter hell):**
```sql
SELECT DATE_TRUNC('week', event_time), COUNT(*)
FROM FCT_ALL_EVENTS
WHERE event_detail_type = 'pro-business-master.created.v1'  -- must know exact string
  AND is_created = 1                                         -- redundant safety filter
  AND pro_business_id IS NOT NULL                           -- exclude contact events
  AND (funnel_stage IS NULL OR funnel_stage = 'LEAD_CREATED') -- avoid double-counting
GROUP BY 1;
```

**With 3 Fact Tables (clean):**
```sql
SELECT DATE_TRUNC('week', event_time), SUM(is_created_event)
FROM FCT_PRO_BUSINESS_MASTER_EVENTS
GROUP BY 1;
```

**Winner: 3 facts** — 1 line of logic vs 4 defensive filters.

---

### Query 2: "First login rate by contact type"

**With 1 Merged Fact (awkward):**
```sql
SELECT
    contact_type,
    COUNT(DISTINCT CASE WHEN is_login_created = 1 THEN pro_contact_id END)::FLOAT /
    NULLIF(COUNT(DISTINCT CASE WHEN event_detail_type = 'pro-contact-master.created.v1'
        THEN pro_contact_id END), 0)
FROM FCT_ALL_EVENTS
WHERE pro_contact_id IS NOT NULL       -- exclude 60% of rows (business events)
  AND contact_type IS NOT NULL         -- exclude login events where type isn't repeated
GROUP BY 1;
```

**With 3 Fact Tables (natural):**
```sql
SELECT
    contact_type,
    COUNT(DISTINCT CASE WHEN is_login_created_event = 1 THEN pro_contact_id END)::FLOAT /
    NULLIF(COUNT(DISTINCT CASE WHEN is_created_event = 1 THEN pro_contact_id END), 0)
FROM FCT_PRO_CONTACT_MASTER_EVENTS
GROUP BY contact_type;
```

**Winner: 3 facts** — no row exclusion filters needed, no event_type string knowledge required.

---

### Query 3: "Approval rate with sales rep attribution"

**With 1 Merged Fact (dangerous):**
```sql
SELECT
    sales_rep_name,
    SUM(CASE WHEN funnel_stage = 'LEAD_APPROVED' THEN 1 ELSE 0 END) as approved,
    SUM(CASE WHEN funnel_stage = 'LEAD_REJECTED' THEN 1 ELSE 0 END) as rejected
FROM FCT_ALL_EVENTS
WHERE funnel_stage IS NOT NULL           -- exclude 80% of rows
  AND sales_rep_name IS NOT NULL         -- exclude events without rep
  AND event_detail_type LIKE '%lead%'    -- don't accidentally count business-master.rejected
GROUP BY 1;
```
⚠️ **Risk**: Without the `LIKE '%lead%'` filter, you'd accidentally include
`pro-business-master.rejected` events (different business meaning than lead rejection).

**With 3 Fact Tables (precise):**
```sql
SELECT
    sales_rep_name,
    SUM(CASE WHEN funnel_stage = 'LEAD_APPROVED' THEN 1 ELSE 0 END) as approved,
    SUM(CASE WHEN funnel_stage = 'LEAD_REJECTED' THEN 1 ELSE 0 END) as rejected
FROM FCT_LEAD_FUNNEL
WHERE sales_rep_name IS NOT NULL
GROUP BY 1;
```

**Winner: 3 facts** — the table already contains only funnel events. No risk of mixing event semantics.

---

## 5. Performance Comparison

| Factor | 1 Merged Fact | 3 Separate Facts |
|--------|:------------:|:----------------:|
| Rows scanned for dealer metrics | 363 (all events) | 156 (business events only) |
| Rows scanned for contact metrics | 363 (all events) | 75 (contact events only) |
| Rows scanned for funnel metrics | 363 (all events) | 132 (funnel events only) |
| Column storage waste (NULLs) | ~65% of cells are NULL | ~5% of cells are NULL |
| Partition pruning | Only by date | By date + natural event type separation |
| BI tool auto-join | Complex (must filter event_type first) | Simple (each fact joins to its dims naturally) |
| Query complexity for consumers | High (defensive filtering required) | Low (table = domain boundary) |
| Risk of incorrect aggregation | High (mixing event semantics) | Low (grain is unambiguous) |

### At Scale (Production Projection)

With estimated production volumes:
- ~10,000 business events/month
- ~25,000 contact events/month
- ~5,000 funnel events/month

A merged table would scan **40,000 rows** for every query regardless of domain.
Separate facts scan only the relevant 5,000–25,000 rows per domain.

With Snowflake's columnar storage and micro-partitioning, the 3-table approach
also benefits from better clustering (events of the same type have similar column patterns).

---

## 6. When WOULD a Single Fact Table Make Sense?

A single `FCT_ALL_EVENTS` is valid in these scenarios:

| Scenario | Why It Works |
|----------|-------------|
| **Timeline/Audit queries** | "Show me everything that happened to biz-123 in chronological order" |
| **Data lineage** | Tracking which events flowed through the pipeline |
| **Very small volume** | At 363 rows, performance difference is negligible |
| **ELT staging layer** | A single parsed layer before splitting into domain facts |
| **Event correlation** | Finding relationships between dealer and contact events by time proximity |

### How Our Model Handles This

```
STG_EVENTS_PARSED (unified layer — ALL events, fully parsed)
    │
    ├── FCT_PRO_BUSINESS_MASTER_EVENTS (domain: business/dealer lifecycle)
    ├── FCT_PRO_CONTACT_MASTER_EVENTS (domain: user onboarding)
    └── FCT_LEAD_FUNNEL (domain: conversion pipeline)
```

`STG_EVENTS_PARSED` IS the single unified fact — it already exists as the staging view.
The 3 fact tables are **refined analytical projections** of that unified layer.

If someone needs cross-event-type analysis (e.g., "for dealer biz-123, show me when
the business was created AND when each contact completed login"), they can query
`STG_EVENTS_PARSED` directly or join the facts.

---

## 7. Industry Alignment

### Kimball's Principle (The Data Warehouse Toolkit)

> "The grain of a fact table is the most fundamental decision in dimensional design.
> A fact table should contain facts at one and only one level of grain."

Mixing business-level events (grain: one row per business state change) with
contact-level events (grain: one row per user action) in one table violates this principle.

### Common Patterns in Event-Driven Analytics

| Company Pattern | Approach |
|----------------|----------|
| Snowplow/Segment | Separate `events`, `page_views`, `sessions` fact tables from same stream |
| Salesforce analytics | Separate `Opportunity`, `Lead`, `Activity` fact tables |
| Stripe analytics | Separate `charges`, `refunds`, `subscriptions` fact tables |
| Our model | Separate `pro_business_master_events`, `pro_contact_master_events`, `lead_funnel` from same Kafka stream |

All follow the same principle: one source stream → multiple domain-specific fact tables.

---

## 8. Summary Decision Matrix

| Criteria | 1 Merged Fact | 3 Separate Facts | Winner |
|----------|:---:|:---:|:---:|
| Grain clarity | ❌ Ambiguous | ✅ Unambiguous | 3 Facts |
| NULL percentage | ❌ ~65% | ✅ ~5% | 3 Facts |
| Query simplicity | ❌ Defensive filters | ✅ Direct aggregation | 3 Facts |
| BI tool integration | ❌ Manual filtering | ✅ Natural joins | 3 Facts |
| Risk of wrong answers | ❌ High (mixing semantics) | ✅ Low | 3 Facts |
| Cross-domain timeline | ✅ Natural | ⚠️ Needs join or staging layer | 1 Fact |
| Storage efficiency | ❌ Sparse columns | ✅ Dense columns | 3 Facts |
| Maintenance (schema changes) | ✅ One table to alter | ⚠️ May need to alter multiple | 1 Fact |

**Verdict: 3 Fact Tables is the correct design for analytical consumption.**
The unified staging layer (`STG_EVENTS_PARSED`) provides the single-source-of-truth
for anyone needing cross-domain analysis.

---

## 9. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│              RAW_DB_DEV.FLUIDRAPRO_RAW.EVENTS__RAW_FLUIDRA       │
│              (363 events, 13 event types, single Kafka topic)    │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              STG_EVENTS_PARSED (Unified Staging Layer)            │
│              - Deduplication (290 distinct from 363 raw)          │
│              - JSON parsing to typed columns                      │
│              - ALL event types in ONE view                        │
│              - Use for: audit, lineage, cross-domain queries     │
└──────┬──────────────────────┬──────────────────────┬────────────┘
       │                      │                      │
       ▼                      ▼                      ▼
┌──────────────────────────┐    ┌──────────────────────────────┐    ┌────────────────┐
│FCT_PRO_BUSINESS_MASTER_  │    │FCT_PRO_CONTACT_MASTER_       │    │FCT_LEAD_       │
│EVENTS                    │    │EVENTS                        │    │FUNNEL          │
│──────────────│    │──────────────────│    │────────────────│
│156 rows      │    │75 rows           │    │132 rows        │
│Grain: biz    │    │Grain: contact    │    │Grain: stage    │
│event         │    │event             │    │transition      │
│──────────────│    │──────────────────│    │────────────────│
│Measures:     │    │Measures:         │    │Measures:       │
│• dist_count  │    │• is_login_created│    │• seconds_in_   │
│• program_cnt │    │• contact_type    │    │  stage         │
│• is_created  │    │• is_created      │    │• funnel_stage  │
│• utm_*       │    │                  │    │• sales_rep     │
│• is_approved │    │                  │    │• failure_reason│
└──────┬───────┘    └────────┬─────────┘    └───────┬────────┘
       │                     │                      │
       ▼                     ▼                      ▼
┌──────────────┐    ┌──────────────────┐    ┌────────────────┐
│METRIC_DEALER │    │METRIC_USER_      │    │METRIC_DEALER_  │
│_ADOPTION     │    │ADOPTION          │    │CONVERSION      │
│KPI 1.1-1.5   │    │KPI 3.1-3.7       │    │KPI 2.1-2.4     │
└──────────────┘    └──────────────────┘    └────────────────┘
```
