{{
  config(
    materialized='view',
    schema='staging'
  )
}}

/*
  stg_pro_business_program_optins
  ===============================
  Grain: One row per (pro_business_id, program_name) — latest state
  Source: RAW_DB_PROD.FLUIDRAPRO_RAW.RAW_DEALERS_DATA
  Pattern: LATERAL FLATTEN on programOptIns[] array
  Downstream: dim_pro_program_opt_in
*/

with source as (
    select
        parse_json(record_metadata) as metadata_json,
        parse_json(record_content) as payload
    from {{ source('fluidrapro_raw', 'raw_dealers_data') }}
    where parse_json(record_content):"detail-type"::string like '%pro-business-master%'
      and parse_json(record_content):detail.data.proBusinessId is not null
      and parse_json(record_content):detail.data.programOptIns is not null
      and array_size(parse_json(record_content):detail.data.programOptIns) > 0
),

flattened as (
    select
        payload:id::string as event_id,
        payload:time::timestamp_ntz as event_time,
        metadata_json:offset::number as kafka_offset,
        payload:detail.data.proBusinessId::string as pro_business_id,

        -- Flattened program opt-in fields
        f.value:programName::string as program_name,
        f.value:programStatus::string as program_status,
        try_to_timestamp_ntz(f.value:programOptInDate::string) as program_opt_in_date,
        try_to_timestamp_ntz(f.value:programStartDate::string) as program_start_date,
        f.value:source::string as source,
        f.value:fluidraAccountNumber::string as fluidra_account_number,
        f.value:proBusinessId::string as program_pro_business_id,

        -- Program audit
        try_to_timestamp_ntz(f.value:auditInfo.createdAt::string) as program_created_at,
        try_to_timestamp_ntz(f.value:auditInfo.updatedAt::string) as program_updated_at,
        f.value:auditInfo.createdBy::string as program_created_by,
        f.value:auditInfo.updatedBy::string as program_updated_by

    from source,
        lateral flatten(input => payload:detail.data.programOptIns) f
),

deduplicated as (
    select
        *,
        row_number() over (
            partition by pro_business_id, program_name
            order by event_time desc, kafka_offset desc
        ) as rn
    from flattened
)

select * exclude (rn)
from deduplicated
where rn = 1

