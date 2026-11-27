-- Estrutura analítica do projeto.
-- O script de preparação cria a tabela vendas_brutas antes de executar este arquivo.

CREATE INDEX IF NOT EXISTS idx_vendas_brutas_invoice
    ON vendas_brutas (invoice_no);

CREATE INDEX IF NOT EXISTS idx_vendas_brutas_data
    ON vendas_brutas (invoice_date);

CREATE INDEX IF NOT EXISTS idx_vendas_brutas_produto
    ON vendas_brutas (stock_code);

CREATE INDEX IF NOT EXISTS idx_vendas_brutas_cliente
    ON vendas_brutas (customer_id);

CREATE INDEX IF NOT EXISTS idx_vendas_brutas_pais
    ON vendas_brutas (country);

-- Linhas de venda válidas para os indicadores de faturamento bruto.
-- Cancelamentos, quantidades negativas e preços não positivos são analisados separadamente.
DROP VIEW IF EXISTS vw_vendas_validas;

CREATE VIEW vw_vendas_validas AS
SELECT
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country,
    ROUND(quantity * unit_price, 2) AS gross_revenue,
    substr(invoice_date, 1, 7) AS sales_month,
    CAST(strftime('%Y', invoice_date) AS INTEGER) AS sales_year
FROM vendas_brutas
WHERE UPPER(TRIM(invoice_no)) NOT LIKE 'C%'
  AND quantity > 0
  AND unit_price > 0
  AND invoice_date IS NOT NULL;

-- Registros sinalizados como cancelamento ou ajuste/devolução.
-- Esta view é exploratória: não representa, por si só, o valor líquido das devoluções.
DROP VIEW IF EXISTS vw_cancelamentos_devolucoes;

CREATE VIEW vw_cancelamentos_devolucoes AS
SELECT
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country,
    ROUND(quantity * unit_price, 2) AS line_amount,
    CASE
        WHEN UPPER(TRIM(invoice_no)) LIKE 'C%' THEN 'cancelamento'
        WHEN quantity < 0 THEN 'quantidade negativa'
        ELSE 'outro registro não positivo'
    END AS record_type
FROM vendas_brutas
WHERE UPPER(TRIM(invoice_no)) LIKE 'C%'
   OR quantity < 0
   OR unit_price <= 0;
