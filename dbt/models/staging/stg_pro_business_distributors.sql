{{
  config(
    materialized='view',
    schema='staging'
  )
}}

/*
  stg_pro_business_distributors
  =============================
  Grain: One row per (pro_business_id, distributor_name, distributor_account_number) — latest state
  Source: RAW_DB_PROD.FLUIDRAPRO_RAW.RAW_DEALERS_DATA
  Pattern: LATERAL FLATTEN on distributors[] array
  Downstream: dim_pro_associated_distributor
*/

with source as (
    select
        parse_json(record_metadata) as metadata_json,
        parse_json(record_content) as payload
    from {{ source('fluidrapro_raw', 'raw_dealers_data') }}
    where parse_json(record_content):"detail-type"::string like '%pro-business-master%'
      and parse_json(record_content):detail.data.proBusinessId is not null
      and parse_json(record_content):detail.data.distributors is not null
      and array_size(parse_json(record_content):detail.data.distributors) > 0
),

flattened as (
    select
        payload:id::string as event_id,
        payload:time::timestamp_ntz as event_time,
        metadata_json:offset::number as kafka_offset,
        payload:detail.data.proBusinessId::string as pro_business_id,

        -- Flattened distributor fields
        f.value:distributorName::string as distributor_name,
        f.value:distributorAccountNumber::string as distributor_account_number,
        f.value:distributorAccountStatus::string as distributor_account_status,
        f.value:fluidraAccountNumber::string as fluidra_account_number,
        f.value:source::string as source,
        try_to_timestamp_ntz(f.value:activeDate::string) as active_date,

        -- Distributor audit
        try_to_timestamp_ntz(f.value:auditInfo.createdAt::string) as distributor_created_at,
        try_to_timestamp_ntz(f.value:auditInfo.updatedAt::string) as distributor_updated_at,
        f.value:auditInfo.createdBy::string as distributor_created_by,
        f.value:auditInfo.updatedBy::string as distributor_updated_by

    from source,
        lateral flatten(input => payload:detail.data.distributors) f
),

deduplicated as (
    select
        *,
        row_number() over (
            partition by pro_business_id, distributor_name, distributor_account_number
            order by event_time desc, kafka_offset desc
        ) as rn
    from flattened
)

select * exclude (rn)
from deduplicated
where rn = 1

