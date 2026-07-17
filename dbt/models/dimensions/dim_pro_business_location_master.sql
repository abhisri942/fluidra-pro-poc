{{
    config(materialized='view', tags=['dimensions']
    )
}}

/*
  dim_pro_business_location_master
  ================================
  Grain: One row per pro_location_id
  Source: stg_pro_business_location_master (already deduped to latest state)
  Purpose: Location dimension for dealer business addresses
*/

select
    pro_location_id,
    pro_business_id,
    location_name,
    location_type,
    location_status,
    street_line_1,
    street_line_2,
    city,
    state,
    zip,
    country,
    phone_number,
    lead_management_email,
    hide_address,
    hide_location,
    service_zip_count,
    created_at,
    event_time as last_event_time

from {{ ref('stg_pro_business_location_master') }}


