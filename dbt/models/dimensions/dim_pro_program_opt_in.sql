{{
    config(materialized='view', tags=['dimensions']
    )
}}

/*
  dim_pro_program_opt_in
  ======================
  Grain: One row per (pro_business_id, program_name)
  Source: stg_pro_business_program_optins (already deduped to latest state)
  Purpose: Program enrollment dimension per dealer business
*/

select
    pro_business_id,
    program_name,
    program_status,
    program_opt_in_date,
    program_start_date,
    fluidra_account_number,
    source,
    program_created_at,
    program_updated_at,
    program_created_by,
    program_updated_by,
    event_time as last_event_time

from {{ ref('stg_pro_business_program_optins') }}


