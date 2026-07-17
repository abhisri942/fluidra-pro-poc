# Dimensional Model & Analytics Queries

## Overview

This document defines the complete dimensional model for the Fluidra Pro analytics platform,
including dimension tables, fact tables, and metric views — all built from the single source:
`RAW_DB_DEV.FLUIDRAPRO_RAW.EVENTS__RAW_FLUIDRA`.

---

## 1. Data Architecture Layers

```
RAW_DB_DEV.FLUIDRAPRO_RAW.EVENTS__RAW_FLUIDRA (source)
    │
    ▼
STAGING (parsed, deduplicated, typed)
    │
    ▼
DIMENSIONS (conformed, SCD Type 2 where needed)
    │
    ▼
FACTS (event-level grain, measures)
    │
    ▼
METRICS VIEWS (pre-aggregated KPIs)
```

---

## 2. Staging Layer

### stg_events_parsed (base CTE for all downstream)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.STAGING.STG_EVENTS_PARSED AS
SELECT
    PARSE_JSON(RECORD_CONTENT) as event_json,
    PARSE_JSON(RECORD_METADATA) as meta_json,
    -- Event envelope
    PARSE_JSON(RECORD_CONTENT):id::STRING as event_id,
    PARSE_JSON(RECORD_CONTENT):"detail-type"::STRING as event_detail_type,
    PARSE_JSON(RECORD_CONTENT):time::TIMESTAMP_NTZ as event_time,
    PARSE_JSON(RECORD_CONTENT):source::STRING as event_source,
    PARSE_JSON(RECORD_CONTENT):env::STRING as event_env,
    PARSE_JSON(RECORD_CONTENT):region::STRING as event_region,
    -- Metadata
    PARSE_JSON(RECORD_CONTENT):detail.metadata.eventType::STRING as metadata_event_type,
    PARSE_JSON(RECORD_CONTENT):detail.metadata.domain::STRING as metadata_domain,
    PARSE_JSON(RECORD_CONTENT):detail.metadata.subDomain::STRING as metadata_sub_domain,
    PARSE_JSON(RECORD_CONTENT):detail.metadata.service::STRING as metadata_service,
    PARSE_JSON(RECORD_CONTENT):detail.metadata.correlationId::STRING as correlation_id,
    PARSE_JSON(RECORD_CONTENT):detail.metadata.payloadVersion::STRING as payload_version,
    PARSE_JSON(RECORD_CONTENT):detail.metadata.fieldsUpdated as fields_updated_array,
    -- Kafka metadata
    PARSE_JSON(RECORD_METADATA):offset::NUMBER as kafka_offset,
    PARSE_JSON(RECORD_METADATA):partition::NUMBER as kafka_partition,
    PARSE_JSON(RECORD_METADATA):topic::STRING as kafka_topic,
    PARSE_JSON(RECORD_METADATA):key::STRING as kafka_key,
    PARSE_JSON(RECORD_METADATA):CreateTime::NUMBER as kafka_create_time,
    -- Data payload (full)
    PARSE_JSON(RECORD_CONTENT):detail.data as data_payload
FROM RAW_DB_DEV.FLUIDRAPRO_RAW.EVENTS__RAW_FLUIDRA
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY PARSE_JSON(RECORD_CONTENT):id::STRING
    ORDER BY PARSE_JSON(RECORD_METADATA):offset::NUMBER DESC
) = 1;  -- Deduplication: keep latest offset per event_id
```

---

## 3. Dimension Tables

### Relationship Map (Foreign Keys)

```
DIM_DEALER.pro_business_id (PK)
    │
    ├──► DIM_CONTACT.pro_business_id (FK)
    │        └── DIM_CONTACT.pro_contact_id (PK)
    │
    ├──► DIM_LOCATION.pro_business_id (FK)
    │        └── DIM_LOCATION.pro_location_id (PK)
    │
    ├──► DIM_DISTRIBUTOR.pro_business_id (FK)
    │        └── composite PK: (pro_business_id, distributor_name, distributor_account_number)
    │
    ├──► DIM_PROGRAM.pro_business_id (FK, also PK — one rewards account per dealer)
    │
    ├──► DIM_PROGRAM_OPT_IN.pro_business_id (FK)
    │        └── composite PK: (pro_business_id, program_name)
    │
    ├──► DIM_SUBSCRIPTION.pro_business_id (FK)
    │        └── DIM_SUBSCRIPTION.subscription_id (PK)
    │
    └──► DIM_SALES_REP.sales_rep_email (linked via FCT_LEAD_FUNNEL)
```

**Data Linkage Challenge:**
- `pro-contact-master.created` events have NULL `proBusinessId`
- The link is resolved by matching `proContactId` from standalone contact events
  to `primaryContact.proContactId` embedded in business-master events
- Location events (`pro-location-master`) also may lack `proBusinessId` —
  the link comes from the parent business-master event where the location is nested

### 3.0 BRIDGE_CONTACT_DEALER (resolves contact ↔ dealer link)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.DIMENSIONS.BRIDGE_CONTACT_DEALER AS
-- Source 1: primaryContact embedded in business-master events
SELECT DISTINCT
    data_payload:proBusinessId::STRING as pro_business_id,
    data_payload:primaryContact.proContactId::STRING as pro_contact_id,
    'PRIMARY_CONTACT' as relationship_type
FROM ANALYTICS_DB.STAGING.STG_EVENTS_PARSED
WHERE event_detail_type LIKE '%pro-business-master%'
  AND data_payload:primaryContact.proContactId IS NOT NULL
  AND data_payload:proBusinessId IS NOT NULL;
```

### 3.1 DIM_DEALER (Slowly Changing Dimension Type 2)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.DIMENSIONS.DIM_DEALER AS
WITH latest_business AS (
    SELECT
        data_payload:proBusinessId::STRING as pro_business_id,
        data_payload:businessName::STRING as business_name,
        data_payload:doingBusinessAs::STRING as doing_business_as,
        data_payload:status::STRING as business_status,
        data_payload:loginStatus::STRING as login_status,
        data_payload:source::STRING as registration_source,
        data_payload:customerType::STRING as customer_type,
        data_payload:primaryBusinessType::STRING as primary_business_type,
        data_payload:businessSegment::STRING as business_segment,
        data_payload:channel::STRING as channel,
        data_payload:customerClass::STRING as customer_class,
        data_payload:salesChannel::STRING as sales_channel,
        data_payload:fluidraAccountNumber::STRING as fluidra_account_number,
        data_payload:isPrimaryKeyAccount::BOOLEAN as is_primary_key_account,
        data_payload:keyAccountTypeName::STRING as key_account_type_name,
        data_payload:keyAccountTypeRole::STRING as key_account_type_role,
        data_payload:isProLoginAllowed::BOOLEAN as is_pro_login_allowed,
        data_payload:termsAccepted::BOOLEAN as terms_accepted,
        data_payload:eStatementEnabled::BOOLEAN as e_statement_enabled,
        data_payload:isMarComConsent::BOOLEAN as is_marcom_consent,
        data_payload:tseViolator::BOOLEAN as tse_violator,
        data_payload:website::STRING as website,
        data_payload:crmLeadId::STRING as crm_lead_id,
        data_payload:webAccountId::STRING as web_account_id,
        data_payload:secondaryBusinessTypes as secondary_business_types_array,
        data_payload:auditInfo.createdAt::TIMESTAMP_NTZ as created_at,
        data_payload:auditInfo.createdBy::STRING as created_by,
        data_payload:auditInfo.updatedAt::TIMESTAMP_NTZ as updated_at,
        data_payload:auditInfo.updatedBy::STRING as updated_by,
        event_time as last_event_time,
        event_detail_type as last_event_type
    FROM ANALYTICS_DB.STAGING.STG_EVENTS_PARSED
    WHERE event_detail_type LIKE '%pro-business-master%'
      AND data_payload:proBusinessId IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY data_payload:proBusinessId::STRING
        ORDER BY event_time DESC
    ) = 1
)
SELECT
    pro_business_id,
    business_name,
    doing_business_as,
    business_status,
    login_status,
    registration_source,
    customer_type,
    primary_business_type,
    business_segment,
    channel,
    customer_class,
    sales_channel,
    fluidra_account_number,
    is_primary_key_account,
    key_account_type_name,
    key_account_type_role,
    is_pro_login_allowed,
    terms_accepted,
    e_statement_enabled,
    is_marcom_consent,
    tse_violator,
    website,
    crm_lead_id,
    web_account_id,
    secondary_business_types_array,
    created_at,
    created_by,
    updated_at,
    updated_by,
    last_event_time,
    last_event_type
FROM latest_business;
```

**Relationships:**
- `pro_business_id` → links to DIM_CONTACT, DIM_LOCATION, DIM_DISTRIBUTOR, DIM_PROGRAM, DIM_SUBSCRIPTION
- `fluidra_account_number` → future join key to revenue/PSOT data
- `crm_lead_id` → join key to Salesforce leads

---

### 3.2 DIM_CONTACT

**Linkage Note:** Contact events (`pro-contact-master.created`) have NULL `proBusinessId`.
The link is established via the `primaryContact.proContactId` embedded in business-master events.
The query below resolves this by extracting contacts from BOTH sources and using the
business-master's `proBusinessId` as the authoritative link.

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.DIMENSIONS.DIM_CONTACT AS
WITH contact_from_contact_events AS (
    SELECT
        data_payload:proContactId::STRING as pro_contact_id,
        data_payload:proBusinessId::STRING as pro_business_id_from_event,
        data_payload:contactType::STRING as contact_type,
        data_payload:firstName::STRING as first_name,
        data_payload:lastName::STRING as last_name,
        data_payload:email::STRING as email,
        data_payload:phoneNumber::STRING as phone_number,
        data_payload:loginStatus::STRING as login_status,
        data_payload:username::STRING as username,
        data_payload:cognitoSubId::STRING as cognito_sub_id,
        data_payload:webUserId::STRING as web_user_id,
        data_payload:lastLoginDate::TIMESTAMP_NTZ as last_login_date,
        data_payload:source::STRING as source,
        data_payload:status::STRING as contact_status,
        data_payload:auditInfo.createdAt::TIMESTAMP_NTZ as created_at,
        data_payload:auditInfo.createdBy::STRING as created_by,
        event_time as last_event_time,
        event_detail_type as last_event_type
    FROM ANALYTICS_DB.STAGING.STG_EVENTS_PARSED
    WHERE event_detail_type LIKE '%pro-contact-master%'
      AND data_payload:proContactId IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY data_payload:proContactId::STRING
        ORDER BY event_time DESC
    ) = 1
),
contact_from_business_events AS (
    SELECT
        data_payload:primaryContact.proContactId::STRING as pro_contact_id,
        data_payload:proBusinessId::STRING as pro_business_id_from_event,
        data_payload:primaryContact.contactType::STRING as contact_type,
        data_payload:primaryContact.firstName::STRING as first_name,
        data_payload:primaryContact.lastName::STRING as last_name,
        data_payload:primaryContact.email::STRING as email,
        data_payload:primaryContact.phoneNumber::STRING as phone_number,
        data_payload:primaryContact.loginStatus::STRING as login_status,
        data_payload:primaryContact.username::STRING as username,
        data_payload:primaryContact.cognitoSubId::STRING as cognito_sub_id,
        data_payload:primaryContact.webUserId::STRING as web_user_id,
        data_payload:primaryContact.lastLoginDate::TIMESTAMP_NTZ as last_login_date,
        data_payload:primaryContact.source::STRING as source,
        data_payload:primaryContact.status::STRING as contact_status,
        data_payload:primaryContact.auditInfo.createdAt::TIMESTAMP_NTZ as created_at,
        data_payload:primaryContact.auditInfo.createdBy::STRING as created_by,
        event_time as last_event_time,
        event_detail_type as last_event_type
    FROM ANALYTICS_DB.STAGING.STG_EVENTS_PARSED
    WHERE event_detail_type LIKE '%pro-business-master%'
      AND data_payload:primaryContact.proContactId IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY data_payload:primaryContact.proContactId::STRING
        ORDER BY event_time DESC
    ) = 1
),
-- Merge both sources, prefer business-master (has proBusinessId)
merged AS (
    SELECT * FROM contact_from_business_events
    UNION ALL
    SELECT * FROM contact_from_contact_events
    WHERE pro_contact_id NOT IN (SELECT pro_contact_id FROM contact_from_business_events)
)
SELECT
    m.pro_contact_id,
    -- Resolve pro_business_id: use business event link, or fallback to bridge
    COALESCE(m.pro_business_id_from_event, b.pro_business_id) as pro_business_id,
    m.contact_type,
    m.first_name,
    m.last_name,
    m.email,
    m.phone_number,
    m.login_status,
    m.username,
    m.cognito_sub_id,
    m.web_user_id,
    m.last_login_date,
    m.source,
    m.contact_status,
    m.created_at,
    m.created_by,
    m.last_event_time,
    m.last_event_type
FROM merged m
LEFT JOIN ANALYTICS_DB.DIMENSIONS.BRIDGE_CONTACT_DEALER b
    ON m.pro_contact_id = b.pro_contact_id
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY m.pro_contact_id
    ORDER BY m.last_event_time DESC
) = 1;
```

### 3.3 DIM_LOCATION

**Linkage Note:** Locations are embedded within business-master events as
`primaryBillingLocation` and `primaryShippingLocation`. Each location carries
a `proLocationId` and is linked back to the dealer via the parent event's `proBusinessId`.
There is no standalone location event with its own `proBusinessId` — the FK is inherited.

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.DIMENSIONS.DIM_LOCATION AS
WITH billing_locations AS (
    SELECT
        data_payload:primaryBillingLocation.proLocationId::STRING as pro_location_id,
        data_payload:proBusinessId::STRING as pro_business_id,
        'PRIMARY_BILL_TO' as location_type,
        data_payload:primaryBillingLocation.locationName::STRING as location_name,
        data_payload:primaryBillingLocation.locationStatus::STRING as location_status,
        data_payload:primaryBillingLocation.address.streetLine1::STRING as street_line_1,
        data_payload:primaryBillingLocation.address.streetLine2::STRING as street_line_2,
        data_payload:primaryBillingLocation.address.city::STRING as city,
        data_payload:primaryBillingLocation.address.state::STRING as state,
        data_payload:primaryBillingLocation.address.zip::STRING as zip,
        data_payload:primaryBillingLocation.address.country::STRING as country,
        data_payload:primaryBillingLocation.hideAddress::BOOLEAN as hide_address,
        data_payload:primaryBillingLocation.hideLocation::BOOLEAN as hide_location,
        data_payload:primaryBillingLocation.isEmailLeadsEnabled::BOOLEAN as is_email_leads_enabled,
        event_time
    FROM ANALYTICS_DB.STAGING.STG_EVENTS_PARSED
    WHERE event_detail_type LIKE '%pro-business-master%'
      AND data_payload:primaryBillingLocation.proLocationId IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY data_payload:primaryBillingLocation.proLocationId::STRING
        ORDER BY event_time DESC
    ) = 1
),
shipping_locations AS (
    SELECT
        data_payload:primaryShippingLocation.proLocationId::STRING as pro_location_id,
        data_payload:proBusinessId::STRING as pro_business_id,
        'PRIMARY_SHIP_TO' as location_type,
        data_payload:primaryShippingLocation.locationName::STRING as location_name,
        data_payload:primaryShippingLocation.locationStatus::STRING as location_status,
        data_payload:primaryShippingLocation.address.streetLine1::STRING as street_line_1,
        data_payload:primaryShippingLocation.address.streetLine2::STRING as street_line_2,
        data_payload:primaryShippingLocation.address.city::STRING as city,
        data_payload:primaryShippingLocation.address.state::STRING as state,
        data_payload:primaryShippingLocation.address.zip::STRING as zip,
        data_payload:primaryShippingLocation.address.country::STRING as country,
        data_payload:primaryShippingLocation.hideAddress::BOOLEAN as hide_address,
        data_payload:primaryShippingLocation.hideLocation::BOOLEAN as hide_location,
        data_payload:primaryShippingLocation.isEmailLeadsEnabled::BOOLEAN as is_email_leads_enabled,
        event_time
    FROM ANALYTICS_DB.STAGING.STG_EVENTS_PARSED
    WHERE event_detail_type LIKE '%pro-business-master%'
      AND data_payload:primaryShippingLocation.proLocationId IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY data_payload:primaryShippingLocation.proLocationId::STRING
        ORDER BY event_time DESC
    ) = 1
)
SELECT * FROM billing_locations
UNION ALL
SELECT * FROM shipping_locations;
```

### 3.4 DIM_PROGRAM

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.DIMENSIONS.DIM_PROGRAM AS
WITH rewards AS (
    SELECT
        data_payload:proBusinessId::STRING as pro_business_id,
        data_payload:rewardsAccount.programLevel::STRING as program_level,
        data_payload:rewardsAccount.achieverLevel::STRING as achiever_level,
        data_payload:rewardsAccount.programStatus::STRING as program_status,
        data_payload:rewardsAccount.region::STRING as region,
        data_payload:rewardsAccount.source::STRING as source,
        data_payload:rewardsAccount.rebatePayType::STRING as rebate_pay_type,
        data_payload:rewardsAccount.enableAutoZodiacPremium::BOOLEAN as enable_auto_zodiac_premium,
        data_payload:rewardsAccount.overrideAchieverLevelRoll::BOOLEAN as override_achiever_level_roll,
        data_payload:rewardsAccount.programSignupDate::TIMESTAMP_NTZ as program_signup_date,
        data_payload:rewardsAccount.programLevelStartDate::TIMESTAMP_NTZ as program_level_start_date,
        data_payload:rewardsAccount.achieverLevelStartDate::TIMESTAMP_NTZ as achiever_level_start_date,
        data_payload:rewardsAccount.auditInfo.createdAt::TIMESTAMP_NTZ as rewards_created_at,
        data_payload:rewardsAccount.auditInfo.updatedAt::TIMESTAMP_NTZ as rewards_updated_at,
        event_time
    FROM ANALYTICS_DB.STAGING.STG_EVENTS_PARSED
    WHERE event_detail_type LIKE '%pro-business-master%'
      AND data_payload:rewardsAccount IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY data_payload:proBusinessId::STRING
        ORDER BY event_time DESC
    ) = 1
)
SELECT * FROM rewards;
```

### 3.5 DIM_DISTRIBUTOR

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.DIMENSIONS.DIM_DISTRIBUTOR AS
WITH flattened AS (
    SELECT
        data_payload:proBusinessId::STRING as pro_business_id,
        f.value:distributorName::STRING as distributor_name,
        f.value:distributorAccountNumber::STRING as distributor_account_number,
        f.value:distributorAccountStatus::STRING as distributor_account_status,
        f.value:fluidraAccountNumber::STRING as fluidra_account_number,
        f.value:source::STRING as source,
        f.value:activeDate::TIMESTAMP_NTZ as active_date,
        f.value:auditInfo.createdAt::TIMESTAMP_NTZ as created_at,
        f.value:auditInfo.updatedAt::TIMESTAMP_NTZ as updated_at,
        f.value:auditInfo.createdBy::STRING as created_by,
        f.value:auditInfo.updatedBy::STRING as updated_by,
        event_time
    FROM ANALYTICS_DB.STAGING.STG_EVENTS_PARSED,
        LATERAL FLATTEN(input => data_payload:distributors) f
    WHERE event_detail_type LIKE '%pro-business-master%'
      AND data_payload:distributors IS NOT NULL
      AND ARRAY_SIZE(data_payload:distributors) > 0
)
SELECT
    pro_business_id,
    distributor_name,
    distributor_account_number,
    distributor_account_status,
    fluidra_account_number,
    source,
    active_date,
    created_at,
    updated_at,
    created_by,
    updated_by
FROM flattened
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY pro_business_id, distributor_name, distributor_account_number
    ORDER BY event_time DESC
) = 1;
```

### 3.6 DIM_PROGRAM_OPT_IN

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.DIMENSIONS.DIM_PROGRAM_OPT_IN AS
WITH flattened AS (
    SELECT
        data_payload:proBusinessId::STRING as pro_business_id,
        f.value:programName::STRING as program_name,
        f.value:programStatus::STRING as program_status,
        f.value:programOptInDate::TIMESTAMP_NTZ as program_opt_in_date,
        f.value:source::STRING as source,
        f.value:auditInfo.createdAt::TIMESTAMP_NTZ as created_at,
        f.value:auditInfo.updatedAt::TIMESTAMP_NTZ as updated_at,
        event_time
    FROM ANALYTICS_DB.STAGING.STG_EVENTS_PARSED,
        LATERAL FLATTEN(input => data_payload:programOptIns) f
    WHERE event_detail_type LIKE '%pro-business-master%'
      AND data_payload:programOptIns IS NOT NULL
      AND ARRAY_SIZE(data_payload:programOptIns) > 0
)
SELECT
    pro_business_id,
    program_name,
    program_status,
    program_opt_in_date,
    source,
    created_at,
    updated_at
FROM flattened
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY pro_business_id, program_name
    ORDER BY event_time DESC
) = 1;
```

### 3.7 DIM_SUBSCRIPTION

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.DIMENSIONS.DIM_SUBSCRIPTION AS
WITH flattened AS (
    SELECT
        data_payload:proBusinessId::STRING as pro_business_id,
        f.value:subscriptionId::STRING as subscription_id,
        f.value:subscriptionName::STRING as subscription_name,
        f.value:subscriptionStatus::STRING as subscription_status,
        f.value:programStartDate::TIMESTAMP_NTZ as program_start_date,
        f.value:source::STRING as source,
        f.value:auditInfo.createdAt::TIMESTAMP_NTZ as created_at,
        f.value:auditInfo.updatedAt::TIMESTAMP_NTZ as updated_at,
        event_time
    FROM ANALYTICS_DB.STAGING.STG_EVENTS_PARSED,
        LATERAL FLATTEN(input => data_payload:subscriptions) f
    WHERE event_detail_type LIKE '%pro-business-master%'
      AND data_payload:subscriptions IS NOT NULL
      AND ARRAY_SIZE(data_payload:subscriptions) > 0
)
SELECT
    pro_business_id,
    subscription_id,
    subscription_name,
    subscription_status,
    program_start_date,
    source,
    created_at,
    updated_at
FROM flattened
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY pro_business_id, subscription_id
    ORDER BY event_time DESC
) = 1;
```

### 3.8 DIM_SALES_REP

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.DIMENSIONS.DIM_SALES_REP AS
SELECT DISTINCT
    data_payload:salesRep.email::STRING as sales_rep_email,
    data_payload:salesRep.name::STRING as sales_rep_name
FROM ANALYTICS_DB.STAGING.STG_EVENTS_PARSED
WHERE data_payload:salesRep IS NOT NULL;
```

### 3.9 DIM_DATE (generated)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.DIMENSIONS.DIM_DATE AS
SELECT
    date_day as date_key,
    DAYOFWEEK(date_day) as day_of_week,
    DAYNAME(date_day) as day_name,
    DAY(date_day) as day_of_month,
    WEEKOFYEAR(date_day) as week_of_year,
    MONTH(date_day) as month_number,
    MONTHNAME(date_day) as month_name,
    QUARTER(date_day) as quarter,
    YEAR(date_day) as year,
    CASE WHEN DAYOFWEEK(date_day) IN (0, 6) THEN TRUE ELSE FALSE END as is_weekend
FROM (
    SELECT DATEADD(day, seq4(), '2023-01-01')::DATE as date_day
    FROM TABLE(GENERATOR(ROWCOUNT => 1461))  -- 4 years
);
```

---

## 4. Fact Tables

### 4.1 FCT_PRO_BUSINESS_MASTER_EVENTS (grain: one row per business event)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.FACTS.FCT_PRO_BUSINESS_MASTER_EVENTS AS
SELECT
    event_id,
    event_time,
    event_time::DATE as event_date,
    event_detail_type,
    metadata_event_type,
    correlation_id,
    -- Dimension keys
    data_payload:proBusinessId::STRING as pro_business_id,
    data_payload:primaryContact.proContactId::STRING as primary_contact_id,
    data_payload:primaryBillingLocation.proLocationId::STRING as billing_location_id,
    data_payload:primaryShippingLocation.proLocationId::STRING as shipping_location_id,
    -- Measures / flags
    data_payload:status::STRING as business_status,
    data_payload:loginStatus::STRING as login_status,
    data_payload:source::STRING as source,
    ARRAY_SIZE(COALESCE(data_payload:distributors, ARRAY_CONSTRUCT())) as distributor_count,
    ARRAY_SIZE(COALESCE(data_payload:programOptIns, ARRAY_CONSTRUCT())) as program_opt_in_count,
    ARRAY_SIZE(COALESCE(data_payload:subscriptions, ARRAY_CONSTRUCT())) as subscription_count,
    ARRAY_SIZE(COALESCE(data_payload:secondaryBusinessTypes, ARRAY_CONSTRUCT())) as secondary_type_count,
    -- Event type flags (for easy aggregation)
    CASE WHEN metadata_event_type = 'created' THEN 1 ELSE 0 END as is_created_event,
    CASE WHEN metadata_event_type = 'updated' THEN 1 ELSE 0 END as is_updated_event,
    CASE WHEN metadata_event_type = 'approved' THEN 1 ELSE 0 END as is_approved_event,
    CASE WHEN metadata_event_type = 'rejected' THEN 1 ELSE 0 END as is_rejected_event,
    CASE WHEN event_detail_type LIKE '%creation-failed%' THEN 1 ELSE 0 END as is_creation_failed,
    -- UTM attribution
    data_payload:utm.utm_source::STRING as utm_source,
    data_payload:utm.utm_medium::STRING as utm_medium,
    data_payload:utm.utm_campaign::STRING as utm_campaign,
    data_payload:utm.utm_content::STRING as utm_content,
    data_payload:utm.utm_term::STRING as utm_term
FROM ANALYTICS_DB.STAGING.STG_EVENTS_PARSED
WHERE event_detail_type LIKE '%pro-business%';
```

### 4.2 FCT_PRO_CONTACT_MASTER_EVENTS (grain: one row per contact event)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.FACTS.FCT_PRO_CONTACT_MASTER_EVENTS AS
SELECT
    event_id,
    event_time,
    event_time::DATE as event_date,
    event_detail_type,
    metadata_event_type,
    correlation_id,
    -- Dimension keys
    data_payload:proContactId::STRING as pro_contact_id,
    data_payload:proBusinessId::STRING as pro_business_id,
    -- Measures
    data_payload:contactType::STRING as contact_type,
    data_payload:loginStatus::STRING as login_status,
    data_payload:source::STRING as source,
    data_payload:status::STRING as contact_status,
    -- Event type flags
    CASE WHEN metadata_event_type = 'created' THEN 1 ELSE 0 END as is_created_event,
    CASE WHEN metadata_event_type = 'updated' THEN 1 ELSE 0 END as is_updated_event,
    CASE WHEN event_detail_type LIKE '%login-created%' THEN 1 ELSE 0 END as is_login_created_event
FROM ANALYTICS_DB.STAGING.STG_EVENTS_PARSED
WHERE event_detail_type LIKE '%pro-contact-master%';
```

### 4.3 FCT_LEAD_FUNNEL (grain: one row per lead stage transition)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.FACTS.FCT_LEAD_FUNNEL AS
SELECT
    event_id,
    event_time,
    event_time::DATE as event_date,
    event_detail_type,
    -- Dimension keys
    data_payload:proBusinessId::STRING as pro_business_id,
    data_payload:crmLeadId::STRING as crm_lead_id,
    data_payload:primaryBusinessEmail::STRING as primary_email,
    data_payload:salesRep.name::STRING as sales_rep_name,
    data_payload:salesRep.email::STRING as sales_rep_email,
    -- Funnel stage
    CASE
        WHEN event_detail_type LIKE '%created%' AND data_payload:status::STRING = 'GUEST' THEN 'GUEST'
        WHEN event_detail_type LIKE '%created%' AND data_payload:status::STRING = 'LEAD' THEN 'LEAD_CREATED'
        WHEN event_detail_type LIKE '%lead.approved%' THEN 'LEAD_APPROVED'
        WHEN event_detail_type LIKE '%business-master.approved%' THEN 'BUSINESS_APPROVED'
        WHEN event_detail_type LIKE '%lead.rejected%' THEN 'LEAD_REJECTED'
        WHEN event_detail_type LIKE '%business-master.rejected%' THEN 'BUSINESS_REJECTED'
        WHEN event_detail_type LIKE '%creation-failed%' THEN 'CREATION_FAILED'
        ELSE 'OTHER'
    END as funnel_stage,
    -- Measures
    data_payload:status::STRING as business_status,
    data_payload:auditInfo.createdAt::TIMESTAMP_NTZ as submission_time,
    DATEDIFF('second', data_payload:auditInfo.createdAt::TIMESTAMP_NTZ, event_time) as seconds_in_stage,
    -- Failure/rejection detail
    data_payload:reason::STRING as failure_reason,
    data_payload:rejectionReason::STRING as rejection_reason
FROM ANALYTICS_DB.STAGING.STG_EVENTS_PARSED
WHERE event_detail_type IN (
    'fluidrapro.pro-business-master.created.v1',
    'fluidrapro.pro-business-master.approved.v1',
    'fluidrapro.pro-business-master.rejected.v1',
    'fluidrapro.pro-business-master.creation-failed.v1',
    'fluidrapro.pro-business-lead.approved.v1',
    'fluidrapro.pro-business-lead.rejected.v1'
);
```

### 4.4 FCT_RECONCILIATION (grain: one row per reconciliation run)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.FACTS.FCT_RECONCILIATION AS
SELECT
    event_id,
    event_time,
    event_time::DATE as event_date,
    data_payload:runId::STRING as run_id,
    data_payload:entity::STRING as entity,
    data_payload:domains as domains_array,
    data_payload:config.dqStructural::STRING as dq_structural_version,
    data_payload:config.gatekeeperPolicy::STRING as gatekeeper_policy_version,
    data_payload:config.masteringRules::STRING as mastering_rules_version,
    data_payload:decisionsPrefix::STRING as decisions_prefix,
    data_payload:diffsPrefix::STRING as diffs_prefix
FROM ANALYTICS_DB.STAGING.STG_EVENTS_PARSED
WHERE event_detail_type = 'fluidrapro.pro-reconcile.completed.v1';
```

---

## 5. Metrics Views (Pre-Aggregated KPIs)

### 5.1 METRIC_DEALER_ADOPTION (KPIs 1.1–1.5)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.METRICS.METRIC_DEALER_ADOPTION AS
WITH dealer_current_state AS (
    SELECT * FROM ANALYTICS_DB.DIMENSIONS.DIM_DEALER
),
contact_state AS (
    SELECT * FROM ANALYTICS_DB.DIMENSIONS.DIM_CONTACT
),
new_dealers AS (
    SELECT
        event_date,
        COUNT(*) as new_dealer_count
    FROM ANALYTICS_DB.FACTS.FCT_PRO_BUSINESS_MASTER_EVENTS
    WHERE is_created_event = 1
    GROUP BY event_date
)
SELECT
    -- KPI 1.1: Total Active Dealer Accounts (login in last 30 days)
    COUNT(DISTINCT CASE
        WHEN d.login_status = 'ACTIVE'
         AND c.last_login_date >= DATEADD('day', -30, CURRENT_TIMESTAMP())
        THEN d.pro_business_id
    END) as kpi_1_1_active_dealers_30d,

    -- KPI 1.2: Total Enrolled Dealers (ACTIVE status + ACTIVE rewards)
    COUNT(DISTINCT CASE
        WHEN d.business_status = 'ACTIVE'
         AND p.program_status = 'ACTIVE'
        THEN d.pro_business_id
    END) as kpi_1_2_enrolled_dealers,

    -- KPI 1.3: Dealers Not Set Up (PENDING login status)
    COUNT(DISTINCT CASE
        WHEN d.login_status = 'PENDING'
        THEN d.pro_business_id
    END) as kpi_1_3_dealers_not_setup,

    -- KPI 1.4: Total Inactive Dealers (active account, no login in 30+ days)
    COUNT(DISTINCT CASE
        WHEN d.login_status = 'ACTIVE'
         AND (c.last_login_date < DATEADD('day', -30, CURRENT_TIMESTAMP())
              OR c.last_login_date IS NULL)
        THEN d.pro_business_id
    END) as kpi_1_4_inactive_dealers,

    -- KPI 1.5: New Dealer Accounts (period total)
    (SELECT SUM(new_dealer_count) FROM new_dealers) as kpi_1_5_new_dealers_total

FROM dealer_current_state d
LEFT JOIN ANALYTICS_DB.DIMENSIONS.DIM_CONTACT c
    ON d.pro_business_id = c.pro_business_id
LEFT JOIN ANALYTICS_DB.DIMENSIONS.DIM_PROGRAM p
    ON d.pro_business_id = p.pro_business_id;
```

### 5.2 METRIC_DEALER_CONVERSION (KPIs 2.1–2.4)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.METRICS.METRIC_DEALER_CONVERSION AS
WITH funnel_stats AS (
    SELECT
        funnel_stage,
        COUNT(*) as stage_count,
        AVG(seconds_in_stage) as avg_seconds_in_stage,
        MAX(seconds_in_stage) as max_seconds_in_stage
    FROM ANALYTICS_DB.FACTS.FCT_LEAD_FUNNEL
    GROUP BY funnel_stage
)
SELECT
    -- KPI 2.1: Guest-to-Lead Conversion
    (SELECT stage_count FROM funnel_stats WHERE funnel_stage = 'GUEST') as guest_count,
    (SELECT stage_count FROM funnel_stats WHERE funnel_stage = 'LEAD_CREATED') as lead_created_count,
    CASE
        WHEN (SELECT stage_count FROM funnel_stats WHERE funnel_stage = 'GUEST') > 0
        THEN ROUND(
            (SELECT stage_count FROM funnel_stats WHERE funnel_stage = 'LEAD_CREATED')::FLOAT /
            ((SELECT stage_count FROM funnel_stats WHERE funnel_stage = 'GUEST') +
             (SELECT stage_count FROM funnel_stats WHERE funnel_stage = 'LEAD_CREATED'))::FLOAT * 100, 2)
        ELSE NULL
    END as kpi_2_1_guest_to_lead_pct,

    -- KPI 2.2: Lead Rejection Rate
    (SELECT stage_count FROM funnel_stats WHERE funnel_stage = 'LEAD_REJECTED') as rejections,
    (SELECT stage_count FROM funnel_stats WHERE funnel_stage = 'LEAD_APPROVED') as approvals,
    ROUND(
        (SELECT COALESCE(stage_count, 0) FROM funnel_stats WHERE funnel_stage = 'LEAD_REJECTED')::FLOAT /
        NULLIF(
            (SELECT COALESCE(stage_count, 0) FROM funnel_stats WHERE funnel_stage = 'LEAD_APPROVED') +
            (SELECT COALESCE(stage_count, 0) FROM funnel_stats WHERE funnel_stage = 'LEAD_REJECTED'),
        0)::FLOAT * 100, 2
    ) as kpi_2_2_rejection_rate_pct,

    -- KPI 2.3: Time to Approve Lead (avg seconds)
    (SELECT avg_seconds_in_stage FROM funnel_stats WHERE funnel_stage = 'LEAD_APPROVED')
        as kpi_2_3_avg_seconds_to_approve,
    (SELECT max_seconds_in_stage FROM funnel_stats WHERE funnel_stage = 'LEAD_APPROVED')
        as kpi_2_3_max_seconds_to_approve,

    -- KPI 2.4: Approved to Rewards Activation (avg hours)
    (SELECT AVG(DATEDIFF('hour', p.rewards_created_at, d.last_event_time))
     FROM ANALYTICS_DB.DIMENSIONS.DIM_DEALER d
     JOIN ANALYTICS_DB.DIMENSIONS.DIM_PROGRAM p ON d.pro_business_id = p.pro_business_id
     WHERE d.business_status = 'ACTIVE' AND p.program_status = 'ACTIVE'
    ) as kpi_2_4_avg_hours_to_rewards_activation;
```

### 5.3 METRIC_USER_ADOPTION (KPIs 3.1–3.7)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.METRICS.METRIC_USER_ADOPTION AS
WITH contact_events AS (
    SELECT * FROM ANALYTICS_DB.FACTS.FCT_PRO_CONTACT_MASTER_EVENTS
),
contacts_created AS (
    SELECT DISTINCT pro_contact_id
    FROM contact_events
    WHERE is_created_event = 1
),
logins_created AS (
    SELECT DISTINCT pro_contact_id
    FROM contact_events
    WHERE is_login_created_event = 1
),
technicians_created AS (
    SELECT DISTINCT pro_contact_id
    FROM contact_events
    WHERE is_created_event = 1
      AND contact_type = 'TECHNICIAN'
),
time_to_first_login AS (
    SELECT
        c.pro_contact_id,
        DATEDIFF('minute',
            MIN(CASE WHEN ce.is_created_event = 1 THEN ce.event_time END),
            MIN(CASE WHEN ce.is_login_created_event = 1 THEN ce.event_time END)
        ) as minutes_to_first_login
    FROM contacts_created c
    JOIN contact_events ce ON c.pro_contact_id = ce.pro_contact_id
    GROUP BY c.pro_contact_id
    HAVING MIN(CASE WHEN ce.is_login_created_event = 1 THEN ce.event_time END) IS NOT NULL
)
SELECT
    -- KPI 3.1: Total Active Users
    (SELECT COUNT(*) FROM ANALYTICS_DB.DIMENSIONS.DIM_CONTACT
     WHERE login_status = 'ACTIVE') as kpi_3_1_total_active_users,

    -- KPI 3.2: New Technician Accounts
    (SELECT COUNT(*) FROM technicians_created) as kpi_3_2_new_technicians,

    -- KPI 3.3: Users Never Set Up
    (SELECT COUNT(*) FROM contacts_created
     WHERE pro_contact_id NOT IN (SELECT pro_contact_id FROM logins_created)
    ) as kpi_3_3_users_never_setup,

    -- KPI 3.4: Inactive Users (active login status but stale lastLoginDate)
    (SELECT COUNT(*) FROM ANALYTICS_DB.DIMENSIONS.DIM_CONTACT
     WHERE login_status = 'ACTIVE'
       AND (last_login_date < DATEADD('day', -30, CURRENT_TIMESTAMP()) OR last_login_date IS NULL)
    ) as kpi_3_4_inactive_users,

    -- KPI 3.5: Time to First Login (avg minutes)
    (SELECT AVG(minutes_to_first_login) FROM time_to_first_login) as kpi_3_5_avg_minutes_to_first_login,
    (SELECT MAX(minutes_to_first_login) FROM time_to_first_login) as kpi_3_5_max_minutes_to_first_login,

    -- KPI 3.6: First Login Rate (%)
    ROUND(
        (SELECT COUNT(*) FROM logins_created)::FLOAT /
        NULLIF((SELECT COUNT(*) FROM contacts_created), 0)::FLOAT * 100, 2
    ) as kpi_3_6_first_login_rate_pct,

    -- KPI 3.7: Active Users per Dealer (avg)
    (SELECT AVG(user_count) FROM (
        SELECT pro_business_id, COUNT(*) as user_count
        FROM ANALYTICS_DB.DIMENSIONS.DIM_CONTACT
        WHERE login_status = 'ACTIVE' AND pro_business_id IS NOT NULL
        GROUP BY pro_business_id
    )) as kpi_3_7_avg_active_users_per_dealer;
```

### 5.4 METRIC_DEALER_HEALTH (composite dashboard view)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.METRICS.METRIC_DEALER_HEALTH AS
SELECT
    d.pro_business_id,
    d.business_name,
    d.business_status,
    d.login_status,
    d.primary_business_type,
    d.business_segment,
    d.channel,
    d.customer_class,
    d.sales_channel,
    d.registration_source,
    d.fluidra_account_number,
    d.key_account_type_name,
    d.key_account_type_role,
    d.created_at as business_created_at,
    -- Program info
    p.program_level,
    p.achiever_level,
    p.program_status as rewards_status,
    p.rebate_pay_type,
    p.program_signup_date,
    -- Contact info
    c.contact_type as primary_contact_type,
    c.login_status as contact_login_status,
    c.last_login_date,
    c.cognito_sub_id,
    -- Computed health indicators
    CASE
        WHEN d.login_status = 'ACTIVE' AND c.last_login_date >= DATEADD('day', -30, CURRENT_TIMESTAMP())
            THEN 'HEALTHY'
        WHEN d.login_status = 'ACTIVE' AND c.last_login_date < DATEADD('day', -30, CURRENT_TIMESTAMP())
            THEN 'AT_RISK'
        WHEN d.login_status = 'PENDING'
            THEN 'NOT_ONBOARDED'
        ELSE 'UNKNOWN'
    END as health_status,
    DATEDIFF('day', c.last_login_date, CURRENT_TIMESTAMP()) as days_since_last_login,
    -- Distributor coverage
    (SELECT COUNT(*) FROM ANALYTICS_DB.DIMENSIONS.DIM_DISTRIBUTOR dist
     WHERE dist.pro_business_id = d.pro_business_id
       AND dist.distributor_account_status = 'ACTIVE') as active_distributor_count,
    -- Program opt-in count
    (SELECT COUNT(*) FROM ANALYTICS_DB.DIMENSIONS.DIM_PROGRAM_OPT_IN poi
     WHERE poi.pro_business_id = d.pro_business_id
       AND poi.program_status = 'ACTIVE') as active_program_count,
    -- Subscription count
    (SELECT COUNT(*) FROM ANALYTICS_DB.DIMENSIONS.DIM_SUBSCRIPTION sub
     WHERE sub.pro_business_id = d.pro_business_id
       AND sub.subscription_status = 'ACTIVE') as active_subscription_count
FROM ANALYTICS_DB.DIMENSIONS.DIM_DEALER d
LEFT JOIN ANALYTICS_DB.DIMENSIONS.DIM_CONTACT c
    ON d.pro_business_id = c.pro_business_id
LEFT JOIN ANALYTICS_DB.DIMENSIONS.DIM_PROGRAM p
    ON d.pro_business_id = p.pro_business_id;
```

### 5.5 METRIC_FUNNEL_DAILY (daily funnel metrics)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.METRICS.METRIC_FUNNEL_DAILY AS
SELECT
    event_date,
    -- Volume metrics
    COUNT(*) as total_funnel_events,
    SUM(CASE WHEN funnel_stage = 'GUEST' THEN 1 ELSE 0 END) as guest_registrations,
    SUM(CASE WHEN funnel_stage = 'LEAD_CREATED' THEN 1 ELSE 0 END) as leads_created,
    SUM(CASE WHEN funnel_stage = 'LEAD_APPROVED' THEN 1 ELSE 0 END) as leads_approved,
    SUM(CASE WHEN funnel_stage = 'BUSINESS_APPROVED' THEN 1 ELSE 0 END) as businesses_approved,
    SUM(CASE WHEN funnel_stage = 'LEAD_REJECTED' THEN 1 ELSE 0 END) as leads_rejected,
    SUM(CASE WHEN funnel_stage = 'BUSINESS_REJECTED' THEN 1 ELSE 0 END) as businesses_rejected,
    SUM(CASE WHEN funnel_stage = 'CREATION_FAILED' THEN 1 ELSE 0 END) as creation_failures,
    -- Conversion rates
    ROUND(
        SUM(CASE WHEN funnel_stage = 'LEAD_APPROVED' THEN 1 ELSE 0 END)::FLOAT /
        NULLIF(SUM(CASE WHEN funnel_stage IN ('LEAD_APPROVED','LEAD_REJECTED') THEN 1 ELSE 0 END), 0)
        * 100, 2
    ) as approval_rate_pct,
    -- Timing
    AVG(CASE WHEN funnel_stage = 'LEAD_APPROVED' THEN seconds_in_stage END) as avg_seconds_to_approve
FROM ANALYTICS_DB.FACTS.FCT_LEAD_FUNNEL
GROUP BY event_date
ORDER BY event_date;
```

### 5.6 METRIC_REGISTRATION_TRENDS (weekly new dealer trend)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.METRICS.METRIC_REGISTRATION_TRENDS AS
SELECT
    DATE_TRUNC('week', event_date) as week_start,
    -- New dealers
    SUM(is_created_event) as new_dealers,
    -- By segment
    SUM(CASE WHEN business_status = 'LEAD' AND is_created_event = 1 THEN 1 ELSE 0 END) as new_leads,
    SUM(CASE WHEN business_status = 'GUEST' AND is_created_event = 1 THEN 1 ELSE 0 END) as new_guests,
    -- Creation failures
    SUM(is_creation_failed) as failed_registrations,
    -- Failure rate
    ROUND(
        SUM(is_creation_failed)::FLOAT /
        NULLIF(SUM(is_created_event) + SUM(is_creation_failed), 0) * 100, 2
    ) as registration_failure_rate_pct,
    -- By source
    SUM(CASE WHEN source = 'PROWEB' AND is_created_event = 1 THEN 1 ELSE 0 END) as from_proweb,
    SUM(CASE WHEN source = 'SALESFORCE' AND is_created_event = 1 THEN 1 ELSE 0 END) as from_salesforce,
    -- By business type
    SUM(CASE WHEN is_created_event = 1 THEN distributor_count ELSE 0 END) as total_distributor_links
FROM ANALYTICS_DB.FACTS.FCT_PRO_BUSINESS_MASTER_EVENTS
GROUP BY DATE_TRUNC('week', event_date)
ORDER BY week_start;
```

### 5.7 METRIC_PROGRAM_ENROLLMENT (program adoption metrics)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.METRICS.METRIC_PROGRAM_ENROLLMENT AS
SELECT
    poi.program_name,
    -- Status counts
    COUNT(DISTINCT CASE WHEN poi.program_status = 'ACTIVE' THEN poi.pro_business_id END) as active_count,
    COUNT(DISTINCT CASE WHEN poi.program_status = 'PENDING' THEN poi.pro_business_id END) as pending_count,
    COUNT(DISTINCT CASE WHEN poi.program_status = 'DECLINED' THEN poi.pro_business_id END) as declined_count,
    COUNT(DISTINCT CASE WHEN poi.program_status = 'INACTIVE' THEN poi.pro_business_id END) as inactive_count,
    COUNT(DISTINCT poi.pro_business_id) as total_enrolled,
    -- Activation rate
    ROUND(
        COUNT(DISTINCT CASE WHEN poi.program_status = 'ACTIVE' THEN poi.pro_business_id END)::FLOAT /
        NULLIF(COUNT(DISTINCT poi.pro_business_id), 0) * 100, 2
    ) as activation_rate_pct,
    -- Decline rate
    ROUND(
        COUNT(DISTINCT CASE WHEN poi.program_status = 'DECLINED' THEN poi.pro_business_id END)::FLOAT /
        NULLIF(COUNT(DISTINCT poi.pro_business_id), 0) * 100, 2
    ) as decline_rate_pct
FROM ANALYTICS_DB.DIMENSIONS.DIM_PROGRAM_OPT_IN poi
GROUP BY poi.program_name
ORDER BY total_enrolled DESC;
```

### 5.8 METRIC_DISTRIBUTOR_COVERAGE (distributor health metrics)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.METRICS.METRIC_DISTRIBUTOR_COVERAGE AS
SELECT
    dist.distributor_name,
    -- Status breakdown
    COUNT(DISTINCT CASE WHEN dist.distributor_account_status = 'ACTIVE'
        THEN dist.pro_business_id END) as active_dealers,
    COUNT(DISTINCT CASE WHEN dist.distributor_account_status = 'PENDING ACTIVE'
        THEN dist.pro_business_id END) as pending_active_dealers,
    COUNT(DISTINCT CASE WHEN dist.distributor_account_status = 'PENDING INACTIVE'
        THEN dist.pro_business_id END) as pending_inactive_dealers,
    COUNT(DISTINCT CASE WHEN dist.distributor_account_status = 'INACTIVE'
        THEN dist.pro_business_id END) as inactive_dealers,
    COUNT(DISTINCT dist.pro_business_id) as total_dealers,
    -- Health rate
    ROUND(
        COUNT(DISTINCT CASE WHEN dist.distributor_account_status = 'ACTIVE'
            THEN dist.pro_business_id END)::FLOAT /
        NULLIF(COUNT(DISTINCT dist.pro_business_id), 0) * 100, 2
    ) as active_rate_pct,
    -- Source breakdown
    COUNT(DISTINCT CASE WHEN dist.source = 'MANUAL' THEN dist.pro_business_id END) as manual_source,
    COUNT(DISTINCT CASE WHEN dist.source = 'PROWEB' THEN dist.pro_business_id END) as proweb_source
FROM ANALYTICS_DB.DIMENSIONS.DIM_DISTRIBUTOR dist
GROUP BY dist.distributor_name
ORDER BY total_dealers DESC;
```

### 5.9 METRIC_CONTACT_ONBOARDING (contact lifecycle tracking)

```sql
CREATE OR REPLACE VIEW ANALYTICS_DB.METRICS.METRIC_CONTACT_ONBOARDING AS
WITH created AS (
    SELECT
        pro_contact_id,
        contact_type,
        MIN(event_time) as created_time
    FROM ANALYTICS_DB.FACTS.FCT_PRO_CONTACT_MASTER_EVENTS
    WHERE is_created_event = 1
    GROUP BY pro_contact_id, contact_type
),
login_created AS (
    SELECT
        pro_contact_id,
        MIN(event_time) as login_created_time
    FROM ANALYTICS_DB.FACTS.FCT_PRO_CONTACT_MASTER_EVENTS
    WHERE is_login_created_event = 1
    GROUP BY pro_contact_id
)
SELECT
    c.contact_type,
    COUNT(DISTINCT c.pro_contact_id) as total_created,
    COUNT(DISTINCT l.pro_contact_id) as completed_login_setup,
    COUNT(DISTINCT c.pro_contact_id) - COUNT(DISTINCT l.pro_contact_id) as never_setup,
    -- First login rate by contact type
    ROUND(
        COUNT(DISTINCT l.pro_contact_id)::FLOAT /
        NULLIF(COUNT(DISTINCT c.pro_contact_id), 0) * 100, 2
    ) as first_login_rate_pct,
    -- Avg time to first login (minutes)
    AVG(DATEDIFF('minute', c.created_time, l.login_created_time)) as avg_minutes_to_login,
    MAX(DATEDIFF('minute', c.created_time, l.login_created_time)) as max_minutes_to_login
FROM created c
LEFT JOIN login_created l ON c.pro_contact_id = l.pro_contact_id
GROUP BY c.contact_type
ORDER BY total_created DESC;
```

---

## 6. Entity Relationship Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                        DIMENSIONS                                      │
├──────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ┌─────────────┐     ┌──────────────┐     ┌─────────────────┐        │
│  │ DIM_DEALER  │◄────│ DIM_CONTACT  │     │ DIM_LOCATION    │        │
│  │             │     │              │     │                 │        │
│  │ pro_biz_id  │     │ pro_contact  │     │ pro_location_id │        │
│  │ biz_name    │     │ contact_type │     │ city, state     │        │
│  │ status      │     │ login_status │     │ location_type   │        │
│  │ segment     │     │ cognito_sub  │     │                 │        │
│  └──────┬──────┘     └──────────────┘     └─────────────────┘        │
│         │                                                              │
│         ├──────────────────┬──────────────────┬────────────────┐      │
│         │                  │                  │                │      │
│  ┌──────▼──────┐   ┌──────▼───────┐  ┌──────▼──────┐  ┌─────▼────┐ │
│  │DIM_PROGRAM  │   │DIM_DISTRIBTR │  │DIM_PROG_OPT │  │DIM_SUBSCR│ │
│  │             │   │              │  │             │  │          │ │
│  │ prog_level  │   │ dist_name    │  │ prog_name   │  │ sub_name │ │
│  │ achiever_lv │   │ acct_status  │  │ prog_status │  │ sub_stat │ │
│  │ rebate_type │   │ acct_number  │  │ opt_in_date │  │ start_dt │ │
│  └─────────────┘   └──────────────┘  └─────────────┘  └──────────┘ │
│                                                                        │
│  ┌─────────────┐   ┌──────────────┐                                   │
│  │DIM_SALES_REP│   │  DIM_DATE    │                                   │
│  │             │   │              │                                   │
│  │ rep_name    │   │ date_key     │                                   │
│  │ rep_email   │   │ week, month  │                                   │
│  └─────────────┘   └──────────────┘                                   │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                           FACTS                                        │
├──────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────────┐  │
│  │FCT_PRO_BUSINESS_MASTER_EVENTS │  │FCT_PRO_CONTACT_MASTER_EVENTS│  │ FCT_LEAD_FUNNEL   │  │
│  │                  │  │                  │  │                    │  │
│  │ event_id         │  │ event_id         │  │ event_id           │  │
│  │ event_time       │  │ event_time       │  │ event_time         │  │
│  │ pro_business_id  │  │ pro_contact_id   │  │ pro_business_id    │  │
│  │ event_type flags │  │ contact_type     │  │ funnel_stage       │  │
│  │ distributor_cnt  │  │ event_type flags │  │ seconds_in_stage   │  │
│  │ program_cnt      │  │                  │  │ sales_rep          │  │
│  │ utm_*            │  │                  │  │ crm_lead_id        │  │
│  └──────────────────┘  └──────────────────┘  └────────────────────┘  │
│                                                                        │
│  ┌──────────────────┐                                                  │
│  │FCT_RECONCILIATION│                                                  │
│  │                  │                                                  │
│  │ run_id           │                                                  │
│  │ entity           │                                                  │
│  │ config_versions  │                                                  │
│  └──────────────────┘                                                  │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                        METRICS VIEWS                                   │
├──────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  METRIC_DEALER_ADOPTION      → KPIs 1.1–1.5                           │
│  METRIC_DEALER_CONVERSION    → KPIs 2.1–2.4                           │
│  METRIC_USER_ADOPTION        → KPIs 3.1–3.7                           │
│  METRIC_DEALER_HEALTH        → Per-dealer composite scorecard          │
│  METRIC_FUNNEL_DAILY         → Daily funnel volume & rates             │
│  METRIC_REGISTRATION_TRENDS  → Weekly new dealer trends                │
│  METRIC_PROGRAM_ENROLLMENT   → Program adoption by type                │
│  METRIC_DISTRIBUTOR_COVERAGE → Distributor health by name              │
│  METRIC_CONTACT_ONBOARDING   → Contact lifecycle by type               │
│                                                                        │
└──────────────────────────────────────────────────────────────────────┘
```

### 6.1 Advanced ER Diagram (Interactive)

![Fluidra Pro Dimensional Model](fluidra-dimensional-model.png)

**[▶ View & Edit Interactive ER Diagram on Mermaid Live](https://mermaid.live/edit#pako:eNq9WW1v2zYQ_iuCP6_AFncb0G-OraTGHDuQnQIDAhCMRMtcJFIjKQeek_--E_ViUqJkxxjWAi3Cu3t473dUjqOQR2T0zRsRMaM4Fjh9Zh78mc0f0MyfLPzAe3__8oUf9cl0tdxMphvvm_c82mHphZwpHCr5PBqSWqymk818tWzEEh5iRTk7IzebrzfB_PZpswq0aELZK4k8xb2ISiXoS6646MN4f9cnj8HqPpg8NFcL8oZFJL1McG3soAKVMFo9btC8VJ9nClSgDJSoIM4YsX66XU-D-aPlAJm_yFDQ7IwT7qab6gT5P_zlZq0BYsKIwIpIj-wJU2fkF_5khu6elkt_oaVBggjpbXPGSGKK1rE1ZKujSy-vET64dv9tMJ_d-w1IpVoBIojkyR78uKe4BnBzV1CGaXUiSMgD8_I1UNco8B-HjE8xwzHonhAc2X6bbPxhr2tzvQhMH5JzeOwywU6YOlJdtSrxBx-qZFrTJrPVKddwHAsS63CdvHUOKPDvi8LTJYs2gb-crYfBTN2dOoFXfvjB-qxW_UDlIXhtvvhzGKMVARvmaX2xhwZxauJqebuaBLP58r4fzNFIbLCa6C-D1WLxANcNg5ltseXuEwVUBJdP7v0zWFa_sKP2Hf7bfNfyIU8zLqkiHt8W4h2AY3lS_Ck6M4uL7oheckkZkRLRyHv8o8PSkBlOST9VKqxy2aEnPKasj5gJmmJxOGmgDtnQFSROod46DOEO6zbZOc-l4ikRKEyw7N4ucUIk6hPeJjmNBEY4DHnOFGJ5-kJEh-2VHBqWQnu3l0KRoqKbgYs7NAh5MSf1qEWS5yI05BVNCTgvzQCCQGZECFf2f5jxrXu6O8DV_O-JbzsF7rosNYAzPFsqpHKbDW7voZAU0-RzyRLymFHFEUxly40nF-nrSgzdkj_rxWYDcrux3oeu92OD4HRkSNWhm6TKsqQ6_YdmDv9ADopD_6WmXy27zVZ1vMYuY9Fzh9tkOFNQLtaejOgvFkhWuidGFlj21tvmVe2w2iehnPeOroHDHQWC6CHXwj0GCfICGqMMH1oZcrKsQaAxy7MzFtaT7Kqg1jc5A9pnSFdRWMWRVZCWotbe3VXT3MCvLzsLxWmOxXHeJvhJqF6TmhX32DNyBMmQboAue04sJ03tai12UgO6UEP_g2AWWYhU76YHxLfojZBXm1CcFJQDwcKmpNDtd53yLCh_52B3-_AE0KjpfiVcm4Xm_HJwCJKUz9QdzYyyaZTpLtJdRfQe306wU9xLcvHzNSaU0hFREPFWXesIGQ1Ptzub3KojBweFJaYaa_qqDhVnALLvJQvyFwkd0pX6uUo7a4lBCsFBGJqRw-ut5fy_dvtwWly91lzk0nLLcPBYDjBfSv9z0g1tnOVXhaKLxS27JQGfRBKVW1hMLupOJjKkeC4IMGDJ2ynR8wI-2iq8ZhT9An_rEU7gRiHR-OfIxXeDCBM8SSAIFaeLa9zAMA7bBFF55mL7Cnbb17q4fkWMvDWAiiucDBpqPKsNU7cJxyXiDWDGOQQdsMqQZaFyM95UtVpMKaE3hT7OMcL7GNXhBOCqB7i5v2ruHRR5yVv4QPdUt2H2-9wRvzGYpB1TRzGXTmeO4e7CmYqEO0ZDipmTaVzKA2uxWbXCd7JjjH5D5WOkrM4hD43R79rmEjgD2DKgg5GsntpXzbEdwMNUbe8W1YiGty1lIUGnF4zNUmfl8KiouOqJYXC0DbI-1LR3iWpeWe-OAl5_jmuGiYtWT5K2x0sZSAc7JG2tXJ-02srptUXvX7YCRk22b7ce2E2HGtTE8bHneOGCbATCNc0Ji0C2Tarc1NTdGfWcX5COn3iWmTnldlpFHdbD8YHt-IkpW7aIaoi2FbikkosKTinLFdF9yyicj9FP3iglArbsqPi9yfF5pHYEXDAqPpRFZIvzRD2PNFueFZlV_V4F6ErkBI4Fz-Md_LjFiSQf_wICvCEY)**

> Click the link above to view the full interactive ER diagram with all entities, attributes, PKs, FKs, and relationships rendered professionally.

**Download rendered images:**
- [SVG (vector, scalable)](https://diagrams-mcp-production.up.railway.app/images/tH5Vr-07QFBPaoYy751-81MxyPMDxMn8FeQRN7KkN7w)
- [PNG (raster)](https://diagrams-mcp-production.up.railway.app/images/-aWodr9mW05CDCvj08ZazX_fq7d_Ey0gfc5pGQ_EGkE)

#### Relationship Notation

| Symbol | Meaning | Example |
|--------|---------|---------|
| `||--||` | Exactly one-to-one | DIM_DEALER has exactly one DIM_PROGRAM |
| `||--o{` | One-to-many | DIM_DEALER has many DIM_CONTACTs |
| `}o--||` | Many-to-one (reverse) | BRIDGE resolves many contacts to one dealer |
| PK | Primary Key | Uniquely identifies the row |
| FK | Foreign Key | References parent dimension |

#### Layer Legend

| Layer | Purpose | Grain |
|-------|---------|-------|
| **DIM_*** | Conformed dimensions | Current state (latest per entity) |
| **BRIDGE_*** | Resolves broken/implicit FK relationships | One row per link |
| **FCT_*** | Fact tables | One row per event occurrence |
| **METRIC_*** | Pre-aggregated KPI views | Consumed by dashboards/BI tools |

#### Key Design Decisions

1. **Star Schema with Bridge** — DIM_DEALER is the central hub. All other dims connect via `pro_business_id`.
2. **Bridge Pattern** — BRIDGE_CONTACT_DEALER resolves the NULL `proBusinessId` on contact-created events by extracting the relationship from business-master events.
3. **Degenerate Dimensions** — UTM fields live directly on FCT_PRO_BUSINESS_MASTER_EVENTS (no separate UTM dimension needed at this volume).
4. **Conformed Dimensions** — DIM_DATE is role-playing across all fact tables (event_date FK).
5. **Semi-Additive Facts** — `distributor_count` and `program_opt_in_count` are snapshot measures (latest state), not additive across time.

```
1. ANALYTICS_DB.STAGING.STG_EVENTS_PARSED          (base layer — deduped, typed)
2. ANALYTICS_DB.DIMENSIONS.DIM_DATE                (no dependencies)
3. ANALYTICS_DB.DIMENSIONS.DIM_DEALER              (depends on: staging)
4. ANALYTICS_DB.DIMENSIONS.DIM_CONTACT             (depends on: staging)
5. ANALYTICS_DB.DIMENSIONS.DIM_LOCATION            (depends on: staging)
6. ANALYTICS_DB.DIMENSIONS.DIM_PROGRAM             (depends on: staging)
7. ANALYTICS_DB.DIMENSIONS.DIM_DISTRIBUTOR         (depends on: staging)
8. ANALYTICS_DB.DIMENSIONS.DIM_PROGRAM_OPT_IN      (depends on: staging)
9. ANALYTICS_DB.DIMENSIONS.DIM_SUBSCRIPTION        (depends on: staging)
10. ANALYTICS_DB.DIMENSIONS.DIM_SALES_REP          (depends on: staging)
11. ANALYTICS_DB.FACTS.FCT_PRO_BUSINESS_MASTER_EVENTS           (depends on: staging)
12. ANALYTICS_DB.FACTS.FCT_PRO_CONTACT_MASTER_EVENTS          (depends on: staging)
13. ANALYTICS_DB.FACTS.FCT_LEAD_FUNNEL             (depends on: staging)
14. ANALYTICS_DB.FACTS.FCT_RECONCILIATION          (depends on: staging)
15. ANALYTICS_DB.METRICS.METRIC_DEALER_ADOPTION    (depends on: dims + facts)
16. ANALYTICS_DB.METRICS.METRIC_DEALER_CONVERSION  (depends on: dims + facts)
17. ANALYTICS_DB.METRICS.METRIC_USER_ADOPTION      (depends on: dims + facts)
18. ANALYTICS_DB.METRICS.METRIC_DEALER_HEALTH      (depends on: all dims)
19. ANALYTICS_DB.METRICS.METRIC_FUNNEL_DAILY       (depends on: facts)
20. ANALYTICS_DB.METRICS.METRIC_REGISTRATION_TRENDS(depends on: facts)
21. ANALYTICS_DB.METRICS.METRIC_PROGRAM_ENROLLMENT (depends on: dims)
22. ANALYTICS_DB.METRICS.METRIC_DISTRIBUTOR_COVERAGE(depends on: dims)
23. ANALYTICS_DB.METRICS.METRIC_CONTACT_ONBOARDING (depends on: facts)
```
