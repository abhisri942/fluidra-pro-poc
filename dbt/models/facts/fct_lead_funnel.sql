{{
    config(materialized='view', tags=['facts']
    )
}}

/*
  fct_lead_funnel
  ===============
  Grain: One row per funnel stage transition (excludes generic 'UPDATED' events)
  Source: stg_pro_business_master_events
  KPIs supported:
    - Time to Approve Lead (seconds_in_stage for LEAD_APPROVED)
    - Approved Leads to Rewards Activated (stage transitions)
    - First Login Rate (GUEST → LEAD_CREATED → LEAD_APPROVED timeline)
    - Leads Rejection Rate (LEAD_REJECTED / total leads)
    - New Dealer Accounts Created (BUSINESS_CREATED, LEAD_CREATED, GUEST stages)
*/

select
    event_id,
    event_detail_type,
    event_time,
    event_date,

    -- Dimension keys
    pro_business_id,
    primary_contact_id,

    -- Business context for segmentation
    primary_business_email,
    crm_lead_id,
    sales_rep_name,
    sales_rep_email,
    business_status,
    primary_business_type,
    business_segment,
    registration_source,
    is_primary_key_account,
    key_account_type_name,

    -- Funnel measures
    funnel_stage,
    seconds_in_stage,
    failure_reason,

    -- Audit
    record_created_at

from {{ ref('stg_pro_business_master_events') }}
where funnel_stage != 'UPDATED'


