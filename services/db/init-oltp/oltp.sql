SET NAMES utf8mb4;
ALTER DATABASE solarway CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Configurações Globais e Permissões
CREATE USER IF NOT EXISTS 'solarway'@'%' IDENTIFIED BY '06241234';
GRANT ALL PRIVILEGES ON *.* TO 'solarway'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

-- 1. Funções Base
CREATE FUNCTION IF NOT EXISTS unaccent(str TEXT) 
RETURNS TEXT DETERMINISTIC 
RETURN str COLLATE utf8mb4_unicode_ci;

-- 2. DDL Básica (Tabelas dependentes de inserts iniciais)
-- Criamos as tabelas manualmente para garantir que existam ANTES dos inserts do script de inicialização.
-- O Hibernate fará o "update" delas depois, o que é seguro.

CREATE TABLE IF NOT EXISTS permission_group (
    id_permission_group BIGINT AUTO_INCREMENT PRIMARY KEY,
    role VARCHAR(255),
    main_module VARCHAR(255),
    access_client INT,
    access_project INT,
    access_budget INT,
    access_schedule INT,
    access_material INT,
    access_configuration INT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS address (
    id_address BIGINT AUTO_INCREMENT PRIMARY KEY,
    postal_code VARCHAR(255),
    street_name VARCHAR(255),
    number VARCHAR(255),
    neighborhood VARCHAR(255),
    city VARCHAR(255),
    state VARCHAR(255),
    type VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS client (
    id_client BIGINT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    document_number VARCHAR(255),
    document_type VARCHAR(255),
    created_at DATETIME(6),
    updated_at DATETIME(6),
    phone VARCHAR(255),
    email VARCHAR(255),
    fk_main_address BIGINT,
    status VARCHAR(255),
    CONSTRAINT fk_client_address FOREIGN KEY (fk_main_address) REFERENCES address(id_address)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS coworker (
    id_coworker BIGINT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(255),
    password VARCHAR(255),
    is_active BIT(1),
    fk_permission_group BIGINT,
    CONSTRAINT fk_coworker_permission FOREIGN KEY (fk_permission_group) REFERENCES permission_group(id_permission_group)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS project (
    id_project BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    description TEXT,
    status VARCHAR(255),
    status_weight INT,
    preview_status VARCHAR(255),
    is_active BIT(1),
    system_type VARCHAR(255),
    project_from VARCHAR(255),
    created_at DATETIME(6),
    deadline DATETIME(6),
    fk_client BIGINT,
    fk_responsible BIGINT,
    fk_address BIGINT,
    CONSTRAINT fk_project_client FOREIGN KEY (fk_client) REFERENCES client(id_client),
    CONSTRAINT fk_project_coworker FOREIGN KEY (fk_responsible) REFERENCES coworker(id_coworker),
    CONSTRAINT fk_project_address FOREIGN KEY (fk_address) REFERENCES address(id_address)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS material (
    id_material BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    metric VARCHAR(255),
    hidden BIT(1),
    description TEXT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS material_url (
    id_material_url BIGINT AUTO_INCREMENT PRIMARY KEY,
    url VARCHAR(500),
    fk_material BIGINT,
    price DECIMAL(19,2),
    hidden BIT(1),
    CONSTRAINT fk_material_url_material FOREIGN KEY (fk_material) REFERENCES material(id_material)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS coworker_project (
    fk_coworker BIGINT NOT NULL,
    fk_project BIGINT NOT NULL,
    is_responsible BIT(1),
    PRIMARY KEY (fk_coworker, fk_project),
    CONSTRAINT fk_cp_coworker FOREIGN KEY (fk_coworker) REFERENCES coworker(id_coworker),
    CONSTRAINT fk_cp_project FOREIGN KEY (fk_project) REFERENCES project(id_project)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS schedule (
    id_schedule BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255),
    description TEXT,
    start_date DATETIME(6),
    end_date DATETIME(6),
    type VARCHAR(255),
    status VARCHAR(255),
    is_active BIT(1),
    fk_project BIGINT,
    fk_coworker BIGINT NOT NULL,
    CONSTRAINT fk_schedule_project FOREIGN KEY (fk_project) REFERENCES project(id_project),
    CONSTRAINT fk_schedule_coworker FOREIGN KEY (fk_coworker) REFERENCES coworker(id_coworker)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS portfolio (
    id_portfolio BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255),
    description TEXT,
    image_path VARCHAR(500),
    fk_project BIGINT,
    CONSTRAINT fk_portfolio_project FOREIGN KEY (fk_project) REFERENCES project(id_project)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS retry_queue (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    scheduled_date DATETIME(6),
    retrying BIT(1),
    fk_project BIGINT,
    CONSTRAINT fk_retry_project FOREIGN KEY (fk_project) REFERENCES project(id_project)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS project_file (
    id_project_file BIGINT AUTO_INCREMENT PRIMARY KEY,
    filename VARCHAR(255),
    original_filename VARCHAR(255),
    created_at DATETIME(6),
    mb_size INT,
    check_sum VARCHAR(255),
    homologation_doc BIT(1),
    content_type VARCHAR(255),
    fk_project BIGINT,
    fk_coworker BIGINT,
    CONSTRAINT fk_project_file_project FOREIGN KEY (fk_project) REFERENCES project(id_project),
    CONSTRAINT fk_project_file_coworker FOREIGN KEY (fk_coworker) REFERENCES coworker(id_coworker)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS project_comment (
    id_project_comment BIGINT AUTO_INCREMENT PRIMARY KEY,
    comment TEXT,
    created_at DATETIME(6),
    fk_project BIGINT,
    fk_coworker BIGINT,
    CONSTRAINT fk_project_comment_project FOREIGN KEY (fk_project) REFERENCES project(id_project),
    CONSTRAINT fk_project_comment_coworker FOREIGN KEY (fk_coworker) REFERENCES coworker(id_coworker)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS budget (
    id_budget BIGINT AUTO_INCREMENT PRIMARY KEY,
    subtotal DECIMAL(19,2),
    total_cost DECIMAL(19,2),
    discount DECIMAL(19,2),
    material_cost DECIMAL(19,2),
    service_cost DECIMAL(19,2),
    created_at DATETIME(6),
    discount_type VARCHAR(255),
    final_budget BIT(1),
    fk_project BIGINT,
    CONSTRAINT fk_budget_project FOREIGN KEY (fk_project) REFERENCES project(id_project)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS budget_material (
    fk_budget BIGINT,
    fk_material_url BIGINT,
    quantity INT,
    price DECIMAL(19,2),
    PRIMARY KEY (fk_budget, fk_material_url),
    CONSTRAINT fk_bm_budget FOREIGN KEY (fk_budget) REFERENCES budget(id_budget),
    CONSTRAINT fk_bm_material_url FOREIGN KEY (fk_material_url) REFERENCES material_url(id_material_url)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS payment (
    id_payment BIGINT AUTO_INCREMENT PRIMARY KEY,
    method VARCHAR(255),
    installments_count INT,
    total_amount DECIMAL(19,2),
    created_at DATETIME(6),
    fk_budget BIGINT,
    CONSTRAINT fk_payment_budget FOREIGN KEY (fk_budget) REFERENCES budget(id_budget)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payment_installment (
    id_payment_installment BIGINT AUTO_INCREMENT PRIMARY KEY,
    installment_number INT,
    amount DECIMAL(19,2),
    due_date DATE,
    paid_at DATETIME(6),
    status VARCHAR(255),
    fk_payment BIGINT,
    CONSTRAINT fk_pi_payment FOREIGN KEY (fk_payment) REFERENCES payment(id_payment)
) ENGINE=InnoDB;


-- 3. Carga de Dados (Inserts)
-- Usamos INSERT IGNORE para evitar erros se rodar mais de uma vez.

INSERT IGNORE INTO permission_group
(id_permission_group, role, main_module,
 access_client,
 access_project,
 access_budget,
 access_schedule,
 access_material,
 access_configuration)
VALUES
(1, 'ADMIN', 'PROJECT',   15, 15, 15, 15, 15, 15),
(2, 'TÉCNICO', 'SCHEDULE', 1,  7,  1, 15,  1,  1),
(3, 'SECRETÁRIA', 'CLIENT',15,  3, 15,  1,  1,  1);

INSERT IGNORE INTO coworker (id_coworker, first_name, last_name, email, phone, password, is_active, fk_permission_group) VALUES
(1, 'Sálvio', 'Nobrega', 'salvio.admin@solarway.com.br', '11987654321', '$2a$12$dUlemf8rtZhoMu/nH.5XtOmerR.uxfLp5vmVbYVrzduguD.d/jhWG', TRUE, 1),
(2, 'Cristiano', 'Ribeiro', 'cristiano.eng@solarway.com.br', '11912345678', '$2a$12$dUlemf8rtZhoMu/nH.5XtOmerR.uxfLp5vmVbYVrzduguD.d/jhWG', TRUE, 2),
(3, 'Maria', 'Gomes', 'maria.tec@solarway.com.br', '11998765432', '$2a$12$dUlemf8rtZhoMu/nH.5XtOmerR.uxfLp5vmVbYVrzduguD.d/jhWG', TRUE, 2),
(4, 'Ana', 'Vendas', 'ana.sales@solarway.com.br', '11955554444', '$2a$12$dUlemf8rtZhoMu/nH.5XtOmerR.uxfLp5vmVbYVrzduguD.d/jhWG', TRUE, 3),
(5, 'Bryan', 'Rocha', 'bryangomesrocha@gmail.com', '11964275054', '$2a$12$dUlemf8rtZhoMu/nH.5XtOmerR.uxfLp5vmVbYVrzduguD.d/jhWG', TRUE, 1);

INSERT IGNORE INTO address (id_address, postal_code, street_name, number, neighborhood, city, state, type) VALUES
(1, '13010-050', 'Rua XV de Novembro', '123', 'Centro', 'Campinas', 'SP', 'RESIDENTIAL'),
(2, '01311-000', 'Av. Paulista', '2000', 'Bela Vista', 'São Paulo', 'SP', 'BUILDING'),
(3, '88015-000', 'Rua Bocaiúva', '90', 'Centro', 'Florianópolis', 'SC', 'COMMERCIAL'),
(4, '22021-001', 'Av. Atlântica', '500', 'Copacabana', 'Rio de Janeiro', 'RJ', 'RESIDENTIAL'),
(5, '30130-000', 'Rua da Bahia', '1000', 'Centro', 'Belo Horizonte', 'MG', 'COMMERCIAL'),
(6, '70000-000', 'Asa Norte', 'SQN 102', 'Plano Piloto', 'Brasília', 'DF', 'RESIDENTIAL');

INSERT IGNORE INTO client (id_client, first_name, last_name, document_number, document_type, created_at, phone, email, fk_main_address, status) VALUES
(1, 'João', 'Silva', '12345678901', 'CPF', '2025-08-01 10:00:00', '1933233431', 'ranierd.couto@gmail.com', 1, 'ACTIVE'),
(2, 'Maria', 'Oliveira', '12345678902', 'CPF', '2025-09-10 14:30:00', '2199865432', 'maria.oliveira@example.com', 2, 'ACTIVE'),
(3, 'Pedro', 'Santos', '11222333000144', 'CNPJ', '2025-10-05 09:00:00', '4899123456', 'pedro.santos@example.com', 3, 'ACTIVE'),
(4, 'Lucia', 'Ferreira', '98765432100', 'CPF', '2025-10-20 11:00:00', '21988887777', 'lucia.ferreira@example.com', 4, 'ACTIVE'),
(5, 'Empresa Tech', 'Solar', '55666777000199', 'CNPJ', '2025-11-01 15:45:00', '3133334444', 'contato@techsolar.com', 5, 'ACTIVE');

INSERT IGNORE INTO client (first_name, last_name, phone, email, status, document_number, document_type, created_at, updated_at) VALUES
('João', 'da Silva', '11999999999', 'joao@gmail.com', 'ACTIVE', '12345678900', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Maria', 'Souza', '11888888888', 'maria@email.com', 'ACTIVE', '98765432100', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Carlos', 'Pereira', '11777777777', 'carlos@email.com', 'INACTIVE', '11122233344', 'CNPJ', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Ana', 'Oliveira', '11912345678', 'ana.oliveira@email.com', 'ACTIVE', '44455566677', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Ricardo', 'Santos', '21987654321', 'ricardo.santos@email.com', 'ACTIVE', '88899900011', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Luciana', 'Mendes', '31998877665', 'luciana.mendes@email.com', 'INACTIVE', '22233344455', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Marcos', 'Almeida', '1133445566', 'contato@almeidame.com', 'ACTIVE', '12345678000199', 'CNPJ', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Fernanda', 'Costa', '41995544332', 'fer.costa@email.com', 'ACTIVE', '77788899922', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Roberto', 'Ferreira', '51988772211', 'roberto.f@email.com', 'ACTIVE', '55566677788', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Juliana', 'Lima', '61991122334', 'juliana.lima@email.com', 'ACTIVE', '99900011122', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Bruno', 'Rocha', '1144556677', 'financeiro@rochacorp.com', 'ACTIVE', '98765432000188', 'CNPJ', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Camila', 'Barbosa', '71992233445', 'camila.b@email.com', 'INACTIVE', '33344455566', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Tiago', 'Nunes', '81987651234', 'tiago.nunes@email.com', 'ACTIVE', '11100099988', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Gabriel', 'Duarte', '11911112222', 'gabriel.duarte@email.com', 'ACTIVE', '10120230344', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Beatriz', 'Pinto', '21922223333', 'beatriz.p@email.com', 'ACTIVE', '50560670788', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('André', 'Teixeira', '31933334444', 'andre.tex@email.com', 'INACTIVE', '90980870766', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Larissa', 'Cavalcanti', '41944445555', 'lari.cav@email.com', 'ACTIVE', '11223344000155', 'CNPJ', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Felipe', 'Cardoso', '51955556666', 'felipe.c@email.com', 'ACTIVE', '30340450599', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Patrícia', 'Gomes', '61966667777', 'patri.gomes@email.com', 'ACTIVE', '60670780811', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Henrique', 'Souza', '71977778888', 'h.souza@email.com', 'ACTIVE', '80890910122', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Daniela', 'Moreira', '81988889999', 'dani.moreira@email.com', 'INACTIVE', '44332211000100', 'CNPJ', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Leonardo', 'Freitas', '11912123434', 'leo.freitas@email.com', 'ACTIVE', '12132343455', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Vanessa', 'Lopes', '21923234545', 'vanessa.l@email.com', 'ACTIVE', '54565676788', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Gustavo', 'Batista', '31934345656', 'gustavo.b@email.com', 'ACTIVE', '98978767655', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Letícia', 'Assis', '41945456767', 'leticia.assis@email.com', 'ACTIVE', '10190980877', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Sérgio', 'Marques', '51956567878', 'sergio.m@email.com', 'ACTIVE', '55443322000111', 'CNPJ', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Aline', 'Vieira', '61967678989', 'aline.v@email.com', 'INACTIVE', '70780890933', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Maurício', 'Moraes', '71978789090', 'mau.moraes@email.com', 'ACTIVE', '20230340455', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Tatiane', 'Ribeiro', '81989890101', 'tati.rib@email.com', 'ACTIVE', '40450560677', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Renato', 'Carvalho', '11990901212', 'renato.c@email.com', 'ACTIVE', '80870760644', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Sabrina', 'Gonçalves', '21901012323', 'sabrina.g@email.com', 'ACTIVE', '66554433000122', 'CNPJ', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Igor', 'Fernandes', '31912123434', 'igor.f@email.com', 'ACTIVE', '90910120233', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('Priscila', 'Monteiro', '41923234545', 'pri.monteiro@email.com', 'ACTIVE', '30320210144', 'CPF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- PROJECTS
INSERT IGNORE INTO project (id_project, name, description, status, status_weight, preview_status, is_active, system_type, project_from, created_at, deadline, fk_client, fk_responsible, fk_address) VALUES
(1, 'Residência João Silva', 'Instalação 5kWp', 'SCHEDULED_TECHNICAL_VISIT', 5, 'CLIENT_AWAITING_CONTACT', TRUE, 'ON_GRID', 'SITE_BUDGET_FORM', DATE_ADD(NOW(), INTERVAL -5 DAY), DATE_ADD('2025-09-15', INTERVAL 30 DAY), 1, 2, 1),
(2, 'Clínica Maria Oliveira', 'Backup Off-grid', 'INSTALLED', 10, 'SCHEDULED_INSTALLING_VISIT', TRUE, 'OFF_GRID', 'WHATSAPP_BOT', DATE_ADD(NOW(), INTERVAL -60 DAY), DATE_ADD('2025-09-20', INTERVAL 30 DAY), 2, 3, 2),
(3, 'Comércio Pedro Santos', 'Sistema Comercial', 'COMPLETED', 13, 'INSTALLED', TRUE, 'ON_GRID', 'INTERNAL_MANUAL_ENTRY', DATE_ADD(NOW(), INTERVAL -70 DAY), DATE_ADD('2025-10-02', INTERVAL 30 DAY), 3, 1, 3),
(4, 'Casa de Praia Lucia', 'Off-grid simples', 'FINAL_BUDGET', 7, 'TECHNICAL_VISIT_COMPLETED', TRUE, 'OFF_GRID', 'SITE_BUDGET_FORM', DATE_ADD(NOW(), INTERVAL -45 DAY), DATE_ADD('2025-10-15', INTERVAL 30 DAY), 4, 4, 4),
(5, 'Tech Solar Sede', 'Alta demanda', 'NEW', 3, NULL, TRUE, 'ON_GRID', 'INTERNAL_MANUAL_ENTRY', DATE_ADD(NOW(), INTERVAL -1 DAY), DATE_ADD('2025-10-28', INTERVAL 30 DAY), 5, 2, 5),
(6, 'Expansão João Silva', 'Adição de painéis', 'PRE_BUDGET', 4, 'NEW', TRUE, 'ON_GRID', 'WHATSAPP_BOT', DATE_ADD(NOW(), INTERVAL -10 DAY), DATE_ADD('2025-11-05', INTERVAL 30 DAY), 1, 2, 1),
(7, 'Estacionamento Shopping', 'Carport Solar', 'SCHEDULED_INSTALLING_VISIT', 6, 'AWAITING_MATERIALS', TRUE, 'ON_GRID', 'SITE_BUDGET_FORM', DATE_ADD(NOW(), INTERVAL -30 DAY), DATE_ADD('2025-11-10', INTERVAL 30 DAY), 3, 3, 3),
(8, 'Sítio Recanto', 'Bombeamento Solar', 'NEGOTIATION_FAILED', 12, 'FINAL_BUDGET', TRUE, 'OFF_GRID', 'WHATSAPP_BOT', DATE_ADD(NOW(), INTERVAL -40 DAY), DATE_ADD('2025-11-12', INTERVAL 30 DAY), 2, 4, 2),
(9, 'Condomínio Flores', 'Área comum', 'CLIENT_AWAITING_CONTACT', 1, 'PRE_BUDGET', TRUE, 'ON_GRID', 'SITE_BUDGET_FORM', DATE_ADD(NOW(), INTERVAL -2 DAY), DATE_ADD('2025-11-20', INTERVAL 30 DAY), 4, 1, 2);

-- BUDGETS
INSERT IGNORE INTO budget (id_budget, subtotal, total_cost, discount, material_cost, service_cost, created_at, discount_type, final_budget, fk_project) VALUES
(10, 18000.00, 18000.00, 0.00, 12900.00, 0.00, DATE_ADD(NOW(), INTERVAL -3 DAY), 'AMOUNT', FALSE, 1),
(2, 24535.10, 24000.00, 535.10, 19535.10, 5000.00, DATE_ADD(NOW(), INTERVAL -45 DAY), 'AMOUNT', TRUE, 2),
(3, 44387.30, 43000.00, 1387.30, 36387.30, 8000.00, DATE_ADD(NOW(), INTERVAL -55 DAY), 'AMOUNT', TRUE, 3),
(4, 18292.55, 18000.00, 292.55, 15292.55, 3000.00, DATE_ADD(NOW(), INTERVAL -30 DAY), 'AMOUNT', TRUE, 4),
(6, 10000.00, 9500.00, 5.00, 8000.00, 2000.00, DATE_ADD(NOW(), INTERVAL -2 DAY), 'PERCENT', FALSE, 6),
(7, 76025.50, 75000.00, 1025.50, 61025.50, 15000.00, DATE_ADD(NOW(), INTERVAL -15 DAY), 'AMOUNT', TRUE, 7),
(8, 38270.20, 38270.20, 0.00, 32270.20, 6000.00, DATE_ADD(NOW(), INTERVAL -25 DAY), 'AMOUNT', TRUE, 8),
(9, 15000.00, 15000.00, 0.00, 10000.00, 5000.00, DATE_ADD(NOW(), INTERVAL -1 DAY), 'AMOUNT', FALSE, 9);

-- SCHEDULES
INSERT IGNORE INTO schedule (id_schedule, title, description, start_date, end_date, type, status, is_active, fk_project, fk_coworker) VALUES
(1, 'Visita Técnica João', 'Medição de telhado', DATE_ADD(NOW(), INTERVAL 24 HOUR), DATE_ADD(NOW(), INTERVAL 26 HOUR), 'TECHNICAL_VISIT', 'MARKED', TRUE, 1, 2),
(2, 'Visita Técnica Maria', 'Análise de local', DATE_ADD(NOW(), INTERVAL -50 DAY), DATE_ADD(NOW(), INTERVAL -50 DAY), 'TECHNICAL_VISIT', 'FINISHED', TRUE, 2, 3),
(3, 'Instalação Maria', 'Instalação Off-grid', DATE_ADD(NOW(), INTERVAL -20 DAY), DATE_ADD(NOW(), INTERVAL -18 DAY), 'INSTALL_VISIT', 'FINISHED', TRUE, 2, 3),
(4, 'Visita Técnica Pedro', 'Medição comercial', DATE_ADD(NOW(), INTERVAL -60 DAY), DATE_ADD(NOW(), INTERVAL -60 DAY), 'TECHNICAL_VISIT', 'FINISHED', TRUE, 3, 1),
(5, 'Instalação Pedro', 'Instalação On-grid', DATE_ADD(NOW(), INTERVAL -30 DAY), DATE_ADD(NOW(), INTERVAL -25 DAY), 'INSTALL_VISIT', 'FINISHED', TRUE, 3, 1),
(6, 'Visita Técnica Lucia', 'Análise Off-grid', DATE_ADD(NOW(), INTERVAL -40 DAY), DATE_ADD(NOW(), INTERVAL -40 DAY), 'TECHNICAL_VISIT', 'FINISHED', TRUE, 4, 4),
(7, 'Visita Técnica Shopping', 'Avaliação Carport', DATE_ADD(NOW(), INTERVAL -20 DAY), DATE_ADD(NOW(), INTERVAL -20 DAY), 'TECHNICAL_VISIT', 'FINISHED', TRUE, 7, 3),
(8, 'Instalação Shopping', 'Montagem Carport', DATE_ADD(NOW(), INTERVAL 5 DAY), DATE_ADD(NOW(), INTERVAL 15 DAY), 'INSTALL_VISIT', 'MARKED', TRUE, 7, 3),
(9, 'Visita Técnica Sítio', 'Medição bombeamento', DATE_ADD(NOW(), INTERVAL -30 DAY), DATE_ADD(NOW(), INTERVAL -30 DAY), 'TECHNICAL_VISIT', 'FINISHED', TRUE, 8, 4);

-- COMMENTS
INSERT IGNORE INTO project_comment (id_project_comment, comment, created_at, fk_project, fk_coworker) VALUES
(1, 'Visita Técnica concluída com sucesso. Local preparado para instalação off-grid.', DATE_ADD(NOW(), INTERVAL -49 DAY), 2, 3),
(2, 'Instalação Off-grid finalizada e testada. Cliente satisfeito.', DATE_ADD(NOW(), INTERVAL -15 DAY), 2, 3),
(3, 'Documentação de homologação enviada e aprovada pela concessionária.', DATE_ADD(NOW(), INTERVAL -5 DAY), 7, 3),
(4, 'Visita técnica no comércio realizada. Estrutura suporta os painéis.', DATE_ADD(NOW(), INTERVAL -59 DAY), 3, 1),
(5, 'Instalação On-grid finalizada e sistema operando.', DATE_ADD(NOW(), INTERVAL -25 DAY), 3, 1),
(6, 'Homologação aprovada.', DATE_ADD(NOW(), INTERVAL -5 DAY), 3, 1),
(7, 'Projeto Elétrico elaborado e aprovado.', DATE_ADD(NOW(), INTERVAL -44 DAY), 2, 3),
(8, 'Visita técnica concluída. Cliente solicitou alteração no escopo.', DATE_ADD(NOW(), INTERVAL -38 DAY), 4, 4),
(9, 'Estrutura metálica do estacionamento vistoriada.', DATE_ADD(NOW(), INTERVAL -19 DAY), 7, 3);

-- FILES
INSERT IGNORE INTO project_file (id_project_file, filename, original_filename, created_at, mb_size, check_sum, homologation_doc, content_type, fk_project, fk_coworker) VALUES
(1, 'homologacao_shopping.pdf', 'Homologação Copel.pdf', DATE_ADD(NOW(), INTERVAL -5 DAY), 2, 'abc123checksum', TRUE, 'application/pdf', 7, 3),
(2, 'homologacao_maria.pdf', 'Homologação CPFL Maria.pdf', DATE_ADD(NOW(), INTERVAL -5 DAY), 1, 'def456checksum', TRUE, 'application/pdf', 2, 3),
(3, 'homologacao_pedro.pdf', 'Homologação Elektro Pedro.pdf', DATE_ADD(NOW(), INTERVAL -5 DAY), 3, 'ghi789checksum', TRUE, 'application/pdf', 3, 1),
(4, 'projeto_eletrico_maria.pdf', 'Projeto Eletrico.pdf', DATE_ADD(NOW(), INTERVAL -44 DAY), 4, 'jkl012checksum', FALSE, 'application/pdf', 2, 3);

-- PAYMENTS
INSERT IGNORE INTO payment (id_payment, method, installments_count, total_amount, created_at, fk_budget) VALUES
(1, 'PIX', 1, 24000.00, DATE_ADD(NOW(), INTERVAL -45 DAY), 2),
(2, 'CREDIT_CARD', 3, 43000.00, DATE_ADD(NOW(), INTERVAL -55 DAY), 3),
(3, 'FINANCING', 60, 75000.00, DATE_ADD(NOW(), INTERVAL -15 DAY), 7);

-- PAYMENT INSTALLMENTS
INSERT IGNORE INTO payment_installment (id_payment_installment, installment_number, amount, due_date, paid_at, status, fk_payment) VALUES
(1, 1, 24000.00, DATE_ADD(NOW(), INTERVAL -40 DAY), DATE_ADD(NOW(), INTERVAL -44 DAY), 'PAID', 1),
(2, 1, 14333.33, DATE_ADD(NOW(), INTERVAL -50 DAY), DATE_ADD(NOW(), INTERVAL -54 DAY), 'PAID', 2),
(3, 2, 14333.33, DATE_ADD(NOW(), INTERVAL -20 DAY), DATE_ADD(NOW(), INTERVAL -19 DAY), 'PAID', 2),
(4, 3, 14333.34, DATE_ADD(NOW(), INTERVAL 10 DAY), NULL, 'PENDING', 2),
(5, 1, 1250.00, DATE_ADD(NOW(), INTERVAL 15 DAY), NULL, 'PENDING', 3),
(6, 2, 1250.00, DATE_ADD(NOW(), INTERVAL 45 DAY), NULL, 'PENDING', 3),
(7, 3, 1250.00, DATE_ADD(NOW(), INTERVAL 75 DAY), NULL, 'PENDING', 3);

INSERT IGNORE INTO material (id_material, name, metric, hidden, description) VALUES
(1, 'Painel Solar 550W (Solar Center)', 'UNIT', FALSE, 'Ficha Técnica Painel'),
(2, 'Inversor On-Grid 5kW (Painel Forte)', 'UNIT', FALSE, 'Manual Inversor'),
(3, 'Cabo Solar 6mm', 'METER', FALSE, NULL),
(4, 'Bateria 5kWh (EcoSolar)', 'UNIT', FALSE, 'Certificação Bateria'),
(5, 'Estrutura de Fixação Telhado', 'UNIT', FALSE, NULL);

INSERT IGNORE INTO material_url (id_material_url, url, fk_material, price, hidden) VALUES
(1, 'https://solarcenter.com/fichas/painel550w.pdf', 1, 900.00, FALSE),
(2, 'https://painelforte.com.br/manual/inversor5kw.pdf', 2, 3500.00, FALSE),
(3, 'https://ecosolar.com.br/docs/bateria5kwh.pdf', 4, 2800.00, FALSE),
(4, 'https://solarcenter.com/fichas/cabo6mm.pdf', 3, 12.00, FALSE),
(5, 'https://www.mercadolivre.com.br/painel-placa-solar-fotovoltaica-50w--controlador--cabos/up/MLBU1167249603#polycard_client=search-desktop&search_layout=grid&position=2&type=product&tracking_id=b9346980-69e9-42ee-bd8b-13f7d2334d32&wid=MLB690995630&sid=search', 1, 820.00, FALSE),
(6, 'https://www.mercadolivre.com.br/inversor-growatt-min-5000tl-x2-5kw-gerador-220v-afci/p/MLB41505710?pdp_filters=item_id%3AMLB5495151532&from=gshop&matt_tool=47518833&matt_word=&matt_source=google&matt_campaign_id=22090354007&matt_ad_group_id=173090504316&matt_match_type=&matt_network=g&matt_device=c&matt_creative=727882725753&matt_keyword=&matt_ad_position=&matt_ad_type=pla&matt_merchant_id=735098660&matt_product_id=MLB41505710-product&matt_product_partition_id=2388858354208&matt_target_id=aud-1966857867496:pla-2388858354208&cq_src=google_ads&cq_cmp=22090354007&cq_net=g&cq_plt=gp&cq_med=pla&gad_source=1&gad_campaignid=22090354007&gclid=Cj0KCQjwy_fOBhC6ARIsAHKFB7_9MV1jjRU_f-S7dKRMRt--OTSMVnrvloMuIFZbN9WJ_2jnDvghkFQaAg2ZEALw_wcB', 2, 2999.00, FALSE),
(7, 'https://www.mercadolivre.com.br/cabo-solar-6mm-flexivel-100-metros-pretovermelho-cabel-preto/p/MLB61100209?pdp_filters=item_id:MLB4587600165#is_advertising=true&searchVariation=MLB61100209&backend_model=search-backend&position=1&search_layout=grid&type=pad&tracking_id=709c4c4a-38d8-46b0-bc66-396a6b6a665d&ad_domain=VQCATCORE_LST&ad_position=1&ad_click_id=MGExMjViMDktMGU5NS00NDA3LTkzYzItNzBiNTFjMWE1NmQ4', 3, 285.00, FALSE),
(8, 'https://www.mercadolivre.com.br/bateria-solar-felicity-lifepo4-48v-100ah-alta-performance/p/MLB2072983676#polycard_client=search-desktop&search_layout=grid&position=1&type=product&tracking_id=e8684cee-65bc-406a-9885-7aacb1740c4f&wid=MLB3927023235&sid=search', 4, 5975.00, FALSE),
(9, 'https://www.mercadolivre.com.br/kit-16-parafuso-estrutura-painel-solar-telha-fibro-madeira/p/MLB67069391#polycard_client=search-desktop&search_layout=grid&position=1&type=product&tracking_id=98cdb6db-e2c5-4f5f-af97-cae489e22705&wid=MLB6505776872&sid=search', 5, 417.55, FALSE);

INSERT IGNORE INTO coworker_project (fk_coworker, fk_project, is_responsible) VALUES
(2, 1, TRUE),
(3, 2, TRUE),
(1, 3, TRUE),
(4, 4, TRUE),
(2, 5, TRUE);

INSERT IGNORE INTO portfolio (id_portfolio, title, description, image_path, fk_project) VALUES
(1, 'Residência Sustentável', 'Sistema 5kWp em telhado cerâmico', '/images/portfolio/joao_v1.jpg', 1),
(2, 'Backup Hospitalar', 'Sistema de segurança energética', '/images/portfolio/maria_clinic.jpg', 2);

INSERT IGNORE INTO budget_material (fk_budget, fk_material_url, quantity, price) VALUES
(2, 1, 10, 900.00),
(2, 2, 1, 3500.00),
(2, 3, 2, 2800.00),
(2, 4, 50, 12.00),
(2, 9, 2, 417.55),
(3, 5, 30, 820.00),
(3, 6, 3, 2999.00),
(3, 7, 1, 285.00),
(3, 9, 6, 417.55),
(4, 1, 6, 900.00),
(4, 2, 1, 3500.00),
(4, 8, 1, 5975.00),
(4, 9, 1, 417.55),
(7, 5, 50, 820.00),
(7, 6, 5, 2999.00),
(7, 7, 3, 285.00),
(7, 9, 10, 417.55),
(8, 1, 20, 900.00),
(8, 2, 2, 3500.00),
(8, 3, 2, 2800.00),
(8, 9, 4, 417.55);

INSERT IGNORE INTO budget_parameter (name, description, metric, is_pre_budget, fixed_value, active, created_at) VALUES
('Tipo de Telhado', 'Define o material do telhado da instalação', 'un', TRUE, 0.00, TRUE, CURRENT_TIMESTAMP),
('Potência do Sistema', 'Potência total do sistema solar em kWp', 'kWp', TRUE, 0.00, TRUE, CURRENT_TIMESTAMP),
('Mão de Obra', 'Custo por hora de mão de obra da equipe', 'R$/h', FALSE, 150.00, TRUE, CURRENT_TIMESTAMP),
('Deslocamento', 'Custo de deslocamento da equipe até o local', 'km', FALSE, 2.50, TRUE, CURRENT_TIMESTAMP),
('Engenheiro', 'Valor cobrado pelo serviço de engenharia', 'R$', FALSE, 800.00, TRUE, CURRENT_TIMESTAMP),
('Tipo de Estrutura', 'Define o tipo de estrutura de fixação dos painéis', 'un', TRUE, 0.00, FALSE, CURRENT_TIMESTAMP);

INSERT IGNORE INTO parameter_option (type, addition_tax, fixed_cost, fk_budget_parameter) VALUES
('Cerâmico', 0.08, 500.00, 1),
('Metálico', 0.12, 800.00, 1),
('Fibrocimento', 0.05, 300.00, 1),
('até 5kWp', 0.00, 0.00, 2),
('5kWp a 10kWp', 0.10, 0.00, 2),
('acima de 10kWp', 0.20, 0.00, 2),
('Solo', 0.15, 1200.00, 6),
('Telhado Inclinado', 0.05, 400.00, 6),
('Telhado Plano', 0.08, 600.00, 6);

-- 4. Views de Análise
CREATE OR REPLACE VIEW view_analysis_project_finance AS
SELECT
    p.id_project,
    p.project_from AS acquisition_channel,
    p.created_at,
    p.status,
    COALESCE(b.total_cost, 0) AS total_revenue,
    COALESCE(b.material_cost, 0) + COALESCE(b.service_cost, 0) AS total_project_cost,
    COALESCE(b.total_cost, 0) - (COALESCE(b.material_cost, 0) + COALESCE(b.service_cost, 0)) AS profit_margin,
    CASE
        WHEN p.status IN ('NEW', 'PRE_BUDGET', 'NEGOTIATION_FAILED', 'RETRYING', 'CLIENT_AWAITING_CONTACT', 'AWAITING_RETRY', 'SCHEDULED_TECHNICAL_VISIT', 'TECHNICAL_VISIT_COMPLETED', 'AWAITING_MATERIALS') THEN 'Leads'
        WHEN p.status IN ('FINAL_BUDGET', 'SCHEDULED_INSTALLING_VISIT') THEN 'Contrato Assinado'
        WHEN p.status IN ('INSTALLED', 'COMPLETED') THEN 'Instalado/Finalizado'
        ELSE 'Outras Etapas'
    END AS funnel_stage
FROM
    project p
LEFT JOIN
    budget b ON b.fk_project = p.id_project
WHERE
    p.is_active = true;

CREATE OR REPLACE VIEW view_analysis_kpis AS
WITH ProjectCounts AS (
    SELECT
        COUNT(id_project) AS total_projects,
        SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_projects,
        SUM(CASE WHEN status = 'NEW' THEN 1 ELSE 0 END) AS new_projects,
        SUM(CASE WHEN status IN ('FINAL_BUDGET', 'INSTALLED', 'COMPLETED') THEN 1 ELSE 0 END) AS contracts_signed_projects
    FROM
        project
    WHERE
        is_active = true
),
FinancialSummary AS (
    SELECT
        acquisition_channel,
        SUM(total_project_cost) AS total_cost_by_channel,
        ROW_NUMBER() OVER (ORDER BY SUM(total_project_cost) DESC) as rn
    FROM
        view_analysis_project_finance
    GROUP BY
        acquisition_channel
)
SELECT
    (SELECT SUM(profit_margin) FROM view_analysis_project_finance) AS total_profit_margin,
    (SELECT acquisition_channel FROM FinancialSummary WHERE rn = 1) AS most_costly_channel,
    (PC.completed_projects * 100.0 / NULLIF(PC.total_projects, 0)) AS project_completion_rate,
    (PC.contracts_signed_projects * 100.0 / NULLIF(PC.new_projects, 0)) AS funnel_conversion_rate
FROM
    ProjectCounts PC;

CREATE OR REPLACE VIEW view_analysis_acquisition_channels AS
WITH ChannelCounts AS (
    SELECT
        acquisition_channel,
        COUNT(id_project) AS channel_project_count
    FROM
        view_analysis_project_finance
    GROUP BY
        acquisition_channel
),
TotalProjects AS (
    SELECT COUNT(id_project) AS total_projects FROM project WHERE is_active = true
)
SELECT
    CC.acquisition_channel AS nome,
    CC.channel_project_count,
    (CC.channel_project_count * 100.0 / NULLIF((SELECT total_projects FROM TotalProjects), 0)) AS percentual
FROM
    ChannelCounts CC
ORDER BY
    percentual DESC;

CREATE OR REPLACE VIEW view_analysis_profit_cost_monthly AS
SELECT
    YEAR(created_at) AS ano,
    MONTH(created_at) AS mes,
    SUM(total_project_cost) AS total_cost,
    SUM(profit_margin) AS total_profit
FROM
    view_analysis_project_finance
GROUP BY
    YEAR(created_at), MONTH(created_at)
ORDER BY
    ano ASC, mes ASC;

CREATE OR REPLACE VIEW view_analysis_projects_status_summary AS
SELECT
    CASE p.status
        WHEN 'COMPLETED' THEN 'Finalizado'
        WHEN 'NEGOTIATION_FAILED' THEN 'Finalizado'
        WHEN 'SCHEDULED_TECHNICAL_VISIT' THEN 'Agendado'
        WHEN 'SCHEDULED_INSTALLING_VISIT' THEN 'Agendado'
        WHEN 'NEW' THEN 'Novo'
        ELSE 'Em andamento'
    END AS status_group,
    COUNT(p.id_project) AS quantidade
FROM
    project p
WHERE
    p.is_active = true
GROUP BY
    status_group;

CREATE OR REPLACE VIEW view_analysis_sales_funnel_stages AS
SELECT
    CASE
        WHEN p.status IN ('NEW', 'PRE_BUDGET', 'NEGOTIATION_FAILED', 'RETRYING', 'CLIENT_AWAITING_CONTACT', 'AWAITING_RETRY', 'SCHEDULED_TECHNICAL_VISIT', 'TECHNICAL_VISIT_COMPLETED', 'AWAITING_MATERIALS') THEN 'Leads'
        WHEN p.status IN ('FINAL_BUDGET', 'SCHEDULED_INSTALLING_VISIT') THEN 'Contrato Assinado'
        WHEN p.status IN ('INSTALLED', 'COMPLETED') THEN 'Instalado/Finalizado'
        ELSE 'Outras Etapas'
    END AS etapa,
    COUNT(p.id_project) AS valor
FROM
    project p
WHERE
    p.is_active = true AND p.status IN (
        'NEW', 'PRE_BUDGET', 'NEGOTIATION_FAILED', 'RETRYING', 'CLIENT_AWAITING_CONTACT', 'AWAITING_RETRY', 'SCHEDULED_TECHNICAL_VISIT', 'TECHNICAL_VISIT_COMPLETED', 'AWAITING_MATERIALS',
        'FINAL_BUDGET', 'SCHEDULED_INSTALLING_VISIT',
        'INSTALLED', 'COMPLETED'
    )
GROUP BY
    etapa;