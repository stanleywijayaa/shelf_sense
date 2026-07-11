# Exploratory Data Analysis
import pandas as pd
 
# Path to the raw data
RAW_DATA_PATH = ""

import pandas as pd

# TODO: update this to your actual dataset filename once approved
RAW_DATA_PATH = "datasets/raw/perishable_goods_management.csv"


def main():
    df = pd.read_csv(RAW_DATA_PATH)

    print("=" * 60)
    print("SHAPE:", df.shape)
    print("=" * 60)

    print("\n── COLUMNS & TYPES ──")
    print(df.dtypes)

    print("\n── FIRST 5 ROWS ──")
    print(df.head())

    print("\n── MISSING VALUES PER COLUMN ──")
    print(df.isnull().sum())

    print("\n── SUMMARY STATISTICS (numeric) ──")
    print(df.describe())

    # 1. What does the risk target actually look like?
    print("spoilage_risk stats:")
    print(df['spoilage_risk'].describe())
    print()

    # 2. What categories exist, and do they match household food?
    print("categories:")
    print(df['category'].value_counts())
    print()

    # 3. The storage temp range (to see if we can map it to Fridge/Freezer/Pantry)
    print("storage_temp stats:")
    print(df['storage_temp'].describe())
    print()

    # 4. quality_grade values (might be useful or might be another target)
    print("quality_grade:")
    print(df['quality_grade'].value_counts())


if __name__ == "__main__":
    main()