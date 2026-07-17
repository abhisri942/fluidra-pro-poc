{{
    config(materialized='view', tags=['dimensions']
    )
}}

/*
  dim_pro_contact_master
  ======================
  Grain: One row per pro_contact_id — latest state
  Source: stg_pro_contact_master_events + bridge from business events
  Purpose: Contact dimension with business linkage (fills missing pro_business_id)
*/

with contact_standalone as (
    select *
    from {{ ref('stg_pro_contact_master_events') }}
),

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
    c.pro_contact_id,
    coalesce(c.pro_business_id, b.pro_business_id) as pro_business_id,
    c.contact_type,
    c.first_name,
    c.last_name,
    c.email,
    c.phone_number,
    c.login_status,
    c.username,
    c.cognito_sub_id,
    c.web_user_id,
    c.last_login_date,
    c.contact_status,
    c.is_deleted_event,
    c.record_created_at as created_at,
    c.event_time as last_event_time

from contact_standalone c
left join bridge b on c.pro_contact_id = b.pro_contact_id
qualify row_number() over (
    partition by c.pro_contact_id
    order by c.event_time desc, c.kafka_offset desc
) = 1


