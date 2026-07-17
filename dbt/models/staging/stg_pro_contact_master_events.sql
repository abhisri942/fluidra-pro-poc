{{
  config(
    materialized='view',
    schema='staging'
  )
}}

/*
  stg_pro_contact_master_events
  =============================
  Grain: One row per event_id (every contact event preserved, Kafka duplicates removed)
  Source: RAW_DB_PROD.FLUIDRAPRO_RAW.RAW_DEALERS_DATA
  Downstream: fct_pro_contact_master_events, stg_pro_contact_master
*/

with source as (
    select
        parse_json(record_metadata) as metadata_json,
        parse_json(record_content) as payload
    from {{ source('fluidrapro_raw', 'raw_dealers_data') }}
    where parse_json(record_content):"detail-type"::string like '%pro-contact-master%'
)

select
    -- Event envelope
    payload:id::string as event_id,
    payload:"detail-type"::string as event_detail_type,
    payload:time::timestamp_ntz as event_time,
    payload:time::date as event_date,
    metadata_json:offset::number as kafka_offset,
    metadata_json:partition::number as kafka_partition,

    -- Event metadata
    payload:detail.metadata.eventType::string as metadata_event_type,
    payload:detail.metadata.correlationId::string as correlation_id,
    payload:detail.metadata.service::string as metadata_service,

    -- Contact identity
    payload:detail.data.proContactId::string as pro_contact_id,
    payload:detail.data.proBusinessId::string as pro_business_id,
    payload:detail.data.contactType::string as contact_type,
    payload:detail.data.firstName::string as first_name,
    payload:detail.data.lastName::string as last_name,
    payload:detail.data.email::string as email,
    payload:detail.data.phoneNumber::string as phone_number,
    payload:detail.data.loginStatus::string as login_status,
    payload:detail.data.username::string as username,
    payload:detail.data.cognitoSubId::string as cognito_sub_id,
    payload:detail.data.webUserId::string as web_user_id,
    try_to_timestamp_ntz(payload:detail.data.lastLoginDate::string) as last_login_date,
    payload:detail.data.status::string as contact_status,

    -- Array sizes (measures)
    coalesce(array_size(payload:detail.data.locations), 0) as assigned_location_count,
    coalesce(array_size(payload:detail.data.userSubscriptions), 0) as user_subscription_count,

    -- Event type flags
    case when payload:"detail-type"::string like '%created.v1' then 1 else 0 end as is_created_event,
    case when payload:"detail-type"::string like '%updated.v1' then 1 else 0 end as is_updated_event,
    case when payload:"detail-type"::string like '%login-created%' then 1 else 0 end as is_login_created_event,
    case when payload:"detail-type"::string like '%deleted%' then 1 else 0 end as is_deleted_event,

    -- Audit
    try_to_timestamp_ntz(payload:detail.data.auditInfo.createdAt::string) as record_created_at,
    payload:detail.data.auditInfo.createdBy::string as record_created_by

from source
where payload:detail.data.proContactId is not null
qualify row_number() over (partition by payload:id::string order by metadata_json:offset::number desc) = 1

