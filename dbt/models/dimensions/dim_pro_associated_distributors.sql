{{
  config(
    materialized='table',
    schema='DIMENSIONS',
    tags=['dimensions', 'distributor']
  )
}}

/*
  Dimension: dim_pro_associated_distributors
  Type: Type 1 SCD (overwrite on refresh)
  Grain: One row per (pro_business_id, distributor_name, distributor_account_number)
  Design: Pure Kimball — outrigger/child dimension of dim_pro_business_master.
           Attributes only, no counts.
  Source: stg_pro_associated_distributors
*/

SELECT
    -- Surrogate key
    distributor_sk,

    -- FK to business dimension
    pro_business_id,

    -- Distributor attributes
    distributor_name,
    distributor_account_number,
    distributor_account_status,
    fluidra_account_number,
    source,
    active_date,

    -- Audit
    distributor_created_at,
    distributor_updated_at,
    distributor_created_by,
    distributor_updated_by,
    event_time AS last_event_time

FROM {{ ref('stg_pro_associated_distributors') }}
