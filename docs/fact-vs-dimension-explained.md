# Fact vs Dimension: Why "Business Master" Appears in Both Layers

## 1. Dimension vs Fact — Same Entity, Different Purpose

The `pro_business_master` entity appears in both the dimension and fact layers because they serve fundamentally different purposes. This is a standard Kimball dimensional modeling pattern, not duplication.

### dim_pro_business_master — "What does this dealer look like *right now*?"

- **Grain:** One row per `pro_business_id` (latest state only)
- **Contains:** Current attributes — name, status, segment, channel, login_status
- **Role:** Used for filtering and grouping in queries
- **Example question:** "Show me only active dealers in the commercial segment"

### fct_pro_business_master_events — "What *happened* to this dealer over time?"

- **Grain:** One row per *event* (many rows per business)
- **Contains:** Full event history — created, updated, approved, rejected, failed
- **Role:** Used for counting and trending
- **Example question:** "How many dealers were created this month?", "What's the rejection rate over time?"

### How They Work Together

The dimension is the **noun** (the dealer entity). The fact is the **verb** (what the dealer did or what happened to it). You join them together:

```sql
select
    d.business_segment,
    count(*) as new_dealers
from fct_pro_business_master_events f
join dim_pro_business_master d
    on f.pro_business_id = d.pro_business_id
where f.is_created_event = 1
group by d.business_segment
```

The same pattern applies to contacts: `dim_pro_contact_master` (current user state) vs `fct_pro_contact_master_events` (user lifecycle events).

The "business_master" in both names reflects that they derive from the same source system entity (`pro-business-master` events from Kafka). The prefix (`dim_` vs `fct_`) distinguishes their role in the model.

---

## 2. Transaction Fact vs Snapshot Fact — fct_pro_business_master_events vs fct_pro_business_master_snapshot

These are two different fact types in classical Kimball modeling:

| | `fct_pro_business_master_events` | `fct_pro_business_master_snapshot` |
|--|--|--|
| **Fact Type** | Transaction fact | Periodic snapshot fact |
| **Grain** | 1 row per *event* | 1 row per *dealer* |
| **Growth** | Grows with every new event (append-only) | Relatively stable (one row per dealer) |
| **Answers** | "What happened?" | "What's the current state?" |
| **Example** | "How many dealers were created this month?" | "How many dealers are active right now?" |

### fct_pro_business_master_events (Transaction Fact)

A raw event log where every create, update, approve, and reject is a separate row. It's append-only and ideal for:
- Time-series analysis and trending
- Event counting by period
- Funnel/conversion analysis over time

### fct_pro_business_master_snapshot (Periodic Snapshot Fact)

Collapses all events into one row per dealer showing their current computed state. It combines data from both business events *and* contact events to derive pre-computed flags:
- `is_active_30d` / `is_active_90d` / `is_active_1y`
- `is_enrolled`
- `is_inactive`
- `has_login_setup`
- `seconds_to_approve`

### When to Use Which

| Use Case | Model |
|----------|-------|
| "Count of new dealers in March" | `fct_pro_business_master_events` |
| "Rejection rate trend by week" | `fct_pro_business_master_events` |
| "How many dealers are currently active?" | `fct_pro_business_master_snapshot` |
| "Average time-to-approve" | `fct_pro_business_master_snapshot` |
| "Dealers not set up (never logged in)" | `fct_pro_business_master_snapshot` |

### Relationship

They are complementary. The activity snapshot is essentially pre-computed aggregations and flags derived *from* the events fact, optimized so dashboards don't have to re-calculate window functions at query time.

```
stg_pro_business_master_events
    │
    ├──► fct_pro_business_master_events   (raw events, full history)
    │
    └──► fct_pro_business_master_snapshot              (one row per dealer, current state)
              ▲
              │
         stg_pro_contact_master_events    (also contributes login data)
```
