"""
Pydantic schemas that define the exact JSON shape exchanged between
the Flutter app and this ML API.

The app collects: category, storage type, purchase date, and OPTIONALLY an
expiry date. Rather than make the app compute model features, it sends these
raw values and the API derives what each model needs — keeping all feature
engineering in one place (predict.py), matching how preprocessing built the
training data.

TWO MODELS, ONE ENDPOINT:
  days_until_expiry provided -> main 5-feature model
  days_until_expiry omitted  -> no-expiry 4-feature model
The response reports which was used.
"""

from typing import Optional

from pydantic import BaseModel, Field


class PredictionRequest(BaseModel):
    """Incoming data from the Flutter app for a single food item."""

    category: str = Field(..., description="Food category, e.g. Dairy, Meat, Produce")
    storage_type: str = Field(..., description="Fridge, Freezer, or Pantry")
    days_since_purchase: int = Field(
        ..., ge=0, description="Days elapsed since purchase (today - purchaseDate)"
    )
    days_until_expiry: Optional[int] = Field(
        None,
        description=(
            "Days remaining until expiry (expiryDate - today; negative if "
            "expired). OMIT or send null when the item has no expiry date — "
            "the API will use the no-expiry model instead."
        ),
    )

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "category": "Dairy",
                    "storage_type": "Fridge",
                    "days_since_purchase": 3,
                    "days_until_expiry": 4,
                },
                {
                    "category": "Produce",
                    "storage_type": "Pantry",
                    "days_since_purchase": 5,
                },
            ]
        }
    }


class PredictionResponse(BaseModel):
    """Risk classification returned to the Flutter app."""

    risk_level: str = Field(..., description="Low, Medium, or High")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Model confidence 0-1")
    model_used: str = Field(
        ..., description="'main' (with expiry date) or 'noexpiry'"
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "risk_level": "Medium",
                "confidence": 0.82,
                "model_used": "main",
            }
        }
    }