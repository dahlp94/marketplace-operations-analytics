# Marketplace Operations & Customer Experience Intelligence

A data foundation for an Olist marketplace operations study.

The eventual business question is which operational problems drive deteriorating customer experience, and where Operations should intervene first. That question is **not** answered here.

This repository currently covers the **raw-source audit**: inventory, grain, keys, cardinalities, and join-safety. No KPI layer, analytical facts/dimensions, or treatment rules have been applied.

## Why the source audit exists

Olist is a relational extract. Orders have multiple items and multiple payments. Joining those children through `order_id` multiplies money. Customer identifiers do not mean what a CRM-style `customer_id` usually means. Geolocation is not a zip-code dimension.

Until those properties are measured, delivery and CX metrics are not trustworthy.

## Repository layout

```
data/                  # raw CSV instructions; extracts are gitignored
sql/raw/               # raw schema and table DDL
sql/quality/           # reusable source-profiling SQL
python/scripts/        # download, load, source-audit runner
docs/                  # inventory, relationship audit, source ER diagram
tests/                 # executable grain/relationship checks against raw
scripts/               # local PostgreSQL bootstrap
```

## Database

PostgreSQL is the analytical engine. The default local setup is a **project-local cluster** on `127.0.0.1:55432` so it does not require the password of a system-wide Postgres install.

```bash
./scripts/setup_local_postgres.sh
```

Defaults (override with environment variables or a `.env` copied from `.env.example`):

- host `127.0.0.1`
- port `55432`
- user `marketplace`
- database `marketplace_ops`
- schema `raw`

`raw` stores source extracts without primary keys, foreign keys, filters, or repairs.

## Reproduce the source audit

Python 3.11+ with `psycopg2`. PostgreSQL 14+ (developed on 18.3). Add `psql` to `PATH` (this machine uses `/Library/PostgreSQL/18/bin`).

```bash
python -m pip install -r requirements.txt
./scripts/setup_local_postgres.sh
python -m python.scripts.download_raw
python -m python.scripts.load_raw
python -m python.scripts.run_source_audit
pytest -q
```

`load_raw.py` compares logical CSV row counts to loaded table counts and aborts on mismatch.

Audit SQL can also be rerun directly:

```bash
export PGHOST=127.0.0.1 PGPORT=55432 PGUSER=marketplace PGDATABASE=marketplace_ops
psql -f sql/raw/02_row_counts.sql
psql -f sql/quality/01_key_uniqueness.sql
psql -f sql/quality/03_fk_coverage.sql
psql -f sql/quality/04_cardinality.sql
psql -f sql/quality/05_customer_identity.sql
psql -f sql/quality/06_join_fanout.sql
psql -f sql/quality/07_sample_order_lineage.sql
```

## Documentation

| Document | Contents |
|---|---|
| [docs/source_inventory.md](docs/source_inventory.md) | What each table is, grain, keys, row counts, limitations |
| [docs/relationship_audit.md](docs/relationship_audit.md) | Cardinalities, FK coverage, customer identity, join fan-out |
| [docs/er_diagram.md](docs/er_diagram.md) | Source-level relationship diagram |

## What this audit does not do

It does not drop duplicates, repair timestamps, define KPIs, rank sellers, or build facts and dimensions. Suspicious records are identified only. Treatment rules, the analytical model, and the KPI layer are separate later work.
