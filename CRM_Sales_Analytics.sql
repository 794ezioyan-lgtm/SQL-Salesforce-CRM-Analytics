CREATE DATABASE IF NOT EXISTS maven_crm;

USE maven_crm;

SHOW TABLES;
USE maven_crm;

CREATE TABLE IF NOT EXISTS accounts (
    account VARCHAR(150) PRIMARY KEY,
    sector VARCHAR(100),
    year_established INT,
    revenue DECIMAL(15,2),
    employees INT,
    office_location VARCHAR(100),
    subsidiary_of VARCHAR(150)
);
USE maven_crm;

CREATE TABLE IF NOT EXISTS products (
    product VARCHAR(100) PRIMARY KEY,
    series VARCHAR(100),
    sales_price DECIMAL(12,2)
);

SHOW TABLES;
USE maven_crm;

CREATE TABLE IF NOT EXISTS sales_teams (
    sales_agent VARCHAR(100) PRIMARY KEY,
    manager VARCHAR(100),
    regional_office VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS sales_pipeline (
    opportunity_id VARCHAR(20) PRIMARY KEY,
    sales_agent VARCHAR(100),
    product VARCHAR(100),
    account VARCHAR(150),
    deal_stage VARCHAR(50),
    engage_date DATE,
    close_date DATE,
    close_value DECIMAL(12,2)
);

SHOW TABLES;
-- =====================================
-- 02. SALES PIPELINE IMPORT FIX
-- =====================================

USE maven_crm;

ALTER TABLE sales_pipeline
MODIFY COLUMN close_date VARCHAR(20) NULL,
MODIFY COLUMN close_value VARCHAR(30) NULL;

SHOW TABLES;
USE maven_crm;

SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT opportunity_id) AS unique_opportunities
FROM sales_pipeline;
SHOW CREATE TABLE maven_crm.sales_pipeline;
DESCRIBE maven_crm.sales_pipeline;
SELECT
    deal_stage,
    COUNT(*) AS total_deals
FROM maven_crm.sales_pipeline
GROUP BY deal_stage
ORDER BY total_deals DESC;
-- 01 | DATABASE VALIDATION

USE maven_crm;

SELECT 'accounts' AS table_name, COUNT(*) AS records
FROM accounts

UNION ALL

SELECT 'products', COUNT(*)
FROM products

UNION ALL

SELECT 'sales_teams', COUNT(*)
FROM sales_teams

UNION ALL

SELECT 'sales_pipeline', COUNT(*)
FROM sales_pipeline;

-- ==========================================
-- 02 | SALES PERFORMANCE OVERVIEW
-- ==========================================

SELECT
    ROUND(SUM(
        CASE WHEN deal_stage = 'Won'
        THEN CAST(NULLIF(close_value, '') AS DECIMAL(15,2))
        ELSE 0 END
    ), 2) AS total_revenue,

    SUM(CASE WHEN deal_stage = 'Won'
        THEN 1 ELSE 0 END) AS won_deals,

    ROUND(AVG(
        CASE WHEN deal_stage = 'Won'
        THEN CAST(NULLIF(close_value, '') AS DECIMAL(15,2))
        ELSE NULL END
    ), 2) AS average_deal_size,

    ROUND(
        100.0 * SUM(CASE WHEN deal_stage = 'Won'
            THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN deal_stage IN ('Won', 'Lost')
            THEN 1 ELSE 0 END), 0),
        2
    ) AS closed_deal_win_rate_pct

FROM sales_pipeline;

-- ==========================================
-- 03 | MONTHLY REVENUE TRENDS
-- ==========================================

SELECT
    DATE_FORMAT(close_date, '%Y-%m') AS sales_month,
    COUNT(*) AS won_deals,
    ROUND(SUM(
        CAST(NULLIF(close_value, '') AS DECIMAL(15,2))
    ), 2) AS monthly_revenue,
    ROUND(AVG(
        CAST(NULLIF(close_value, '') AS DECIMAL(15,2))
    ), 2) AS average_deal_size

FROM sales_pipeline

WHERE deal_stage = 'Won'
  AND close_date IS NOT NULL
  AND close_date <> ''

GROUP BY DATE_FORMAT(close_date, '%Y-%m')
ORDER BY sales_month;

-- ==========================================
-- 04 | SALES PIPELINE ANALYSIS
-- ==========================================

SELECT
    deal_stage,
    COUNT(*) AS total_opportunities,
    ROUND(
        100.0 * COUNT(*) /
        (SELECT COUNT(*) FROM sales_pipeline),
        2
    ) AS percentage_of_pipeline

FROM sales_pipeline

GROUP BY deal_stage

ORDER BY total_opportunities DESC;

-- ==========================================
-- 05 | SALES AGENT PERFORMANCE
-- ==========================================

SELECT
    sales_agent,

    COUNT(*) AS total_opportunities,

    SUM(CASE WHEN deal_stage = 'Won'
        THEN 1 ELSE 0 END) AS won_deals,

    ROUND(SUM(CASE WHEN deal_stage = 'Won'
        THEN CAST(NULLIF(close_value, '') AS DECIMAL(15,2))
        ELSE 0 END), 2) AS total_revenue,

    ROUND(
        100.0 * SUM(CASE WHEN deal_stage = 'Won'
            THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN deal_stage IN ('Won', 'Lost')
            THEN 1 ELSE 0 END), 0),
        2
    ) AS win_rate_pct

FROM sales_pipeline

GROUP BY sales_agent
ORDER BY total_revenue DESC;

-- ==========================================
-- 06 | PRODUCT PERFORMANCE
-- ==========================================

SELECT
    product,
    COUNT(*) AS total_opportunities,

    SUM(CASE WHEN deal_stage = 'Won'
        THEN 1 ELSE 0 END) AS won_deals,

    ROUND(SUM(CASE WHEN deal_stage = 'Won'
        THEN CAST(NULLIF(close_value, '') AS DECIMAL(15,2))
        ELSE 0 END), 2) AS total_revenue,

    ROUND(AVG(CASE WHEN deal_stage = 'Won'
        THEN CAST(NULLIF(close_value, '') AS DECIMAL(15,2))
        ELSE NULL END), 2) AS average_deal_size,

    ROUND(
        100.0 * SUM(CASE WHEN deal_stage = 'Won'
            THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN deal_stage IN ('Won', 'Lost')
            THEN 1 ELSE 0 END), 0),
        2
    ) AS win_rate_pct

FROM sales_pipeline

GROUP BY product
ORDER BY total_revenue DESC;

-- ==========================================
-- 07 | CUSTOMER & INDUSTRY ANALYSIS
-- ==========================================

SELECT
    a.sector AS industry,
    COUNT(*) AS total_opportunities,

    SUM(CASE WHEN s.deal_stage = 'Won'
        THEN 1 ELSE 0 END) AS won_deals,

    ROUND(SUM(CASE WHEN s.deal_stage = 'Won'
        THEN CAST(NULLIF(s.close_value, '') AS DECIMAL(15,2))
        ELSE 0 END), 2) AS total_revenue,

    ROUND(
        100.0 * SUM(CASE WHEN s.deal_stage = 'Won'
            THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN s.deal_stage IN ('Won', 'Lost')
            THEN 1 ELSE 0 END), 0),
        2
    ) AS win_rate_pct

FROM sales_pipeline s

LEFT JOIN accounts a
    ON s.account = a.account

GROUP BY a.sector
ORDER BY total_revenue DESC;

-- 08 | CUSTOMER DATA QUALITY CHECK

SELECT
    COUNT(*) AS unmatched_opportunities,
    SUM(CASE WHEN s.deal_stage = 'Won'
        THEN 1 ELSE 0 END) AS unmatched_won_deals
FROM sales_pipeline s
LEFT JOIN accounts a
    ON s.account = a.account
WHERE a.account IS NULL;
-- 09 | UNMATCHED ACCOUNT INVESTIGATION

SELECT
    s.deal_stage,
    COUNT(*) AS unmatched_deals
FROM sales_pipeline s
LEFT JOIN accounts a
    ON s.account = a.account
WHERE a.account IS NULL
GROUP BY s.deal_stage
ORDER BY unmatched_deals DESC;

-- ==========================================
-- 10 | REGIONAL SALES PERFORMANCE
-- ==========================================

SELECT
    t.regional_office,
    COUNT(*) AS total_opportunities,

    SUM(CASE WHEN s.deal_stage = 'Won'
        THEN 1 ELSE 0 END) AS won_deals,

    ROUND(SUM(CASE WHEN s.deal_stage = 'Won'
        THEN CAST(NULLIF(s.close_value, '') AS DECIMAL(15,2))
        ELSE 0 END), 2) AS total_revenue,

    ROUND(
        100.0 * SUM(CASE WHEN s.deal_stage = 'Won'
            THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN s.deal_stage IN ('Won', 'Lost')
            THEN 1 ELSE 0 END), 0),
        2
    ) AS win_rate_pct

FROM sales_pipeline s

LEFT JOIN sales_teams t
    ON s.sales_agent = t.sales_agent

GROUP BY t.regional_office
ORDER BY total_revenue DESC;

-- ==========================================
-- 11 | SALES CYCLE ANALYSIS
-- ==========================================

SELECT
    deal_stage,
    COUNT(*) AS completed_deals,

    ROUND(AVG(
        DATEDIFF(
            STR_TO_DATE(close_date, '%Y-%m-%d'),
            engage_date
        )
    ), 1) AS avg_days_to_close,

    MIN(DATEDIFF(
        STR_TO_DATE(close_date, '%Y-%m-%d'),
        engage_date
    )) AS fastest_days,

    MAX(DATEDIFF(
        STR_TO_DATE(close_date, '%Y-%m-%d'),
        engage_date
    )) AS longest_days

FROM sales_pipeline

WHERE deal_stage IN ('Won', 'Lost')
  AND engage_date IS NOT NULL
  AND close_date IS NOT NULL
  AND close_date <> ''

GROUP BY deal_stage;
