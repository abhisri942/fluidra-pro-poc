{{
    config(materialized='table', tags=['marts']
    )
}}

/*
  mart_lead_funnel_kpi
  ====================
  Purpose: Lead funnel analysis mart for dashboard
  Grain: One row per pro_business_id (lifecycle summary)
  KPIs:
    - Time to Approve Lead
    - Approved Leads to Rewards Activated
    - Leads Rejection Rate
    - New Dealer Accounts Created (by period)
*/

with funnel_events as (
    select * from {{ ref('fct_lead_funnel') }}
),

-- Pivot: first occurrence of each funnel stage per business
business_funnel as (
    select
        pro_business_id,
        min(case when funnel_stage = 'GUEST' then event_time end) as guest_at,
        min(case when funnel_stage = 'LEAD_CREATED' then event_time end) as lead_created_at,
        min(case when funnel_stage = 'LEAD_APPROVED' then event_time end) as lead_approved_at,
        min(case when funnel_stage = 'BUSINESS_APPROVED' then event_time end) as business_approved_at,
        min(case when funnel_stage = 'LEAD_REJECTED' then event_time end) as lead_rejected_at,
        min(case when funnel_stage = 'BUSINESS_REJECTED' then event_time end) as business_rejected_at,
        min(case when funnel_stage = 'CREATION_FAILED' then event_time end) as creation_failed_at,

        -- Latest stage
        max(event_time) as last_funnel_event_time,

        -- Attributes from latest event
        max_by(primary_business_type, event_time) as primary_business_type,
        max_by(business_segment, event_time) as business_segment,
        max_by(registration_source, event_time) as registration_source,
        max_by(sales_rep_name, event_time) as sales_rep_name,
        max_by(sales_rep_email, event_time) as sales_rep_email,
        max_by(is_primary_key_account, event_time) as is_primary_key_account,
        max_by(key_account_type_name, event_time) as key_account_type_name,
        max_by(failure_reason, event_time) as last_failure_reason
    from funnel_events
    where pro_business_id is not null
    group by pro_business_id
)

select
    pro_business_id,

    -- Segmentation
    primary_business_type,
    business_segment,
    registration_source,
    sales_rep_name,
    sales_rep_email,
    is_primary_key_account,
    key_account_type_name,

    -- Funnel timestamps
    guest_at,
    lead_created_at,
    lead_approved_at,
    business_approved_at,
    lead_rejected_at,
    business_rejected_at,
    creation_failed_at,
    last_funnel_event_time,

    -- KPI: Time to Approve Lead (seconds and days)
    datediff('second', coalesce(lead_created_at, guest_at), lead_approved_at) as seconds_lead_to_approved,
    round(datediff('second', coalesce(lead_created_at, guest_at), lead_approved_at) / 86400.0, 2) as days_lead_to_approved,

    -- KPI: Time from created to business approved
    datediff('second', coalesce(lead_created_at, guest_at), business_approved_at) as seconds_to_business_approved,
    round(datediff('second', coalesce(lead_created_at, guest_at), business_approved_at) / 86400.0, 2) as days_to_business_approved,

    -- Current funnel stage
    case
        when business_approved_at is not null then 'BUSINESS_APPROVED'
        when lead_approved_at is not null then 'LEAD_APPROVED'
        when business_rejected_at is not null then 'BUSINESS_REJECTED'
        when lead_rejected_at is not null then 'LEAD_REJECTED'
        when creation_failed_at is not null then 'CREATION_FAILED'
        when lead_created_at is not null then 'LEAD_CREATED'
        when guest_at is not null then 'GUEST'
        else 'UNKNOWN'
    end as current_funnel_stage,

    -- Rejection flag
    case
        when lead_rejected_at is not null or business_rejected_at is not null then true
        else false
    end as is_rejected,

    last_failure_reason

from business_funnel


