#!/usr/bin/env python3

"""Load Olist CSV files into the PostgreSQL raw schema."""

import csv

from python.scripts.config import RAW_DIR, SOURCE_FILES, SQL_DIR, connect


def run_sql(cursor, filename):
    sql = (SQL_DIR / filename).read_text()
    cursor.execute(sql)


def count_csv_rows(path):
    """Count CSV rows excluding the header."""
    with path.open(encoding="utf-8-sig", newline="") as file:
        reader = csv.reader(file)
        next(reader)
        return sum(1 for _ in reader)


def load_table(cursor, table, filename):
    path = RAW_DIR / filename

    if not path.exists():
        raise FileNotFoundError(
            f"Missing {filename}. Run download_raw.py first."
        )

    with path.open(encoding="utf-8-sig", newline="") as file:
        cursor.copy_expert(
            f"""
            COPY raw.{table}
            FROM STDIN
            WITH (FORMAT CSV, HEADER, NULL '')
            """,
            file,
        )

    cursor.execute(f"SELECT COUNT(*) FROM raw.{table}")
    database_rows = cursor.fetchone()[0]

    file_rows = count_csv_rows(path)

    return file_rows, database_rows


def main():
    with connect() as conn:
        with conn.cursor() as cursor:
            run_sql(cursor, "raw/00_create_schema.sql")
            run_sql(cursor, "raw/01_create_raw_tables.sql")

            print(f"{'table':<30} {'csv':>10} {'database':>10}")

            for table, filename in SOURCE_FILES.items():
                file_rows, database_rows = load_table(
                    cursor,
                    table,
                    filename,
                )

                print(
                    f"{table:<30} "
                    f"{file_rows:>10} "
                    f"{database_rows:>10}"
                )

                if file_rows != database_rows:
                    raise ValueError(
                        f"Row count mismatch for {table}: "
                        f"CSV={file_rows}, database={database_rows}"
                    )

    print("\nRaw load complete. All row counts match.")


if __name__ == "__main__":
    main()