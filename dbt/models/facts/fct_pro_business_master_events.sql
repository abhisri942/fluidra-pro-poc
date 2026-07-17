{{
    config(materialized='view', tags=['facts']
    )
}}

/*
  fct_pro_business_master_events
  ==============================
  Grain: One row per business event
  Source: stg_pro_business_master_events
  KPIs supported:
    - New Dealer Accounts Created (is_created_event)
    - Total Active Dealer Accounts (via login events)
    - Total Enrolled Dealers (approved events)
    - Leads Rejection Rate (is_rejected_event, is_lead_rejected)
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
    pro_business_id,
    primary_contact_id,
    billing_location_id,

    -- Descriptors for filtering/segmentation
    business_status,
    login_status,
    registration_source,
    primary_business_type,
    business_segment,
    channel,
    customer_class,
    sales_channel,
    is_primary_key_account,
    key_account_type_name,

    -- Measures
    distributor_count,
    program_opt_in_count,
    subscription_count,

    -- Event type flags (additive measures)
    is_created_event,
    is_updated_event,
    is_approved_event,
    is_rejected_event,
    is_creation_failed,
    is_update_requested,
    is_lead_approved,
    is_lead_rejected,

    -- UTM attribution
    utm_source,
    utm_medium,
    utm_campaign,

    -- Failure detail
    failure_reason,

    -- Audit
    record_created_at

from {{ ref('stg_pro_business_master_events') }}
where event_detail_type like '%pro-business-master%'


