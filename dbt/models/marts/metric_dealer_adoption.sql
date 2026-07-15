{{
  config(
    materialized='table',
    schema='MARTS',
    tags=['marts', 'metric', 'adoption']
  )
}}

/*
  Mart: metric_dealer_adoption
  Type: Pre-aggregated KPI metric
  Purpose: Dealer adoption metrics by business status and login status
  Grain: One row per (business_status, login_status)
*/

SELECT
    business_status,
    login_status,
    COUNT(*) AS dealer_count,
    SUM(CASE WHEN login_status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_login_count,
    ROUND(
        SUM(CASE WHEN login_status = 'ACTIVE' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0),
        2
    ) AS active_login_pct
FROM {{ ref('dim_pro_business_master') }}
GROUP BY business_status, login_status
ORDER BY dealer_count DESC
