"""
FastAPI entry point for the ShelfSense ML backend.

Run locally with:
    uvicorn main:app --reload --host 0.0.0.0 --port 8000

Then visit http://localhost:8000/docs for interactive API documentation.

Note on --host 0.0.0.0: this makes the server reachable from your phone
on the same Wi-Fi network (needed when testing the Flutter app on a real
device like your Galaxy A71). From the phone, call your computer's local
IP, e.g. http://192.168.1.5:8000/predict — not localhost.
"""

from fastapi import FastAPI
from api.schemas import PredictionRequest, PredictionResponse
from api.predict import predict_risk

app = FastAPI(
    title="ShelfSense ML API",
    description="Spoilage risk prediction service for the ShelfSense app.",
    version="0.1.0",
)

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # allow any origin (fine for development)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    """Simple health check so you can confirm the server is running."""
    return {"status": "ok", "service": "ShelfSense ML API"}


@app.post("/predict", response_model=PredictionResponse)
def predict(request: PredictionRequest) -> PredictionResponse:
    """
    Accepts food item attributes and returns a spoilage risk classification.

    Currently backed by a placeholder rule-based classifier — see
    api/predict.py. Will use the trained model once Phase 4 is complete.
    """
    return predict_risk(request)