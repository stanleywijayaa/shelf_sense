"""
Data Preprocessing — Phase 4, Step 2.
 
Tailored to the Perishable Goods Management dataset. Reads the raw CSV,
reduces it to ONLY the features the ShelfSense app can actually supply,
converts the continuous `spoilage_risk` score into a Low/Medium/High
class label, encodes categoricals, and writes a clean CSV for training.
 
Usage (run from ml_backend/):
    python training/preprocess.py
 
Design decisions (see notes inline):
  - Target: `spoilage_risk` (float) is binned into 3 classes via QUANTILES
    (pd.qcut) so Low/Medium/High are balanced. The raw scores are tightly
    clustered (mostly 0.16-0.23), so fixed thresholds would dump nearly
    everything into one bucket — quantile binning avoids that.
  - Pharmaceuticals rows are dropped: this is a household FOOD app, so
    vaccines/medicines don't belong.
  - `storage_temp` is bucketed into Freezer/Fridge/Pantry to match what
    the app collects (storage TYPE, not a temperature reading).
  - Only app-suppliable features are kept. Retail/supply-chain columns
    (revenue, profit, demand, supplier, etc.) are dropped.
"""
 
import pandas as pd
import joblib
from sklearn.preprocessing import LabelEncoder
 
RAW_DATA_PATH = "datasets/raw/perishable_goods_management.csv" # Path to the raw dataset
PROCESSED_DATA_PATH = "datasets/processed/cleaned_data.csv" # Path to save cleaned data
ENCODERS_PATH = "model/encoders.pkl" # Path to save label encoders
 
 
def bucket_storage(temp: float) -> str:
    """
    Map a storage temperature to the app's three storage types.
    Thresholds chosen to reflect typical storage:
      - Freezer: below 0C
      - Fridge:  0C to 10C
      - Pantry:  above 10C (room temperature)
    """
    if temp < 0:
        return "Freezer"
    elif temp <= 10:
        return "Fridge"
    else:
        return "Pantry"
 
 
def main():
    df = pd.read_csv(RAW_DATA_PATH)
    print(f"Loaded raw data: {df.shape}")
 
    # Drop non-food category (household FOOD app)
    df = df[df["category"] != "Pharmaceuticals"].copy()
    print(f"After dropping Pharmaceuticals: {df.shape}")
 
    # Derive storage_type from storage_temp
    # The app collects storage TYPE, not temperature — so we translate the
    # dataset's numeric temp into the same three buckets the app uses.
    df["storage_type"] = df["storage_temp"].apply(bucket_storage)
 
    # Select ONLY features the app can supply
    # category            -> user selects it
    # storage_type        -> user selects it (derived above)
    # shelf_life_days     -> expiry - purchase
    # days_remaining_at_purchase -> derivable
    # days_until_expiry   -> derivable
    feature_cols = [
        "category",
        "storage_type",
        "shelf_life_days",
        "days_remaining_at_purchase",
        "days_until_expiry",
    ]
    target_raw = "spoilage_risk"
 
    df = df[feature_cols + [target_raw]].copy()
 
    # ── 4. Convert continuous risk score -> Low/Medium/High ──────────────
    # qcut splits by quantiles so the three classes are balanced. This is
    # essential here because the raw scores are tightly clustered.
    df["risk_level"] = pd.qcut(
        df[target_raw],
        q=3,
        labels=["Low", "Medium", "High"],
    )
    df = df.drop(columns=[target_raw])
 
    print("\nClass balance after binning:")
    print(df["risk_level"].value_counts())
 
    # ── 5. Encode categorical features ───────────────────────────────────
    # Save encoders so the API applies the SAME mapping at prediction time.
    encoders = {}
    for col in ["category", "storage_type"]:
        le = LabelEncoder()
        df[col] = le.fit_transform(df[col])
        encoders[col] = le
 
    # ── 6. Save outputs ──────────────────────────────────────────────────
    df.to_csv(PROCESSED_DATA_PATH, index=False)
    joblib.dump(encoders, ENCODERS_PATH)
 
    print(f"\nProcessed data saved to {PROCESSED_DATA_PATH}  {df.shape}")
    print(f"Encoders saved to {ENCODERS_PATH}")
    print("\nColumns in processed data:")
    print(list(df.columns))
 
 
if __name__ == "__main__":
    main()