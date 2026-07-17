{{
    config(materialized='view', tags=['dimensions']
    )
}}

/*
  dim_pro_subscription_master
  ===========================
  Grain: One row per (pro_business_id, subscription_id)
  Source: stg_pro_business_subscriptions (already deduped to latest state)
  Purpose: Subscription dimension per dealer business
*/

select
    pro_business_id,
    subscription_id,
    subscription_name,
    subscription_status,
    program_start_date,
    source,
    subscription_created_at,
    subscription_updated_at,
    subscription_created_by,
    subscription_updated_by,
    event_time as last_event_time

from {{ ref('stg_pro_business_subscriptions') }}


