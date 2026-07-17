"""
No-Expiry Model Preprocessing — Phase 4b.

Builds a training set for the SECOND model: the one used when the user has
no expiry date for an item (loose produce, bulk goods, homemade food).

Usage (run from ml_backend/):
    python training/preprocess_noexpiry.py

WHAT THE APP CAN SUPPLY WITHOUT AN EXPIRY DATE:
    - category        (dropdown)
    - storage_type    (dropdown)
    - purchase date   -> days_since_purchase

Everything else here is DERIVED FROM CATEGORY via lookup tables that ship
with the app, so train-time and serve-time features match exactly:

    spoilage_sensitivity      per-category perishability (fixed in dataset:
                              1 unique value per category). Provides an
                              ORDERED encoding of perishability, unlike the
                              arbitrary alphabetical label-encoding of
                              `category`.
    category_median_shelf_life  typical total shelf life for that category.
    est_remaining_days        median_shelf_life - days_since_purchase
                              -> approximates days_until_expiry.
    est_life_used_ratio       days_since_purchase / median_shelf_life
                              -> how much of the typical life is spent.

The last two matter because tree models can only make axis-aligned splits;
they cannot themselves express a subtraction or a ratio between features.

Outputs:
    datasets/processed/cleaned_data_noexpiry.csv
    model/category_stats.json   <- lookup tables the API needs at predict time
"""

import json

import joblib
import pandas as pd
from sklearn.preprocessing import LabelEncoder

RAW_DATA_PATH = "datasets/raw/perishable_goods_management.csv"
PROCESSED_PATH = "datasets/processed/cleaned_data_noexpiry.csv"
ENCODERS_PATH = "model/encoders_noexpiry.pkl"
CATEGORY_STATS_PATH = "model/category_stats.json"


def bucket_storage(temp: float) -> str:
    """Same bucketing as the main model, so both agree on storage_type."""
    if temp < 0:
        return "Freezer"
    elif temp <= 10:
        return "Fridge"
    else:
        return "Pantry"


def main():
    df = pd.read_csv(RAW_DATA_PATH)
    print(f"Loaded raw data: {df.shape}")

    # ── 1. Same cleaning as the main model ───────────────────────────────
    df = df[df["category"] != "Pharmaceuticals"].copy()
    df["storage_type"] = df["storage_temp"].apply(bucket_storage)
    print(f"After dropping Pharmaceuticals: {df.shape}")

    # ── 2. days_since_purchase, derived HONESTLY ─────────────────────────
    # elapsed life = total shelf life - life remaining.
    # This matches what the app computes (today - purchaseDate), unlike a
    # reference-date derivation, which is arbitrary and behaves as noise.
    df["days_since_purchase"] = (
        df["shelf_life_days"] - df["days_until_expiry"]
    ).clip(lower=0)

    # ── 3. Category lookup tables (these ship with the app) ──────────────
    sensitivity_map = (
        df.groupby("category")["spoilage_sensitivity"].median().round(4).to_dict()
    )
    median_shelf_map = (
        df.groupby("category")["shelf_life_days"].median().round(2).to_dict()
    )

    print("\nCategory lookups derived from the dataset:")
    print(f"{'category':16s} {'sensitivity':>12s} {'median shelf':>13s}")
    for cat in sorted(median_shelf_map):
        print(f"{cat:16s} {sensitivity_map[cat]:12.2f} {median_shelf_map[cat]:13.1f}")

    df["spoilage_sensitivity_cat"] = df["category"].map(sensitivity_map)
    df["category_median_shelf_life"] = df["category"].map(median_shelf_map)

    # ── 4. Engineered estimates of the missing expiry information ────────
    df["est_remaining_days"] = (
        df["category_median_shelf_life"] - df["days_since_purchase"]
    )
    df["est_life_used_ratio"] = (
        df["days_since_purchase"] / df["category_median_shelf_life"]
    ).replace([float("inf"), float("-inf")], 0).fillna(0)

    # ── 5. Target: identical binning to the main model ───────────────────
    df["risk_level"] = pd.qcut(
        df["spoilage_risk"], q=3, labels=["Low", "Medium", "High"], duplicates="drop"
    )

    feature_cols = [
        "category",
        "storage_type",
        "days_since_purchase",
        "spoilage_sensitivity_cat",
        "category_median_shelf_life",
        "est_remaining_days",
        "est_life_used_ratio",
        # Carried through ONLY to test the ceiling of a per-item shelf-life
        # lookup (e.g. USDA FoodKeeper). This is the dataset's true per-row
        # value — the best case any external reference could achieve. It is
        # NOT app-suppliable as-is; see evaluate_noexpiry.py set 7.
        "shelf_life_days",
    ]
    df = df[feature_cols + ["risk_level"]].copy()

    print("\nClass balance:")
    print(df["risk_level"].value_counts())

    # ── 6. Encode categoricals (separate encoders from the main model) ───
    encoders = {}
    for col in ["category", "storage_type"]:
        le = LabelEncoder()
        df[col] = le.fit_transform(df[col])
        encoders[col] = le

    # ── 7. Save ──────────────────────────────────────────────────────────
    df.to_csv(PROCESSED_PATH, index=False)
    joblib.dump(encoders, ENCODERS_PATH)
    with open(CATEGORY_STATS_PATH, "w") as f:
        json.dump(
            {
                "spoilage_sensitivity": sensitivity_map,
                "median_shelf_life": median_shelf_map,
            },
            f,
            indent=2,
        )

    print(f"\nProcessed data -> {PROCESSED_PATH}  {df.shape}")
    print(f"Encoders       -> {ENCODERS_PATH}")
    print(f"Category stats -> {CATEGORY_STATS_PATH}")
    print("\nNext: python training/evaluate_noexpiry.py")


if __name__ == "__main__":
    main()