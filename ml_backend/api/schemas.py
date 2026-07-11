# Defines JSON contract between Flutter and Python
"""
Pydantic schemas that define the exact JSON shape exchanged between
the Flutter app and this ML API.
 
The Flutter side (ml_service.dart) must send fields matching
`PredictionRequest`, and will receive fields matching `PredictionResponse`.
Keep these in sync with the Dart model if you change anything here.
"""
 
from pydantic import BaseModel, Field
 
 
class PredictionRequest(BaseModel):
    """Incoming data from the Flutter app for a single food item."""
 
    food_type: str = Field(..., description="Category, e.g. Dairy, Meat, Vegetable")
    storage_type: str = Field(..., description="Fridge, Freezer, or Pantry")
    days_since_purchase: int = Field(..., ge=0, description="Days elapsed since purchase")
    days_until_expiry: int = Field(..., description="Days remaining until expiry (can be negative if expired)")
 
    # Example payload shown in the auto-generated API docs (/docs)
    model_config = {
        "json_schema_extra": {
            "example": {
                "food_type": "Dairy",
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