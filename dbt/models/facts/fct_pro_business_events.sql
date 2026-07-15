{{
  config(
    materialized='table',
    schema='FACTS'
  )
}}

/*
  Fact: fct_pro_business_events
  Grain: One row per business event (deduped by event_id, keeps all unique events for time-series)
  Source: POOLPRO_INBOUND_EVENTS -> pro-business-master.* events
*/

WITH source AS (
    SELECT
        PARSE_JSON(RECORD_METADATA) AS metadata_json,
        PARSE_JSON(RECORD_CONTENT) AS payload
    FROM {{ source('fluidrapro_raw', 'POOLPRO_INBOUND_EVENTS') }}
    WHERE RECORD_METADATA != 'RECORD_METADATA'
      AND PARSE_JSON(RECORD_CONTENT):"detail-type"::STRING LIKE '%pro-business-master%'
),

parsed AS (
    SELECT
        payload:id::STRING                                              AS event_id,
        payload:"detail-type"::STRING                                   AS event_detail_type,
        payload:time::TIMESTAMP_NTZ                                     AS event_time,
        payload:time::DATE                                              AS event_date,
        metadata_json:offset::NUMBER                                    AS kafka_offset,
        metadata_json:partition::NUMBER                                  AS kafka_partition,
        payload:detail.metadata.eventType::STRING                        AS metadata_event_type,
        payload:detail.metadata.correlationId::STRING                    AS correlation_id,
        payload:detail.metadata.service::STRING                          AS metadata_service,
        payload:detail.data.proBusinessId::STRING                        AS pro_business_id,
        payload:detail.data.primaryContact.proContactId::STRING          AS primary_contact_id,
        payload:detail.data.primaryBillingLocation.proLocationId::STRING AS billing_location_id,
        payload:detail.data.primaryShippingLocation.proLocationId::STRING AS shipping_location_id,
        payload:detail.data.status::STRING                               AS business_status,
        payload:detail.data.loginStatus::STRING                          AS login_status,
        payload:detail.data.source::STRING                               AS source,
        payload:detail.data.primaryBusinessType::STRING                   AS primary_business_type,
        payload:detail.data.businessSegment::STRING                       AS business_segment,
        COALESCE(ARRAY_SIZE(payload:detail.data.distributors), 0)        AS distributor_count,
        COALESCE(ARRAY_SIZE(payload:detail.data.programOptIns), 0)       AS program_opt_in_count,
        COALESCE(ARRAY_SIZE(payload:detail.data.subscriptions), 0)       AS subscription_count,
        COALESCE(ARRAY_SIZE(payload:detail.data.secondaryBusinessTypes), 0) AS secondary_type_count,
        CASE WHEN payload:detail.metadata.eventType::STRING = 'created' THEN 1 ELSE 0 END   AS is_created_event,
        CASE WHEN payload:detail.metadata.eventType::STRING = 'updated' THEN 1 ELSE 0 END   AS is_updated_event,
        CASE WHEN payload:detail.metadata.eventType::STRING = 'approved' THEN 1 ELSE 0 END  AS is_approved_event,
        CASE WHEN payload:detail.metadata.eventType::STRING = 'rejected' THEN 1 ELSE 0 END  AS is_rejected_event,
        CASE WHEN payload:"detail-type"::STRING LIKE '%creation-failed%' THEN 1 ELSE 0 END  AS is_creation_failed,
        CASE WHEN payload:"detail-type"::STRING LIKE '%update-requested%' THEN 1 ELSE 0 END AS is_update_requested,
        payload:detail.data.utm.utm_source::STRING                       AS utm_source,
        payload:detail.data.utm.utm_medium::STRING                       AS utm_medium,
        payload:detail.data.utm.utm_campaign::STRING                     AS utm_campaign,
        payload:detail.data.reason::STRING                               AS failure_reason,
        TRY_TO_TIMESTAMP_NTZ(payload:detail.data.auditInfo.createdAt::STRING) AS record_created_at
    FROM source
)

SELECT * FROM parsed
QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY kafka_offset DESC) = 1
