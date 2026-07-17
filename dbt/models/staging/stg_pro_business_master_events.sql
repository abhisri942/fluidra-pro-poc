{{
  config(
    materialized='view',
    schema='staging'
  )
}}

/*
  stg_pro_business_master_events
  ==============================
  Grain: One row per event_id (every business event preserved, Kafka duplicates removed)
  Source: RAW_DB_PROD.FLUIDRAPRO_RAW.RAW_DEALERS_DATA
  Downstream: fct_pro_business_master_events, fct_lead_funnel, stg_pro_business_master
*/

with source as (
    select
        parse_json(record_metadata) as metadata_json,
        parse_json(record_content) as payload
    from {{ source('fluidrapro_raw', 'raw_dealers_data') }}
    where parse_json(record_content):"detail-type"::string like '%pro-business%'
)

select
    -- Event envelope
    payload:id::string as event_id,
    payload:"detail-type"::string as event_detail_type,
    payload:time::timestamp_ntz as event_time,
    payload:time::date as event_date,
    payload:source::string as event_source,
    payload:region::string as event_region,

    -- Kafka metadata
    metadata_json:offset::number as kafka_offset,
    metadata_json:partition::number as kafka_partition,
    metadata_json:topic::string as kafka_topic,

    -- Event metadata
    payload:detail.metadata.eventType::string as metadata_event_type,
    payload:detail.metadata.correlationId::string as correlation_id,
    payload:detail.metadata.service::string as metadata_service,
    payload:detail.metadata.subDomain::string as metadata_sub_domain,
    payload:detail.metadata.payloadVersion::string as payload_version,

    -- Business identity
    payload:detail.data.proBusinessId::string as pro_business_id,
    payload:detail.data.businessName::string as business_name,
    payload:detail.data.doingBusinessAs::string as doing_business_as,
    payload:detail.data.status::string as business_status,
    payload:detail.data.loginStatus::string as login_status,
    payload:detail.data.source::string as registration_source,

    -- Classification
    payload:detail.data.customerType::string as customer_type,
    payload:detail.data.primaryBusinessType::string as primary_business_type,
    payload:detail.data.businessSegment::string as business_segment,
    payload:detail.data.channel::string as channel,
    payload:detail.data.customerClass::string as customer_class,
    payload:detail.data.salesChannel::string as sales_channel,

    -- Contact info
    payload:detail.data.primaryBusinessEmail::string as primary_business_email,
    payload:detail.data.primaryBusinessPhoneNumber::string as primary_business_phone,

    -- Key account
    payload:detail.data.isPrimaryKeyAccount::boolean as is_primary_key_account,
    payload:detail.data.keyAccountTypeName::string as key_account_type_name,

    -- External keys
    payload:detail.data.fluidraAccountNumber::string as fluidra_account_number,
    payload:detail.data.crmLeadId::string as crm_lead_id,
    payload:detail.data.webAccountId::string as web_account_id,

    -- Flags
    payload:detail.data.termsAccepted::boolean as terms_accepted,
    payload:detail.data.eStatementEnabled::boolean as e_statement_enabled,
    payload:detail.data.isMarComConsent::boolean as is_marcom_consent,
    payload:detail.data.tseViolator::boolean as tse_violator,

    -- Rewards (scalar attributes from embedded object)
    payload:detail.data.rewardsAccount.programLevel::string as rewards_program_level,
    payload:detail.data.rewardsAccount.achieverLevel::string as rewards_achiever_level,
    payload:detail.data.rewardsAccount.programStatus::string as rewards_program_status,
    payload:detail.data.rewardsAccount.rebatePayType::string as rewards_rebate_pay_type,
    try_to_timestamp_ntz(payload:detail.data.rewardsAccount.programSignupDate::string) as rewards_signup_date,

    -- Primary contact (embedded)
    payload:detail.data.primaryContact.proContactId::string as primary_contact_id,
    payload:detail.data.primaryContact.contactType::string as primary_contact_type,
    payload:detail.data.primaryContact.loginStatus::string as primary_contact_login_status,
    try_to_timestamp_ntz(payload:detail.data.primaryContact.lastLoginDate::string) as primary_contact_last_login,

    -- Location
    payload:detail.data.primaryBillingLocation.proLocationId::string as billing_location_id,
    payload:detail.data.primaryBillingLocation.address.city::string as billing_city,
    payload:detail.data.primaryBillingLocation.address.state::string as billing_state,

    -- Sales rep
    payload:detail.data.salesRep.name::string as sales_rep_name,
    payload:detail.data.salesRep.email::string as sales_rep_email,

    -- UTM
    payload:detail.data.utm.utm_source::string as utm_source,
    payload:detail.data.utm.utm_medium::string as utm_medium,
    payload:detail.data.utm.utm_campaign::string as utm_campaign,

    -- Array sizes (measures)
    coalesce(array_size(payload:detail.data.distributors), 0) as distributor_count,
    coalesce(array_size(payload:detail.data.programOptIns), 0) as program_opt_in_count,
    coalesce(array_size(payload:detail.data.subscriptions), 0) as subscription_count,

    -- Event type flags
    case when payload:detail.metadata.eventType::string = 'created' then 1 else 0 end as is_created_event,
    case when payload:detail.metadata.eventType::string = 'updated' then 1 else 0 end as is_updated_event,
    case when payload:detail.metadata.eventType::string = 'approved' then 1 else 0 end as is_approved_event,
    case when payload:detail.metadata.eventType::string = 'rejected' then 1 else 0 end as is_rejected_event,
    case when payload:"detail-type"::string like '%creation-failed%' then 1 else 0 end as is_creation_failed,
    case when payload:"detail-type"::string like '%update-requested%' then 1 else 0 end as is_update_requested,
    case when payload:"detail-type"::string like '%lead.approved%' then 1 else 0 end as is_lead_approved,
    case when payload:"detail-type"::string like '%lead.rejected%' then 1 else 0 end as is_lead_rejected,

    -- Funnel stage (derived)
    case
        when payload:"detail-type"::string like '%created%' and payload:detail.data.status::string = 'GUEST' then 'GUEST'
        when payload:"detail-type"::string like '%created%' and payload:detail.data.status::string = 'LEAD' then 'LEAD_CREATED'
        when payload:"detail-type"::string like '%created%' then 'BUSINESS_CREATED'
        when payload:"detail-type"::string = 'fluidrapro.pro-business-lead.approved.v1' then 'LEAD_APPROVED'
        when payload:"detail-type"::string = 'fluidrapro.pro-business-master.approved.v1' then 'BUSINESS_APPROVED'
        when payload:"detail-type"::string like '%lead.rejected%' then 'LEAD_REJECTED'
        when payload:"detail-type"::string like '%master.rejected%' then 'BUSINESS_REJECTED'
        when payload:"detail-type"::string like '%creation-failed%' then 'CREATION_FAILED'
        when payload:"detail-type"::string like '%update-requested%' then 'UPDATE_REQUESTED'
        else 'UPDATED'
    end as funnel_stage,

    -- Timing measure
    datediff('second',
        try_to_timestamp_ntz(payload:detail.data.auditInfo.createdAt::string),
        payload:time::timestamp_ntz
    ) as seconds_in_stage,

    -- Failure detail
    payload:detail.data.reason::string as failure_reason,

    -- Audit
    try_to_timestamp_ntz(payload:detail.data.auditInfo.createdAt::string) as record_created_at,
    payload:detail.data.auditInfo.createdBy::string as record_created_by

from source
qualify row_number() over (partition by payload:id::string order by metadata_json:offset::number desc) = 1

