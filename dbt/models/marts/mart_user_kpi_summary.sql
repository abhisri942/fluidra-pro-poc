{{
    config(materialized='table', tags=['marts']
    )
}}

/*
  mart_user_kpi_summary
  =====================
  Purpose: Pre-aggregated user-level KPI mart for dashboard consumption
  Grain: One row per pro_contact_id
  KPIs:
    - Total Active Users (TAU) 30d/90d/year
    - Total Users Not Set Up Login
    - Total Inactive Users
    - New Technician Accounts Created
    - First Login Rate (within 7d/14d)
    - Stickiness Ratio prep (login timestamps)
*/

select
    -- Identity
    pro_contact_id,
    pro_business_id,
    contact_type,

    -- Status
    login_status,
    contact_status,
    last_login_date,
    last_event_time,

    -- Lifecycle
    first_created_at,
    first_login_created_at,

    -- KPI: Time to First Login
    seconds_to_first_login,
    round(seconds_to_first_login / 86400.0, 2) as days_to_first_login,

    -- KPI: First Login Rate
    first_login_within_7d,
    first_login_within_14d,

    -- KPI: Activity Classification
    is_active_30d,
    is_active_90d,
    is_active_1y,
    has_login_setup,
    is_inactive,

    -- Role flags
    is_technician,
    is_dealer

from {{ ref('fct_pro_contact_master_snapshot') }}


