{{
  config(
    materialized='view',
    schema='staging'
  )
}}

/*
  stg_pro_key_account_types
  =========================
  Grain: One row per key_account_type_id — latest state
  Source: RAW_DB_PROD.FLUIDRAPRO_RAW.RAW_DEALERS_DATA
  Filter: pro-key-account-type-master.* events
  Downstream: dim_key_account_type
*/

with source as (
    select
        parse_json(record_metadata) as metadata_json,
        parse_json(record_content) as payload
    from {{ source('fluidrapro_raw', 'raw_dealers_data') }}
    where parse_json(record_content):"detail-type"::string like '%pro-key-account-type-master%'
),

parsed as (
    select
        payload:id::string as event_id,
        payload:"detail-type"::string as event_detail_type,
        payload:time::timestamp_ntz as event_time,
        metadata_json:offset::number as kafka_offset,

        payload:detail.metadata.eventType::string as metadata_event_type,

        payload:detail.data.keyAccountTypeId::string as key_account_type_id,
        payload:detail.data.keyAccountTypeName::string as key_account_type_name,
        payload:detail.data.keyAccountTypeRole::string as key_account_type_role,
        payload:detail.data.customerClass::string as customer_class,
        payload:detail.data.salesChannel::string as sales_channel,
        payload:detail.data.programName::string as program_name,
        payload:detail.data.achieverLevel::string as achiever_level,
        payload:detail.data.enableZodiacPremium::boolean as enable_zodiac_premium,
        payload:detail.data.overrideAchieverLevelRole::boolean as override_achiever_level_role,
        payload:detail.data.eStatementEnabled::boolean as e_statement_enabled,
        payload:detail.data.printStatements::boolean as print_statements,

        try_to_timestamp_ntz(payload:detail.data.auditInfo.createdAt::string) as created_at,
        payload:detail.data.auditInfo.createdBy::string as created_by

    from source
),

deduplicated as (
    select
        *,
        row_number() over (
            partition by key_account_type_id
            order by event_time desc, kafka_offset desc
        ) as rn
    from parsed
)

select * exclude (rn)
from deduplicated
where rn = 1

