import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, f1_score
import warnings; warnings.filterwarnings("ignore")

df = pd.read_csv("datasets/raw/perishable_goods_management.csv")
df = df[df["category"] != "Pharmaceuticals"].copy()

# ── CHECK 1: Is spoilage_sensitivity consistent within category? ──
print("── Is spoilage_sensitivity derivable from category? ──")
print(df.groupby("category")["spoilage_sensitivity"].agg(["min","max","mean","nunique"]))
print()

# ── CHECK 2: Does adding it actually improve accuracy? ──
def bucket(t):
    if t < 0: return "Freezer"
    elif t <= 10: return "Fridge"
    else: return "Pantry"

df["storage_type"] = df["storage_temp"].apply(bucket)
df["risk_level"] = pd.qcut(df["spoilage_risk"], q=3, labels=["Low","Medium","High"], duplicates="drop")
df["category_enc"] = LabelEncoder().fit_transform(df["category"])
df["storage_enc"] = LabelEncoder().fit_transform(df["storage_type"])
y = LabelEncoder().fit_transform(df["risk_level"])

base = ["category_enc","storage_enc","shelf_life_days","days_remaining_at_purchase","days_until_expiry"]

for label, feats in [("WITHOUT sensitivity", base),
                     ("WITH sensitivity", base + ["spoilage_sensitivity"])]:
    X = df[feats]
    Xtr,Xte,ytr,yte = train_test_split(X,y,test_size=0.2,random_state=42,stratify=y)
    m = RandomForestClassifier(n_estimators=100,random_state=42); m.fit(Xtr,ytr)
    p = m.predict(Xte)
    print(f"{label:22s} acc={accuracy_score(yte,p):.3f}  f1={f1_score(yte,p,average='macro'):.3f}")