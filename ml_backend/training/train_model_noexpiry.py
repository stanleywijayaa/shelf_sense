"""
No-Expiry Model Training — Phase 4b.

Trains and exports the model used when an item has no expiry date.
Run AFTER evaluate_noexpiry.py has identified the best feature set.

Usage (run from ml_backend/):
    python training/train_model_noexpiry.py

Outputs:
    model/spoilage_model_noexpiry.pkl
    model/target_encoder_noexpiry.pkl
    Console: the exact feature order the API must send.
"""

import json
import os

import joblib
import pandas as pd
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from xgboost import XGBClassifier

PROCESSED_PATH = "datasets/processed/cleaned_data_noexpiry.csv"
MODEL_PATH = "model/spoilage_model_noexpiry.pkl"
TARGET_ENCODER_PATH = "model/target_encoder_noexpiry.pkl"
BEST_PARAMS_PATH = "model/best_params_noexpiry.json"

TARGET_COLUMN = "risk_level"

# UPDATE THIS to whichever set evaluate_noexpiry.py reported as best.
WINNING_FEATURES = [
    "category",
    "storage_type",
    "days_since_purchase",
    "spoilage_sensitivity_cat",
]


def main():
    df = pd.read_csv(PROCESSED_PATH)

    X = df[WINNING_FEATURES]
    target_encoder = LabelEncoder()
    y = target_encoder.fit_transform(df[TARGET_COLUMN])

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    # Optional tuned params (tune_model.py can be pointed at this dataset too)
    best_params = {}
    if os.path.exists(BEST_PARAMS_PATH):
        with open(BEST_PARAMS_PATH) as f:
            best_params = json.load(f)
        print(f"Using tuned hyperparameters from {BEST_PARAMS_PATH}\n")

    model = XGBClassifier(
        **best_params, random_state=42, eval_metric="mlogloss", n_jobs=-1
    )
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    class_names = target_encoder.classes_
    print("── CLASSIFICATION REPORT (no-expiry model) ──")
    print(classification_report(y_test, y_pred, target_names=class_names,
                                zero_division=0))
    print("── CONFUSION MATRIX ──")
    print(f"(rows/cols ordered as: {list(class_names)})")
    print(confusion_matrix(y_test, y_pred))

    joblib.dump(model, MODEL_PATH)
    joblib.dump(target_encoder, TARGET_ENCODER_PATH)
    print(f"\nModel saved to {MODEL_PATH}")
    print(f"Target encoder saved to {TARGET_ENCODER_PATH}")
    print("\nFeature order the API must send, IN THIS ORDER:")
    print(list(X.columns))


if __name__ == "__main__":
    main()