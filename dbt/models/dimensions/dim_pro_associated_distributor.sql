{{
    config(materialized='view', tags=['dimensions']
    )
}}

/*
  dim_pro_associated_distributor
  ==============================
  Grain: One row per (pro_business_id, distributor_name, distributor_account_number)
  Source: stg_pro_business_distributors (already deduped to latest state)
  Purpose: Distributor relationships per dealer business
*/

select
    pro_business_id,
    distributor_name,
    distributor_account_number,
    distributor_account_status,
    fluidra_account_number,
    source,
    active_date,
    distributor_created_at,
    distributor_updated_at,
    distributor_created_by,
    distributor_updated_by,
    event_time as last_event_time

from {{ ref('stg_pro_business_distributors') }}


