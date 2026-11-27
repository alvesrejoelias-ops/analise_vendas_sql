-- ANÁLISE DE VENDAS | Online Retail (UCI)
-- Banco: SQLite
-- Antes de executar este arquivo, rode:
--   1) python scripts/setup_database.py
--   2) sql/01_schema.sql (o carregador já executa este arquivo automaticamente)
--
-- Regra central: vw_vendas_validas representa faturamento bruto de linhas positivas.
-- Cancelamentos e registros negativos são avaliados separadamente ao final.

-- ============================================================
-- 1. INDICADORES GERAIS (KPIs)
-- Pergunta: qual é a dimensão geral das vendas válidas?
-- ============================================================

SELECT
    COUNT(DISTINCT invoice_no) AS total_pedidos,
    COUNT(DISTINCT customer_id) AS clientes_identificados,
    COUNT(DISTINCT stock_code) AS produtos_vendidos,
    SUM(quantity) AS unidades_vendidas,
    ROUND(SUM(gross_revenue), 2) AS faturamento_bruto_gbp,
    ROUND(
        SUM(gross_revenue) / NULLIF(COUNT(DISTINCT invoice_no), 0),
        2
    ) AS ticket_medio_gbp
FROM vw_vendas_validas;


-- ============================================================
-- 2. EVOLUÇÃO MENSAL
-- Pergunta: como o faturamento e o volume de pedidos evoluíram?
-- ============================================================

SELECT
    sales_month AS mes,
    COUNT(DISTINCT invoice_no) AS total_pedidos,
    SUM(quantity) AS unidades_vendidas,
    ROUND(SUM(gross_revenue), 2) AS faturamento_bruto_gbp
FROM vw_vendas_validas
GROUP BY sales_month
ORDER BY sales_month;


-- ============================================================
-- 3. VARIAÇÃO MENSAL DO FATURAMENTO
-- Usa LAG para comparar cada mês com o mês anterior.
-- ============================================================

WITH faturamento_mensal AS (
    SELECT
        sales_month AS mes,
        SUM(gross_revenue) AS faturamento
    FROM vw_vendas_validas
    GROUP BY sales_month
),
comparacao AS (
    SELECT
        mes,
        faturamento,
        LAG(faturamento) OVER (ORDER BY mes) AS faturamento_mes_anterior
    FROM faturamento_mensal
)
SELECT
    mes,
    ROUND(faturamento, 2) AS faturamento_gbp,
    ROUND(faturamento_mes_anterior, 2) AS mes_anterior_gbp,
    ROUND(
        100.0 * (faturamento - faturamento_mes_anterior)
        / NULLIF(faturamento_mes_anterior, 0),
        2
    ) AS variacao_percentual
FROM comparacao
ORDER BY mes;


-- ============================================================
-- 4. PRODUTOS COM MAIOR FATURAMENTO
-- Pergunta: quais produtos mais contribuíram para a receita?
-- ============================================================

SELECT
    stock_code,
    MAX(description) AS produto,
    SUM(quantity) AS unidades_vendidas,
    COUNT(DISTINCT invoice_no) AS pedidos,
    ROUND(SUM(gross_revenue), 2) AS faturamento_bruto_gbp
FROM vw_vendas_validas
GROUP BY stock_code
ORDER BY faturamento_bruto_gbp DESC
LIMIT 10;


-- ============================================================
-- 5. PRODUTOS COM MAIOR VOLUME
-- Um produto muito vendido não necessariamente é o que mais fatura.
-- ============================================================

SELECT
    stock_code,
    MAX(description) AS produto,
    SUM(quantity) AS unidades_vendidas,
    ROUND(SUM(gross_revenue), 2) AS faturamento_bruto_gbp
FROM vw_vendas_validas
GROUP BY stock_code
ORDER BY unidades_vendidas DESC
LIMIT 10;


-- ============================================================
-- 6. DESEMPENHO POR PAÍS
-- Pergunta: quais mercados apresentam maior faturamento?
-- ============================================================

SELECT
    country AS pais,
    COUNT(DISTINCT invoice_no) AS total_pedidos,
    COUNT(DISTINCT customer_id) AS clientes_identificados,
    SUM(quantity) AS unidades_vendidas,
    ROUND(SUM(gross_revenue), 2) AS faturamento_bruto_gbp
FROM vw_vendas_validas
GROUP BY country
ORDER BY faturamento_bruto_gbp DESC;


-- ============================================================
-- 7. CLIENTES COM MAIOR FATURAMENTO
-- Linhas sem CustomerID não entram nesta análise de clientes.
-- ============================================================

SELECT
    customer_id,
    COUNT(DISTINCT country) AS quantidade_paises,
    COUNT(DISTINCT invoice_no) AS total_pedidos,
    SUM(quantity) AS unidades_compradas,
    ROUND(SUM(gross_revenue), 2) AS faturamento_associado_gbp
FROM vw_vendas_validas
WHERE customer_id IS NOT NULL
GROUP BY customer_id
ORDER BY faturamento_associado_gbp DESC
LIMIT 10;


-- ============================================================
-- 8. FREQUÊNCIA DE COMPRA
-- Pergunta: quantos clientes identificados fizeram mais de um pedido?
-- ============================================================

WITH pedidos_por_cliente AS (
    SELECT
        customer_id,
        COUNT(DISTINCT invoice_no) AS quantidade_pedidos
    FROM vw_vendas_validas
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
)
SELECT
    COUNT(*) AS clientes_identificados,
    SUM(CASE WHEN quantidade_pedidos > 1 THEN 1 ELSE 0 END)
        AS clientes_com_compra_recorrente,
    ROUND(
        100.0 * SUM(CASE WHEN quantidade_pedidos > 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS percentual_clientes_recorrentes
FROM pedidos_por_cliente;


-- ============================================================
-- 9. TICKET MÉDIO POR PAÍS
-- Útil para comparar o valor médio por fatura em cada mercado.
-- ============================================================

WITH faturamento_por_pedido AS (
    SELECT
        country,
        invoice_no,
        SUM(gross_revenue) AS valor_pedido
    FROM vw_vendas_validas
    GROUP BY country, invoice_no
)
SELECT
    country AS pais,
    COUNT(*) AS total_pedidos,
    ROUND(AVG(valor_pedido), 2) AS ticket_medio_gbp,
    ROUND(SUM(valor_pedido), 2) AS faturamento_bruto_gbp
FROM faturamento_por_pedido
GROUP BY country
ORDER BY ticket_medio_gbp DESC;


-- ============================================================
-- 10. PRODUTO MAIS VENDIDO EM CADA PAÍS
-- Usa ROW_NUMBER e CTE para ranquear produtos dentro de cada país.
-- ============================================================

WITH vendas_produto_pais AS (
    SELECT
        country,
        stock_code,
        MAX(description) AS produto,
        SUM(quantity) AS unidades_vendidas,
        SUM(gross_revenue) AS faturamento
    FROM vw_vendas_validas
    GROUP BY country, stock_code
),
ranking AS (
    SELECT
        country,
        stock_code,
        produto,
        unidades_vendidas,
        faturamento,
        ROW_NUMBER() OVER (
            PARTITION BY country
            ORDER BY unidades_vendidas DESC, faturamento DESC
        ) AS posicao
    FROM vendas_produto_pais
)
SELECT
    country AS pais,
    stock_code,
    produto,
    unidades_vendidas,
    ROUND(faturamento, 2) AS faturamento_bruto_gbp
FROM ranking
WHERE posicao = 1
ORDER BY unidades_vendidas DESC;


-- ============================================================
-- 11. HORÁRIOS COM MAIOR NÚMERO DE PEDIDOS
-- Considera a hora registrada na data da fatura.
-- ============================================================

SELECT
    strftime('%H', invoice_date) AS hora,
    COUNT(DISTINCT invoice_no) AS total_pedidos,
    ROUND(SUM(gross_revenue), 2) AS faturamento_bruto_gbp
FROM vw_vendas_validas
GROUP BY hora
ORDER BY total_pedidos DESC;


-- ============================================================
-- 12. CANCELAMENTOS E REGISTROS NÃO POSITIVOS
-- A consulta conta registros sinalizados; não calcula o valor efetivamente
-- reembolsado. A soma abaixo é o valor aritmético das linhas da fonte.
-- ============================================================

SELECT
    record_type AS tipo_registro,
    COUNT(*) AS quantidade_linhas,
    COUNT(DISTINCT invoice_no) AS faturas_distintas,
    ROUND(SUM(line_amount), 2) AS soma_valores_das_linhas_gbp
FROM vw_cancelamentos_devolucoes
GROUP BY record_type
ORDER BY quantidade_linhas DESC;


-- ============================================================
-- 13. VERIFICAÇÕES DE QUALIDADE DOS DADOS
-- Pergunta: quantos registros brutos apresentam campos relevantes ausentes?
-- ============================================================

SELECT
    COUNT(*) AS total_registros,
    SUM(CASE WHEN invoice_no IS NULL OR TRIM(invoice_no) = '' THEN 1 ELSE 0 END)
        AS faturas_ausentes,
    SUM(CASE WHEN stock_code IS NULL OR TRIM(stock_code) = '' THEN 1 ELSE 0 END)
        AS codigos_produto_ausentes,
    SUM(CASE WHEN invoice_date IS NULL THEN 1 ELSE 0 END)
        AS datas_ausentes,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END)
        AS clientes_nao_identificados,
    SUM(CASE WHEN quantity <= 0 THEN 1 ELSE 0 END)
        AS quantidades_nao_positivas,
    SUM(CASE WHEN unit_price <= 0 THEN 1 ELSE 0 END)
        AS precos_nao_positivos
FROM vendas_brutas;
