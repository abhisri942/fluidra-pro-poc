{{
  config(
    materialized='table',
    schema='DIMENSIONS',
    tags=['dimensions', 'location']
  )
}}

/*
  Dimension: dim_pro_business_location_master
  Type: Type 1 SCD (overwrite on refresh)
  Grain: One row per pro_location_id
  Design: Pure Kimball — outrigger/child dimension of dim_pro_business_master.
           Attributes only.
  Source: stg_pro_business_location_master
*/

SELECT
    -- Surrogate key
    location_sk,

    -- Natural key
    pro_location_id,

    -- FK to business dimension
    pro_business_id,

    -- Location attributes
    location_name,
    location_type,
    location_status,

    -- Address
    street_line_1,
    street_line_2,
    city,
    state,
    zip,
    country,

    -- Contact
    phone_number,
    lead_management_email,

    -- Flags
    hide_address,
    hide_location,
    service_zip_count,

    -- Audit
    created_at,
    event_time AS last_event_time

FROM {{ ref('stg_pro_business_location_master') }}
