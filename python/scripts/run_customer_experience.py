#!/usr/bin/env python3
"""Run customer experience analysis."""

from python.scripts.config import ANALYSIS_OUTPUT_DIR, connect
from python.scripts.customer_experience import (
    delay_sensitivity,
    export_extracts,
    load_extracts,
    make_figures,
    order_spot_checks,
    rebuild_extracts,
    write_validation_report,
)


def main():
    with connect() as conn:
        rebuild_extracts(conn)
        frames = load_extracts(conn)
        outputs = export_extracts(frames)

        sensitivity = delay_sensitivity(conn)
        spot_checks = order_spot_checks(conn)

        for filename, frame in (
            ("cx_delay_sensitivity.csv", sensitivity),
            ("cx_spot_checks.csv", spot_checks),
        ):
            path = ANALYSIS_OUTPUT_DIR / filename
            frame.to_csv(path, index=False)
            outputs.append(path)

        outputs.append(write_validation_report(frames, sensitivity, spot_checks))
        outputs.extend(make_figures(frames))

    print("Customer experience analysis complete.")
    for path in outputs:
        print(f"  {path}")


if __name__ == "__main__":
    main()
