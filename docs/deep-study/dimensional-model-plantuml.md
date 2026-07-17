# Dimensional Model — PlantUML Diagram

## How to Render

1. Copy the PlantUML code below (between `@startuml` and `@enduml`)
2. Paste into [PlantUML Online Server](https://www.plantuml.com/plantuml/uml/)
3. Or use any IDE with PlantUML plugin (IntelliJ, VS Code PlantUML extension)
4. Or render via CLI: `java -jar plantuml.jar dimensional-model.puml`

---

## PlantUML Source Code

```plantuml
@startuml
!theme cerulean
skinparam linetype ortho
skinparam classAttributeIconSize 0
skinparam classFontSize 11
skinparam packageBackgroundColor #FAFAFA
skinparam packageBorderColor #90A4AE
skinparam arrowThickness 1.5
skinparam groupInheritance 2

title Fluidra Pro Analytics — Star Schema Dimensional Model\n<size:12>20 KPI Metrics from CDC Event Stream (EVENTS__RAW_FLUIDRA)</size>

' ============================================================
' DIMENSION LAYER
' ============================================================
package "DIMENSIONS (Conformed - Current State)" as dims #E8F4FD {

  class DIM_DEALER <<(D,#1565C0) Central Hub>> {
    .. Primary Key ..
    + pro_business_id : STRING <<PK>>
    .. Business Identity ..
    business_name : STRING
    doing_business_as : STRING
    business_status : STRING {ACTIVE|LEAD|GUEST|REJECTED}
    login_status : STRING {ACTIVE|PENDING}
    .. Classification ..
    customer_type : STRING {POOL PRO}
    primary_business_type : STRING {BUILDER|SERVICE|RETAILER}
    business_segment : STRING {BUILD|SERVICE|RETAIL}
    channel : STRING {NEW CONSTRUCTION|AFTERMARKET}
    customer_class : STRING {PIP MEMBER|AFTERMARKET|INDIRECT}
    sales_channel : STRING {PIP MEMBER|INDIRECT|DIRECT|DD/CAR}
    .. Key Account ..
    is_primary_key_account : BOOLEAN
    key_account_type_name : STRING {Poolwerx|APE|Premier Build}
    key_account_type_role : STRING {Standard|Restricted}
    .. External Join Keys ..
    fluidra_account_number : STRING <<Join to PSOT Revenue>>
    crm_lead_id : STRING <<Salesforce Lead 00QQJ...>>
    web_account_id : STRING <<Legacy extranet>>
    .. Registration ..
    registration_source : STRING {PROWEB|SALESFORCE}
    terms_accepted : BOOLEAN
    e_statement_enabled : BOOLEAN
    is_marcom_consent : BOOLEAN
    tse_violator : BOOLEAN
    .. Audit ..
    created_at : TIMESTAMP
    created_by : STRING
    updated_at : TIMESTAMP
    last_event_time : TIMESTAMP
  }

  class DIM_CONTACT <<(D,#2E7D32) User>> {
    .. Primary Key ..
    + pro_contact_id : STRING <<PK>>
    .. Foreign Key ..
    # pro_business_id : STRING <<FK via BRIDGE>>
    .. Identity ..
    contact_type : STRING {OWNER|TECHNICIAN|OFFICE ADMIN|CO-OWNER|CSC|OTHER}
    first_name : STRING
    last_name : STRING
    email : STRING
    phone_number : STRING
    .. Login State ..
    login_status : STRING {ACTIVE|PENDING|NOLOGIN|DISABLE_PENDING}
    username : STRING
    cognito_sub_id : STRING <<Join to Cognito Logs>>
    web_user_id : STRING
    last_login_date : TIMESTAMP <<Snapshot, not real-time>>
    .. Audit ..
    source : STRING {PROWEB}
    contact_status : STRING {ACTIVE}
    created_at : TIMESTAMP
  }

  class DIM_LOCATION <<(D,#00695C) Geography>> {
    .. Primary Key ..
    + pro_location_id : STRING <<PK>>
    .. Foreign Key ..
    # pro_business_id : STRING <<FK>>
    .. Type ..
    location_type : STRING {PRIMARY_BILL_TO|PRIMARY_SHIP_TO}
    location_name : STRING
    location_status : STRING {ACTIVE}
    .. Address ..
    street_line_1 : STRING
    street_line_2 : STRING
    city : STRING
    state : STRING <<Needs normalization: CA vs California>>
    zip : STRING
    country : STRING {USA}
    .. Flags ..
    hide_address : BOOLEAN
    hide_location : BOOLEAN
    is_email_leads_enabled : BOOLEAN
  }

  class DIM_PROGRAM <<(D,#F57F17) Rewards>> {
    .. Primary Key (1:1 with Dealer) ..
    + pro_business_id : STRING <<PK>>
    .. Program Level ..
    program_level : STRING {PROEDGE|SERVICEPRO|FLATRATE SERVICEPRO|RETAIL SELECT|BASE REWARDS}
    achiever_level : STRING {PARTNER|ELITE|MEMBER}
    program_status : STRING {ACTIVE|PENDING}
    .. Rewards ..
    rebate_pay_type : STRING {AP Voucher|Debit VISA}
    enable_auto_zodiac_premium : BOOLEAN
    override_achiever_level_roll : BOOLEAN
    region : STRING {USA}
    .. Dates ..
    program_signup_date : TIMESTAMP
    program_level_start_date : TIMESTAMP
    achiever_level_start_date : TIMESTAMP
    rewards_created_at : TIMESTAMP
  }

  class DIM_DISTRIBUTOR <<(D,#6A1B9A) Channel>> {
    .. Composite Key ..
    # pro_business_id : STRING <<FK>>
    distributor_name : STRING {POOLCORP|COVERPOOLS|HERITAGE|SOLAR POOLS}
    distributor_account_number : STRING
    .. Status ..
    distributor_account_status : STRING {ACTIVE|PENDING ACTIVE|PENDING INACTIVE|INACTIVE}
    source : STRING {MANUAL|PROWEB}
    fluidra_account_number : STRING
    .. Dates ..
    active_date : TIMESTAMP
    created_at : TIMESTAMP
    updated_at : TIMESTAMP
  }

  class DIM_PROGRAM_OPT_IN <<(D,#F57F17) Enrollment>> {
    .. Composite Key ..
    # pro_business_id : STRING <<FK>>
    program_name : STRING {PROEDGE|SERVICEPRO|FLATRATE SERVICEPRO|RETAIL SELECT|BASE REWARDS}
    .. Status ..
    program_status : STRING {ACTIVE|PENDING|DECLINED|INACTIVE}
    program_opt_in_date : TIMESTAMP
    source : STRING {PROWEB}
  }

  class DIM_SUBSCRIPTION <<(D,#00838F) IoT>> {
    .. Primary Key ..
    + subscription_id : STRING <<PK>>
    .. Foreign Key ..
    # pro_business_id : STRING <<FK>>
    .. Details ..
    subscription_name : STRING {ION POOL CARE}
    subscription_status : STRING {ACTIVE}
    program_start_date : TIMESTAMP
    source : STRING {PROWEB}
  }

  class DIM_SALES_REP <<(D,#AD1457) Attribution>> {
    .. Primary Key ..
    + sales_rep_email : STRING <<PK>>
    .. Details ..
    sales_rep_name : STRING
  }

  class DIM_DATE <<(D,#37474F) Time>> {
    .. Primary Key ..
    + date_key : DATE <<PK>>
    .. Attributes ..
    day_of_week : INT
    day_name : STRING
    day_of_month : INT
    week_of_year : INT
    month_number : INT
    month_name : STRING
    quarter : INT
    year : INT
    is_weekend : BOOLEAN
  }

  class BRIDGE_CONTACT_DEALER <<(B,#E65100) Bridge>> {
    .. Foreign Keys ..
    # pro_business_id : STRING <<FK to DIM_DEALER>>
    # pro_contact_id : STRING <<FK to DIM_CONTACT>>
    .. Metadata ..
    relationship_type : STRING {PRIMARY_CONTACT}
    __ Note __
    Resolves NULL proBusinessId
    on contact-created events
  }
}

' ============================================================
' FACT LAYER
' ============================================================
package "FACTS (Event Grain - One Row Per Event)" as facts #FBE9E7 {

  class FCT_PRO_BUSINESS_MASTER_EVENTS <<(F,#BF360C) Business Events>> {
    .. Primary Key ..
    + event_id : STRING <<PK>>
    .. Dimension Foreign Keys ..
    # pro_business_id : STRING <<FK to DIM_DEALER>>
    # event_date : DATE <<FK to DIM_DATE>>
    # billing_location_id : STRING <<FK to DIM_LOCATION>>
    # shipping_location_id : STRING <<FK to DIM_LOCATION>>
    .. Event Identity ..
    event_time : TIMESTAMP
    event_detail_type : STRING
    metadata_event_type : STRING {created|updated|approved|rejected}
    correlation_id : STRING
    .. Additive Measures ..
    distributor_count : INT
    program_opt_in_count : INT
    subscription_count : INT
    secondary_type_count : INT
    .. Event Flags (0|1) ..
    is_created_event : INT
    is_updated_event : INT
    is_approved_event : INT
    is_rejected_event : INT
    is_creation_failed : INT
    .. Degenerate Dimensions ..
    business_status : STRING
    login_status : STRING
    source : STRING
    .. Marketing Attribution ..
    utm_source : STRING
    utm_medium : STRING
    utm_campaign : STRING
    utm_content : STRING
    utm_term : STRING
  }

  class FCT_PRO_CONTACT_MASTER_EVENTS <<(F,#BF360C) User Events>> {
    .. Primary Key ..
    + event_id : STRING <<PK>>
    .. Dimension Foreign Keys ..
    # pro_contact_id : STRING <<FK to DIM_CONTACT>>
    # pro_business_id : STRING <<FK to DIM_DEALER>>
    # event_date : DATE <<FK to DIM_DATE>>
    .. Event Identity ..
    event_time : TIMESTAMP
    event_detail_type : STRING
    metadata_event_type : STRING {created|updated|login-created}
    correlation_id : STRING
    .. Attributes ..
    contact_type : STRING
    login_status : STRING
    source : STRING
    contact_status : STRING
    .. Event Flags (0|1) ..
    is_created_event : INT
    is_updated_event : INT
    is_login_created_event : INT
  }

  class FCT_LEAD_FUNNEL <<(F,#BF360C) Conversion Pipeline>> {
    .. Primary Key ..
    + event_id : STRING <<PK>>
    .. Dimension Foreign Keys ..
    # pro_business_id : STRING <<FK to DIM_DEALER>>
    # event_date : DATE <<FK to DIM_DATE>>
    .. Event Identity ..
    event_time : TIMESTAMP
    event_detail_type : STRING
    .. Funnel Stage ..
    funnel_stage : STRING {GUEST|LEAD_CREATED|LEAD_APPROVED|BUSINESS_APPROVED|LEAD_REJECTED|BUSINESS_REJECTED|CREATION_FAILED}
    .. Cross-References ..
    crm_lead_id : STRING <<Salesforce>>
    primary_email : STRING
    sales_rep_name : STRING <<DIM_SALES_REP>>
    sales_rep_email : STRING <<DIM_SALES_REP>>
    .. Measures ..
    seconds_in_stage : INT
    submission_time : TIMESTAMP
    .. Failure Detail ..
    failure_reason : STRING {Business with email already exists}
    rejection_reason : STRING
    .. Derived ..
    business_status : STRING
  }

  class FCT_RECONCILIATION <<(F,#BF360C) Data Ops>> {
    .. Primary Key ..
    + event_id : STRING <<PK>>
    .. Event Identity ..
    event_time : TIMESTAMP
    event_date : DATE
    .. Reconciliation Run ..
    run_id : STRING
    entity : STRING {pro-associated-distributor}
    domains_array : ARRAY
    .. Configuration Versions ..
    dq_structural_version : STRING {v001}
    gatekeeper_policy_version : STRING {v001}
    mastering_rules_version : STRING {v001}
    .. S3 Paths ..
    decisions_prefix : STRING
    diffs_prefix : STRING
  }
}

' ============================================================
' METRICS LAYER (Pre-Aggregated KPI Views)
' ============================================================
package "METRICS (Pre-Aggregated KPI Views)" as metrics #E8F5E9 {

  class METRIC_DEALER_ADOPTION <<(M,#2E7D32) KPI 1.x>> {
    KPI 1.1 : active_dealers_30d : INT
    KPI 1.2 : enrolled_dealers : INT
    KPI 1.3 : dealers_not_setup : INT
    KPI 1.4 : inactive_dealers : INT
    KPI 1.5 : new_dealers_total : INT
  }

  class METRIC_DEALER_CONVERSION <<(M,#2E7D32) KPI 2.x>> {
    KPI 2.1 : guest_to_lead_pct : FLOAT
    KPI 2.2 : rejection_rate_pct : FLOAT
    KPI 2.3 : avg_seconds_to_approve : FLOAT
    KPI 2.4 : avg_hours_to_activation : FLOAT
  }

  class METRIC_USER_ADOPTION <<(M,#2E7D32) KPI 3.x>> {
    KPI 3.1 : total_active_users : INT
    KPI 3.2 : new_technicians : INT
    KPI 3.3 : users_never_setup : INT
    KPI 3.4 : inactive_users : INT
    KPI 3.5 : avg_minutes_to_first_login : FLOAT
    KPI 3.6 : first_login_rate_pct : FLOAT
    KPI 3.7 : avg_active_users_per_dealer : FLOAT
  }

  class METRIC_DEALER_HEALTH <<(M,#2E7D32) Scorecard>> {
    # pro_business_id : STRING <<FK>>
    health_status : STRING {HEALTHY|AT_RISK|NOT_ONBOARDED}
    days_since_last_login : INT
    active_distributor_count : INT
    active_program_count : INT
    active_subscription_count : INT
  }

  class METRIC_FUNNEL_DAILY <<(M,#2E7D32) Daily>> {
    event_date : DATE
    guest_registrations : INT
    leads_created : INT
    leads_approved : INT
    leads_rejected : INT
    creation_failures : INT
    approval_rate_pct : FLOAT
    avg_seconds_to_approve : FLOAT
  }

  class METRIC_REGISTRATION_TRENDS <<(M,#2E7D32) Weekly>> {
    week_start : DATE
    new_dealers : INT
    new_leads : INT
    new_guests : INT
    failed_registrations : INT
    registration_failure_rate_pct : FLOAT
    from_proweb : INT
    from_salesforce : INT
  }

  class METRIC_PROGRAM_ENROLLMENT <<(M,#2E7D32) Programs>> {
    program_name : STRING
    active_count : INT
    pending_count : INT
    declined_count : INT
    total_enrolled : INT
    activation_rate_pct : FLOAT
    decline_rate_pct : FLOAT
  }

  class METRIC_DISTRIBUTOR_COVERAGE <<(M,#2E7D32) Distributors>> {
    distributor_name : STRING
    active_dealers : INT
    pending_active_dealers : INT
    inactive_dealers : INT
    total_dealers : INT
    active_rate_pct : FLOAT
  }

  class METRIC_CONTACT_ONBOARDING <<(M,#2E7D32) Onboarding>> {
    contact_type : STRING
    total_created : INT
    completed_login_setup : INT
    never_setup : INT
    first_login_rate_pct : FLOAT
    avg_minutes_to_login : FLOAT
    max_minutes_to_login : FLOAT
  }
}

' ============================================================
' RELATIONSHIPS: Dimension to Dimension (Star Schema)
' ============================================================
DIM_DEALER "1" -down-o "0..*" DIM_CONTACT : "has contacts"
DIM_DEALER "1" -down-o "0..*" DIM_LOCATION : "has locations"
DIM_DEALER "1" -down-o "0..*" DIM_DISTRIBUTOR : "linked to"
DIM_DEALER "1" -down- "1" DIM_PROGRAM : "has rewards"
DIM_DEALER "1" -down-o "0..*" DIM_PROGRAM_OPT_IN : "enrolled in"
DIM_DEALER "1" -down-o "0..*" DIM_SUBSCRIPTION : "subscribes"

' Bridge Pattern
DIM_CONTACT "0..*" .right.> "1" BRIDGE_CONTACT_DEALER : "resolved via"
BRIDGE_CONTACT_DEALER "0..*" .right.> "1" DIM_DEALER : "links to"

' ============================================================
' RELATIONSHIPS: Dimension to Fact
' ============================================================
DIM_DEALER "1" -down-o "0..*" FCT_PRO_BUSINESS_MASTER_EVENTS
DIM_DEALER "1" -down-o "0..*" FCT_LEAD_FUNNEL
DIM_CONTACT "1" -down-o "0..*" FCT_PRO_CONTACT_MASTER_EVENTS
DIM_SALES_REP "1" .down.o "0..*" FCT_LEAD_FUNNEL : "attributed"
DIM_DATE "1" .down.o "0..*" FCT_PRO_BUSINESS_MASTER_EVENTS : "date"
DIM_DATE "1" .down.o "0..*" FCT_PRO_CONTACT_MASTER_EVENTS : "date"
DIM_DATE "1" .down.o "0..*" FCT_LEAD_FUNNEL : "date"

' ============================================================
' RELATIONSHIPS: Fact to Metric (Aggregation)
' ============================================================
FCT_PRO_BUSINESS_MASTER_EVENTS .down.> METRIC_DEALER_ADOPTION : "aggregates"
FCT_PRO_BUSINESS_MASTER_EVENTS .down.> METRIC_REGISTRATION_TRENDS : "aggregates"
FCT_LEAD_FUNNEL .down.> METRIC_DEALER_CONVERSION : "aggregates"
FCT_LEAD_FUNNEL .down.> METRIC_FUNNEL_DAILY : "aggregates"
FCT_PRO_CONTACT_MASTER_EVENTS .down.> METRIC_USER_ADOPTION : "aggregates"
FCT_PRO_CONTACT_MASTER_EVENTS .down.> METRIC_CONTACT_ONBOARDING : "aggregates"
DIM_PROGRAM_OPT_IN .down.> METRIC_PROGRAM_ENROLLMENT : "aggregates"
DIM_DISTRIBUTOR .down.> METRIC_DISTRIBUTOR_COVERAGE : "aggregates"
DIM_DEALER .down.> METRIC_DEALER_HEALTH : "composite"

@enduml
```

---

## Quick Render Links

Paste the code above into any of these:

| Tool | URL |
|------|-----|
| PlantUML Online | https://www.plantuml.com/plantuml/uml/ |
| PlantText | https://www.planttext.com/ |
| Kroki | https://kroki.io/ |
| VS Code Extension | Search "PlantUML" in extensions |
| IntelliJ Plugin | Built-in PlantUML support |

---

## Design Notes

### Star Schema Structure
- **DIM_DEALER** is the central hub — all other dimensions connect via `pro_business_id`
- **BRIDGE_CONTACT_DEALER** resolves the NULL FK issue where contact-created events lack `proBusinessId`
- **DIM_DATE** is a role-playing dimension (same table joins to all facts on `event_date`)

### Fact Table Separation Rationale
- **FCT_PRO_BUSINESS_MASTER_EVENTS**: Business lifecycle (creation, approval, updates) — grain is one business event
- **FCT_PRO_CONTACT_MASTER_EVENTS**: User onboarding (contact creation, login setup) — grain is one contact event
- **FCT_LEAD_FUNNEL**: Conversion pipeline (guest→lead→approved→rejected) — grain is one stage transition
- **FCT_RECONCILIATION**: Data operations health — grain is one reconciliation run

### Cardinality Summary

| Relationship | Type | Notes |
|-------------|------|-------|
| DIM_DEALER → DIM_CONTACT | 1:N | One dealer has many contacts (OWNER, TECHNICIAN, etc.) |
| DIM_DEALER → DIM_LOCATION | 1:N | One dealer has billing + shipping locations |
| DIM_DEALER → DIM_PROGRAM | 1:1 | One rewards account per dealer |
| DIM_DEALER → DIM_DISTRIBUTOR | 1:N | One dealer has 0-29 distributor associations |
| DIM_DEALER → DIM_PROGRAM_OPT_IN | 1:N | One dealer opts into multiple programs |
| DIM_DEALER → DIM_SUBSCRIPTION | 1:N | One dealer has 0+ IoT subscriptions |
| DIM_CONTACT → BRIDGE | N:1 | Many contacts resolve to one bridge entry |
| BRIDGE → DIM_DEALER | N:1 | Bridge links back to dealer |
| DIM_DEALER → FCT_PRO_BUSINESS_MASTER_EVENTS | 1:N | One dealer generates many events over time |
| DIM_CONTACT → FCT_PRO_CONTACT_MASTER_EVENTS | 1:N | One contact generates many events |
| DIM_DATE → All Facts | 1:N | Role-playing date dimension |