{{
  config(
    materialized='table',
    schema='DIMENSIONS',
    tags=['dimensions', 'contact']
  )
}}

/*
  Dimension: dim_pro_contact_master
  Type: Type 1 SCD (overwrite on refresh)
  Grain: One row per pro_contact_id
  Design: Pure Kimball THIN dimension — attributes only.
           last_login_date is kept as a timestamp ATTRIBUTE (not a measure).
           days_since_last_login is NOT here — it's a derived measure in the fact.
  Source: stg_pro_contact_master + bridge resolution for pro_business_id
  Note: 99% of contact events have NULL pro_business_id.
        The bridge resolves this using the primary contact embedded in business events.
*/

WITH bridge AS (
    SELECT DISTINCT
        primary_contact_id AS pro_contact_id,
        pro_business_id
    FROM {{ ref('stg_pro_business_master') }}
    WHERE primary_contact_id IS NOT NULL
      AND pro_business_id IS NOT NULL
)

SELECT
    -- Surrogate key
    c.pro_contact_sk,

    -- Natural key
    c.pro_contact_id,

    -- Resolved FK to business
    COALESCE(c.pro_business_id, b.pro_business_id) AS pro_business_id,

    -- Contact attributes
    c.contact_type,
    c.first_name,
    c.last_name,
    c.email,
    c.phone_number,

    -- Login state (attributes)
    c.login_status,
    c.username,
    c.cognito_sub_id,
    c.web_user_id,
    c.last_login_date,      -- timestamp attribute, NOT a measure

    -- Status
    c.contact_status,
    c.is_deleted_event,

    -- Audit
    c.created_at,
    c.updated_at,
    c.event_time AS last_event_time

FROM {{ ref('stg_pro_contact_master') }} c
LEFT JOIN bridge b
    ON c.pro_contact_id = b.pro_contact_id
