import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, f1_score
import warnings; warnings.filterwarnings("ignore")

import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from xgboost import XGBClassifier
from sklearn.metrics import accuracy_score, f1_score
import warnings; warnings.filterwarnings("ignore")

df = pd.read_csv("datasets/raw/perishable_goods_management.csv")
df = df[df["category"] != "Pharmaceuticals"].copy()

# Build target the same way as preprocessing
df["risk_level"] = pd.qcut(df["spoilage_risk"], q=3, labels=["Low","Medium","High"], duplicates="drop")
y = LabelEncoder().fit_transform(df["risk_level"])

def bucket(t):
    if t < 0: return "Freezer"
    elif t <= 10: return "Fridge"
    else: return "Pantry"
df["storage_type"] = df["storage_temp"].apply(bucket)
df["category_enc"] = LabelEncoder().fit_transform(df["category"])
df["storage_enc"] = LabelEncoder().fit_transform(df["storage_type"])

# ── Three feature sets, increasing in "cheating" ──
app_features = ["category_enc","storage_enc","shelf_life_days",
                "days_remaining_at_purchase","days_until_expiry"]

# Environmental features the app CANNOT supply (need sensors/IoT)
environmental = ["storage_temp","temp_deviation","temp_abuse_events",
                 "handling_score","packaging_score","spoilage_sensitivity",
                 "distribution_hours"]

# Everything usable (app + environmental), still excluding obvious leakage
full = app_features + environmental

sets = {
    "App-only (household-suppliable)": app_features,
    "App + Environmental (needs IoT)": full,
    "Environmental-only": environmental,
}

for label, feats in sets.items():
    X = df[feats]
    Xtr,Xte,ytr,yte = train_test_split(X,y,test_size=0.2,random_state=42,stratify=y)
    m = XGBClassifier(random_state=42, eval_metric="mlogloss")
    m.fit(Xtr,ytr)
    p = m.predict(Xte)
    print(f"{label:34s} acc={accuracy_score(yte,p):.3f}  f1={f1_score(yte,p,average='macro'):.3f}")