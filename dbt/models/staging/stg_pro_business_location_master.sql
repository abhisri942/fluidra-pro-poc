{{
  config(
    materialized='view',
    schema='staging'
  )
}}

/*
  stg_pro_locations
  =================
  Grain: One row per pro_location_id — latest state
  Source: RAW_DB_PROD.FLUIDRAPRO_RAW.RAW_DEALERS_DATA
  Filter: pro-location-master.* events
  Downstream: dim_pro_business_location_master
*/

with source as (
    select
        parse_json(record_metadata) as metadata_json,
        parse_json(record_content) as payload
    from {{ source('fluidrapro_raw', 'raw_dealers_data') }}
    where parse_json(record_content):"detail-type"::string like '%pro-location-master%'
      and parse_json(record_content):detail.data.proLocationId is not null
),

parsed as (
    select
        payload:id::string as event_id,
        payload:"detail-type"::string as event_detail_type,
        payload:time::timestamp_ntz as event_time,
        metadata_json:offset::number as kafka_offset,

        payload:detail.metadata.eventType::string as metadata_event_type,

        payload:detail.data.proLocationId::string as pro_location_id,
        payload:detail.data.proBusinessId::string as pro_business_id,
        payload:detail.data.locationName::string as location_name,
        payload:detail.data.locationType::string as location_type,
        payload:detail.data.locationStatus::string as location_status,

        -- Address
        payload:detail.data.address.streetLine1::string as street_line_1,
        payload:detail.data.address.streetLine2::string as street_line_2,
        payload:detail.data.address.city::string as city,
        payload:detail.data.address.state::string as state,
        payload:detail.data.address.zip::string as zip,
        payload:detail.data.address.country::string as country,

        -- Contact
        payload:detail.data.phoneNumber::string as phone_number,
        payload:detail.data.leadManagementEmail::string as lead_management_email,

        -- Flags
        payload:detail.data.hideAddress::boolean as hide_address,
        payload:detail.data.hideLocation::boolean as hide_location,

        -- Measures
        coalesce(array_size(payload:detail.data.serviceZipCodes), 0) as service_zip_count,

        -- Audit
        try_to_timestamp_ntz(payload:detail.data.auditInfo.createdAt::string) as created_at,
        payload:detail.data.auditInfo.createdBy::string as created_by,
        try_to_timestamp_ntz(payload:detail.data.auditInfo.updatedAt::string) as updated_at

    from source
),

deduplicated as (
    select
        *,
        row_number() over (
            partition by pro_location_id
            order by event_time desc, kafka_offset desc
        ) as rn
    from parsed
)

select * exclude (rn)
from deduplicated
where rn = 1

