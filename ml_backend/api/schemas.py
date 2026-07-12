"""
Pydantic schemas that define the exact JSON shape exchanged between
the Flutter app and this ML API.
 
The Flutter side (ml_service.dart) sends fields matching `PredictionRequest`,
and receives fields matching `PredictionResponse`.
 
The app collects: category, storage type, purchase date, expiry date.
Rather than make the app compute model features, it sends these raw values
and the API derives what the model needs (shelf_life_days,
days_remaining_at_purchase, days_until_expiry). This keeps the app simple
and keeps all feature engineering in one place (predict.py), matching how
preprocess.py built the training data.
"""
 
from pydantic import BaseModel, Field
 
 
class PredictionRequest(BaseModel):
    """Incoming data from the Flutter app for a single food item."""
 
    category: str = Field(..., description="Food category, e.g. Dairy, Meat, Produce")
    storage_type: str = Field(..., description="Fridge, Freezer, or Pantry")
    days_since_purchase: int = Field(..., ge=0, description="Days elapsed since purchase (today - purchaseDate)")
    days_until_expiry: int = Field(..., description="Days remaining until expiry (expiryDate - today; negative if expired)")
 
    model_config = {
        "json_schema_extra": {
            "example": {
                "category": "Dairy",
                "storage_type": "Fridge",
                "days_since_purchase": 3,
                "days_until_expiry": 4,
            }
        }
    }
 
 
class PredictionResponse(BaseModel):
    """Risk classification returned to the Flutter app."""
 
    risk_level: str = Field(..., description="Low, Medium, or High")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Model confidence 0-1")
 
    model_config = {
        "json_schema_extra": {
            "example": {
                "risk_level": "Medium",
                "confidence": 0.82,
            }
        }
    }