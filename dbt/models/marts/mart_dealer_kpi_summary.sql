{{
    config(materialized='table', tags=['marts']
    )
}}

/*
  mart_dealer_kpi_summary
  =======================
  Purpose: Pre-aggregated dealer-level KPI mart for dashboard consumption
  Grain: One row per pro_business_id
  KPIs:
    - Total Active Dealer Accounts (30d/90d/year)
    - Total Enrolled Dealers
    - Total Dealer Accounts Not Set Up
    - Total Inactive Dealers
    - TAU per Dealer Account
    - Time to Approve Lead
  Segmentation: key_account, primary_business_type, achiever_level, business_segment
*/

with dealer_activity as (
    select * from {{ ref('fct_pro_business_master_snapshot') }}
),

user_counts as (
    select
        pro_business_id,
        count(*) as total_users,
        count(case when is_active_30d then 1 end) as active_users_30d,
        count(case when is_active_90d then 1 end) as active_users_90d,
        count(case when is_active_1y then 1 end) as active_users_1y,
        count(case when has_login_setup then 1 end) as users_with_login,
        count(case when is_inactive then 1 end) as inactive_users,
        count(case when is_technician then 1 end) as technician_count,
        count(case when is_dealer then 1 end) as dealer_contact_count
    from {{ ref('fct_pro_contact_master_snapshot') }}
    where pro_business_id is not null
    group by pro_business_id
)

select
    -- Dimension keys
    da.pro_business_id,
    da.business_name,

    -- Segmentation attributes
    da.business_status,
    da.login_status,
    da.registration_source,
    da.primary_business_type,
    da.business_segment,
    da.is_primary_key_account,
    da.key_account_type_name,
    da.rewards_achiever_level,

    -- Lifecycle
    da.first_created_at,
    da.first_approved_at,
    da.business_created_at,
    da.last_business_event_time,

    -- KPI: Time to Approve (seconds and days)
    da.seconds_to_approve,
    round(da.seconds_to_approve / 86400.0, 2) as days_to_approve,

    -- KPI: Dealer Activity Flags
    da.is_enrolled,
    da.has_login_setup,
    da.is_active_30d,
    da.is_active_90d,
    da.is_active_1y,
    da.is_inactive,

    -- KPI: TAU per Dealer
    coalesce(uc.total_users, 0) as total_users,
    coalesce(uc.active_users_30d, 0) as active_users_30d,
    coalesce(uc.active_users_90d, 0) as active_users_90d,
    coalesce(uc.active_users_1y, 0) as active_users_1y,
    coalesce(uc.users_with_login, 0) as users_with_login,
    coalesce(uc.inactive_users, 0) as inactive_users,
    coalesce(uc.technician_count, 0) as technician_count,
    coalesce(uc.dealer_contact_count, 0) as dealer_contact_count,

    -- Contact activity from dealer fact
    da.total_contacts,
    da.contacts_with_login,
    da.last_contact_login_date

from dealer_activity da
left join user_counts uc on da.pro_business_id = uc.pro_business_id


