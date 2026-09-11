#!/usr/bin/env python3
"""Run statistical validation."""

from python.scripts.config import connect
from python.scripts.statistical_validation import (
    bootstrap_outputs,
    comparison_table,
    diagnostics,
    export_tables,
    fit_models,
    load_extracts,
    make_figures,
    missingness_table,
    model_population,
    rate_interval_table,
    rebuild_extracts,
    sensitivity_table,
    write_validation_report,
)


def main():
    with connect() as conn:
        rebuild_extracts(conn)
        raw = load_extracts(conn)

        model_orders = model_population(raw["orders"])
        model, result = fit_models(model_orders)

        tables = {
            "intervals": rate_interval_table(raw["counts"]),
            "comparisons": comparison_table(raw["counts"]),
            "bootstrap": bootstrap_outputs(model_orders, raw["orders"]),
            "model": model,
            "diagnostics": diagnostics(model_orders, result),
            "sensitivity": sensitivity_table(model_orders, raw["orders"]),
            "missingness": missingness_table(raw["orders"]),
        }

        outputs = export_tables(tables)
        outputs.append(write_validation_report(tables))
        outputs.extend(make_figures(tables))

    print("Statistical validation complete.")
    for path in outputs:
        print(f"  {path}")


if __name__ == "__main__":
    main()
