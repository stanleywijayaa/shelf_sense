ShelfSense ML Backend

Python + FastAPI service that predicts food spoilage risk (Low / Medium / High)
for the ShelfSense Flutter app.

Structure

ml_backend/
├── datasets/
│   ├── raw/          # Original Kaggle dataset (untouched)
│   └── processed/    # Cleaned, model-ready data
├── training/
│   ├── explore.py       # Step 1: EDA
│   ├── preprocess.py    # Step 2: clean + encode
│   └── train_model.py   # Step 3: train + export model
├── model/            # Exported .pkl model + encoders
├── api/
│   ├── schemas.py    # Request/response shapes
│   └── predict.py    # Prediction logic
├── main.py           # FastAPI entry point
└── requirements.txt

Setup

bash# From inside ml_backend/
python -m venv venv

# Activate it:
#   Windows:  venv\Scripts\activate
#   Mac/Linux: source venv/bin/activate

pip install -r requirements.txt

Run the API

bashuvicorn main:app --reload --host 0.0.0.0 --port 8000

Then open http://localhost:8000/docs for interactive testing.

Current status

The /predict endpoint currently returns a placeholder rule-based
risk estimate so the API is runnable before the real model exists.
Once the dataset is approved:


Drop the CSV into datasets/raw/
Run explore.py → preprocess.py → train_model.py
Replace the placeholder in api/predict.py with real model inference


Workflow order (Phase 4)

explore → preprocess → train → integrate with FastAPI → connect Flutter