{{
  config(
    materialized='table',
    schema='DIMENSIONS',
    tags=['dimensions', 'business']
  )
}}

/*
  Dimension: dim_pro_business_master
  Type: Type 1 SCD (overwrite on refresh)
  Grain: One row per pro_business_id
  Design: Pure Kimball THIN dimension — attributes/descriptors ONLY, no counts or measures.
  Source: stg_pro_business_master
*/

SELECT
    -- Surrogate key
    pro_business_sk,

    -- Natural key
    pro_business_id,

    -- Business identity
    business_name,
    doing_business_as,
    business_status,
    login_status,
    registration_source,

    -- Classification
    customer_type,
    primary_business_type,
    business_segment,
    channel,
    customer_class,
    sales_channel,

    -- Contact info
    primary_business_email,
    primary_business_phone,
    website,

    -- Key account attributes
    is_primary_key_account,
    key_account_type_name,
    key_account_type_role,

    -- External identifiers
    fluidra_account_number,
    crm_lead_id,
    web_account_id,

    -- Flags
    is_pro_login_allowed,
    terms_accepted,
    e_statement_enabled,
    is_marcom_consent,
    tse_violator,

    -- Rewards attributes (descriptors, NOT measures)
    rewards_program_level,
    rewards_achiever_level,
    rewards_program_status,
    rewards_rebate_pay_type,
    rewards_region,
    rewards_auto_zodiac,
    rewards_signup_date,

    -- Primary contact attributes (embedded 1:1 relationship)
    primary_contact_id,
    primary_contact_type,
    primary_contact_first_name,
    primary_contact_last_name,
    primary_contact_login_status,
    primary_contact_cognito_sub_id,

    -- Location attributes
    billing_location_id,
    billing_city,
    billing_state,
    billing_zip,
    billing_country,
    shipping_location_id,
    shipping_city,
    shipping_state,

    -- Sales rep attributes
    sales_rep_name,
    sales_rep_email,

    -- UTM attribution (descriptors)
    utm_source,
    utm_medium,
    utm_campaign,

    -- Audit
    created_at,
    created_by,
    updated_at,
    event_time AS last_event_time

FROM {{ ref('stg_pro_business_master') }}
