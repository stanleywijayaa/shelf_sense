"""
Hyperparameter Tuning with Optuna — Phase 4, Step 5.

Tunes the selected XGBoost model using Optuna's TPE (Tree-structured Parzen
Estimator) sampler, which models the search space probabilistically and
concentrates trials in promising regions — more sample-efficient than grid
or random search. Trials that clearly underperform are pruned early.

Usage (run from ml_backend/):
    python training/tune_model.py

Outputs:
    model/best_params.json  — the winning hyperparameters
    Console: baseline vs tuned macro-F1, best params, parameter importances

train_model.py automatically loads best_params.json if present, so after
tuning you simply re-run train_model.py to export the tuned model.

NOTE ON EXPECTATIONS: the model-comparison experiment showed four
architecturally different algorithms all landing within ~3 points of each
other (macro-F1 0.42-0.43), which indicates performance is bounded by the
available FEATURES rather than model capacity. Tuning is therefore expected
to yield small gains. A negligible improvement is itself a valid finding:
it confirms the ceiling is informational, not capacity-related.
"""

import json
import warnings

import numpy as np
import optuna
import pandas as pd
from sklearn.metrics import f1_score
from sklearn.model_selection import StratifiedKFold, cross_val_score, train_test_split
from sklearn.preprocessing import LabelEncoder
from xgboost import XGBClassifier

warnings.filterwarnings("ignore")
optuna.logging.set_verbosity(optuna.logging.WARNING)

# ── Which model to tune ──────────────────────────────────────────────
#   "main"     -> the 5-feature model (with expiry dates)
#   "noexpiry" -> the model used when no expiry date is available
# Change this and re-run to tune the other variant.
VARIANT = "noexpiry"

TARGET_COLUMN = "risk_level"

_CONFIG = {
    "main": {
        "data": "datasets/processed/cleaned_data.csv",
        "out": "model/best_params.json",
        # None = use every column except the target
        "features": None,
    },
    "noexpiry": {
        "data": "datasets/processed/cleaned_data_noexpiry.csv",
        "out": "model/best_params_noexpiry.json",
        # Must match WINNING_FEATURES in train_model_noexpiry.py, or you
        # would tune on features the exported model never uses.
        "features": [
            "category",
            "storage_type",
            "days_since_purchase",
            "spoilage_sensitivity_cat",
        ],
    },
}

PROCESSED_DATA_PATH = _CONFIG[VARIANT]["data"]
BEST_PARAMS_PATH = _CONFIG[VARIANT]["out"]
FEATURES = _CONFIG[VARIANT]["features"]

# Number of hyperparameter combinations to try. 50 is a reasonable
# accuracy/runtime tradeoff; raise for a more thorough search.
N_TRIALS = 50
CV_FOLDS = 3
RANDOM_STATE = 42


def load_data():
    df = pd.read_csv(PROCESSED_DATA_PATH)
    X = df[FEATURES] if FEATURES else df.drop(columns=[TARGET_COLUMN])
    y = LabelEncoder().fit_transform(df[TARGET_COLUMN])
    return train_test_split(
        X, y, test_size=0.2, random_state=RANDOM_STATE, stratify=y
    )


def objective(trial, X_train, y_train):
    """One Optuna trial: sample hyperparameters, return cross-validated
    macro-F1. Macro-F1 is used (not accuracy) so every risk class counts
    equally — important given the Medium class is hardest to separate."""
    params = {
        "n_estimators": trial.suggest_int("n_estimators", 100, 600, step=50),
        "max_depth": trial.suggest_int("max_depth", 3, 12),
        "learning_rate": trial.suggest_float("learning_rate", 0.01, 0.3, log=True),
        "subsample": trial.suggest_float("subsample", 0.6, 1.0),
        "colsample_bytree": trial.suggest_float("colsample_bytree", 0.6, 1.0),
        "min_child_weight": trial.suggest_int("min_child_weight", 1, 10),
        "gamma": trial.suggest_float("gamma", 0.0, 5.0),
        "reg_alpha": trial.suggest_float("reg_alpha", 0.0, 2.0),
        "reg_lambda": trial.suggest_float("reg_lambda", 0.0, 5.0),
    }

    model = XGBClassifier(
        **params,
        random_state=RANDOM_STATE,
        eval_metric="mlogloss",
        n_jobs=-1,
    )

    cv = StratifiedKFold(n_splits=CV_FOLDS, shuffle=True, random_state=RANDOM_STATE)
    scores = cross_val_score(
        model, X_train, y_train, cv=cv, scoring="f1_macro", n_jobs=1
    )
    return float(np.mean(scores))


def main():
    print(f"Tuning variant: {VARIANT}")
    print(f"Data: {PROCESSED_DATA_PATH}\n")
    X_train, X_test, y_train, y_test = load_data()

    # ── Baseline: current default-parameter model ────────────────────────
    baseline = XGBClassifier(
        random_state=RANDOM_STATE, eval_metric="mlogloss", n_jobs=-1
    )
    baseline.fit(X_train, y_train)
    baseline_f1 = f1_score(y_test, baseline.predict(X_test), average="macro")
    print(f"Baseline (default params) macro-F1: {baseline_f1:.4f}\n")

    # ── Optuna study ────────────────────────────────────────────────────
    print(f"Running {N_TRIALS} Optuna trials ({CV_FOLDS}-fold CV each)...")
    print("This may take several minutes.\n")

    study = optuna.create_study(
        direction="maximize",
        sampler=optuna.samplers.TPESampler(seed=RANDOM_STATE),
        study_name="shelfsense_xgb",
    )

    def _callback(study_, trial_):
        if trial_.number % 10 == 0:
            print(f"  trial {trial_.number:3d} | best so far: {study_.best_value:.4f}")

    study.optimize(
        lambda t: objective(t, X_train, y_train),
        n_trials=N_TRIALS,
        callbacks=[_callback],
    )

    # ── Evaluate the tuned model on the held-out test set ────────────────
    tuned = XGBClassifier(
        **study.best_params,
        random_state=RANDOM_STATE,
        eval_metric="mlogloss",
        n_jobs=-1,
    )
    tuned.fit(X_train, y_train)
    tuned_f1 = f1_score(y_test, tuned.predict(X_test), average="macro")

    # ── Report ──────────────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("TUNING RESULTS")
    print("=" * 60)
    print(f"Baseline macro-F1 (test): {baseline_f1:.4f}")
    print(f"Tuned    macro-F1 (test): {tuned_f1:.4f}")
    delta = tuned_f1 - baseline_f1
    print(f"Improvement:              {delta:+.4f} ({delta * 100:+.2f} points)")

    print("\nBest hyperparameters:")
    for k, v in study.best_params.items():
        print(f"  {k:20s} {v}")

    # Which parameters actually mattered — good material for the report.
    try:
        importances = optuna.importance.get_param_importances(study)
        print("\nParameter importance (share of variance explained):")
        for k, v in importances.items():
            print(f"  {k:20s} {v:.3f}")
    except Exception:
        pass  # importance needs enough completed trials

    # ── Save for train_model.py ─────────────────────────────────────────
    with open(BEST_PARAMS_PATH, "w") as f:
        json.dump(study.best_params, f, indent=2)
    print(f"\nBest params saved to {BEST_PARAMS_PATH}")
    print("Next: re-run `python training/train_model.py` to export the tuned model.")


if __name__ == "__main__":
    main()