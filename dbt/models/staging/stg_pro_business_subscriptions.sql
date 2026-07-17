{{
  config(
    materialized='view',
    schema='staging'
  )
}}

/*
  stg_pro_business_subscriptions
  ==============================
  Grain: One row per (pro_business_id, subscription_id) — latest state
  Source: RAW_DB_PROD.FLUIDRAPRO_RAW.RAW_DEALERS_DATA
  Pattern: LATERAL FLATTEN on subscriptions[] array
  Downstream: dim_pro_subscription_master
*/

with source as (
    select
        parse_json(record_metadata) as metadata_json,
        parse_json(record_content) as payload
    from {{ source('fluidrapro_raw', 'raw_dealers_data') }}
    where parse_json(record_content):"detail-type"::string like '%pro-business-master%'
      and parse_json(record_content):detail.data.proBusinessId is not null
      and parse_json(record_content):detail.data.subscriptions is not null
      and array_size(parse_json(record_content):detail.data.subscriptions) > 0
),

flattened as (
    select
        payload:id::string as event_id,
        payload:time::timestamp_ntz as event_time,
        metadata_json:offset::number as kafka_offset,
        payload:detail.data.proBusinessId::string as pro_business_id,

        -- Flattened subscription fields
        f.value:subscriptionId::string as subscription_id,
        f.value:subscriptionName::string as subscription_name,
        f.value:subscriptionStatus::string as subscription_status,
        try_to_timestamp_ntz(f.value:programStartDate::string) as program_start_date,
        f.value:source::string as source,
        f.value:proBusinessId::string as subscription_pro_business_id,

        -- Subscription audit
        try_to_timestamp_ntz(f.value:auditInfo.createdAt::string) as subscription_created_at,
        try_to_timestamp_ntz(f.value:auditInfo.updatedAt::string) as subscription_updated_at,
        f.value:auditInfo.createdBy::string as subscription_created_by,
        f.value:auditInfo.updatedBy::string as subscription_updated_by

    from source,
        lateral flatten(input => payload:detail.data.subscriptions) f
),

deduplicated as (
    select
        *,
        row_number() over (
            partition by pro_business_id, subscription_id
            order by event_time desc, kafka_offset desc
        ) as rn
    from flattened
)

select * exclude (rn)
from deduplicated
where rn = 1

