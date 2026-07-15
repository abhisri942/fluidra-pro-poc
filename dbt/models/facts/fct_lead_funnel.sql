{{
  config(
    materialized='table',
    schema='FACTS',
    tags=['facts', 'lead', 'funnel']
  )
}}

/*
  Fact: fct_lead_funnel
  Type: Transaction/event fact (one row per funnel transition event)
  Grain: One row per event_id
  Measures: seconds_in_stage, funnel_stage classification
  FKs: pro_business_id -> dim_pro_business_master, event_date -> dim_date
  Source: Direct from raw source for full event history
  Note: In production with dbt-core, switch to incremental with merge on event_id.
*/

WITH source AS (
    SELECT
        PARSE_JSON(RECORD_METADATA) AS metadata_json,
        PARSE_JSON(RECORD_CONTENT) AS payload
    FROM {{ source('fluidrapro_raw', 'POOLPRO_INBOUND_EVENTS') }}
    WHERE RECORD_METADATA != 'RECORD_METADATA'
      AND PARSE_JSON(RECORD_CONTENT):"detail-type"::STRING IN (
          'fluidrapro.pro-business-master.created.v1',
          'fluidrapro.pro-business-master.approved.v1',
          'fluidrapro.pro-business-master.rejected.v1',
          'fluidrapro.pro-business-master.creation-failed.v1',
          'fluidrapro.pro-business-lead.approved.v1',
          'fluidrapro.pro-business-lead.rejected.v1'
      )
),

parsed AS (
    SELECT
        payload:id::STRING                                          AS event_id,
        payload:"detail-type"::STRING                               AS event_detail_type,
        payload:time::TIMESTAMP_NTZ                                 AS event_time,
        payload:time::DATE                                          AS event_date,
        metadata_json:offset::NUMBER                                AS kafka_offset,
        payload:detail.metadata.correlationId::STRING                AS correlation_id,
        payload:detail.data.proBusinessId::STRING                    AS pro_business_id,
        payload:detail.data.primaryBusinessEmail::STRING             AS primary_email,
        payload:detail.data.crmLeadId::STRING                        AS crm_lead_id,
        payload:detail.data.salesRep.name::STRING                    AS sales_rep_name,
        payload:detail.data.salesRep.email::STRING                   AS sales_rep_email,
        payload:detail.data.status::STRING                           AS business_status,
        payload:detail.data.primaryBusinessType::STRING               AS primary_business_type,
        payload:detail.data.source::STRING                           AS registration_source,
        CASE
            WHEN payload:"detail-type"::STRING LIKE '%created%' AND payload:detail.data.status::STRING = 'GUEST' THEN 'GUEST'
            WHEN payload:"detail-type"::STRING LIKE '%created%' AND payload:detail.data.status::STRING = 'LEAD' THEN 'LEAD_CREATED'
            WHEN payload:"detail-type"::STRING LIKE '%created%' THEN 'BUSINESS_CREATED'
            WHEN payload:"detail-type"::STRING = 'fluidrapro.pro-business-lead.approved.v1' THEN 'LEAD_APPROVED'
            WHEN payload:"detail-type"::STRING = 'fluidrapro.pro-business-master.approved.v1' THEN 'BUSINESS_APPROVED'
            WHEN payload:"detail-type"::STRING LIKE '%lead.rejected%' THEN 'LEAD_REJECTED'
            WHEN payload:"detail-type"::STRING LIKE '%master.rejected%' THEN 'BUSINESS_REJECTED'
            WHEN payload:"detail-type"::STRING LIKE '%creation-failed%' THEN 'CREATION_FAILED'
            ELSE 'OTHER'
        END AS funnel_stage,
        TRY_TO_TIMESTAMP_NTZ(payload:detail.data.auditInfo.createdAt::STRING) AS submission_time,
        DATEDIFF('second', TRY_TO_TIMESTAMP_NTZ(payload:detail.data.auditInfo.createdAt::STRING), payload:time::TIMESTAMP_NTZ) AS seconds_in_stage,
        payload:detail.data.reason::STRING                           AS failure_reason
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
