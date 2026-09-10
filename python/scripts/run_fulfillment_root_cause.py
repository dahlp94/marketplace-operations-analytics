#!/usr/bin/env python3
"""Build fulfillment root-cause extracts, figures, and validation outputs."""

from python.scripts.config import ANALYSIS_OUTPUT_DIR, connect
from python.scripts.fulfillment_root_cause import (
    export_extracts,
    extreme_delay_orders,
    load_extracts,
    make_figures,
    monthly_outlier_sensitivity,
    order_component_spot_checks,
    outlier_sensitivity,
    quarterly_aggregation,
    rebuild_extracts,
    seller_descriptive_snapshot,
    weekly_around_spikes,
    write_validation_report,
)


def main():
    with connect() as conn:
        print("Rebuilding fulfillment extracts")
        rebuild_extracts(conn)

        frames = load_extracts(conn)
        export_extracts(frames)

        print("Running sensitivity and spot checks")
        sensitivity = outlier_sensitivity(conn)
        monthly_sensitivity = monthly_outlier_sensitivity(conn)
        quarterly = quarterly_aggregation(conn)
        weekly = weekly_around_spikes(conn)
        spot_checks = order_component_spot_checks(conn)
        extremes = extreme_delay_orders(conn)

        outputs = {
            "seller_fulfillment_snapshot.csv": seller_descriptive_snapshot(conn),
            "fulfillment_outlier_sensitivity.csv": sensitivity,
            "fulfillment_monthly_outlier_sensitivity.csv": monthly_sensitivity,
            "fulfillment_quarterly.csv": quarterly,
            "fulfillment_weekly_spikes.csv": weekly,
            "order_component_spot_checks.csv": spot_checks,
            "extreme_delivery_delays.csv": extremes,
        }
        for filename, frame in outputs.items():
            frame.to_csv(ANALYSIS_OUTPUT_DIR / filename, index=False)

        report = write_validation_report(
            frames,
            sensitivity,
            monthly_sensitivity,
            quarterly,
            weekly,
            spot_checks,
            extremes,
        )
        print(f"Validation report: {report}")

        print("Writing figures")
        for path in make_figures(frames):
            print(f"  {path}")

    print("\nFulfillment root-cause analysis complete.")


if __name__ == "__main__":
    main()
