{{
  config(
    materialized='table',
    schema='DIMENSIONS',
    tags=['dimensions', 'subscription']
  )
}}

/*
  Dimension: dim_pro_subscription_master
  Type: Type 1 SCD (overwrite on refresh)
  Grain: One row per (pro_business_id, subscription_id)
  Design: Pure Kimball — outrigger/child dimension of dim_pro_business_master.
           Attributes only.
  Source: stg_pro_subscription_master
*/

SELECT
    -- Surrogate key
    subscription_sk,

    -- FK to business dimension
    pro_business_id,

    -- Subscription attributes
    subscription_id,
    subscription_name,
    subscription_status,
    program_start_date,
    source,

    -- Audit
    subscription_created_at,
    subscription_updated_at,
    subscription_created_by,
    subscription_updated_by,
    event_time AS last_event_time

FROM {{ ref('stg_pro_subscription_master') }}
