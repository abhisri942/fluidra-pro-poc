{{
    config(materialized='view', tags=['facts']
    )
}}

/*
  fct_pro_contact_master_events
  =============================
  Grain: One row per contact event
  Source: stg_pro_contact_master_events
  KPIs supported:
    - Total Active Users (TAU) — login-created events + last_login_date
    - New Technician Accounts Created (is_created_event where contact_type = technician)
    - TAU per Dealer Account (join to dim_pro_business_master)
    - Stickiness Ratio (DAU/WAU/MAU from login events)
    - Total Inactive Users (no login-created events in period)
*/

select
    event_id,
    event_detail_type,
    event_time,
    event_date,
    kafka_offset,
    metadata_event_type,
    correlation_id,

    -- Dimension keys
    pro_contact_id,
    pro_business_id,

    -- Contact attributes for segmentation
    contact_type,
    login_status,
    contact_status,
    email,
    last_login_date,

    -- Event type flags (additive measures)
    is_created_event,
    is_updated_event,
    is_login_created_event,
    is_deleted_event,

    -- Measures
    assigned_location_count,
    user_subscription_count,

    -- Audit
    record_created_at

from {{ ref('stg_pro_contact_master_events') }}


