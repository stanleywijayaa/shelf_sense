# Model Training
import pandas as pd
import joblib
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix
 
PROCESSED_DATA_PATH = "" # Path to cleaned data
MODEL_PATH = "model/spoilage_model.pkl"