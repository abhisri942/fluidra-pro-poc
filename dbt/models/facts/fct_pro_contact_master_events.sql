{{
  config(
    materialized='table',
    schema='FACTS',
    tags=['facts', 'contact', 'events']
  )
}}

/*
  Fact: fct_pro_contact_master_events
  Type: Transaction/event fact (one row per event)
  Grain: One row per event_id (deduplicated by kafka_offset)
  Measures: event type flags (1/0 for aggregation)
  FKs: pro_contact_id -> dim_pro_contact_master, event_date -> dim_date
  Source: Direct from raw source for full event history
  Note: In production with dbt-core, switch to incremental with merge on event_id.
*/

WITH source AS (
    SELECT
        PARSE_JSON(RECORD_METADATA) AS metadata_json,
        PARSE_JSON(RECORD_CONTENT) AS payload
    FROM {{ source('fluidrapro_raw', 'POOLPRO_INBOUND_EVENTS') }}
    WHERE RECORD_METADATA != 'RECORD_METADATA'
      AND PARSE_JSON(RECORD_CONTENT):"detail-type"::STRING LIKE '%pro-contact-master%'
      AND PARSE_JSON(RECORD_CONTENT):detail.data.proContactId IS NOT NULL
),

parsed AS (
    SELECT
        payload:id::STRING                                          AS event_id,
        payload:"detail-type"::STRING                               AS event_detail_type,
        payload:time::TIMESTAMP_NTZ                                 AS event_time,
        payload:time::DATE                                          AS event_date,
        metadata_json:offset::NUMBER                                AS kafka_offset,
        payload:detail.metadata.eventType::STRING                    AS metadata_event_type,
        payload:detail.metadata.correlationId::STRING                AS correlation_id,
        payload:detail.data.proContactId::STRING                     AS pro_contact_id,
        payload:detail.data.proBusinessId::STRING                    AS pro_business_id,
        payload:detail.data.contactType::STRING                      AS contact_type,
        payload:detail.data.loginStatus::STRING                      AS login_status,
        payload:detail.data.status::STRING                           AS contact_status,
        payload:detail.data.email::STRING                            AS email,
        CASE WHEN payload:"detail-type"::STRING LIKE '%created.v1' THEN 1 ELSE 0 END       AS is_created_event,
        CASE WHEN payload:"detail-type"::STRING LIKE '%updated.v1' THEN 1 ELSE 0 END       AS is_updated_event,
        CASE WHEN payload:"detail-type"::STRING LIKE '%login-created%' THEN 1 ELSE 0 END   AS is_login_created_event,
        CASE WHEN payload:"detail-type"::STRING LIKE '%deleted%' THEN 1 ELSE 0 END         AS is_deleted_event,
        TRY_TO_TIMESTAMP_NTZ(payload:detail.data.auditInfo.createdAt::STRING) AS record_created_at
    FROM source
),

deduplicated AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY kafka_offset DESC) AS _row_num
    FROM parsed
)

SELECT * EXCLUDE (_row_num)
FROM deduplicated
WHERE _row_num = 1
