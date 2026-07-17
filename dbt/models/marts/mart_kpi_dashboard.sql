{{
    config(materialized='table', tags=['marts']
    )
}}

/*
  mart_kpi_dashboard
  ==================
  Purpose: Single-row KPI summary for executive dashboard top-level metrics
  Grain: One row (aggregated totals)
  All KPIs pre-computed for direct dashboard binding
*/

with dealer_stats as (
    select
        count(*) as total_dealers,
        count(case when is_enrolled then 1 end) as total_enrolled_dealers,
        count(case when is_active_30d then 1 end) as active_dealers_30d,
        count(case when is_active_90d then 1 end) as active_dealers_90d,
        count(case when is_active_1y then 1 end) as active_dealers_1y,
        count(case when not has_login_setup then 1 end) as dealers_not_setup,
        count(case when is_inactive then 1 end) as inactive_dealers,
        avg(total_contacts) as avg_contacts_per_dealer,
        avg(case when seconds_to_approve is not null then seconds_to_approve end) as avg_seconds_to_approve
    from {{ ref('fct_pro_business_master_snapshot') }}
),

user_stats as (
    select
        count(*) as total_users,
        count(case when is_active_30d then 1 end) as tau_30d,
        count(case when is_active_90d then 1 end) as tau_90d,
        count(case when is_active_1y then 1 end) as tau_1y,
        count(case when not has_login_setup then 1 end) as users_not_setup,
        count(case when is_inactive then 1 end) as inactive_users,
        count(case when is_technician and first_created_at >= dateadd('day', -30, current_timestamp()) then 1 end) as new_technicians_30d,
        count(case when is_technician and first_created_at >= dateadd('day', -90, current_timestamp()) then 1 end) as new_technicians_90d,

        -- First Login Rate
        count(case when first_login_within_7d then 1 end) as logins_within_7d,
        count(case when first_login_within_14d then 1 end) as logins_within_14d,
        count(case when first_created_at is not null then 1 end) as total_with_created_date
    from {{ ref('fct_pro_contact_master_snapshot') }}
),

funnel_stats as (
    select
        count(distinct case when funnel_stage in ('LEAD_CREATED', 'GUEST') then pro_business_id end) as total_leads_created,
        count(distinct case when funnel_stage in ('LEAD_REJECTED', 'BUSINESS_REJECTED') then pro_business_id end) as total_rejected,
        count(distinct case when funnel_stage in ('LEAD_CREATED', 'GUEST') and event_date >= dateadd('day', -30, current_date()) then pro_business_id end) as new_dealers_30d,
        count(distinct case when funnel_stage in ('LEAD_CREATED', 'GUEST') and event_date >= dateadd('day', -90, current_date()) then pro_business_id end) as new_dealers_90d,
        count(distinct case when funnel_stage in ('LEAD_CREATED', 'GUEST') and event_date >= dateadd('year', -1, current_date()) then pro_business_id end) as new_dealers_1y
    from {{ ref('fct_lead_funnel') }}
)

select
    -- Dealer KPIs
    d.total_dealers,
    d.total_enrolled_dealers,
    d.active_dealers_30d,
    d.active_dealers_90d,
    d.active_dealers_1y,
    d.dealers_not_setup,
    d.inactive_dealers,
    round(d.avg_contacts_per_dealer, 1) as avg_tau_per_dealer,
    round(d.avg_seconds_to_approve / 3600.0, 1) as avg_hours_to_approve,
    round(d.avg_seconds_to_approve / 86400.0, 2) as avg_days_to_approve,

    -- User KPIs
    u.total_users,
    u.tau_30d,
    u.tau_90d,
    u.tau_1y,
    u.users_not_setup,
    u.inactive_users,
    u.new_technicians_30d,
    u.new_technicians_90d,

    -- First Login Rate
    case when u.total_with_created_date > 0
        then round(u.logins_within_7d * 100.0 / u.total_with_created_date, 1)
        else 0
    end as first_login_rate_7d_pct,
    case when u.total_with_created_date > 0
        then round(u.logins_within_14d * 100.0 / u.total_with_created_date, 1)
        else 0
    end as first_login_rate_14d_pct,

    -- Funnel KPIs
    f.total_leads_created,
    f.total_rejected,
    case when f.total_leads_created > 0
        then round(f.total_rejected * 100.0 / f.total_leads_created, 1)
        else 0
    end as leads_rejection_rate_pct,
    f.new_dealers_30d,
    f.new_dealers_90d,
    f.new_dealers_1y,

    -- Metadata
    current_timestamp() as refreshed_at

from dealer_stats d
cross join user_stats u
cross join funnel_stats f


