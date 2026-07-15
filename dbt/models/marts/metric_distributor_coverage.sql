{{
  config(
    materialized='table',
    schema='MARTS',
    tags=['marts', 'metric', 'distributor']
  )
}}

/*
  Mart: metric_distributor_coverage
  Type: Pre-aggregated KPI metric
  Purpose: Distributor coverage and status distribution
  Grain: One row per distributor_account_status
*/

SELECT
    distributor_account_status,
    COUNT(*) AS distributor_link_count,
    COUNT(DISTINCT pro_business_id) AS unique_businesses,
    COUNT(DISTINCT distributor_name) AS unique_distributors
FROM {{ ref('dim_pro_associated_distributors') }}
GROUP BY distributor_account_status
ORDER BY distributor_link_count DESC
