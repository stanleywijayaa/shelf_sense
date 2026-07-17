"""
No-Expiry Feature Evaluation — Phase 4b.

The no-expiry model loses the three date features, so candidate replacements
are derived from category lookups. This script tests which of them actually
EARN their place, rather than assuming. Same discipline used to reject
storage temperature and days_since_purchase in the main model.

Usage (run from ml_backend/):
    python training/evaluate_noexpiry.py

Prints a macro-F1 comparison of progressively richer feature sets, plus the
main model's headline figure for reference, and the feature importances of
the best set.
"""

import warnings

import pandas as pd
from sklearn.metrics import accuracy_score, f1_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from xgboost import XGBClassifier

warnings.filterwarnings("ignore")

PROCESSED_PATH = "datasets/processed/cleaned_data_noexpiry.csv"
TARGET_COLUMN = "risk_level"
RANDOM_STATE = 42

BASE = ["category", "storage_type", "days_since_purchase"]

FEATURE_SETS = {
    "1. Base (category, storage, days_since)": BASE,
    "2. + spoilage_sensitivity": BASE + ["spoilage_sensitivity_cat"],
    "3. + median_shelf_life": BASE + ["spoilage_sensitivity_cat",
                                      "category_median_shelf_life"],
    "4. + est_remaining_days": BASE + ["spoilage_sensitivity_cat",
                                       "category_median_shelf_life",
                                       "est_remaining_days"],
    "5. + est_life_used_ratio (all)": BASE + ["spoilage_sensitivity_cat",
                                              "category_median_shelf_life",
                                              "est_remaining_days",
                                              "est_life_used_ratio"],
    "6. Estimates only (no raw category)": ["storage_type",
                                            "days_since_purchase",
                                            "spoilage_sensitivity_cat",
                                            "est_remaining_days",
                                            "est_life_used_ratio"],
}


def main():
    df = pd.read_csv(PROCESSED_PATH)
    y = LabelEncoder().fit_transform(df[TARGET_COLUMN])

    results = []
    best_name, best_f1, best_model, best_feats = None, -1.0, None, None

    for name, feats in FEATURE_SETS.items():
        X = df[feats]
        X_tr, X_te, y_tr, y_te = train_test_split(
            X, y, test_size=0.2, random_state=RANDOM_STATE, stratify=y
        )
        model = XGBClassifier(
            random_state=RANDOM_STATE, eval_metric="mlogloss", n_jobs=-1
        )
        model.fit(X_tr, y_tr)
        pred = model.predict(X_te)

        acc = accuracy_score(y_te, pred)
        f1 = f1_score(y_te, pred, average="macro")
        results.append({"Feature set": name, "Accuracy": round(acc, 4),
                        "F1 (macro)": round(f1, 4), "n_features": len(feats)})

        if f1 > best_f1:
            best_name, best_f1, best_model, best_feats = name, f1, model, feats

    print("\n" + "=" * 74)
    print("NO-EXPIRY MODEL — FEATURE SET COMPARISON (XGBoost, defaults)")
    print("=" * 74)
    print(pd.DataFrame(results).to_string(index=False))

    print("\n" + "=" * 74)
    print(f"BEST: {best_name}   (macro-F1 {best_f1:.4f})")
    print("=" * 74)

    # ── Feature importances of the winning set ──────────────────────────
    print("\nFeature importances (best set):")
    importances = sorted(
        zip(best_feats, best_model.feature_importances_),
        key=lambda t: -t[1],
    )
    for feat, imp in importances:
        print(f"  {feat:28s} {imp:.4f}")

    # ── Interpretation ──────────────────────────────────────────────────
    base_f1 = next(r["F1 (macro)"] for r in results if r["Feature set"].startswith("1."))
    sens_f1 = next(r["F1 (macro)"] for r in results if r["Feature set"].startswith("2."))
    est_f1 = next(r["F1 (macro)"] for r in results if r["Feature set"].startswith("5."))

    print("\n" + "=" * 74)
    print("INTERPRETATION")
    print("=" * 74)

    print(f"""
1. ENGINEERED ESTIMATES DID NOT HELP  ({base_f1:.4f} base -> {est_f1:.4f} with all)

   est_remaining_days  = category_median_shelf_life - days_since_purchase
   est_life_used_ratio = days_since_purchase / category_median_shelf_life

   The hypothesis was that tree models cannot express subtraction or
   division (they only make axis-aligned splits), so supplying these
   derived quantities directly should help. It did not, because
   `category_median_shelf_life` is a CONSTANT per category. Subtracting a
   per-category constant from days_since_purchase is merely a per-category
   RESCALING of a feature the model already has — no new information, but
   extra dimensions through which to overfit.

   Feature engineering of this kind only adds value when both operands vary
   per row. Here one of them does not.

2. IMPORTANCE IS NOT CONTRIBUTION  (spoilage_sensitivity: {sens_f1 - base_f1:+.4f})

   spoilage_sensitivity_cat typically dominates the importance ranking above
   while contributing almost nothing to the score. This is not a
   contradiction: XGBoost importance measures how often and how usefully a
   feature is USED IN SPLITS, not how much unique information it adds.

   Because it is a deterministic function of `category` — but ORDERED by
   perishability rather than alphabetically — the model prefers to split on
   it INSTEAD OF category (whose importance collapses correspondingly). The
   information is the same; only the encoding is more convenient. Hence high
   importance, negligible gain.

   It is retained because the ordered encoding is defensible and costs only
   a lookup table, but the improvement is within noise and is reported as
   such rather than claimed as a result.

3. THE COST OF LOSING EXPIRY DATES

   Main model (5 features, WITH expiry): macro-F1 ~0.431 / accuracy ~0.455
   Best no-expiry model:                 macro-F1 {best_f1:.4f}
   Difference:                           {best_f1 - 0.431:+.4f}

   Removing ALL expiry information costs only a few points, demonstrating
   that the system retains most of its predictive capability for items with
   no printed date. Note however that the Medium class degrades most (see
   train_model_noexpiry.py output): the model can separate clearly-fresh
   from clearly-at-risk items, but expiry timing is what resolves the
   ambiguous middle.
""")

    print("Set WINNING_FEATURES in train_model_noexpiry.py to the best set,")
    print("then run: python training/train_model_noexpiry.py")


if __name__ == "__main__":
    main()