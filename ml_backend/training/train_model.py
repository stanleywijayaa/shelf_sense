"""
Model Training — Phase 4, Step 4 (final model export).

Trains the winning model from the comparison (XGBoost — see evaluate_model.py)
on the processed data and exports it, plus the label encoder for the target,
so the FastAPI service can load and serve predictions.

Usage (run from ml_backend/):
    python training/train_model.py

Why XGBoost: it produced the best macro-F1 in evaluate_model.py. XGBoost
requires integer class labels, so the Low/Medium/High target is encoded
here and the encoder is saved alongside the model so the API can translate
integer predictions back into readable labels.
"""

import json
import os

import pandas as pd
import joblib
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report, confusion_matrix
from xgboost import XGBClassifier

PROCESSED_DATA_PATH = "datasets/processed/cleaned_data.csv"
MODEL_PATH = "model/spoilage_model.pkl"
TARGET_ENCODER_PATH = "model/target_encoder.pkl"
BEST_PARAMS_PATH = "model/best_params.json"

TARGET_COLUMN = "risk_level"


def main():
    df = pd.read_csv(PROCESSED_DATA_PATH)

    # ── 1. Split features and target ─────────────────────────────────────
    X = df.drop(columns=[TARGET_COLUMN])

    # XGBoost needs integer labels, so encode Low/Medium/High -> 0/1/2.
    # Save this encoder so the API can map predictions back to text.
    target_encoder = LabelEncoder()
    y = target_encoder.fit_transform(df[TARGET_COLUMN])

    # ── 2. Train / test split ────────────────────────────────────────────
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    # ── 3. Train XGBoost ─────────────────────────────────────────────────
    # Use tuned hyperparameters if tune_model.py has been run; otherwise
    # fall back to defaults so this script always works standalone.
    best_params = {}
    if os.path.exists(BEST_PARAMS_PATH):
        with open(BEST_PARAMS_PATH) as f:
            best_params = json.load(f)
        print(f"Using tuned hyperparameters from {BEST_PARAMS_PATH}:")
        for k, v in best_params.items():
            print(f"  {k:20s} {v}")
        print()
    else:
        print("No best_params.json found — training with default parameters.")
        print("(Run training/tune_model.py first to tune.)\n")

    model = XGBClassifier(
        **best_params,
        random_state=42,
        eval_metric="mlogloss",
    )
    model.fit(X_train, y_train)

    # ── 4. Evaluate (sanity check — should match evaluate_model.py) ──────
    y_pred = model.predict(X_test)
    class_names = target_encoder.classes_
    print("── CLASSIFICATION REPORT ──")
    print(classification_report(y_test, y_pred, target_names=class_names, zero_division=0))
    print("── CONFUSION MATRIX ──")
    print(f"(rows/cols ordered as: {list(class_names)})")
    print(confusion_matrix(y_test, y_pred))

    # ── 5. Export model + target encoder ─────────────────────────────────
    joblib.dump(model, MODEL_PATH)
    joblib.dump(target_encoder, TARGET_ENCODER_PATH)
    print(f"\nModel saved to {MODEL_PATH}")
    print(f"Target encoder saved to {TARGET_ENCODER_PATH}")
    print("\nFeature order used for training (the API must send these in this order):")
    print(list(X.columns))


if __name__ == "__main__":
    main()