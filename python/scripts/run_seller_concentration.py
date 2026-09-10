#!/usr/bin/env python3
"""Run seller concentration analysis."""

from python.scripts.config import ANALYSIS_OUTPUT_DIR, connect
from python.scripts.seller_concentration import (
    export_extracts,
    load_extracts,
    make_figures,
    rebuild_extracts,
    seller_spot_checks,
    write_validation_report,
)


def main():
    with connect() as conn:
        print("Rebuilding seller concentration analysis")
        rebuild_extracts(conn)

        frames = load_extracts(conn)
        outputs = export_extracts(frames)

        spot_checks = seller_spot_checks(conn)
        spot_path = ANALYSIS_OUTPUT_DIR / "seller_spot_checks.csv"
        spot_checks.to_csv(spot_path, index=False)

        outputs += [
            spot_path,
            write_validation_report(frames, spot_checks),
            *make_figures(frames),
        ]

        for path in outputs:
            print(f"  {path}")

    print("Seller concentration analysis complete.")


if __name__ == "__main__":
    main()
