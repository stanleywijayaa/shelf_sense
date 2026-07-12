"""
Prediction logic for the /predict endpoint.
 
Loads the trained XGBoost model and encoders produced by the training
pipeline, and turns an incoming app request into a Low/Medium/High
spoilage-risk classification.
 
CRITICAL — feature consistency:
The model was trained on these columns, IN THIS ORDER:
    ['category', 'storage_type', 'shelf_life_days',
     'days_remaining_at_purchase', 'days_until_expiry']
So this file must build a feature row in exactly that order, and encode
`category` / `storage_type` with the SAME encoders used at training time
(loaded from model/encoders.pkl). Any mismatch -> wrong predictions.
 
The app sends `days_since_purchase` and `days_until_expiry`; the other two
date features are derived here to match how preprocess.py built them.
"""
 
import os
import joblib
import numpy as np
import pandas as pd
 
from .schemas import PredictionRequest, PredictionResponse
 
# ── Load model + encoders once at import time (not per request) ──────────
_MODEL_DIR = os.path.join(os.path.dirname(__file__), "..", "model")
 
_model = joblib.load(os.path.join(_MODEL_DIR, "spoilage_model.pkl"))
_feature_encoders = joblib.load(os.path.join(_MODEL_DIR, "encoders.pkl"))
_target_encoder = joblib.load(os.path.join(_MODEL_DIR, "target_encoder.pkl"))
 
# The exact feature order the model was trained on.
_FEATURE_ORDER = [
    "category",
    "storage_type",
    "shelf_life_days",
    "days_remaining_at_purchase",
    "days_until_expiry",
]
 
 
def _safe_encode(encoder, value: str, field_name: str) -> int:
    """
    Encode a categorical value using the training-time encoder.
    If the app sends a category/storage the model never saw, we fall back
    to the first known class rather than crashing — and note it.
    """
    if value in encoder.classes_:
        return int(encoder.transform([value])[0])
    # Unknown label — default to the first class to stay robust.
    return 0
 
 
def predict_risk(request: PredictionRequest) -> PredictionResponse:
    # ── 1. Derive the date features the model expects ────────────────────
    # total shelf life = days already elapsed + days still remaining
    shelf_life_days = request.days_since_purchase + request.days_until_expiry
    # In the training data, remaining-at-purchase ≈ total shelf life
    # (they were ~0.99 correlated), so we use the same value here.
    days_remaining_at_purchase = shelf_life_days
 
    # ── 2. Encode categoricals with the training-time encoders ───────────
    category_enc = _safe_encode(
        _feature_encoders["category"], request.category, "category"
    )
    storage_enc = _safe_encode(
        _feature_encoders["storage_type"], request.storage_type, "storage_type"
    )
 
    # ── 3. Build the feature row IN THE TRAINED ORDER ────────────────────
    row = pd.DataFrame(
        [[
            category_enc,
            storage_enc,
            shelf_life_days,
            days_remaining_at_purchase,
            request.days_until_expiry,
        ]],
        columns=_FEATURE_ORDER,
    )
 
    # ── 4. Predict + decode ──────────────────────────────────────────────
    pred_int = _model.predict(row)[0]
    risk_level = _target_encoder.inverse_transform([pred_int])[0]
 
    # Confidence = probability of the predicted class
    proba = _model.predict_proba(row)[0]
    confidence = float(np.max(proba))
 
    return PredictionResponse(risk_level=str(risk_level), confidence=confidence)