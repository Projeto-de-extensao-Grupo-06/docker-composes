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
