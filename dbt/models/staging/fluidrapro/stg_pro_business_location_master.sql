{{
  config(
    materialized='table',
    transient=true,
    schema='STAGING',
    tags=['staging', 'location']
  )
}}

/*
  Staging model: stg_pro_business_location_master
  Source: RAW_DB_PROD.FLUIDRAPRO_RAW.FPRO_QA
  Filter: pro-location-master.* events
  Grain: Latest event per pro_location_id (deduplicated)
  Materialization: Transient table (Snowflake)
*/

WITH source AS (
    SELECT
        PARSE_JSON(RECORD_METADATA) AS metadata_json,
        PARSE_JSON(RECORD_CONTENT) AS payload
    FROM {{ source('fluidrapro_raw', 'fpro_qa') }}
    WHERE RECORD_METADATA != 'RECORD_METADATA'
      AND PARSE_JSON(RECORD_CONTENT):"detail-type"::STRING LIKE '%pro-location-master%'
      AND PARSE_JSON(RECORD_CONTENT):detail.data.proLocationId IS NOT NULL
),

parsed AS (
    SELECT
        -- Event envelope
        payload:id::STRING                                          AS event_id,
        payload:"detail-type"::STRING                               AS event_detail_type,
        payload:time::TIMESTAMP_NTZ                                 AS event_time,

        -- Kafka metadata
        metadata_json:offset::NUMBER                                AS kafka_offset,

        -- Event metadata
        payload:detail.metadata.eventType::STRING                    AS metadata_event_type,

        -- Location identity
        payload:detail.data.proLocationId::STRING                    AS pro_location_id,
        payload:detail.data.proBusinessId::STRING                    AS pro_business_id,
        payload:detail.data.locationName::STRING                     AS location_name,
        payload:detail.data.locationType::STRING                     AS location_type,
        payload:detail.data.locationStatus::STRING                   AS location_status,

        -- Address
        payload:detail.data.address.streetLine1::STRING              AS street_line_1,
        payload:detail.data.address.streetLine2::STRING              AS street_line_2,
        payload:detail.data.address.city::STRING                     AS city,
        payload:detail.data.address.state::STRING                    AS state,
        payload:detail.data.address.zip::STRING                      AS zip,
        payload:detail.data.address.country::STRING                  AS country,

        -- Location details
        payload:detail.data.phoneNumber::STRING                      AS phone_number,
        payload:detail.data.leadManagementEmail::STRING              AS lead_management_email,
        payload:detail.data.hideAddress::BOOLEAN                     AS hide_address,
        payload:detail.data.hideLocation::BOOLEAN                    AS hide_location,
        COALESCE(ARRAY_SIZE(payload:detail.data.serviceZipCodes), 0) AS service_zip_count,

        -- Audit
        TRY_TO_TIMESTAMP_NTZ(payload:detail.data.auditInfo.createdAt::STRING) AS created_at,
        payload:detail.data.auditInfo.createdBy::STRING              AS created_by,
        TRY_TO_TIMESTAMP_NTZ(payload:detail.data.auditInfo.updatedAt::STRING) AS updated_at

    FROM source
),

deduplicated AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY pro_location_id
            ORDER BY event_time DESC, kafka_offset DESC
        ) AS _row_num
    FROM parsed
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['pro_location_id']) }} AS location_sk,
    *
FROM deduplicated
WHERE _row_num = 1
