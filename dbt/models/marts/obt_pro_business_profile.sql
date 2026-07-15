{{
  config(
    materialized='table',
    schema='MARTS',
    tags=['marts', 'obt', 'business']
  )
}}

/*
  Mart: obt_pro_business_profile
  Type: One Big Table (OBT) — denormalized wide table for BI consumption
  Design: Joins dim_pro_business_master (attributes) + fct_pro_business_master_snapshot (measures)
          into a single wide row per dealer for dashboards and self-service analytics.
  Grain: One row per pro_business_id
  This is NOT a dimension — it's the BI consumption layer.
*/

SELECT
    -- Dimension attributes
    d.pro_business_sk,
    d.pro_business_id,
    d.business_name,
    d.doing_business_as,
    d.business_status,
    d.login_status,
    d.registration_source,
    d.customer_type,
    d.primary_business_type,
    d.business_segment,
    d.channel,
    d.customer_class,
    d.sales_channel,
    d.primary_business_email,
    d.primary_business_phone,
    d.website,
    d.is_primary_key_account,
    d.key_account_type_name,
    d.key_account_type_role,
    d.fluidra_account_number,
    d.crm_lead_id,
    d.web_account_id,
    d.is_pro_login_allowed,
    d.terms_accepted,
    d.e_statement_enabled,
    d.is_marcom_consent,
    d.tse_violator,
    d.rewards_program_level,
    d.rewards_achiever_level,
    d.rewards_program_status,
    d.rewards_rebate_pay_type,
    d.rewards_region,
    d.rewards_auto_zodiac,
    d.rewards_signup_date,
    d.primary_contact_id,
    d.primary_contact_type,
    d.primary_contact_first_name,
    d.primary_contact_last_name,
    d.primary_contact_login_status,
    d.primary_contact_cognito_sub_id,
    d.billing_location_id,
    d.billing_city,
    d.billing_state,
    d.billing_zip,
    d.billing_country,
    d.shipping_location_id,
    d.shipping_city,
    d.shipping_state,
    d.sales_rep_name,
    d.sales_rep_email,
    d.utm_source,
    d.utm_medium,
    d.utm_campaign,
    d.created_at,
    d.updated_at,
    d.last_event_time,

    -- Snapshot measures
    f.snapshot_date,
    f.total_distributor_count,
    f.active_distributor_count,
    f.pending_distributor_count,
    f.inactive_distributor_count,
    f.total_program_count,
    f.active_program_count,
    f.pending_program_count,
    f.declined_program_count,
    f.total_subscription_count,
    f.active_subscription_count,
    f.total_contacts,
    f.active_contacts,
    f.days_since_last_login,
    f.health_status

FROM {{ ref('dim_pro_business_master') }} d
LEFT JOIN {{ ref('fct_pro_business_master_snapshot') }} f
    ON d.pro_business_id = f.pro_business_id
