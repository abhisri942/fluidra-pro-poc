{{
    config(materialized='view', tags=['dimensions']
    )
}}

/*
  dim_pro_business_master
  =======================
  Grain: One row per pro_business_id — latest state, attributes only
  Source: stg_pro_business_master_events (latest per business)
  Purpose: Thin dimension for dealer/business descriptors
*/

select
    pro_business_id,
    business_name,
    doing_business_as,
    business_status,
    login_status,
    registration_source,
    customer_type,
    primary_business_type,
    business_segment,
    channel,
    customer_class,
    sales_channel,
    primary_business_email,
    primary_business_phone,

    is_primary_key_account,
    key_account_type_name,
    fluidra_account_number,
    crm_lead_id,
    web_account_id,

    terms_accepted,
    e_statement_enabled,
    is_marcom_consent,
    tse_violator,

    -- Rewards attributes (descriptors, not measures)
    rewards_program_level,
    rewards_achiever_level,
    rewards_program_status,
    rewards_rebate_pay_type,
    rewards_signup_date,

    -- Primary contact attributes (embedded 1:1)
    primary_contact_id,
    primary_contact_type,
    primary_contact_login_status,

    -- Location attributes
    billing_location_id,
    billing_city,
    billing_state,

    -- Sales rep attributes
    sales_rep_name,
    sales_rep_email,

    -- UTM (descriptors)
    utm_source,
    utm_medium,
    utm_campaign,

    -- Audit
    record_created_at as created_at,
    record_created_by as created_by,
    event_time as last_event_time

from {{ ref('stg_pro_business_master_events') }}
where pro_business_id is not null
  and event_detail_type like '%pro-business-master%'
qualify row_number() over (
    partition by pro_business_id
    order by event_time desc, kafka_offset desc
) = 1


