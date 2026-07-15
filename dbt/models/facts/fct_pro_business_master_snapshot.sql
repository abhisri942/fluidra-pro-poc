{{
  config(
    materialized='table',
    schema='FACTS',
    tags=['facts', 'business', 'snapshot']
  )
}}

/*
  Fact: fct_pro_business_master_snapshot
  Type: Periodic snapshot fact (current state measures per business)
  Grain: One row per pro_business_id (current point-in-time)
  Measures: All numeric counts + days_since_last_login + health_status
  FKs: pro_business_id -> dim_pro_business_master
  Design: This is where ALL dealer measures live (moved out of the dimension per Kimball).
  Source: Aggregated from staging models via ref()
*/

WITH dist_counts AS (
    SELECT
        pro_business_id,
        COUNT(*)                                                                    AS total_distributor_count,
        COUNT(CASE WHEN distributor_account_status = 'ACTIVE' THEN 1 END)           AS active_distributor_count,
        COUNT(CASE WHEN distributor_account_status = 'PENDING ACTIVE' THEN 1 END)   AS pending_distributor_count,
        COUNT(CASE WHEN distributor_account_status IN ('INACTIVE', 'PENDING INACTIVE') THEN 1 END) AS inactive_distributor_count
    FROM {{ ref('stg_pro_associated_distributors') }}
    GROUP BY pro_business_id
),

prog_counts AS (
    SELECT
        pro_business_id,
        COUNT(*)                                                        AS total_program_count,
        COUNT(CASE WHEN program_status = 'ACTIVE' THEN 1 END)          AS active_program_count,
        COUNT(CASE WHEN program_status = 'PENDING' THEN 1 END)         AS pending_program_count,
        COUNT(CASE WHEN program_status = 'DECLINED' THEN 1 END)        AS declined_program_count
    FROM {{ ref('stg_pro_program_opt_in') }}
    GROUP BY pro_business_id
),

sub_counts AS (
    SELECT
        pro_business_id,
        COUNT(*)                                                        AS total_subscription_count,
        COUNT(CASE WHEN subscription_status = 'ACTIVE' THEN 1 END)     AS active_subscription_count
    FROM {{ ref('stg_pro_subscription_master') }}
    GROUP BY pro_business_id
),

contact_counts AS (
    SELECT
        b.pro_business_id,
        COUNT(*)                                                        AS total_contacts,
        COUNT(CASE WHEN c.login_status = 'ACTIVE' THEN 1 END)          AS active_contacts
    FROM {{ ref('bridge_pro_contact_business') }} b
    INNER JOIN {{ ref('stg_pro_contact_master') }} c
        ON b.pro_contact_id = c.pro_contact_id
    GROUP BY b.pro_business_id
)

SELECT
    d.pro_business_id,
    CURRENT_DATE AS snapshot_date,
    COALESCE(dc.total_distributor_count, 0)     AS total_distributor_count,
    COALESCE(dc.active_distributor_count, 0)    AS active_distributor_count,
    COALESCE(dc.pending_distributor_count, 0)   AS pending_distributor_count,
    COALESCE(dc.inactive_distributor_count, 0)  AS inactive_distributor_count,
    COALESCE(pc.total_program_count, 0)         AS total_program_count,
    COALESCE(pc.active_program_count, 0)        AS active_program_count,
    COALESCE(pc.pending_program_count, 0)       AS pending_program_count,
    COALESCE(pc.declined_program_count, 0)      AS declined_program_count,
    COALESCE(sc.total_subscription_count, 0)    AS total_subscription_count,
    COALESCE(sc.active_subscription_count, 0)   AS active_subscription_count,
    COALESCE(cc.total_contacts, 0)              AS total_contacts,
    COALESCE(cc.active_contacts, 0)             AS active_contacts,
    DATEDIFF('day', d.primary_contact_last_login, CURRENT_TIMESTAMP()) AS days_since_last_login,
    CASE
        WHEN d.login_status = 'ACTIVE' AND d.primary_contact_last_login >= DATEADD('day', -30, CURRENT_TIMESTAMP()) THEN 'HEALTHY'
        WHEN d.login_status = 'ACTIVE' AND (d.primary_contact_last_login < DATEADD('day', -30, CURRENT_TIMESTAMP()) OR d.primary_contact_last_login IS NULL) THEN 'AT_RISK'
        WHEN d.login_status = 'PENDING' THEN 'NOT_ONBOARDED'
        WHEN d.business_status = 'GUEST' THEN 'GUEST'
        WHEN d.business_status = 'REJECTED' THEN 'REJECTED'
        ELSE 'UNKNOWN'
    END AS health_status
FROM {{ ref('stg_pro_business_master') }} d
LEFT JOIN dist_counts dc    ON d.pro_business_id = dc.pro_business_id
LEFT JOIN prog_counts pc    ON d.pro_business_id = pc.pro_business_id
LEFT JOIN sub_counts sc     ON d.pro_business_id = sc.pro_business_id
LEFT JOIN contact_counts cc ON d.pro_business_id = cc.pro_business_id
