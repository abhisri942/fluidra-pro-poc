{{
  config(
    materialized='table',
    schema='DIMENSIONS',
    tags=['dimensions', 'program']
  )
}}

/*
  Dimension: dim_pro_program_opt_in
  Type: Type 1 SCD (overwrite on refresh)
  Grain: One row per (pro_business_id, program_name)
  Design: Pure Kimball — outrigger/child dimension of dim_pro_business_master.
           Attributes only.
  Source: stg_pro_program_opt_in
*/

SELECT
    -- Surrogate key
    program_opt_in_sk,

    -- FK to business dimension
    pro_business_id,

    -- Program attributes
    program_name,
    program_status,
    program_opt_in_date,
    program_start_date,
    fluidra_account_number,
    source,

    -- Audit
    program_created_at,
    program_updated_at,
    program_created_by,
    program_updated_by,
    event_time AS last_event_time

FROM {{ ref('stg_pro_program_opt_in') }}
