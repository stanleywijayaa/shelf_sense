"""
Prediction logic for the /predict endpoint.
 
Right now this uses a PLACEHOLDER rule-based classifier so the API is
fully runnable before the real ML model exists. It mirrors the mock logic
in the Flutter app (risk_utils.dart) so both sides behave consistently
during integration testing.
 
TODO (Phase 4): Once train_model.py produces model/spoilage_model.pkl,
replace `_placeholder_predict()` with real model loading + inference:
 
    import joblib
    _model = joblib.load("model/spoilage_model.pkl")
    _encoders = joblib.load("model/encoders.pkl")//
 
    def predict_risk(request):
        X = _build_feature_vector(request, _encoders)
        pred = _model.predict(X)[0]
        proba = _model.predict_proba(X).max()
        return PredictionResponse(risk_level=pred, confidence=float(proba))
"""
 
from .schemas import PredictionRequest, PredictionResponse
 
 
def _placeholder_predict(request: PredictionRequest) -> PredictionResponse:
    """
    Temporary rule-based risk estimate based on how much shelf life is left.
    This has NO relation to the eventual trained model — it exists only so
    the endpoint returns something sensible during development.
    """
    total_shelf_life = request.days_since_purchase + request.days_until_expiry
 
    # Already expired -> High
    if request.days_until_expiry < 0:
        return PredictionResponse(risk_level="High", confidence=1.0)
 
    # Guard against divide-by-zero
    if total_shelf_life <= 0:
        return PredictionResponse(risk_level="High", confidence=1.0)
 
    remaining_ratio = request.days_until_expiry / total_shelf_life
 
    if remaining_ratio <= 0.2:
        return PredictionResponse(risk_level="High", confidence=0.9)
    elif remaining_ratio <= 0.5:
        return PredictionResponse(risk_level="Medium", confidence=0.9)
    else:
        return PredictionResponse(risk_level="Low", confidence=0.9)
 
 
def predict_risk(request: PredictionRequest) -> PredictionResponse:
    """
    Public entry point called by the FastAPI route.
    Swap the body of this function for real model inference in Phase 4.
    """
    return _placeholder_predict(request)