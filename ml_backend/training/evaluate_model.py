"""
Model Comparison — Phase 4, Step 3 (run before finalizing train_model.py).
 
Trains several classifiers on the SAME processed data and prints a side-by-side
metrics table so you can pick the best performer based on evidence rather than
preference. Whichever model wins here is the one you set train_model.py to
export as the final model.
 
Usage:
    python training/evaluate_model.py
 
Models compared:
    - Decision Tree
    - Random Forest
    - XGBoost
    - LightGBM
 
Metrics reported per model: Accuracy, Precision, Recall, F1 (all macro-averaged
so every risk class counts equally, which matters if classes are imbalanced).
"""
 
import warnings
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.tree import DecisionTreeClassifier
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    precision_score,
    recall_score,
    f1_score,
    classification_report,
    confusion_matrix,
)
 
warnings.filterwarnings("ignore")
 
PROCESSED_DATA_PATH = "datasets/processed/cleaned_data.csv"
 
# TODO: set this to your dataset's actual target column name after preprocessing.
TARGET_COLUMN = "risk_level"
 
# Shared label encoder so the target is stored as integers (0/1/2).
# Some models (notably XGBoost) reject string class labels, so we encode
# the target here and keep `label_encoder` around to translate the
# integer predictions back into "Low"/"Medium"/"High" for the reports.
label_encoder = LabelEncoder()
 
 
def load_data():
    df = pd.read_csv(PROCESSED_DATA_PATH)
    X = df.drop(columns=[TARGET_COLUMN])
    y = label_encoder.fit_transform(df[TARGET_COLUMN])  # strings -> ints
    return train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
 
 
def build_models():
    """Returns a dict of {model_name: estimator}. Optional libraries are
    added only if importable, so the script still runs without them."""
    models = {
        "Decision Tree": DecisionTreeClassifier(random_state=42),
        "Random Forest": RandomForestClassifier(n_estimators=100, random_state=42),
    }
 
    # XGBoost — add if available
    try:
        from xgboost import XGBClassifier
        models["XGBoost"] = XGBClassifier(
            random_state=42,
            eval_metric="mlogloss",
            use_label_encoder=False,
        )
    except ImportError:
        print("(XGBoost not installed — skipping. `pip install xgboost` to include it.)")
 
    # LightGBM — add if available
    try:
        from lightgbm import LGBMClassifier
        models["LightGBM"] = LGBMClassifier(random_state=42, verbose=-1)
    except ImportError:
        print("(LightGBM not installed — skipping. `pip install lightgbm` to include it.)")
 
    return models
 
 
def evaluate():
    X_train, X_test, y_train, y_test = load_data()
    models = build_models()
 
    results = []
    best_model_name = None
    best_f1 = -1.0
 
    for name, model in models.items():
        model.fit(X_train, y_train)
        y_pred = model.predict(X_test)
 
        acc = accuracy_score(y_test, y_pred)
        prec = precision_score(y_test, y_pred, average="macro", zero_division=0)
        rec = recall_score(y_test, y_pred, average="macro", zero_division=0)
        f1 = f1_score(y_test, y_pred, average="macro", zero_division=0)
 
        results.append({
            "Model": name,
            "Accuracy": round(acc, 4),
            "Precision": round(prec, 4),
            "Recall": round(rec, 4),
            "F1 (macro)": round(f1, 4),
        })
 
        # Track the best model by macro-F1 (better than accuracy when
        # classes are imbalanced, which spoilage-risk data often is).
        if f1 > best_f1:
            best_f1 = f1
            best_model_name = name
 
    # ── Comparison table ─────────────────────────────────────────────────
    results_df = pd.DataFrame(results).sort_values("F1 (macro)", ascending=False)
    print("\n" + "=" * 60)
    print("MODEL COMPARISON")
    print("=" * 60)
    print(results_df.to_string(index=False))
 
    print("\n" + "=" * 60)
    print(f"BEST MODEL (by macro-F1): {best_model_name}")
    print("=" * 60)
 
    # ── Detailed report for the winner ───────────────────────────────────
    best_model = models[best_model_name]
    y_pred_best = best_model.predict(X_test)
    # Translate encoded ints back to readable class names for the report
    class_names = label_encoder.classes_
    print("\n── Classification report (best model) ──")
    print(classification_report(
        y_test, y_pred_best,
        target_names=class_names,
        zero_division=0,
    ))
    print("── Confusion matrix (best model) ──")
    print(f"(rows/cols ordered as: {list(class_names)})")
    print(confusion_matrix(y_test, y_pred_best))
 
    print(f"\nNext step: set train_model.py to train and export '{best_model_name}'.")
 
 
if __name__ == "__main__":
    evaluate()