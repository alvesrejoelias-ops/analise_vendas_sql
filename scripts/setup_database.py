"""Baixa o conjunto Online Retail e prepara um banco SQLite para análise com SQL.

Uso:
    python scripts/setup_database.py
    python scripts/setup_database.py --input "data/raw/Online Retail.xlsx"
    python scripts/setup_database.py --database "data/meu_banco.db"
"""

from __future__ import annotations

import argparse
import logging
import sqlite3
import sys
from pathlib import Path
from urllib.request import Request, urlopen

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_DATA_PATH = PROJECT_ROOT / "data" / "raw" / "Online Retail.xlsx"
DEFAULT_DATABASE_PATH = PROJECT_ROOT / "data" / "online_retail.db"
SCHEMA_PATH = PROJECT_ROOT / "sql" / "01_schema.sql"

# Arquivo oficial do conjunto Online Retail no UCI Machine Learning Repository.
DATASET_URL = (
    "https://archive.ics.uci.edu/ml/machine-learning-databases/"
    "00352/Online%20Retail.xlsx"
)

COLUMN_MAPPING = {
    "InvoiceNo": "invoice_no",
    "StockCode": "stock_code",
    "Description": "description",
    "Quantity": "quantity",
    "InvoiceDate": "invoice_date",
    "UnitPrice": "unit_price",
    "CustomerID": "customer_id",
    "Country": "country",
}

REQUIRED_COLUMNS = list(COLUMN_MAPPING)


def configure_logging() -> None:
    """Configura mensagens simples para acompanhar cada etapa."""
    logging.basicConfig(
        level=logging.INFO,
        format="%(levelname)s: %(message)s",
    )


def download_dataset(destination: Path) -> Path:
    """Baixa a planilha original do UCI, sem sobrescrever um arquivo existente."""
    destination.parent.mkdir(parents=True, exist_ok=True)

    if destination.exists() and destination.stat().st_size > 0:
        logging.info("Arquivo original já existe: %s", destination)
        return destination

    logging.info("Baixando o conjunto de dados oficial do UCI...")
    request = Request(
        DATASET_URL,
        headers={"User-Agent": "analise-vendas-sql-portfolio/1.0"},
    )

    try:
        with urlopen(request, timeout=90) as response:
            with destination.open("wb") as output_file:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    output_file.write(chunk)
    except Exception:
        # Remove um download incompleto para permitir uma nova tentativa.
        if destination.exists():
            destination.unlink()
        raise

    if not destination.exists() or destination.stat().st_size == 0:
        raise RuntimeError("O download terminou sem gerar um arquivo válido.")

    logging.info("Download concluído: %.1f MB", destination.stat().st_size / 1_000_000)
    return destination


def load_and_prepare_data(source: Path) -> pd.DataFrame:
    """Lê a planilha e padroniza colunas sem descartar linhas de transação."""
    logging.info("Lendo a planilha: %s", source)

    data = pd.read_excel(
        source,
        dtype={"InvoiceNo": "string", "StockCode": "string"},
        engine="openpyxl",
    )

    missing_columns = sorted(set(REQUIRED_COLUMNS) - set(data.columns))
    if missing_columns:
        raise ValueError(
            "A planilha não contém todas as colunas esperadas: "
            + ", ".join(missing_columns)
        )

    data = data[REQUIRED_COLUMNS].rename(columns=COLUMN_MAPPING)

    # Identificadores são tratados como texto para preservar códigos e zeros à esquerda.
    for column in ("invoice_no", "stock_code", "description", "country"):
        values = data[column].astype("string").str.strip()
        data[column] = values.astype(object).where(values.notna(), None)

    data["quantity"] = (
        pd.to_numeric(data["quantity"], errors="coerce")
        .fillna(0)
        .astype("int64")
    )
    data["unit_price"] = pd.to_numeric(
        data["unit_price"], errors="coerce"
    ).fillna(0.0)

    invoice_dates = pd.to_datetime(data["invoice_date"], errors="coerce")
    formatted_dates = invoice_dates.dt.strftime("%Y-%m-%d %H:%M:%S")
    data["invoice_date"] = formatted_dates.astype(object).where(
        formatted_dates.notna(), None
    )

    customer_ids = pd.to_numeric(data["customer_id"], errors="coerce")
    customer_ids = customer_ids.round().astype("Int64")
    data["customer_id"] = customer_ids.astype(object).where(
        customer_ids.notna(), None
    )

    logging.info("Linhas lidas: %s", f"{len(data):,}".replace(",", "."))
    return data


def create_database(data: pd.DataFrame, database_path: Path) -> None:
    """Grava os registros brutos e cria as views usadas nas consultas SQL."""
    database_path.parent.mkdir(parents=True, exist_ok=True)

    if not SCHEMA_PATH.exists():
        raise FileNotFoundError(f"Arquivo SQL não encontrado: {SCHEMA_PATH}")

    schema_sql = SCHEMA_PATH.read_text(encoding="utf-8")

    with sqlite3.connect(database_path) as connection:
        connection.execute("PRAGMA foreign_keys = ON;")

        logging.info("Carregando os registros na tabela vendas_brutas...")
        data.to_sql(
            "vendas_brutas",
            connection,
            if_exists="replace",
            index=False,
            chunksize=10_000,
        )

        logging.info("Criando índices e views analíticas...")
        connection.executescript(schema_sql)
        connection.execute("ANALYZE;")

        total_rows = connection.execute(
            "SELECT COUNT(*) FROM vendas_brutas"
        ).fetchone()[0]
        valid_sales = connection.execute(
            "SELECT COUNT(*) FROM vw_vendas_validas"
        ).fetchone()[0]
        total_invoices = connection.execute(
            "SELECT COUNT(DISTINCT invoice_no) FROM vw_vendas_validas"
        ).fetchone()[0]
        unique_products = connection.execute(
            "SELECT COUNT(DISTINCT stock_code) FROM vw_vendas_validas"
        ).fetchone()[0]

    logging.info("Banco criado: %s", database_path)
    logging.info("Registros brutos: %s", f"{total_rows:,}".replace(",", "."))
    logging.info("Linhas de venda válidas: %s", f"{valid_sales:,}".replace(",", "."))
    logging.info("Faturas de venda: %s", f"{total_invoices:,}".replace(",", "."))
    logging.info("Produtos distintos: %s", f"{unique_products:,}".replace(",", "."))


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepara o banco SQLite do projeto de análise de vendas."
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=None,
        help="Caminho para uma planilha Online Retail já baixada.",
    )
    parser.add_argument(
        "--database",
        type=Path,
        default=DEFAULT_DATABASE_PATH,
        help="Caminho do banco SQLite que será criado.",
    )
    return parser.parse_args()


def main() -> int:
    configure_logging()
    arguments = parse_arguments()

    try:
        source = arguments.input or download_dataset(RAW_DATA_PATH)
        if not source.exists():
            raise FileNotFoundError(f"Planilha não encontrada: {source}")

        prepared_data = load_and_prepare_data(source)
        create_database(prepared_data, arguments.database)
    except (OSError, ValueError, RuntimeError, sqlite3.Error) as error:
        logging.error("%s", error)
        return 1
    except Exception as error:  # Exibe uma mensagem útil para erros inesperados.
        logging.exception("Falha inesperada durante a preparação dos dados: %s", error)
        return 1

    logging.info("Preparação concluída. Abra o banco e execute sql/02_analises.sql.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
