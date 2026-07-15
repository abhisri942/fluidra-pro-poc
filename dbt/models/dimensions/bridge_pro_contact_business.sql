{{
  config(
    materialized='table',
    schema='DIMENSIONS',
    tags=['dimensions', 'bridge']
  )
}}

/*
  Bridge: bridge_pro_contact_business
  Purpose: Resolves the many-to-many (or NULL FK) relationship between contacts and businesses.
  Why: 99% of pro-contact-master.* events have NULL proBusinessId.
       The only place the contact↔dealer link is recorded is inside
       pro-business-master.* events as primaryContact.proContactId.
       This bridge extracts that relationship.
  Grain: One row per (pro_business_id, pro_contact_id) combination
  Source: stg_pro_business_master (primary contact embedded in business events)
*/

SELECT DISTINCT
    pro_business_id,
    primary_contact_id  AS pro_contact_id,
    'PRIMARY_CONTACT'   AS relationship_type

FROM {{ ref('stg_pro_business_master') }}
WHERE primary_contact_id IS NOT NULL
  AND pro_business_id IS NOT NULL
