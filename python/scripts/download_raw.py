#!/usr/bin/env python3
"""Download the Olist dataset from Kaggle."""

import shutil
from pathlib import Path

import kagglehub

from python.scripts.config import RAW_DIR, SOURCE_FILES


DATASET = "olistbr/brazilian-ecommerce"


def main():
    RAW_DIR.mkdir(parents=True, exist_ok=True)

    dataset_path = Path(kagglehub.dataset_download(DATASET))

    for filename in SOURCE_FILES.values():
        source = dataset_path / filename
        destination = RAW_DIR / filename

        shutil.copy(source, destination)
        print(f"Copied: {filename}")

    print(f"\nRaw data ready in: {RAW_DIR}")


if __name__ == "__main__":
    main()