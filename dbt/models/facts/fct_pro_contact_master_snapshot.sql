{{
    config(materialized='view', tags=['facts']
    )
}}

/*
  fct_pro_contact_master_snapshot
  ===============================
  Grain: One row per pro_contact_id (snapshot of current user activity state)
  Source: stg_pro_contact_master_events + bridge to business
  KPIs supported:
    - Total Active Users (TAU) — 30d/90d/year
    - Total Users Not Set Up Login
    - Total Inactive Users
    - New Technician Accounts Created
    - First Login Rate (within 14 days)
    - Stickiness Ratio Technicians (DAU / MAU)
    - TAU per Dealer Account
*/

with contact_latest as (
    select
        pro_contact_id,
        pro_business_id,
        contact_type,
        login_status,
        contact_status,
        last_login_date,
        email,
        event_time as last_event_time
    from {{ ref('stg_pro_contact_master_events') }}
    qualify row_number() over (
        partition by pro_contact_id
        order by event_time desc, kafka_offset desc
    ) = 1
),

-- First created event per contact
contact_first_created as (
    select
        pro_contact_id,
        min(event_time) as first_created_at
    from {{ ref('stg_pro_contact_master_events') }}
    where is_created_event = 1
    group by pro_contact_id
),

-- First login-created event per contact
contact_first_login as (
    select
        pro_contact_id,
        min(event_time) as first_login_created_at
    from {{ ref('stg_pro_contact_master_events') }}
    where is_login_created_event = 1
    group by pro_contact_id
),

-- Bridge: fill missing pro_business_id from business events
bridge as (
    select distinct
        parse_json(record_content):detail.data.proBusinessId::string as pro_business_id,
        parse_json(record_content):detail.data.primaryContact.proContactId::string as pro_contact_id
    from {{ source('fluidrapro_raw', 'raw_dealers_data') }}
    where parse_json(record_content):"detail-type"::string like '%pro-business-master%'
      and parse_json(record_content):detail.data.primaryContact.proContactId is not null
      and parse_json(record_content):detail.data.proBusinessId is not null
)

select
    cl.pro_contact_id,
    coalesce(cl.pro_business_id, br.pro_business_id) as pro_business_id,
    cl.contact_type,
    cl.login_status,
    cl.contact_status,
    cl.last_login_date,
    cl.last_event_time,

    -- Lifecycle timestamps
    fc.first_created_at,
    fl.first_login_created_at,

    -- Time to first login (seconds)
    datediff('second', fc.first_created_at, fl.first_login_created_at) as seconds_to_first_login,

    -- First login within 14 days flag
    case
        when fl.first_login_created_at is not null
         and datediff('day', fc.first_created_at, fl.first_login_created_at) <= 14
        then true
        else false
    end as first_login_within_14d,

    -- First login within 7 days flag
    case
        when fl.first_login_created_at is not null
         and datediff('day', fc.first_created_at, fl.first_login_created_at) <= 7
        then true
        else false
    end as first_login_within_7d,

    -- Activity classification
    case
        when cl.last_login_date >= dateadd('day', -30, current_timestamp()) then true
        else false
    end as is_active_30d,

    case
        when cl.last_login_date >= dateadd('day', -90, current_timestamp()) then true
        else false
    end as is_active_90d,

    case
        when cl.last_login_date >= dateadd('year', -1, current_timestamp()) then true
        else false
    end as is_active_1y,

    -- Login setup status
    case
        when fl.first_login_created_at is not null then true
        else false
    end as has_login_setup,

    -- Inactive: has login but not active in 30 days
    case
        when fl.first_login_created_at is not null
         and (cl.last_login_date is null or cl.last_login_date < dateadd('day', -30, current_timestamp()))
        then true
        else false
    end as is_inactive,

    -- Contact role flags
    case when cl.contact_type = 'TECHNICIAN' then true else false end as is_technician,
    case when cl.contact_type = 'DEALER' then true else false end as is_dealer

from contact_latest cl
left join contact_first_created fc on cl.pro_contact_id = fc.pro_contact_id
left join contact_first_login fl on cl.pro_contact_id = fl.pro_contact_id
left join bridge br on cl.pro_contact_id = br.pro_contact_id


