SET NAMES utf8mb4;
ALTER DATABASE solarway CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- OLAP Schema Inicial (Mapeamento Futuro do Snowflake Schema)
-- Placeholder para criação das Fact Tables e Dimension Tables

CREATE TABLE IF NOT EXISTS dim_time (
    id_time BIGINT AUTO_INCREMENT PRIMARY KEY,
    date DATE,
    year INT,
    month INT,
    day INT,
    quarter INT,
    week INT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dim_project (
    id_project BIGINT PRIMARY KEY,
    name VARCHAR(255),
    status VARCHAR(255),
    system_type VARCHAR(255),
    project_from VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dim_client (
    id_client BIGINT PRIMARY KEY,
    status VARCHAR(255),
    city VARCHAR(255),
    state VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fact_budget (
    id_fact_budget BIGINT AUTO_INCREMENT PRIMARY KEY,
    fk_time BIGINT,
    fk_project BIGINT,
    fk_client BIGINT,
    total_revenue DECIMAL(19,2),
    total_cost DECIMAL(19,2),
    profit_margin DECIMAL(19,2),
    discount_applied DECIMAL(19,2)
) ENGINE=InnoDB;

-- Adicione futuras dimensões e tabelas fatos aqui.
CREATE TABLE IF NOT EXISTS scoring_run (
    id_run BIGINT AUTO_INCREMENT PRIMARY KEY,
    source_bucket VARCHAR(255) NOT NULL,
    source_key VARCHAR(500) NOT NULL,
    source_file VARCHAR(255) NULL,
    generated_at DATETIME NOT NULL,
    total_regions INT NOT NULL,
    top_lead_city VARCHAR(255) NULL,
    top_lead_state VARCHAR(100) NULL,
    top_lead_ibge_city_code BIGINT NULL,
    top_solar_city VARCHAR(255) NULL,
    top_solar_state VARCHAR(100) NULL,
    top_solar_ibge_city_code BIGINT NULL,
    ingested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_scoring_run_source_key (source_key)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fact_scoring_city (
    id_fact_scoring_city BIGINT AUTO_INCREMENT PRIMARY KEY,
    fk_run BIGINT NOT NULL,
    state VARCHAR(100) NOT NULL,
    city VARCHAR(255) NOT NULL,
    ibge_city_code BIGINT NOT NULL,
    lead_rank INT NOT NULL,
    lead_priority VARCHAR(50) NOT NULL,
    points_count INT NOT NULL,
    avg_lat DECIMAL(10,6) NULL,
    avg_lon DECIMAL(10,6) NULL,
    annual_avg DECIMAL(10,2) NULL,
    income_avg DECIMAL(14,2) NULL,
    household_indicator_value DECIMAL(14,2) NULL,
    urban_indicator_value DECIMAL(14,2) NULL,
    sanitation_indicator_value DECIMAL(14,2) NULL,
    solar_score DECIMAL(10,2) NULL,
    income_score DECIMAL(10,2) NULL,
    household_score DECIMAL(10,2) NULL,
    urban_score DECIMAL(10,2) NULL,
    sanitation_score DECIMAL(10,2) NULL,
    solar_lead_score DECIMAL(10,2) NULL,
    generated_at DATETIME NOT NULL,
    source_bucket VARCHAR(255) NOT NULL,
    source_key VARCHAR(500) NOT NULL,
    ingested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_fact_scoring_city_run
        FOREIGN KEY (fk_run) REFERENCES scoring_run(id_run),

    UNIQUE KEY uq_fact_scoring_city_source_city (source_key, ibge_city_code),
    KEY idx_fact_scoring_city_rank (lead_rank),
    KEY idx_fact_scoring_city_priority (lead_priority),
    KEY idx_fact_scoring_city_state (state),
    KEY idx_fact_scoring_city_generated_at (generated_at)
) ENGINE=InnoDB;