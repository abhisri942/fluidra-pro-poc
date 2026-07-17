# FluidraPro Model Field Dictionary

> Complete field-level reference for every model in the dbt project.
> Each section lists the final output fields, their data types, and purpose.

---

## Table of Contents

1. [Staging Models](#staging-models)
2. [Dimension Models](#dimension-models)
3. [Fact Models](#fact-models)
4. [Mart Models](#mart-models)

---

## Staging Models

### stg_pro_business_master_events

**Grain:** One row per `event_id` (every business event, Kafka duplicates removed)
**Purpose:** Parse raw JSON Kafka events into typed columns for all business lifecycle events.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | event_id | STRING | Unique event identifier from payload |
| 2 | event_detail_type | STRING | Full event type string (e.g., `fluidrapro.pro-business-master.created.v1`) |
| 3 | event_time | TIMESTAMP_NTZ | When the event occurred |
| 4 | event_date | DATE | Date portion of event_time |
| 5 | event_source | STRING | Source system identifier |
| 6 | event_region | STRING | AWS region where event originated |
| 7 | kafka_offset | NUMBER | Kafka message offset (used for deduplication) |
| 8 | kafka_partition | NUMBER | Kafka partition number |
| 9 | kafka_topic | STRING | Kafka topic name |
| 10 | metadata_event_type | STRING | Event type from metadata (created/updated/approved/rejected) |
| 11 | correlation_id | STRING | Correlation ID linking related events |
| 12 | metadata_service | STRING | Source microservice name |
| 13 | metadata_sub_domain | STRING | Business sub-domain |
| 14 | payload_version | STRING | Schema version of the event payload |
| 15 | pro_business_id | STRING | Unique business/dealer identifier |
| 16 | business_name | STRING | Registered business name |
| 17 | doing_business_as | STRING | DBA / trade name |
| 18 | business_status | STRING | Current status (GUEST, LEAD, APPROVED, REJECTED, etc.) |
| 19 | login_status | STRING | Login setup status for the business |
| 20 | registration_source | STRING | How the dealer registered (web, mobile, admin, etc.) |
| 21 | customer_type | STRING | Customer type classification |
| 22 | primary_business_type | STRING | Primary business type (Pool Builder, Service Tech, etc.) |
| 23 | business_segment | STRING | Business segment classification |
| 24 | channel | STRING | Sales channel |
| 25 | customer_class | STRING | Customer class tier |
| 26 | sales_channel | STRING | Sales channel attribute |
| 27 | primary_business_email | STRING | Primary email for the business |
| 28 | primary_business_phone | STRING | Primary phone number |
| 29 | is_primary_key_account | BOOLEAN | Whether this is a primary key account |
| 30 | key_account_type_name | STRING | Name of the key account type |
| 31 | fluidra_account_number | STRING | Fluidra ERP account number |
| 32 | crm_lead_id | STRING | CRM lead ID for the business |
| 33 | web_account_id | STRING | Web account ID |
| 34 | terms_accepted | BOOLEAN | Whether T&C were accepted |
| 35 | e_statement_enabled | BOOLEAN | E-statement preference |
| 36 | is_marcom_consent | BOOLEAN | Marketing communication consent |
| 37 | tse_violator | BOOLEAN | TSE violator flag |
| 38 | rewards_program_level | STRING | Rewards program level |
| 39 | rewards_achiever_level | STRING | Rewards achiever tier |
| 40 | rewards_program_status | STRING | Rewards program status |
| 41 | rewards_rebate_pay_type | STRING | How rebates are paid |
| 42 | rewards_signup_date | TIMESTAMP_NTZ | When dealer signed up for rewards |
| 43 | primary_contact_id | STRING | Pro contact ID of primary contact |
| 44 | primary_contact_type | STRING | Contact type of primary contact |
| 45 | primary_contact_login_status | STRING | Login status of primary contact |
| 46 | primary_contact_last_login | TIMESTAMP_NTZ | Last login of primary contact |
| 47 | billing_location_id | STRING | Pro location ID for billing address |
| 48 | billing_city | STRING | Billing address city |
| 49 | billing_state | STRING | Billing address state |
| 50 | sales_rep_name | STRING | Assigned sales representative name |
| 51 | sales_rep_email | STRING | Assigned sales representative email |
| 52 | utm_source | STRING | UTM source parameter |
| 53 | utm_medium | STRING | UTM medium parameter |
| 54 | utm_campaign | STRING | UTM campaign parameter |
| 55 | distributor_count | NUMBER | Count of distributors array elements |
| 56 | program_opt_in_count | NUMBER | Count of program opt-ins array elements |
| 57 | subscription_count | NUMBER | Count of subscriptions array elements |
| 58 | is_created_event | NUMBER (0/1) | Flag: event is a business creation |
| 59 | is_updated_event | NUMBER (0/1) | Flag: event is a business update |
| 60 | is_approved_event | NUMBER (0/1) | Flag: event is a business approval |
| 61 | is_rejected_event | NUMBER (0/1) | Flag: event is a business rejection |
| 62 | is_creation_failed | NUMBER (0/1) | Flag: business creation failed |
| 63 | is_update_requested | NUMBER (0/1) | Flag: update was requested |
| 64 | is_lead_approved | NUMBER (0/1) | Flag: lead specifically approved |
| 65 | is_lead_rejected | NUMBER (0/1) | Flag: lead specifically rejected |
| 66 | funnel_stage | STRING | Derived funnel stage (GUEST, LEAD_CREATED, LEAD_APPROVED, etc.) |
| 67 | seconds_in_stage | NUMBER | Time spent in current stage (seconds) |
| 68 | failure_reason | STRING | Reason for rejection/failure |
| 69 | record_created_at | TIMESTAMP_NTZ | When the business record was originally created |
| 70 | record_created_by | STRING | Who created the business record |

---

### stg_pro_contact_master_events

**Grain:** One row per `event_id` (every contact event, Kafka duplicates removed)
**Purpose:** Parse raw JSON Kafka events for all contact/user lifecycle events.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | event_id | STRING | Unique event identifier |
| 2 | event_detail_type | STRING | Full event type string (e.g., `fluidrapro.pro-contact-master.created.v1`) |
| 3 | event_time | TIMESTAMP_NTZ | When the event occurred |
| 4 | event_date | DATE | Date portion of event_time |
| 5 | kafka_offset | NUMBER | Kafka message offset |
| 6 | kafka_partition | NUMBER | Kafka partition number |
| 7 | metadata_event_type | STRING | Event type (created/updated/login-created/deleted) |
| 8 | correlation_id | STRING | Correlation ID for event tracing |
| 9 | metadata_service | STRING | Source microservice name |
| 10 | pro_contact_id | STRING | Unique contact/user identifier |
| 11 | pro_business_id | STRING | Business this contact belongs to |
| 12 | contact_type | STRING | Contact role (DEALER, TECHNICIAN) |
| 13 | first_name | STRING | Contact first name |
| 14 | last_name | STRING | Contact last name |
| 15 | email | STRING | Contact email address |
| 16 | phone_number | STRING | Contact phone number |
| 17 | login_status | STRING | Login status (ACTIVE, PENDING, etc.) |
| 18 | username | STRING | Login username |
| 19 | cognito_sub_id | STRING | AWS Cognito subject ID |
| 20 | web_user_id | STRING | Web user ID |
| 21 | last_login_date | TIMESTAMP_NTZ | Last login timestamp |
| 22 | contact_status | STRING | Contact status (ACTIVE, DELETED, etc.) |
| 23 | assigned_location_count | NUMBER | Count of locations assigned to contact |
| 24 | user_subscription_count | NUMBER | Count of user subscriptions |
| 25 | is_created_event | NUMBER (0/1) | Flag: contact was created |
| 26 | is_updated_event | NUMBER (0/1) | Flag: contact was updated |
| 27 | is_login_created_event | NUMBER (0/1) | Flag: login was set up for contact |
| 28 | is_deleted_event | NUMBER (0/1) | Flag: contact was deleted |
| 29 | record_created_at | TIMESTAMP_NTZ | Original creation timestamp |
| 30 | record_created_by | STRING | Who created the record |

---

### stg_pro_business_distributors

**Grain:** One row per (`pro_business_id`, `distributor_name`, `distributor_account_number`) — latest state
**Purpose:** Flatten the distributors[] JSON array into typed rows per business-distributor relationship.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | event_id | STRING | Source event ID |
| 2 | event_time | TIMESTAMP_NTZ | When the event occurred |
| 3 | kafka_offset | NUMBER | Kafka offset for dedup ordering |
| 4 | pro_business_id | STRING | Parent business identifier |
| 5 | distributor_name | STRING | Distributor company name |
| 6 | distributor_account_number | STRING | Account number at the distributor |
| 7 | distributor_account_status | STRING | Account status (ACTIVE, INACTIVE, etc.) |
| 8 | fluidra_account_number | STRING | Linked Fluidra account number |
| 9 | source | STRING | How the distributor was added |
| 10 | active_date | TIMESTAMP_NTZ | Date the relationship became active |
| 11 | distributor_created_at | TIMESTAMP_NTZ | When the relationship was created |
| 12 | distributor_updated_at | TIMESTAMP_NTZ | When the relationship was last updated |
| 13 | distributor_created_by | STRING | Who created the relationship |
| 14 | distributor_updated_by | STRING | Who last updated the relationship |

---

### stg_pro_business_location_master

**Grain:** One row per `pro_location_id` — latest state
**Purpose:** Parse location events into typed columns for dealer physical addresses.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | event_id | STRING | Source event ID |
| 2 | event_detail_type | STRING | Full event type string |
| 3 | event_time | TIMESTAMP_NTZ | When the event occurred |
| 4 | kafka_offset | NUMBER | Kafka offset |
| 5 | metadata_event_type | STRING | Event type (created/updated) |
| 6 | pro_location_id | STRING | Unique location identifier |
| 7 | pro_business_id | STRING | Parent business identifier |
| 8 | location_name | STRING | Location display name |
| 9 | location_type | STRING | Type of location (BILLING, SERVICE, etc.) |
| 10 | location_status | STRING | Location status |
| 11 | street_line_1 | STRING | Street address line 1 |
| 12 | street_line_2 | STRING | Street address line 2 |
| 13 | city | STRING | City |
| 14 | state | STRING | State/province |
| 15 | zip | STRING | ZIP/postal code |
| 16 | country | STRING | Country |
| 17 | phone_number | STRING | Location phone |
| 18 | lead_management_email | STRING | Email for lead routing to this location |
| 19 | hide_address | BOOLEAN | Whether to hide address from public |
| 20 | hide_location | BOOLEAN | Whether to hide location from public |
| 21 | service_zip_count | NUMBER | Count of service ZIP codes covered |
| 22 | created_at | TIMESTAMP_NTZ | Record creation timestamp |
| 23 | created_by | STRING | Who created the record |
| 24 | updated_at | TIMESTAMP_NTZ | Last update timestamp |

---

### stg_pro_business_subscriptions

**Grain:** One row per (`pro_business_id`, `subscription_id`) — latest state
**Purpose:** Flatten the subscriptions[] JSON array into typed rows per business subscription.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | event_id | STRING | Source event ID |
| 2 | event_time | TIMESTAMP_NTZ | When the event occurred |
| 3 | kafka_offset | NUMBER | Kafka offset |
| 4 | pro_business_id | STRING | Parent business identifier |
| 5 | subscription_id | STRING | Unique subscription identifier |
| 6 | subscription_name | STRING | Subscription plan name |
| 7 | subscription_status | STRING | Status (ACTIVE, EXPIRED, etc.) |
| 8 | program_start_date | TIMESTAMP_NTZ | When the subscription started |
| 9 | source | STRING | How subscription was created |
| 10 | subscription_created_at | TIMESTAMP_NTZ | Creation timestamp |
| 11 | subscription_updated_at | TIMESTAMP_NTZ | Last update timestamp |
| 12 | subscription_created_by | STRING | Who created it |
| 13 | subscription_updated_by | STRING | Who last updated it |

---

### stg_pro_business_program_optins

**Grain:** One row per (`pro_business_id`, `program_name`) — latest state
**Purpose:** Flatten the programOptIns[] JSON array into typed rows per program enrollment.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | event_id | STRING | Source event ID |
| 2 | event_time | TIMESTAMP_NTZ | When the event occurred |
| 3 | kafka_offset | NUMBER | Kafka offset |
| 4 | pro_business_id | STRING | Parent business identifier |
| 5 | program_name | STRING | Name of the program |
| 6 | program_status | STRING | Enrollment status |
| 7 | program_opt_in_date | TIMESTAMP_NTZ | When dealer opted in |
| 8 | program_start_date | TIMESTAMP_NTZ | When program became effective |
| 9 | source | STRING | How enrollment was created |
| 10 | fluidra_account_number | STRING | Linked Fluidra account |
| 11 | program_created_at | TIMESTAMP_NTZ | Creation timestamp |
| 12 | program_updated_at | TIMESTAMP_NTZ | Last update timestamp |
| 13 | program_created_by | STRING | Who created it |
| 14 | program_updated_by | STRING | Who last updated it |

---

### stg_pro_key_account_types

**Grain:** One row per `key_account_type_id` — latest state
**Purpose:** Parse key account type reference data from events.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | event_id | STRING | Source event ID |
| 2 | event_detail_type | STRING | Full event type string |
| 3 | event_time | TIMESTAMP_NTZ | When the event occurred |
| 4 | kafka_offset | NUMBER | Kafka offset |
| 5 | metadata_event_type | STRING | Event type (created/updated) |
| 6 | key_account_type_id | STRING | Unique key account type ID |
| 7 | key_account_type_name | STRING | Display name for the account type |
| 8 | key_account_type_role | STRING | Role associated with this type |
| 9 | customer_class | STRING | Customer class tier |
| 10 | sales_channel | STRING | Sales channel assignment |
| 11 | program_name | STRING | Associated program name |
| 12 | achiever_level | STRING | Achiever level tier |
| 13 | enable_zodiac_premium | BOOLEAN | Whether Zodiac Premium is enabled |
| 14 | override_achiever_level_role | BOOLEAN | Whether achiever level role is overridden |
| 15 | e_statement_enabled | BOOLEAN | E-statement enabled flag |
| 16 | print_statements | BOOLEAN | Print statements flag |
| 17 | created_at | TIMESTAMP_NTZ | Record creation timestamp |
| 18 | created_by | STRING | Who created the record |

---

## Dimension Models

### dim_pro_business_master

**Grain:** One row per `pro_business_id` — latest state only
**Purpose:** Thin dimension for dealer/business descriptors. Used for segmentation and filtering in BI.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | pro_business_id | STRING | Primary key — unique business identifier |
| 2 | business_name | STRING | Registered business name |
| 3 | doing_business_as | STRING | DBA / trade name |
| 4 | business_status | STRING | Current status (GUEST, LEAD, APPROVED, REJECTED) |
| 5 | login_status | STRING | Login setup status |
| 6 | registration_source | STRING | Registration channel (web, mobile, admin) |
| 7 | customer_type | STRING | Customer type classification |
| 8 | primary_business_type | STRING | Primary business type (Pool Builder, Service Tech) |
| 9 | business_segment | STRING | Business segment |
| 10 | channel | STRING | Channel |
| 11 | customer_class | STRING | Customer class tier |
| 12 | sales_channel | STRING | Sales channel |
| 13 | primary_business_email | STRING | Primary business email |
| 14 | primary_business_phone | STRING | Primary business phone |
| 15 | is_primary_key_account | BOOLEAN | Key account flag |
| 16 | key_account_type_name | STRING | Key account type name |
| 17 | fluidra_account_number | STRING | ERP account number |
| 18 | crm_lead_id | STRING | CRM lead identifier |
| 19 | web_account_id | STRING | Web account identifier |
| 20 | terms_accepted | BOOLEAN | Terms & conditions accepted |
| 21 | e_statement_enabled | BOOLEAN | E-statement preference |
| 22 | is_marcom_consent | BOOLEAN | Marketing consent |
| 23 | tse_violator | BOOLEAN | TSE violation flag |
| 24 | rewards_program_level | STRING | Rewards tier level |
| 25 | rewards_achiever_level | STRING | Rewards achiever level |
| 26 | rewards_program_status | STRING | Rewards enrollment status |
| 27 | rewards_rebate_pay_type | STRING | Rebate payment method |
| 28 | rewards_signup_date | TIMESTAMP_NTZ | Rewards enrollment date |
| 29 | primary_contact_id | STRING | FK to dim_pro_contact_master |
| 30 | primary_contact_type | STRING | Primary contact's role type |
| 31 | primary_contact_login_status | STRING | Primary contact's login status |
| 32 | billing_location_id | STRING | FK to dim_pro_business_location_master |
| 33 | billing_city | STRING | Billing city |
| 34 | billing_state | STRING | Billing state |
| 35 | sales_rep_name | STRING | Assigned sales rep name |
| 36 | sales_rep_email | STRING | Assigned sales rep email |
| 37 | utm_source | STRING | UTM source (marketing attribution) |
| 38 | utm_medium | STRING | UTM medium |
| 39 | utm_campaign | STRING | UTM campaign |
| 40 | created_at | TIMESTAMP_NTZ | Business record creation time |
| 41 | created_by | STRING | Who created the record |
| 42 | last_event_time | TIMESTAMP_NTZ | Timestamp of most recent event |

---

### dim_pro_contact_master

**Grain:** One row per `pro_contact_id` — latest state
**Purpose:** Contact/user dimension with business linkage. Fills missing pro_business_id via bridge.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | pro_contact_id | STRING | Primary key — unique contact identifier |
| 2 | pro_business_id | STRING | FK to dim_pro_business_master (coalesced from contact + bridge) |
| 3 | contact_type | STRING | Role type (DEALER, TECHNICIAN) |
| 4 | first_name | STRING | First name |
| 5 | last_name | STRING | Last name |
| 6 | email | STRING | Email address |
| 7 | phone_number | STRING | Phone number |
| 8 | login_status | STRING | Login status (ACTIVE, PENDING) |
| 9 | username | STRING | Login username |
| 10 | cognito_sub_id | STRING | AWS Cognito subject ID |
| 11 | web_user_id | STRING | Web user ID |
| 12 | last_login_date | TIMESTAMP_NTZ | Most recent login timestamp |
| 13 | contact_status | STRING | Contact status (ACTIVE, DELETED) |
| 14 | is_deleted_event | NUMBER (0/1) | Whether latest event is a deletion |
| 15 | created_at | TIMESTAMP_NTZ | Record creation timestamp |
| 16 | last_event_time | TIMESTAMP_NTZ | Timestamp of most recent event |

---

### dim_pro_business_location_master

**Grain:** One row per `pro_location_id`
**Purpose:** Location dimension for dealer physical addresses.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | pro_location_id | STRING | Primary key — unique location identifier |
| 2 | pro_business_id | STRING | FK to dim_pro_business_master |
| 3 | location_name | STRING | Location display name |
| 4 | location_type | STRING | Type (BILLING, SERVICE, etc.) |
| 5 | location_status | STRING | Location status |
| 6 | street_line_1 | STRING | Address line 1 |
| 7 | street_line_2 | STRING | Address line 2 |
| 8 | city | STRING | City |
| 9 | state | STRING | State |
| 10 | zip | STRING | ZIP/postal code |
| 11 | country | STRING | Country |
| 12 | phone_number | STRING | Location phone |
| 13 | lead_management_email | STRING | Lead routing email |
| 14 | hide_address | BOOLEAN | Hide address from public |
| 15 | hide_location | BOOLEAN | Hide location from public |
| 16 | service_zip_count | NUMBER | Number of service ZIP codes |
| 17 | created_at | TIMESTAMP_NTZ | Creation timestamp |
| 18 | last_event_time | TIMESTAMP_NTZ | Most recent event timestamp |

---

### dim_pro_associated_distributor

**Grain:** One row per (`pro_business_id`, `distributor_name`, `distributor_account_number`)
**Purpose:** Distributor relationships per dealer business (multi-valued dimension).

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | pro_business_id | STRING | FK to dim_pro_business_master |
| 2 | distributor_name | STRING | Distributor company name |
| 3 | distributor_account_number | STRING | Account number at distributor |
| 4 | distributor_account_status | STRING | Relationship status |
| 5 | fluidra_account_number | STRING | Linked Fluidra account |
| 6 | source | STRING | How relationship was created |
| 7 | active_date | TIMESTAMP_NTZ | When relationship became active |
| 8 | distributor_created_at | TIMESTAMP_NTZ | Creation timestamp |
| 9 | distributor_updated_at | TIMESTAMP_NTZ | Last update timestamp |
| 10 | distributor_created_by | STRING | Who created it |
| 11 | distributor_updated_by | STRING | Who last updated it |
| 12 | last_event_time | TIMESTAMP_NTZ | Most recent source event time |

---

### dim_pro_subscription_master

**Grain:** One row per (`pro_business_id`, `subscription_id`)
**Purpose:** Subscription dimension per dealer business (multi-valued dimension).

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | pro_business_id | STRING | FK to dim_pro_business_master |
| 2 | subscription_id | STRING | Unique subscription identifier |
| 3 | subscription_name | STRING | Subscription plan name |
| 4 | subscription_status | STRING | Status (ACTIVE, EXPIRED, etc.) |
| 5 | program_start_date | TIMESTAMP_NTZ | When subscription started |
| 6 | source | STRING | How subscription was created |
| 7 | subscription_created_at | TIMESTAMP_NTZ | Creation timestamp |
| 8 | subscription_updated_at | TIMESTAMP_NTZ | Last update timestamp |
| 9 | subscription_created_by | STRING | Who created it |
| 10 | subscription_updated_by | STRING | Who last updated it |
| 11 | last_event_time | TIMESTAMP_NTZ | Most recent event time |

---

### dim_pro_program_opt_in

**Grain:** One row per (`pro_business_id`, `program_name`)
**Purpose:** Program enrollment dimension per dealer business (multi-valued dimension).

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | pro_business_id | STRING | FK to dim_pro_business_master |
| 2 | program_name | STRING | Program name |
| 3 | program_status | STRING | Enrollment status |
| 4 | program_opt_in_date | TIMESTAMP_NTZ | When dealer opted in |
| 5 | program_start_date | TIMESTAMP_NTZ | When program became effective |
| 6 | fluidra_account_number | STRING | Linked Fluidra account |
| 7 | source | STRING | How enrollment was created |
| 8 | program_created_at | TIMESTAMP_NTZ | Creation timestamp |
| 9 | program_updated_at | TIMESTAMP_NTZ | Last update timestamp |
| 10 | program_created_by | STRING | Who created it |
| 11 | program_updated_by | STRING | Who last updated it |
| 12 | last_event_time | TIMESTAMP_NTZ | Most recent event time |

---

### dim_key_account_type

**Grain:** One row per `key_account_type_id`
**Purpose:** Reference/lookup dimension for key account type classification.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | key_account_type_id | STRING | Primary key — unique account type ID |
| 2 | key_account_type_name | STRING | Display name |
| 3 | key_account_type_role | STRING | Role associated with this type |
| 4 | customer_class | STRING | Customer class tier |
| 5 | sales_channel | STRING | Sales channel |
| 6 | program_name | STRING | Associated program |
| 7 | achiever_level | STRING | Achiever level tier |
| 8 | enable_zodiac_premium | BOOLEAN | Zodiac Premium enabled |
| 9 | override_achiever_level_role | BOOLEAN | Override achiever level role |
| 10 | e_statement_enabled | BOOLEAN | E-statement enabled |
| 11 | print_statements | BOOLEAN | Print statements enabled |
| 12 | created_at | TIMESTAMP_NTZ | Record creation timestamp |
| 13 | created_by | STRING | Who created it |
| 14 | last_event_time | TIMESTAMP_NTZ | Most recent event time |

---

## Fact Models

### fct_pro_business_master_events

**Grain:** One row per business event
**Purpose:** Every business lifecycle event. Supports KPIs: New Dealers Created, Active Dealers, Enrolled Dealers, Rejection Rate.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | event_id | STRING | Unique event identifier |
| 2 | event_detail_type | STRING | Full event type string |
| 3 | event_time | TIMESTAMP_NTZ | When the event occurred |
| 4 | event_date | DATE | Date of event |
| 5 | kafka_offset | NUMBER | Kafka offset |
| 6 | metadata_event_type | STRING | Event type (created/updated/approved/rejected) |
| 7 | correlation_id | STRING | Correlation ID |
| 8 | pro_business_id | STRING | FK to dim_pro_business_master |
| 9 | primary_contact_id | STRING | FK to dim_pro_contact_master |
| 10 | billing_location_id | STRING | FK to dim_pro_business_location_master |
| 11 | business_status | STRING | Degenerate dim — status at event time |
| 12 | login_status | STRING | Degenerate dim — login status at event time |
| 13 | registration_source | STRING | Degenerate dim — registration source |
| 14 | primary_business_type | STRING | Degenerate dim — business type |
| 15 | business_segment | STRING | Degenerate dim — segment |
| 16 | channel | STRING | Degenerate dim — channel |
| 17 | customer_class | STRING | Degenerate dim — customer class |
| 18 | sales_channel | STRING | Degenerate dim — sales channel |
| 19 | is_primary_key_account | BOOLEAN | Degenerate dim — key account flag |
| 20 | key_account_type_name | STRING | Degenerate dim — key account type |
| 21 | distributor_count | NUMBER | Measure — number of distributors at event time |
| 22 | program_opt_in_count | NUMBER | Measure — number of program enrollments |
| 23 | subscription_count | NUMBER | Measure — number of subscriptions |
| 24 | is_created_event | NUMBER (0/1) | Additive measure — creation event flag |
| 25 | is_updated_event | NUMBER (0/1) | Additive measure — update event flag |
| 26 | is_approved_event | NUMBER (0/1) | Additive measure — approval event flag |
| 27 | is_rejected_event | NUMBER (0/1) | Additive measure — rejection event flag |
| 28 | is_creation_failed | NUMBER (0/1) | Additive measure — creation failure flag |
| 29 | is_update_requested | NUMBER (0/1) | Additive measure — update requested flag |
| 30 | is_lead_approved | NUMBER (0/1) | Additive measure — lead approved flag |
| 31 | is_lead_rejected | NUMBER (0/1) | Additive measure — lead rejected flag |
| 32 | utm_source | STRING | UTM source |
| 33 | utm_medium | STRING | UTM medium |
| 34 | utm_campaign | STRING | UTM campaign |
| 35 | failure_reason | STRING | Rejection/failure reason |
| 36 | record_created_at | TIMESTAMP_NTZ | Audit — record creation time |

---

### fct_pro_contact_master_events

**Grain:** One row per contact event
**Purpose:** Every contact lifecycle event. Supports KPIs: TAU, New Technicians, Stickiness Ratio.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | event_id | STRING | Unique event identifier |
| 2 | event_detail_type | STRING | Full event type string |
| 3 | event_time | TIMESTAMP_NTZ | When the event occurred |
| 4 | event_date | DATE | Date of event |
| 5 | kafka_offset | NUMBER | Kafka offset |
| 6 | metadata_event_type | STRING | Event type |
| 7 | correlation_id | STRING | Correlation ID |
| 8 | pro_contact_id | STRING | FK to dim_pro_contact_master |
| 9 | pro_business_id | STRING | FK to dim_pro_business_master |
| 10 | contact_type | STRING | Degenerate dim — role (DEALER, TECHNICIAN) |
| 11 | login_status | STRING | Degenerate dim — login status at event time |
| 12 | contact_status | STRING | Degenerate dim — contact status |
| 13 | email | STRING | Contact email at event time |
| 14 | last_login_date | TIMESTAMP_NTZ | Last login date at event time |
| 15 | is_created_event | NUMBER (0/1) | Additive measure — contact created |
| 16 | is_updated_event | NUMBER (0/1) | Additive measure — contact updated |
| 17 | is_login_created_event | NUMBER (0/1) | Additive measure — login set up |
| 18 | is_deleted_event | NUMBER (0/1) | Additive measure — contact deleted |
| 19 | assigned_location_count | NUMBER | Measure — locations assigned |
| 20 | user_subscription_count | NUMBER | Measure — user subscriptions |
| 21 | record_created_at | TIMESTAMP_NTZ | Audit — record creation time |

---

### fct_lead_funnel

**Grain:** One row per funnel stage transition (excludes generic UPDATED events)
**Purpose:** Lead funnel analysis. Supports KPIs: Time to Approve, Rejection Rate, New Dealers Created.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | event_id | STRING | Unique event identifier |
| 2 | event_detail_type | STRING | Full event type string |
| 3 | event_time | TIMESTAMP_NTZ | When the transition occurred |
| 4 | event_date | DATE | Date of event |
| 5 | pro_business_id | STRING | FK to dim_pro_business_master |
| 6 | primary_contact_id | STRING | FK to dim_pro_contact_master |
| 7 | primary_business_email | STRING | Business email at event time |
| 8 | crm_lead_id | STRING | CRM lead ID |
| 9 | sales_rep_name | STRING | Assigned sales rep |
| 10 | sales_rep_email | STRING | Sales rep email |
| 11 | business_status | STRING | Status at event time |
| 12 | primary_business_type | STRING | Business type for segmentation |
| 13 | business_segment | STRING | Segment for segmentation |
| 14 | registration_source | STRING | Registration channel |
| 15 | is_primary_key_account | BOOLEAN | Key account flag |
| 16 | key_account_type_name | STRING | Key account type |
| 17 | funnel_stage | STRING | Derived stage (GUEST, LEAD_CREATED, LEAD_APPROVED, BUSINESS_APPROVED, LEAD_REJECTED, BUSINESS_REJECTED, CREATION_FAILED) |
| 18 | seconds_in_stage | NUMBER | Time spent in stage (seconds) |
| 19 | failure_reason | STRING | Rejection/failure reason |
| 20 | record_created_at | TIMESTAMP_NTZ | Record creation time |

---

### fct_pro_business_master_snapshot

**Grain:** One row per `pro_business_id` (current snapshot)
**Purpose:** Dealer activity state for dashboard KPIs: Active/Inactive/Enrolled dealers, Time to Approve, TAU per Dealer.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | pro_business_id | STRING | Primary key — business identifier |
| 2 | business_name | STRING | Business name |
| 3 | business_status | STRING | Current business status |
| 4 | login_status | STRING | Current login status |
| 5 | registration_source | STRING | Registration channel |
| 6 | primary_business_type | STRING | Business type for segmentation |
| 7 | business_segment | STRING | Segment for segmentation |
| 8 | is_primary_key_account | BOOLEAN | Key account flag |
| 9 | key_account_type_name | STRING | Key account type |
| 10 | rewards_achiever_level | STRING | Rewards tier |
| 11 | business_created_at | TIMESTAMP_NTZ | Original creation timestamp |
| 12 | last_business_event_time | TIMESTAMP_NTZ | Most recent business event |
| 13 | first_created_at | TIMESTAMP_NTZ | First creation event time |
| 14 | first_approved_at | TIMESTAMP_NTZ | First approval event time |
| 15 | seconds_to_approve | NUMBER | Time from creation to approval (seconds) |
| 16 | total_contacts | NUMBER | Count of associated contacts |
| 17 | contacts_with_login | NUMBER | Contacts that have set up login |
| 18 | last_contact_login_date | TIMESTAMP_NTZ | Most recent login by any contact |
| 19 | is_enrolled | BOOLEAN | Dealer is approved AND has logged in |
| 20 | has_login_setup | BOOLEAN | At least one contact has login |
| 21 | is_active_30d | BOOLEAN | Login within last 30 days |
| 22 | is_active_90d | BOOLEAN | Login within last 90 days |
| 23 | is_active_1y | BOOLEAN | Login within last year |
| 24 | is_inactive | BOOLEAN | Has login but no activity in 30 days |

---

### fct_pro_contact_master_snapshot

**Grain:** One row per `pro_contact_id` (current snapshot)
**Purpose:** User activity state for dashboard KPIs: TAU, Inactive Users, First Login Rate, Stickiness.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | pro_contact_id | STRING | Primary key — contact identifier |
| 2 | pro_business_id | STRING | FK to dim_pro_business_master (coalesced via bridge) |
| 3 | contact_type | STRING | Role (DEALER, TECHNICIAN) |
| 4 | login_status | STRING | Current login status |
| 5 | contact_status | STRING | Current contact status |
| 6 | last_login_date | TIMESTAMP_NTZ | Most recent login |
| 7 | last_event_time | TIMESTAMP_NTZ | Most recent event for this contact |
| 8 | first_created_at | TIMESTAMP_NTZ | When contact was first created |
| 9 | first_login_created_at | TIMESTAMP_NTZ | When login was first set up |
| 10 | seconds_to_first_login | NUMBER | Time from creation to first login (seconds) |
| 11 | first_login_within_14d | BOOLEAN | Whether first login was within 14 days of creation |
| 12 | first_login_within_7d | BOOLEAN | Whether first login was within 7 days of creation |
| 13 | is_active_30d | BOOLEAN | Last login within 30 days |
| 14 | is_active_90d | BOOLEAN | Last login within 90 days |
| 15 | is_active_1y | BOOLEAN | Last login within 1 year |
| 16 | has_login_setup | BOOLEAN | Whether login has ever been created |
| 17 | is_inactive | BOOLEAN | Has login but no activity in 30 days |
| 18 | is_technician | BOOLEAN | Contact type is TECHNICIAN |
| 19 | is_dealer | BOOLEAN | Contact type is DEALER |

---

## Mart Models

### mart_kpi_dashboard

**Grain:** Single row (aggregated global totals)
**Purpose:** Executive dashboard top-line metrics. All KPIs pre-computed for direct binding.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | total_dealers | NUMBER | Total dealer accounts |
| 2 | total_enrolled_dealers | NUMBER | Dealers that are approved and have logged in |
| 3 | active_dealers_30d | NUMBER | Dealers with login activity in last 30 days |
| 4 | active_dealers_90d | NUMBER | Dealers with login activity in last 90 days |
| 5 | active_dealers_1y | NUMBER | Dealers with login activity in last year |
| 6 | dealers_not_setup | NUMBER | Dealers that never set up login |
| 7 | inactive_dealers | NUMBER | Dealers with login but inactive 30+ days |
| 8 | avg_tau_per_dealer | NUMBER | Average contacts per dealer |
| 9 | avg_hours_to_approve | NUMBER | Average time to approve (hours) |
| 10 | avg_days_to_approve | NUMBER | Average time to approve (days) |
| 11 | total_users | NUMBER | Total contact/user records |
| 12 | tau_30d | NUMBER | Total Active Users — 30 day window |
| 13 | tau_90d | NUMBER | Total Active Users — 90 day window |
| 14 | tau_1y | NUMBER | Total Active Users — 1 year window |
| 15 | users_not_setup | NUMBER | Users that never set up login |
| 16 | inactive_users | NUMBER | Users with login but inactive 30+ days |
| 17 | new_technicians_30d | NUMBER | New technician accounts in last 30 days |
| 18 | new_technicians_90d | NUMBER | New technician accounts in last 90 days |
| 19 | first_login_rate_7d_pct | NUMBER | % of users who logged in within 7 days of creation |
| 20 | first_login_rate_14d_pct | NUMBER | % of users who logged in within 14 days of creation |
| 21 | total_leads_created | NUMBER | Total leads/guests created (funnel entry) |
| 22 | total_rejected | NUMBER | Total leads/businesses rejected |
| 23 | leads_rejection_rate_pct | NUMBER | Rejection rate as percentage |
| 24 | new_dealers_30d | NUMBER | New dealer accounts in last 30 days |
| 25 | new_dealers_90d | NUMBER | New dealer accounts in last 90 days |
| 26 | new_dealers_1y | NUMBER | New dealer accounts in last year |
| 27 | refreshed_at | TIMESTAMP_NTZ | When the mart was last refreshed |

---

### mart_dealer_kpi_summary

**Grain:** One row per `pro_business_id`
**Purpose:** Pre-aggregated dealer-level KPIs with user counts for dashboard drill-down.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | pro_business_id | STRING | Primary key — business identifier |
| 2 | business_name | STRING | Business name |
| 3 | business_status | STRING | Current status |
| 4 | login_status | STRING | Login status |
| 5 | registration_source | STRING | Registration channel |
| 6 | primary_business_type | STRING | Business type (segmentation) |
| 7 | business_segment | STRING | Segment (segmentation) |
| 8 | is_primary_key_account | BOOLEAN | Key account flag |
| 9 | key_account_type_name | STRING | Key account type |
| 10 | rewards_achiever_level | STRING | Rewards tier |
| 11 | first_created_at | TIMESTAMP_NTZ | First creation event |
| 12 | first_approved_at | TIMESTAMP_NTZ | First approval event |
| 13 | business_created_at | TIMESTAMP_NTZ | Original creation timestamp |
| 14 | last_business_event_time | TIMESTAMP_NTZ | Most recent event |
| 15 | seconds_to_approve | NUMBER | Creation to approval (seconds) |
| 16 | days_to_approve | NUMBER | Creation to approval (days, rounded) |
| 17 | is_enrolled | BOOLEAN | Approved and logged in |
| 18 | has_login_setup | BOOLEAN | At least one contact has login |
| 19 | is_active_30d | BOOLEAN | Activity within 30 days |
| 20 | is_active_90d | BOOLEAN | Activity within 90 days |
| 21 | is_active_1y | BOOLEAN | Activity within 1 year |
| 22 | is_inactive | BOOLEAN | Has login but inactive 30+ days |
| 23 | total_users | NUMBER | Total users linked to this dealer |
| 24 | active_users_30d | NUMBER | Active users (30d) for this dealer |
| 25 | active_users_90d | NUMBER | Active users (90d) for this dealer |
| 26 | active_users_1y | NUMBER | Active users (1y) for this dealer |
| 27 | users_with_login | NUMBER | Users with login setup |
| 28 | inactive_users | NUMBER | Inactive users for this dealer |
| 29 | technician_count | NUMBER | Technician contacts |
| 30 | dealer_contact_count | NUMBER | Dealer-type contacts |
| 31 | total_contacts | NUMBER | Total contacts from activity fact |
| 32 | contacts_with_login | NUMBER | Contacts with login from activity fact |
| 33 | last_contact_login_date | TIMESTAMP_NTZ | Most recent login across all contacts |

---

### mart_user_kpi_summary

**Grain:** One row per `pro_contact_id`
**Purpose:** Pre-aggregated user-level KPIs for dashboard drill-down.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | pro_contact_id | STRING | Primary key — contact identifier |
| 2 | pro_business_id | STRING | FK to business |
| 3 | contact_type | STRING | Role (DEALER, TECHNICIAN) |
| 4 | login_status | STRING | Current login status |
| 5 | contact_status | STRING | Current contact status |
| 6 | last_login_date | TIMESTAMP_NTZ | Most recent login |
| 7 | last_event_time | TIMESTAMP_NTZ | Most recent event |
| 8 | first_created_at | TIMESTAMP_NTZ | First creation event |
| 9 | first_login_created_at | TIMESTAMP_NTZ | First login setup event |
| 10 | seconds_to_first_login | NUMBER | Time to first login (seconds) |
| 11 | days_to_first_login | NUMBER | Time to first login (days, rounded) |
| 12 | first_login_within_7d | BOOLEAN | Logged in within 7 days of creation |
| 13 | first_login_within_14d | BOOLEAN | Logged in within 14 days of creation |
| 14 | is_active_30d | BOOLEAN | Active within 30 days |
| 15 | is_active_90d | BOOLEAN | Active within 90 days |
| 16 | is_active_1y | BOOLEAN | Active within 1 year |
| 17 | has_login_setup | BOOLEAN | Login has been created |
| 18 | is_inactive | BOOLEAN | Has login but no activity in 30 days |
| 19 | is_technician | BOOLEAN | Contact is a technician |
| 20 | is_dealer | BOOLEAN | Contact is a dealer |

---

### mart_lead_funnel_kpi

**Grain:** One row per `pro_business_id` (lifecycle summary)
**Purpose:** Lead funnel analysis mart — Time to Approve, Rejection Rate, funnel stage tracking.

| # | Field | Type | Description |
|---|-------|------|-------------|
| 1 | pro_business_id | STRING | Primary key — business identifier |
| 2 | primary_business_type | STRING | Business type (segmentation) |
| 3 | business_segment | STRING | Segment (segmentation) |
| 4 | registration_source | STRING | Registration channel |
| 5 | sales_rep_name | STRING | Assigned sales rep |
| 6 | sales_rep_email | STRING | Sales rep email |
| 7 | is_primary_key_account | BOOLEAN | Key account flag |
| 8 | key_account_type_name | STRING | Key account type |
| 9 | guest_at | TIMESTAMP_NTZ | First GUEST stage event |
| 10 | lead_created_at | TIMESTAMP_NTZ | First LEAD_CREATED event |
| 11 | lead_approved_at | TIMESTAMP_NTZ | First LEAD_APPROVED event |
| 12 | business_approved_at | TIMESTAMP_NTZ | First BUSINESS_APPROVED event |
| 13 | lead_rejected_at | TIMESTAMP_NTZ | First LEAD_REJECTED event |
| 14 | business_rejected_at | TIMESTAMP_NTZ | First BUSINESS_REJECTED event |
| 15 | creation_failed_at | TIMESTAMP_NTZ | First CREATION_FAILED event |
| 16 | last_funnel_event_time | TIMESTAMP_NTZ | Most recent funnel event |
| 17 | seconds_lead_to_approved | NUMBER | Lead created → lead approved (seconds) |
| 18 | days_lead_to_approved | NUMBER | Lead created → lead approved (days) |
| 19 | seconds_to_business_approved | NUMBER | Lead created → business approved (seconds) |
| 20 | days_to_business_approved | NUMBER | Lead created → business approved (days) |
| 21 | current_funnel_stage | STRING | Current stage (GUEST, LEAD_CREATED, LEAD_APPROVED, BUSINESS_APPROVED, LEAD_REJECTED, BUSINESS_REJECTED, CREATION_FAILED, UNKNOWN) |
| 22 | is_rejected | BOOLEAN | Whether lead/business was ever rejected |
| 23 | last_failure_reason | STRING | Most recent failure reason |

---

## End of Document
