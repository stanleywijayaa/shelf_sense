"""
Prediction logic for the /predict endpoint.

Serves TWO trained models behind one endpoint:

  MAIN MODEL (spoilage_model.pkl) — used when the app supplies an expiry
  date. Trained on, IN THIS ORDER:
      ['category', 'storage_type', 'shelf_life_days',
       'days_remaining_at_purchase', 'days_until_expiry']

  NO-EXPIRY MODEL (spoilage_model_noexpiry.pkl) — used when the item has
  no expiry date (loose produce, bulk goods, homemade food). Trained on:
      ['category', 'storage_type', 'days_since_purchase',
       'spoilage_sensitivity_cat']
  `spoilage_sensitivity_cat` is a per-category constant, looked up from
  model/category_stats.json — the same table preprocessing derived, so
  train-time and serve-time features match exactly.

CRITICAL — feature consistency:
Each model must receive its features in exactly the trained order, encoded
with the SAME encoders used at training time. Any mismatch produces silently
wrong predictions rather than an error.
"""

import json
import os

import joblib
import numpy as np
import pandas as pd

from .schemas import PredictionRequest, PredictionResponse

# ── Load models, encoders, and lookups once at import (not per request) ──
_MODEL_DIR = os.path.join(os.path.dirname(__file__), "..", "model")


def _p(filename: str) -> str:
    return os.path.join(_MODEL_DIR, filename)


# Main model (with expiry date)
_model = joblib.load(_p("spoilage_model.pkl"))
_feature_encoders = joblib.load(_p("encoders.pkl"))
_target_encoder = joblib.load(_p("target_encoder.pkl"))

_FEATURE_ORDER = [
    "category",
    "storage_type",
    "shelf_life_days",
    "days_remaining_at_purchase",
    "days_until_expiry",
]

# No-expiry model
_model_ne = joblib.load(_p("spoilage_model_noexpiry.pkl"))
_feature_encoders_ne = joblib.load(_p("encoders_noexpiry.pkl"))
_target_encoder_ne = joblib.load(_p("target_encoder_noexpiry.pkl"))

_FEATURE_ORDER_NE = [
    "category",
    "storage_type",
    "days_since_purchase",
    "spoilage_sensitivity_cat",
]

# Category sensitivity values loaded from preprocessing output.
with open(_p("category_stats.json")) as f:
    _category_stats = json.load(f)
_SENSITIVITY = _category_stats["spoilage_sensitivity"]
# Default sensitivity for unknown categories.
_SENSITIVITY_DEFAULT = float(np.median(list(_SENSITIVITY.values())))


def _safe_encode(encoder, value: str) -> int:
    """Encode a categorical value with the training-time encoder.
    Unknown labels fall back to the first known class rather than crashing."""
    if value in encoder.classes_:
        return int(encoder.transform([value])[0])
    return 0


def _finish(model, target_encoder, row: pd.DataFrame, tag: str) -> PredictionResponse:
    """Shared predict + decode step for both models."""
    pred_int = model.predict(row)[0]
    risk_level = target_encoder.inverse_transform([pred_int])[0]
    confidence = float(np.max(model.predict_proba(row)[0]))
    return PredictionResponse(
        risk_level=str(risk_level),
        confidence=confidence,
        model_used=tag,
    )


def _predict_with_expiry(request: PredictionRequest) -> PredictionResponse:
    # Derive the date features the main model expects.
    # total shelf life = days already elapsed + days still remaining
    shelf_life_days = request.days_since_purchase + request.days_until_expiry
    # In the training data, remaining-at-purchase ~= total shelf life
    # (they were ~0.99 correlated), so we use the same value here.
    days_remaining_at_purchase = shelf_life_days

    row = pd.DataFrame(
        [[
            _safe_encode(_feature_encoders["category"], request.category),
            _safe_encode(_feature_encoders["storage_type"], request.storage_type),
            shelf_life_days,
            days_remaining_at_purchase,
            request.days_until_expiry,
        ]],
        columns=_FEATURE_ORDER,
    )
    return _finish(_model, _target_encoder, row, "main")


def _predict_without_expiry(request: PredictionRequest) -> PredictionResponse:
    # Per-category perishability — an ordered encoding of category, looked
    # up from the same table preprocessing built.
    sensitivity = _SENSITIVITY.get(request.category, _SENSITIVITY_DEFAULT)

    row = pd.DataFrame(
        [[
            _safe_encode(_feature_encoders_ne["category"], request.category),
            _safe_encode(_feature_encoders_ne["storage_type"], request.storage_type),
            request.days_since_purchase,
            sensitivity,
        ]],
        columns=_FEATURE_ORDER_NE,
    )
    return _finish(_model_ne, _target_encoder_ne, row, "noexpiry")


def predict_risk(request: PredictionRequest) -> PredictionResponse:
    """Route to the appropriate model based on whether the app supplied
    an expiry date."""
    if request.days_until_expiry is None:
        return _predict_without_expiry(request)
    return _predict_with_expiry(request)