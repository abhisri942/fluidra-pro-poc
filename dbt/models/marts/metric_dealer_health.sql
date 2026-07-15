{{
  config(
    materialized='table',
    schema='MARTS',
    tags=['marts', 'metric', 'dealer']
  )
}}

/*
  Mart: metric_dealer_health
  Type: Pre-aggregated KPI metric
  Purpose: Dealer health distribution for executive dashboards
  Grain: One row per health_status (aggregated)
*/

SELECT
    health_status,
    COUNT(*) AS dealer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM {{ ref('fct_pro_business_master_snapshot') }}
GROUP BY health_status
ORDER BY dealer_count DESC
