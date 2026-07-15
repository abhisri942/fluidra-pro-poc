{{
  config(
    materialized='table',
    schema='MARTS',
    tags=['marts', 'metric', 'program']
  )
}}

/*
  Mart: metric_program_enrollment
  Type: Pre-aggregated KPI metric
  Purpose: Program enrollment status distribution
  Grain: One row per (program_name, program_status)
*/

SELECT
    program_name,
    program_status,
    COUNT(*) AS enrollment_count,
    COUNT(DISTINCT pro_business_id) AS unique_businesses
FROM {{ ref('dim_pro_program_opt_in') }}
GROUP BY program_name, program_status
ORDER BY enrollment_count DESC
