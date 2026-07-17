{{
    config(materialized='view', tags=['dimensions']
    )
}}

/*
  dim_key_account_type
  ====================
  Grain: One row per key_account_type_id
  Source: stg_pro_key_account_types (already deduped to latest state)
  Purpose: Key account type reference dimension
*/

select
    key_account_type_id,
    key_account_type_name,
    key_account_type_role,
    customer_class,
    sales_channel,
    program_name,
    achiever_level,
    enable_zodiac_premium,
    override_achiever_level_role,
    e_statement_enabled,
    print_statements,
    created_at,
    created_by,
    event_time as last_event_time

from {{ ref('stg_pro_key_account_types') }}


