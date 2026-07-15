{{
  config(
    materialized='table',
    schema='MARTS',
    tags=['marts', 'metric', 'contact']
  )
}}

/*
  Mart: metric_contact_activity
  Type: Pre-aggregated KPI metric
  Purpose: Contact event activity summary by date for engagement tracking
  Grain: One row per (event_date, metadata_event_type)
*/

SELECT
    event_date,
    metadata_event_type,
    COUNT(*) AS event_count,
    COUNT(DISTINCT pro_contact_id) AS unique_contacts,
    SUM(is_created_event) AS contacts_created,
    SUM(is_login_created_event) AS logins_created,
    SUM(is_deleted_event) AS contacts_deleted
FROM {{ ref('fct_pro_contact_master_events') }}
GROUP BY event_date, metadata_event_type
ORDER BY event_date DESC
