{{
  config(
    materialized='table',
    schema='DIMENSIONS',
    tags=['dimensions', 'key_account']
  )
}}

/*
  Dimension: dim_key_account_type
  Type: Type 1 SCD (overwrite on refresh)
  Grain: One row per key_account_type_id
  Design: Pure Kimball — reference/lookup dimension.
           Attributes only.
  Source: stg_key_account_type
*/

SELECT
    -- Surrogate key
    key_account_type_sk,

    -- Natural key
    key_account_type_id,

    -- Key account type attributes
    key_account_type_name,
    key_account_type_role,
    customer_class,
    sales_channel,
    program_name,
    achiever_level,

    -- Flags
    enable_zodiac_premium,
    override_achiever_level_role,
    e_statement_enabled,
    print_statements,

    -- Audit
    created_at,
    created_by,
    event_time AS last_event_time

FROM {{ ref('stg_key_account_type') }}
