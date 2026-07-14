{{
  config(
    materialized='table',
    transient=true,
    schema='STAGING',
    tags=['staging', 'contact']
  )
}}

/*
  Staging model: stg_pro_contact_master
  Source: RAW_DB_PROD.FLUIDRAPRO_RAW.FPRO_QA
  Filter: pro-contact-master.* events (created, updated, login-created, deleted)
  Grain: Latest event per pro_contact_id (deduplicated)
  Materialization: Transient table (Snowflake)
  Note: proBusinessId is NULL on most contact events — use bridge table to resolve FK
*/

WITH source AS (
    SELECT
        PARSE_JSON(RECORD_METADATA) AS metadata_json,
        PARSE_JSON(RECORD_CONTENT) AS payload
    FROM {{ source('fluidrapro_raw', 'fpro_qa') }}
    WHERE RECORD_METADATA != 'RECORD_METADATA'
      AND PARSE_JSON(RECORD_CONTENT):"detail-type"::STRING LIKE '%pro-contact-master%'
      AND PARSE_JSON(RECORD_CONTENT):detail.data.proContactId IS NOT NULL
),

parsed AS (
    SELECT
        -- Event envelope
        payload:id::STRING                                          AS event_id,
        payload:"detail-type"::STRING                               AS event_detail_type,
        payload:time::TIMESTAMP_NTZ                                 AS event_time,
        payload:source::STRING                                      AS event_source,

        -- Kafka metadata
        metadata_json:offset::NUMBER                                AS kafka_offset,
        metadata_json:partition::NUMBER                              AS kafka_partition,

        -- Event metadata
        payload:detail.metadata.eventType::STRING                    AS metadata_event_type,
        payload:detail.metadata.correlationId::STRING                AS correlation_id,
        payload:detail.metadata.service::STRING                      AS metadata_service,
        payload:detail.metadata.payloadVersion::STRING               AS payload_version,

        -- Contact identity
        payload:detail.data.proContactId::STRING                     AS pro_contact_id,
        payload:detail.data.proBusinessId::STRING                    AS pro_business_id,
        payload:detail.data.contactType::STRING                      AS contact_type,
        payload:detail.data.firstName::STRING                        AS first_name,
        payload:detail.data.lastName::STRING                         AS last_name,
        payload:detail.data.email::STRING                            AS email,
        payload:detail.data.phoneNumber::STRING                      AS phone_number,

        -- Login state
        payload:detail.data.loginStatus::STRING                      AS login_status,
        payload:detail.data.username::STRING                         AS username,
        payload:detail.data.cognitoSubId::STRING                     AS cognito_sub_id,
        payload:detail.data.webUserId::STRING                        AS web_user_id,
        payload:detail.data.subscriptionUserId::STRING               AS subscription_user_id,
        TRY_TO_TIMESTAMP_NTZ(payload:detail.data.lastLoginDate::STRING) AS last_login_date,

        -- Contact status
        payload:detail.data.status::STRING                           AS contact_status,
        payload:detail.data.otherContactTypeDescription::STRING      AS other_contact_type_desc,

        -- Array sizes
        COALESCE(ARRAY_SIZE(payload:detail.data.locations), 0)       AS assigned_location_count,
        COALESCE(ARRAY_SIZE(payload:detail.data.userSubscriptions), 0) AS user_subscription_count,

        -- Event type flags
        CASE WHEN payload:"detail-type"::STRING LIKE '%created%' THEN TRUE ELSE FALSE END       AS is_created_event,
        CASE WHEN payload:"detail-type"::STRING LIKE '%updated%' THEN TRUE ELSE FALSE END       AS is_updated_event,
        CASE WHEN payload:"detail-type"::STRING LIKE '%login-created%' THEN TRUE ELSE FALSE END AS is_login_created_event,
        CASE WHEN payload:"detail-type"::STRING LIKE '%deleted%' THEN TRUE ELSE FALSE END       AS is_deleted_event,

        -- Audit
        TRY_TO_TIMESTAMP_NTZ(payload:detail.data.auditInfo.createdAt::STRING) AS created_at,
        payload:detail.data.auditInfo.createdBy::STRING              AS created_by,
        TRY_TO_TIMESTAMP_NTZ(payload:detail.data.auditInfo.updatedAt::STRING) AS updated_at,
        payload:detail.data.auditInfo.updatedBy::STRING              AS updated_by

    FROM source
),

deduplicated AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY pro_contact_id
            ORDER BY event_time DESC, kafka_offset DESC
        ) AS _row_num
    FROM parsed
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['pro_contact_id']) }} AS pro_contact_sk,
    *
FROM deduplicated
WHERE _row_num = 1
