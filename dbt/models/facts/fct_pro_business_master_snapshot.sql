{{
    config(materialized='view', tags=['facts']
    )
}}

/*
  fct_pro_business_master_snapshot
  ================================
  Grain: One row per pro_business_id (snapshot of current activity state)
  Source: stg_pro_business_master_events + stg_pro_contact_master_events
  KPIs supported:
    - Total Active Dealer Accounts (logged in within 30/90/365 days)
    - Total Enrolled Dealers (status = APPROVED with login)
    - Total Dealer Accounts Not Set Up (never logged in)
    - Total Inactive Dealers (have login but inactive)
    - TAU per Dealer Account
    - Stickiness Ratio Dealers (WAU / MAU)
*/

with business_latest as (
    select
        pro_business_id,
        business_name,
        business_status,
        login_status,
        registration_source,
        primary_business_type,
        business_segment,
        is_primary_key_account,
        key_account_type_name,
        rewards_achiever_level,
        primary_contact_id,
        record_created_at as business_created_at,
        event_time as last_business_event_time
    from {{ ref('stg_pro_business_master_events') }}
    where pro_business_id is not null
      and event_detail_type like '%pro-business-master%'
    qualify row_number() over (
        partition by pro_business_id
        order by event_time desc, kafka_offset desc
    ) = 1
),

-- First created event per business (for age calculations)
business_first_created as (
    select
        pro_business_id,
        min(event_time) as first_created_at
    from {{ ref('stg_pro_business_master_events') }}
    where is_created_event = 1
    group by pro_business_id
),

-- First approval event per business
business_first_approved as (
    select
        pro_business_id,
        min(event_time) as first_approved_at
    from {{ ref('stg_pro_business_master_events') }}
    where is_approved_event = 1 or is_lead_approved = 1
    group by pro_business_id
),

-- Contact activity per business
contact_activity as (
    select
        pro_business_id,
        count(distinct pro_contact_id) as total_contacts,
        count(distinct case when is_login_created_event = 1 then pro_contact_id end) as contacts_with_login,
        max(last_login_date) as last_contact_login_date
    from {{ ref('stg_pro_contact_master_events') }}
    where pro_business_id is not null
    group by pro_business_id
)

select
    b.pro_business_id,
    b.business_name,
    b.business_status,
    b.login_status,
    b.registration_source,
    b.primary_business_type,
    b.business_segment,
    b.is_primary_key_account,
    b.key_account_type_name,
    b.rewards_achiever_level,
    b.business_created_at,
    b.last_business_event_time,

    -- Lifecycle timestamps
    fc.first_created_at,
    fa.first_approved_at,

    -- Time-to-approve (seconds)
    datediff('second', fc.first_created_at, fa.first_approved_at) as seconds_to_approve,

    -- Contact activity measures
    coalesce(ca.total_contacts, 0) as total_contacts,
    coalesce(ca.contacts_with_login, 0) as contacts_with_login,
    ca.last_contact_login_date,

    -- Activity classification flags
    case
        when b.business_status in ('APPROVED', 'ACTIVE') and ca.last_contact_login_date is not null then true
        else false
    end as is_enrolled,

    case
        when ca.contacts_with_login > 0 then true
        else false
    end as has_login_setup,

    case
        when ca.last_contact_login_date >= dateadd('day', -30, current_timestamp()) then true
        else false
    end as is_active_30d,

    case
        when ca.last_contact_login_date >= dateadd('day', -90, current_timestamp()) then true
        else false
    end as is_active_90d,

    case
        when ca.last_contact_login_date >= dateadd('year', -1, current_timestamp()) then true
        else false
    end as is_active_1y,

    case
        when ca.contacts_with_login > 0 and ca.last_contact_login_date < dateadd('day', -30, current_timestamp()) then true
        else false
    end as is_inactive

from business_latest b
left join business_first_created fc on b.pro_business_id = fc.pro_business_id
left join business_first_approved fa on b.pro_business_id = fa.pro_business_id
left join contact_activity ca on b.pro_business_id = ca.pro_business_id


