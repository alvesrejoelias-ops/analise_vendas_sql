# Análise de Vendas com SQL

Projeto de portfólio de Análise de Dados que utiliza SQL para investigar transações reais de uma loja virtual do Reino Unido. O objetivo é transformar registros de pedidos em indicadores comerciais que ajudem a entender faturamento, comportamento de compra, produtos e mercados.

> **Dados reais:** o projeto utiliza o conjunto **Online Retail**, disponibilizado pelo UCI Machine Learning Repository. Nenhuma venda ou métrica foi inventada. Os dados abrangem o período de 1º de dezembro de 2010 a 9 de dezembro de 2011.

## Objetivos de negócio

- Medir faturamento bruto, quantidade de pedidos e ticket médio.
- Identificar produtos com maior faturamento e maior volume vendido.
- Comparar o desempenho entre países.
- Acompanhar a evolução mensal das vendas.
- Identificar clientes com maior contribuição para o faturamento.
- Examinar registros de cancelamentos e devoluções separadamente.
- Verificar a qualidade e a consistência dos dados.

## Tecnologias

- **SQL (SQLite):** consultas, agregações, CTEs, subconsultas, funções de data e criação de views.
- **Python:** preparação e carga dos dados para o banco.
- **pandas:** leitura e tratamento inicial da planilha.
- **Git e GitHub:** versionamento e documentação.

## Estrutura do projeto

```text
analise_vendas_sql/
├── data/
│   ├── raw/                  # Arquivo original baixado (não versionado)
│   └── .gitkeep
├── scripts/
│   └── setup_database.py     # Baixa os dados e cria o banco SQLite
├── sql/
│   ├── 01_schema.sql         # Índices e views de análise
│   └── 02_analises.sql       # Consultas de negócio comentadas
├── .gitignore
├── requirements.txt
└── README.md
```

## Como executar

### 1. Pré-requisitos

Instale o Python 3.10 ou superior. Abra o terminal na pasta do projeto.

### 2. Instale as dependências

```bash
python -m pip install -r requirements.txt
```

### 3. Baixe os dados e crie o banco

```bash
python scripts/setup_database.py
```

O script baixa a planilha original do UCI, prepara os nomes e tipos das colunas, cria `data/online_retail.db` e aplica o arquivo de estrutura SQL. Na primeira execução, é necessário ter conexão com a internet.

Também é possível informar uma planilha já baixada:

```bash
python scripts/setup_database.py --input "data/raw/Online Retail.xlsx"
```

### 4. Execute as consultas

Abra `data/online_retail.db` em uma ferramenta compatível com SQLite, como **DB Browser for SQLite** ou uma extensão SQLite no VS Code.

Em seguida, abra e execute `sql/02_analises.sql`. As consultas estão numeradas e comentadas para facilitar o entendimento.

## Regras importantes da análise

- A view `vw_vendas_validas` considera linhas com quantidade e preço positivos e exclui faturas cujo identificador começa com `C`. Portanto, o indicador calculado é **faturamento bruto das linhas de venda válidas**, não lucro e nem faturamento líquido após devoluções.
- Cancelamentos e linhas com quantidade negativa ficam disponíveis na view `vw_cancelamentos_devolucoes` para investigação separada.
- O ticket médio é calculado como faturamento bruto dividido pela quantidade de faturas distintas consideradas.
- Algumas linhas não possuem identificador de cliente. Elas continuam disponíveis nas análises gerais de vendas, mas não entram nas métricas que exigem identificação do cliente.
- Os valores monetários estão na moeda original do conjunto de dados: **libra esterlina (GBP)**. Não há conversão cambial.

## Fonte e atribuição dos dados

Chen, D. (2015). *Online Retail* [Dataset]. UCI Machine Learning Repository. https://doi.org/10.24432/C5BW33

Página oficial e download: https://archive.ics.uci.edu/dataset/352/online%2Bretail

Licença do conjunto de dados: **Creative Commons Attribution 4.0 International (CC BY 4.0)**. Atribuição à fonte original mantida neste projeto.

## Próximas melhorias possíveis

- Criar um dashboard no Power BI conectado ao banco SQLite.
- Acrescentar uma análise RFM para segmentação de clientes.
- Documentar os principais resultados encontrados após executar as consultas.
- Criar testes automatizados para as regras de tratamento dos dados.

---

**Observação:** este repositório contém o código e as consultas. O arquivo original e o banco SQLite são gerados localmente pelo script e não são enviados ao GitHub.
