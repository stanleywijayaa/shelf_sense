"""
Hyperparameter Sensitivity Sweep — educational / diagnostic.

Optuna searches all hyperparameters SIMULTANEOUSLY, which finds the best
combination but hides what each individual knob actually does. This script
sweeps ONE parameter at a time (holding the rest at defaults) so the effect
of each is visible in isolation.

Usage (run from ml_backend/):
    python experiments/hyperparameter_sweep.py

Set VARIANT to "main" or "noexpiry".

WHAT TO LOOK FOR
    A parameter that MATTERS produces a curve — performance rises then
    falls, with a visible peak.
    A parameter that DOESN'T matter produces a flat line — every value
    scores the same within noise.

If most curves are flat, the model is not limited by its configuration.
That is a finding, not a failure: it means the ceiling is set by the
information available in the features.

NOTE: each row is a full train+evaluate cycle, so this takes a few minutes.
The bar is a visual aid only — read the numbers.
"""

import warnings

import pandas as pd
from sklearn.metrics import f1_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from xgboost import XGBClassifier

warnings.filterwarnings("ignore")

VARIANT = "noexpiry"  # "main" | "noexpiry"
RANDOM_STATE = 42

_CONFIG = {
    "main": {
        "data": "datasets/processed/cleaned_data.csv",
        "features": None,  # None = all columns except the target
    },
    "noexpiry": {
        "data": "datasets/processed/cleaned_data_noexpiry.csv",
        "features": [
            "category",
            "storage_type",
            "days_since_purchase",
            "spoilage_sensitivity_cat",
        ],
    },
}

TARGET_COLUMN = "risk_level"

# One entry per parameter: the values to try, and a plain-English note.
SWEEPS = {
    "max_depth": (
        [3, 4, 6, 8, 10, 12],
        "tree depth — higher = more complex interactions, more overfitting",
    ),
    "n_estimators": (
        [50, 100, 200, 300, 500],
        "number of trees — more = more capacity",
    ),
    "learning_rate": (
        [0.01, 0.05, 0.1, 0.3, 0.5],
        "step size per tree — lower = slower but more careful",
    ),
    "min_child_weight": (
        [1, 3, 5, 10],
        "minimum leaf weight — higher = refuses tiny leaves",
    ),
    "gamma": (
        [0.0, 0.5, 1.0, 3.0],
        "minimum gain to split — higher = fewer splits",
    ),
    "subsample": (
        [0.6, 0.8, 1.0],
        "fraction of ROWS per tree — below 1.0 adds randomness",
    ),
    "colsample_bytree": (
        [0.6, 0.8, 1.0],
        "fraction of COLUMNS per tree — below 1.0 adds randomness",
    ),
    "reg_lambda": (
        [0.0, 1.0, 3.0, 10.0],
        "L2 penalty — shrinks weights smoothly",
    ),
    "reg_alpha": (
        [0.0, 0.5, 2.0],
        "L1 penalty — pushes weights to exactly zero",
    ),
}


def load():
    cfg = _CONFIG[VARIANT]
    df = pd.read_csv(cfg["data"])
    X = df[cfg["features"]] if cfg["features"] else df.drop(columns=[TARGET_COLUMN])
    y = LabelEncoder().fit_transform(df[TARGET_COLUMN])
    return train_test_split(
        X, y, test_size=0.2, random_state=RANDOM_STATE, stratify=y
    )


def evaluate(X_tr, X_te, y_tr, y_te, **params):
    model = XGBClassifier(
        **params, random_state=RANDOM_STATE, eval_metric="mlogloss", n_jobs=-1
    )
    model.fit(X_tr, y_tr)
    return f1_score(y_te, model.predict(X_te), average="macro")


def main():
    X_tr, X_te, y_tr, y_te = load()
    print(f"Variant: {VARIANT}   |   features: {list(X_tr.columns)}\n")

    baseline = evaluate(X_tr, X_te, y_tr, y_te)
    print(f"Baseline (all defaults) macro-F1: {baseline:.4f}")
    print("Sweeping one parameter at a time; all others stay at defaults.\n")

    summary = []

    for param, (values, note) in SWEEPS.items():
        print("=" * 66)
        print(f"{param}  —  {note}")
        print("=" * 66)

        scores = []
        for v in values:
            f1 = evaluate(X_tr, X_te, y_tr, y_te, **{param: v})
            scores.append(f1)
            delta = f1 - baseline
            # Simple visual bar: each block = 0.002 above the worst so far.
            bar = "#" * max(0, int((f1 - min(scores)) / 0.002))
            print(f"  {param:18s} = {str(v):>6s}   F1={f1:.4f}  "
                  f"({delta:+.4f})  {bar}")

        spread = max(scores) - min(scores)
        best_v = values[scores.index(max(scores))]
        verdict = "MATTERS" if spread >= 0.005 else "flat — no real effect"
        print(f"  -> spread {spread:.4f} across values | best={best_v} | {verdict}\n")
        summary.append((param, spread, best_v, max(scores), verdict))

    # ── Summary ─────────────────────────────────────────────────────────
    print("=" * 66)
    print("SUMMARY — which knobs actually move the needle?")
    print("=" * 66)
    summary.sort(key=lambda r: -r[1])
    print(f"{'parameter':20s} {'spread':>8s} {'best':>8s} {'bestF1':>8s}  verdict")
    for param, spread, best_v, best_f1, verdict in summary:
        print(f"{param:20s} {spread:8.4f} {str(best_v):>8s} {best_f1:8.4f}  {verdict}")

    print(f"\nBaseline: {baseline:.4f}")
    print(
        "\nINTERPRETATION: a flat spread (< 0.005) means the parameter has no\n"
        "meaningful effect on this data. If most parameters are flat, the model\n"
        "is not configuration-limited — performance is bounded by the features.\n"
        "Compare with experiments/model_comparison.py, where adding IoT-derived\n"
        "features moves accuracy by ~49 points."
    )
    print(
        "\nCAUTION: the best value per row is chosen on the TEST set here, for\n"
        "illustration. Picking parameters this way would leak test information —\n"
        "which is exactly why tune_model.py uses cross-validation instead. Use\n"
        "this script to UNDERSTAND the knobs, not to select final values."
    )


if __name__ == "__main__":
    main()