{{
  config(
    materialized='table',
    transient=true,
    schema='STAGING',
    tags=['staging', 'program']
  )
}}

/*
  Staging model: stg_pro_program_opt_in
  Source: RAW_DB_PROD.FLUIDRAPRO_RAW.FPRO_QA
  Filter: pro-business-master.* events with non-empty programOptIns[]
  Grain: One row per (pro_business_id, program_name) — latest state
  Materialization: Transient table (Snowflake)
  Pattern: LATERAL FLATTEN on programOptIns[] array
*/

WITH source AS (
    SELECT
        PARSE_JSON(RECORD_METADATA) AS metadata_json,
        PARSE_JSON(RECORD_CONTENT) AS payload
    FROM {{ source('fluidrapro_raw', 'fpro_qa') }}
    WHERE RECORD_METADATA != 'RECORD_METADATA'
      AND PARSE_JSON(RECORD_CONTENT):"detail-type"::STRING LIKE '%pro-business-master%'
      AND PARSE_JSON(RECORD_CONTENT):detail.data.proBusinessId IS NOT NULL
      AND PARSE_JSON(RECORD_CONTENT):detail.data.programOptIns IS NOT NULL
      AND ARRAY_SIZE(PARSE_JSON(RECORD_CONTENT):detail.data.programOptIns) > 0
),

flattened AS (
    SELECT
        -- Event envelope
        payload:id::STRING                                          AS event_id,
        payload:time::TIMESTAMP_NTZ                                 AS event_time,
        metadata_json:offset::NUMBER                                AS kafka_offset,

        -- Business FK
        payload:detail.data.proBusinessId::STRING                    AS pro_business_id,

        -- Flattened program opt-in fields
        f.value:programName::STRING                                  AS program_name,
        f.value:programStatus::STRING                                AS program_status,
        TRY_TO_TIMESTAMP_NTZ(f.value:programOptInDate::STRING)      AS program_opt_in_date,
        TRY_TO_TIMESTAMP_NTZ(f.value:programStartDate::STRING)      AS program_start_date,
        f.value:source::STRING                                       AS source,
        f.value:fluidraAccountNumber::STRING                         AS fluidra_account_number,

        -- Program audit
        TRY_TO_TIMESTAMP_NTZ(f.value:auditInfo.createdAt::STRING)   AS program_created_at,
        TRY_TO_TIMESTAMP_NTZ(f.value:auditInfo.updatedAt::STRING)   AS program_updated_at,
        f.value:auditInfo.createdBy::STRING                          AS program_created_by,
        f.value:auditInfo.updatedBy::STRING                          AS program_updated_by

    FROM source,
        LATERAL FLATTEN(input => payload:detail.data.programOptIns) f
),

deduplicated AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY pro_business_id, program_name
            ORDER BY event_time DESC, kafka_offset DESC
        ) AS _row_num
    FROM flattened
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['pro_business_id', 'program_name']) }} AS program_opt_in_sk,
    *
FROM deduplicated
WHERE _row_num = 1
