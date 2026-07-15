{{
  config(
    materialized='table',
    transient=true,
    schema='STAGING',
    tags=['staging', 'subscription']
  )
}}

/*
  Staging model: stg_pro_subscription_master
  Source: RAW_DB_PROD.FLUIDRAPRO_RAW.FPRO_QA
  Filter: pro-business-master.* events with non-empty subscriptions[]
  Grain: One row per (pro_business_id, subscription_id) — latest state
  Materialization: Transient table (Snowflake)
  Pattern: LATERAL FLATTEN on subscriptions[] array
*/

WITH source AS (
    SELECT
        PARSE_JSON(RECORD_METADATA) AS metadata_json,
        PARSE_JSON(RECORD_CONTENT) AS payload
    FROM {{ source('fluidrapro_raw', 'POOLPRO_INBOUND_EVENTS') }}
    WHERE RECORD_METADATA != 'RECORD_METADATA'
      AND PARSE_JSON(RECORD_CONTENT):"detail-type"::STRING LIKE '%pro-business-master%'
      AND PARSE_JSON(RECORD_CONTENT):detail.data.proBusinessId IS NOT NULL
      AND PARSE_JSON(RECORD_CONTENT):detail.data.subscriptions IS NOT NULL
      AND ARRAY_SIZE(PARSE_JSON(RECORD_CONTENT):detail.data.subscriptions) > 0
),

flattened AS (
    SELECT
        -- Event envelope
        payload:id::STRING                                          AS event_id,
        payload:time::TIMESTAMP_NTZ                                 AS event_time,
        metadata_json:offset::NUMBER                                AS kafka_offset,

        -- Business FK
        payload:detail.data.proBusinessId::STRING                    AS pro_business_id,

        -- Flattened subscription fields
        f.value:subscriptionId::STRING                               AS subscription_id,
        f.value:subscriptionName::STRING                             AS subscription_name,
        f.value:subscriptionStatus::STRING                           AS subscription_status,
        TRY_TO_TIMESTAMP_NTZ(f.value:programStartDate::STRING)      AS program_start_date,
        f.value:source::STRING                                       AS source,

        -- Subscription audit
        TRY_TO_TIMESTAMP_NTZ(f.value:auditInfo.createdAt::STRING)   AS subscription_created_at,
        TRY_TO_TIMESTAMP_NTZ(f.value:auditInfo.updatedAt::STRING)   AS subscription_updated_at,
        f.value:auditInfo.createdBy::STRING                          AS subscription_created_by,
        f.value:auditInfo.updatedBy::STRING                          AS subscription_updated_by

    FROM source,
        LATERAL FLATTEN(input => payload:detail.data.subscriptions) f
),

deduplicated AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY pro_business_id, subscription_id
            ORDER BY event_time DESC, kafka_offset DESC
        ) AS _row_num
    FROM flattened
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['pro_business_id', 'subscription_id']) }} AS subscription_sk,
    * EXCLUDE (_row_num)
FROM deduplicated
WHERE _row_num = 1
