{{
  config(
    materialized='table',
    schema='MARTS',
    tags=['marts', 'metric', 'funnel']
  )
}}

/*
  Mart: metric_funnel_daily
  Type: Pre-aggregated KPI metric
  Purpose: Daily funnel stage counts for conversion analysis
  Grain: One row per (event_date, funnel_stage)
*/

SELECT
    event_date,
    funnel_stage,
    COUNT(*) AS event_count,
    AVG(seconds_in_stage) AS avg_seconds_in_stage,
    MIN(seconds_in_stage) AS min_seconds_in_stage,
    MAX(seconds_in_stage) AS max_seconds_in_stage
FROM {{ ref('fct_lead_funnel') }}
GROUP BY event_date, funnel_stage
ORDER BY event_date DESC, event_count DESC
