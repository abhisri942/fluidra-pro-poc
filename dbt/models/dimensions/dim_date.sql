{{
  config(
    materialized='table',
    schema='DIMENSIONS',
    tags=['dimensions', 'date']
  )
}}

/*
  Dimension: dim_date
  Type: Static reference dimension
  Grain: One row per calendar date
  Design: Standard Kimball date dimension. Covers 2023-01-01 through 2026-12-31 (4 years).
  Source: Generated via Snowflake GENERATOR function
*/

SELECT
    date_day                                        AS date_key,
    DAYOFWEEK(date_day)                             AS day_of_week,
    DAYNAME(date_day)                               AS day_name,
    DAY(date_day)                                   AS day_of_month,
    DAYOFYEAR(date_day)                             AS day_of_year,
    WEEKOFYEAR(date_day)                            AS week_of_year,
    MONTH(date_day)                                 AS month_number,
    MONTHNAME(date_day)                             AS month_name,
    QUARTER(date_day)                               AS quarter_number,
    YEAR(date_day)                                  AS year_number,
    CASE WHEN DAYOFWEEK(date_day) IN (0, 6) THEN TRUE ELSE FALSE END AS is_weekend,
    CASE WHEN DAYOFWEEK(date_day) IN (0, 6) THEN FALSE ELSE TRUE END AS is_weekday,

    -- Fiscal year (assuming calendar year = fiscal year; adjust if needed)
    YEAR(date_day)                                  AS fiscal_year,
    QUARTER(date_day)                               AS fiscal_quarter,

    -- Useful date formats
    TO_CHAR(date_day, 'YYYY-MM')                    AS year_month,
    TO_CHAR(date_day, 'YYYY-"Q"Q')                  AS year_quarter

FROM (
    SELECT DATEADD(DAY, seq4(), '2023-01-01')::DATE AS date_day
    FROM TABLE(GENERATOR(ROWCOUNT => 1461))  -- 4 years: 365*4 + 1 leap day
)
