-- Arquivo: oficina_logical_model.sql
-- Esquema lógico para Oficina Mecânica -> criação de schema, tabelas, dados de teste e queries.

-- ==================================================
-- 1) Criação do schema
-- ==================================================
DROP SCHEMA IF EXISTS oficina;
CREATE SCHEMA oficina;
USE oficina;

-- ==================================================
-- 2) Tabelas (modelo relacional)
-- Observações: PKs, FKs e CHECKs aplicados.
-- ==================================================

-- Clientes (PF ou PJ)
CREATE TABLE clients (
  client_id INT AUTO_INCREMENT PRIMARY KEY,
  account_type ENUM('PF','PJ') NOT NULL,
  name VARCHAR(200) NOT NULL,
  email VARCHAR(150) UNIQUE,
  phone VARCHAR(40),
  cpf VARCHAR(14) DEFAULT NULL,
  cnpj VARCHAR(20) DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CHECK (
    (account_type='PF' AND cpf IS NOT NULL AND cnpj IS NULL)
    OR
    (account_type='PJ' AND cnpj IS NOT NULL AND cpf IS NULL)
  )
);

-- Veículos (cada cliente pode ter vários veículos)
CREATE TABLE vehicles (
  vehicle_id INT AUTO_INCREMENT PRIMARY KEY,
  client_id INT NOT NULL,
  plate VARCHAR(20) NOT NULL,
  vin VARCHAR(50),
  brand VARCHAR(100),
  model VARCHAR(100),
  year YEAR,
  color VARCHAR(50),
  FOREIGN KEY (client_id) REFERENCES clients(client_id) ON DELETE CASCADE
);

-- Mecânicos
CREATE TABLE mechanics (
  mechanic_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  hire_date DATE,
  hourly_rate DECIMAL(10,2) DEFAULT 0 CHECK (hourly_rate >= 0)
);

-- Peças / Fornecedores
CREATE TABLE suppliers (
  supplier_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  contact VARCHAR(150)
);

CREATE TABLE parts (
  part_id INT AUTO_INCREMENT PRIMARY KEY,
  supplier_id INT NOT NULL,
  sku VARCHAR(80) UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  cost_price DECIMAL(10,2) DEFAULT 0 CHECK (cost_price >= 0),
  sale_price DECIMAL(10,2) DEFAULT 0 CHECK (sale_price >= 0),
  FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);

-- Estoque
CREATE TABLE inventory (
  inventory_id INT AUTO_INCREMENT PRIMARY KEY,
  part_id INT NOT NULL,
  quantity INT NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  location VARCHAR(100),
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (part_id) REFERENCES parts(part_id) ON DELETE CASCADE
);

-- Ordens de Serviço (Work Orders)
CREATE TABLE work_orders (
  wo_id INT AUTO_INCREMENT PRIMARY KEY,
  client_id INT NOT NULL,
  vehicle_id INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  scheduled_date TIMESTAMP NULL,
  status ENUM('OPEN','IN_PROGRESS','WAITING_PARTS','COMPLETED','CANCELLED') DEFAULT 'OPEN',
  estimated_hours DECIMAL(5,2) DEFAULT 0 CHECK (estimated_hours >= 0),
  total DECIMAL(12,2) DEFAULT 0 CHECK (total >= 0),
  notes TEXT,
  FOREIGN KEY (client_id) REFERENCES clients(client_id),
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id)
);

-- Itens da Ordem (serviços executados ou peças trocadas)
CREATE TABLE wo_items (
  wo_item_id INT AUTO_INCREMENT PRIMARY KEY,
  wo_id INT NOT NULL,
  item_type ENUM('SERVICE','PART') NOT NULL,
  description VARCHAR(300) NOT NULL,
  part_id INT NULL,
  mechanic_id INT NULL,
  quantity INT DEFAULT 1 CHECK (quantity > 0),
  unit_price DECIMAL(12,2) DEFAULT 0 CHECK (unit_price >= 0),
  hours DECIMAL(6,2) DEFAULT 0 CHECK (hours >= 0),
  FOREIGN KEY (wo_id) REFERENCES work_orders(wo_id) ON DELETE CASCADE,
  FOREIGN KEY (part_id) REFERENCES parts(part_id),
  FOREIGN KEY (mechanic_id) REFERENCES mechanics(mechanic_id)
);

-- Agendamentos (opcional, se desejar controlar atendimentos)
CREATE TABLE appointments (
  appointment_id INT AUTO_INCREMENT PRIMARY KEY,
  client_id INT NOT NULL,
  vehicle_id INT NOT NULL,
  appointment_date TIMESTAMP NOT NULL,
  reason VARCHAR(255),
  status ENUM('SCHEDULED','ATTENDED','NO_SHOW','CANCELLED') DEFAULT 'SCHEDULED',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (client_id) REFERENCES clients(client_id),
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id)
);

-- Pagamentos / Faturas
CREATE TABLE invoices (
  invoice_id INT AUTO_INCREMENT PRIMARY KEY,
  wo_id INT NOT NULL UNIQUE,
  issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  due_date DATE DEFAULT NULL,
  total_amount DECIMAL(12,2) NOT NULL CHECK (total_amount >= 0),
  paid BOOLEAN DEFAULT FALSE,
  paid_at TIMESTAMP NULL,
  FOREIGN KEY (wo_id) REFERENCES work_orders(wo_id) ON DELETE CASCADE
);

CREATE TABLE payments (
  payment_id INT AUTO_INCREMENT PRIMARY KEY,
  invoice_id INT NOT NULL,
  amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
  method ENUM('CASH','CARD','PIX','TRANSFER') DEFAULT 'CASH',
  paid_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id) ON DELETE CASCADE
);

-- Auditoria simples (logs de status)
CREATE TABLE wo_status_log (
  log_id INT AUTO_INCREMENT PRIMARY KEY,
  wo_id INT NOT NULL,
  old_status VARCHAR(50),
  new_status VARCHAR(50),
  changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (wo_id) REFERENCES work_orders(wo_id) ON DELETE CASCADE
);

-- Índices para desempenho
CREATE INDEX idx_wo_client ON work_orders(client_id);
CREATE INDEX idx_wo_status ON work_orders(status);
CREATE INDEX idx_parts_supplier ON parts(supplier_id);

-- ==================================================
-- 3) Dados de teste (persistência)
-- Observação: pequenos conjuntos para testes
-- ==================================================

-- Suppliers
INSERT INTO suppliers (name, contact) VALUES
('AutoPeças Brasil','contato@autopecas.com'),
('Distribuidora XYZ','vendas@xyz.com');

-- Parts
INSERT INTO parts (supplier_id,sku,name,description,cost_price,sale_price) VALUES
(1,'AP-001','Filtro de Óleo','Filtro para motor 1.8',10.50,25.00),
(1,'AP-002','Pastilha de Freio','Pastilha dianteira',15.00,60.00),
(2,'XYZ-010','Bateria 60Ah','Bateria automotiva 60Ah',200.00,350.00);

-- Inventory
INSERT INTO inventory (part_id,quantity,location) VALUES
(1,30,'ST01'),
(2,10,'ST01'),
(3,3,'ST02');

-- Mechanics
INSERT INTO mechanics (name,hire_date,hourly_rate) VALUES
('Carlos Silva','2015-03-10',45.00),
('Ana Pereira','2018-07-22',55.00),
('João Oliveira','2020-01-15',40.00);

-- Clients (PF e PJ)
INSERT INTO clients (account_type,name,email,phone,cpf,cnpj) VALUES
('PF','Marcos Almeida','marcos@mail.com','+55 11 97777-0001','123.456.789-00',NULL),
('PF','Luciana Costa','luciana@mail.com','+55 21 97777-0002','987.654.321-00',NULL),
('PJ','Oficina ABC Ltda','comercial@abc.com','+55 31 97777-0003',NULL,'12.345.678/0001-99');

-- Vehicles
INSERT INTO vehicles (client_id,plate,vin,brand,model,year,color) VALUES
(1,'ABC1D23','9BWZZZ377VT004251','Volkswagen','Gol',2012,'Prata'),
(1,'XYZ2F56','3C4FY58B29T123456','Fiat','Uno',2010,'Vermelho'),
(2,'CAR3G78','1HGCM82633A004352','Honda','Civic',2016,'Preto');

-- Work Orders
INSERT INTO work_orders (client_id,vehicle_id,scheduled_date,status,estimated_hours,notes) VALUES
(1,1,'2025-11-20 09:00:00','OPEN',2.5,'Troca de óleo e filtro'),
(1,2,'2025-11-21 13:00:00','OPEN',3.0,'Revisão de freios'),
(2,3,'2025-11-18 08:30:00','IN_PROGRESS',5.0,'Troca de bateria e inspeção completa');

-- Wo Items (services and parts)
INSERT INTO wo_items (wo_id,item_type,description,part_id,mechanic_id,quantity,unit_price,hours) VALUES
(1,'SERVICE','Mão-de-obra troca de óleo',NULL,1,1,80.00,1.5),
(1,'PART','Filtro de óleo',1,NULL,1,25.00,0),
(2,'SERVICE','Substituição de pastilhas',NULL,2,1,120.00,2.0),
(2,'PART','Pastilha de freio',2,NULL,2,60.00,0),
(3,'PART','Bateria 60Ah',3,NULL,1,350.00,0),
(3,'SERVICE','Instalação bateria',NULL,3,1,50.00,0.5);

-- Atualiza total do work_orders (soma dos itens)
UPDATE work_orders w
SET w.total = (
  SELECT COALESCE(SUM((wi.unit_price * wi.quantity) + (wi.hours * COALESCE(m.hourly_rate,0))),0)
  FROM wo_items wi
  LEFT JOIN mechanics m ON wi.mechanic_id = m.mechanic_id
  WHERE wi.wo_id = w.wo_id
);

-- Invoices (baseado no total calculado)
INSERT INTO invoices (wo_id,total_amount,due_date,paid) 
SELECT wo_id, total, DATE_ADD(CURDATE(), INTERVAL 7 DAY), FALSE FROM work_orders;

-- Payments (apenas exemplo de pagamento parcial)
INSERT INTO payments (invoice_id,amount,method,paid_at) VALUES
(1,105.00,'CARD','2025-11-20 11:00:00');

-- Logs de status
INSERT INTO wo_status_log (wo_id,old_status,new_status) VALUES
(3,'OPEN','IN_PROGRESS');

-- ==================================================
-- 4) Queries demonstrativas (cobrem SELECT, WHERE, derived attrs, ORDER BY, HAVING, JOINs)
-- Perguntas que as queries respondem estão comentadas
-- ==================================================

-- Q1: Quantas ordens de serviço cada cliente teve? (GROUP BY, ORDER BY)
SELECT c.client_id, c.name, COUNT(w.wo_id) AS total_wo
FROM clients c
LEFT JOIN work_orders w ON c.client_id = w.client_id
GROUP BY c.client_id, c.name
ORDER BY total_wo DESC;

-- Q2: Quais ordens estão com estoque baixo (alguma peça necessária com qty < 5)? (JOIN + WHERE)
-- R: lista de WO que usam peças atualmente com estoque baixo
SELECT DISTINCT w.wo_id, w.status, c.name AS client_name, v.plate
FROM work_orders w
JOIN wo_items wi ON wi.wo_id = w.wo_id AND wi.item_type='PART' AND wi.part_id IS NOT NULL
JOIN inventory i ON i.part_id = wi.part_id
JOIN clients c ON w.client_id = c.client_id
JOIN vehicles v ON v.vehicle_id = w.vehicle_id
WHERE i.quantity < 5
ORDER BY w.wo_id;

-- Q3: Valor derivado: custo estimado de cada ordem (soma parts + hours*hourly_rate)
SELECT w.wo_id, c.name AS client_name,
       SUM((wi.unit_price * wi.quantity) + (wi.hours * COALESCE(m.hourly_rate,0))) AS estimated_cost
FROM work_orders w
JOIN wo_items wi ON wi.wo_id = w.wo_id
LEFT JOIN mechanics m ON wi.mechanic_id = m.mechanic_id
JOIN clients c ON w.client_id = c.client_id
GROUP BY w.wo_id, c.name
ORDER BY estimated_cost DESC;

-- Q4: Quais mecânicos fizeram mais horas no período (HAVING, derived attr)?
SELECT m.mechanic_id, m.name, SUM(wi.hours) AS total_hours
FROM mechanics m
JOIN wo_items wi ON wi.mechanic_id = m.mechanic_id
WHERE wi.item_type='SERVICE'
GROUP BY m.mechanic_id, m.name
HAVING SUM(wi.hours) > 0
ORDER BY total_hours DESC;

-- Q5: Peças mais vendidas (soma de quantities em wo_items)
SELECT p.part_id, p.name, s.name AS supplier, SUM(wi.quantity) AS total_used
FROM parts p
JOIN wo_items wi ON wi.part_id = p.part_id
LEFT JOIN suppliers s ON p.supplier_id = s.supplier_id
WHERE wi.item_type='PART'
GROUP BY p.part_id, p.name, s.name
ORDER BY total_used DESC;

-- Q6: Clientes com gasto total acima de R$200 (JOIN invoices/payments, HAVING)
SELECT c.client_id, c.name, SUM(inv.total_amount) AS total_invoiced,
       SUM(COALESCE(pay.amount,0)) AS total_paid
FROM clients c
JOIN work_orders w ON w.client_id = c.client_id
JOIN invoices inv ON inv.wo_id = w.wo_id
LEFT JOIN payments pay ON pay.invoice_id = inv.invoice_id
GROUP BY c.client_id, c.name
HAVING SUM(inv.total_amount) > 200
ORDER BY total_invoiced DESC;

-- Q7: Detalhe de uma ordem (JOINs e derived line subtotal)
SELECT w.wo_id, c.name AS client_name, v.plate, wi.wo_item_id, wi.item_type, wi.description,
       wi.quantity, wi.unit_price, wi.hours,
       ((wi.unit_price * wi.quantity) + (wi.hours * COALESCE(m.hourly_rate,0))) AS line_total
FROM work_orders w
JOIN clients c ON w.client_id = c.client_id
JOIN vehicles v ON w.vehicle_id = v.vehicle_id
JOIN wo_items wi ON wi.wo_id = w.wo_id
LEFT JOIN mechanics m ON wi.mechanic_id = m.mechanic_id
WHERE w.wo_id = 1
ORDER BY line_total DESC;

-- Q8: Verificar peças com estoque abaixo do limite e quantas ordens dependem delas (JOIN + GROUP + HAVING)
SELECT p.part_id, p.name, i.quantity AS stock_qty, COUNT(DISTINCT wi.wo_id) AS orders_waiting
FROM parts p
JOIN inventory i ON i.part_id = p.part_id
LEFT JOIN wo_items wi ON wi.part_id = p.part_id AND wi.item_type='PART'
GROUP BY p.part_id, p.name, i.quantity
HAVING i.quantity < 5
ORDER BY orders_waiting DESC;

-- Q9: Receita por mecânico (soma faturada por serviços realizados por ele)
SELECT m.mechanic_id, m.name, SUM((wi.hours * m.hourly_rate) + (wi.unit_price * wi.quantity)) AS revenue
FROM mechanics m
JOIN wo_items wi ON wi.mechanic_id = m.mechanic_id
GROUP BY m.mechanic_id, m.name
ORDER BY revenue DESC;

-- Q10: Top 3 clientes por número de ordens e gasto médio (usa derived avg)
SELECT c.client_id, c.name, COUNT(w.wo_id) AS orders_count, AVG(w.total) AS avg_order_value
FROM clients c
LEFT JOIN work_orders w ON w.client_id = c.client_id
GROUP BY c.client_id, c.name
ORDER BY orders_count DESC, avg_order_value DESC
LIMIT 3;

-- ==================================================
-- README resumido (copie para README.md ao subir no GitHub)
-- ==================================================
/*
# Projeto: Oficina Mecânica - Modelo Lógico e Script SQL

## Descrição
Este projeto modela o banco de dados lógico para uma oficina mecânica: clientes (PF/PJ), veículos, mecânicos, peças e fornecedores, inventário, ordens de serviço, itens de ordem (serviços e peças), agendamentos, faturas e pagamentos. O script cria todas as tabelas com PK/FK, constraints e dados de teste.

## Como usar
1. No MySQL 8+: execute o arquivo `oficina_logical_model.sql` em um banco de testes. Recomenda-se rodar em um schema limpo.
2. O script insere dados de exemplo e executa algumas consultas demonstrativas.

## Principais queries incluídas
- Total de ordens por cliente
- Ordens afetadas por peças com estoque baixo
- Cálculo derivado do custo estimado de cada ordem
- Relatórios por mecânico e peças mais usadas

## Observações
- As constraints `CHECK` garantem consistência PF/PJ e valores não-negativos.
- Em produção, dados sensíveis (CPF/CNPJ) devem ser armazenados conforme legislação e segurança apropriada.

*/
