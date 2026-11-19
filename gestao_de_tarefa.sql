CREATE TABLE colaboradores (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    senha VARCHAR(100) NOT NULL,
    status BOOLEAN NOT NULL DEFAULT TRUE 
);

CREATE TABLE categorias (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE tarefas (
    id SERIAL PRIMARY KEY,
    titulo VARCHAR(150) NOT NULL,
    descricao VARCHAR(255),
    data_criacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    prazo_entrega DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Pendente',
    id_colaboradores INT NOT NULL,
    id_categorias INT NOT NULL,
    
    CONSTRAINT chk_status_tarefa CHECK (status IN ('Pendente', 'Em Andamento', 'Concluída', 'Cancelada')),
    CONSTRAINT fk_tarefa_colaborador FOREIGN KEY (id_colaboradores) REFERENCES colaboradores(id),
    CONSTRAINT fk_tarefa_categoria FOREIGN KEY (id_categorias) REFERENCES categorias(id)
);

CREATE TABLE historico_tarefas (
    id SERIAL PRIMARY KEY,
    id_tarefas INT NOT NULL,
    acao VARCHAR(100) NOT NULL,
    data_registro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacao VARCHAR(255),
    
    CONSTRAINT fk_historico_tarefa FOREIGN KEY (id_tarefas) REFERENCES tarefas(id) ON DELETE CASCADE
);


CREATE OR REPLACE FUNCTION fn_validar_tarefa()
RETURNS TRIGGER AS $$
DECLARE
    v_ativo BOOLEAN;
BEGIN
    SELECT status INTO v_ativo 
    FROM colaboradores 
    WHERE id = NEW.id_colaboradores;

    IF v_ativo IS FALSE OR v_ativo IS NULL THEN
        RAISE EXCEPTION 'Operação bloqueada: Não é possível atribuir tarefas a um colaborador inativo ou inexistente.';
    END IF;

    NEW.data_criacao := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_tarefa
BEFORE INSERT ON tarefas
FOR EACH ROW
EXECUTE FUNCTION fn_validar_tarefa();


CREATE OR REPLACE FUNCTION fn_log_tarefa()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO historico_tarefas (id_tarefas, acao, data_registro, observacao)
    VALUES (
        NEW.id, 
        'Tarefa Criada', 
        CURRENT_TIMESTAMP, 
        'Tarefa "' || NEW.titulo || '" criada com status inicial: ' || NEW.status
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_tarefa
AFTER INSERT ON tarefas
FOR EACH ROW
EXECUTE FUNCTION fn_log_tarefa();


INSERT INTO colaboradores (nome, email, senha, status) VALUES
('Ana Silva', 'ana.silva@empresa.com', 'senha123', TRUE),
('Carlos Souza', 'carlos.souza@empresa.com', 'carlos2026', TRUE),
('Mariana Costa', 'mariana.costa@empresa.com', 'mari@99', TRUE),
('Roberto Inativo', 'roberto@empresa.com', '123456', FALSE);

INSERT INTO categorias (nome) VALUES
('Desenvolvimento'),
('Infraestrutura'),
('Financeiro');


INSERT INTO tarefas (titulo, descricao, prazo_entrega, status, id_colaboradores, id_categorias) VALUES
('Criar API de Login', 'Desenvolver endpoints de autenticação', CURRENT_DATE + INTERVAL '2 days', 'Em Andamento', 1, 1),
('Atualizar Servidor Linux', 'Aplicar patches de segurança no banco', CURRENT_DATE + INTERVAL '5 days', 'Pendente', 2, 2),
('Fechamento Mensal', 'Conferir notas fiscais de consultoria', CURRENT_DATE + INTERVAL '1 day', 'Pendente', 3, 3);

CREATE OR REPLACE VIEW vw_painel_principal AS
SELECT 
    c.nome AS colaborador,
    t.titulo AS tarefa,
    cat.nome AS categoria,
    t.prazo_entrega,
    t.status
FROM tarefas t
INNER JOIN colaboradores c ON t.id_colaboradores = c.id
INNER JOIN categorias cat ON t.id_categorias = cat.id;

CREATE OR REPLACE VIEW vw_cronograma_prazos AS
SELECT 
    t.titulo AS tarefa,
    t.status,
    (t.prazo_entrega - CURRENT_DATE) AS dias_restantes,
    c.nome AS responsavel
FROM tarefas t
INNER JOIN colaboradores c ON t.id_colaboradores = c.id
ORDER BY t.prazo_entrega ASC;


CREATE OR REPLACE FUNCTION fn_buscar_colaboradores(p_termo VARCHAR)
RETURNS TABLE (
    id INT,
    nome VARCHAR,
    email VARCHAR,
    status BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.nome, c.email, c.status
    FROM colaboradores c
    WHERE c.nome ILIKE '%' || p_termo || '%'
       OR c.email ILIKE '%' || p_termo || '%';
END;
$$ LANGUAGE plpgsql;

SELECT * FROM vw_painel_principal;

SELECT * FROM vw_cronograma_prazos;

SELECT * FROM fn_buscar_colaboradores('silva');
SELECT * FROM fn_buscar_colaboradores('@consultoria');

SELECT * FROM historico_tarefas;