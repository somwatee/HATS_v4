# python/predict_file.py
import os, time, json, numpy as np, xgboost as xgb

# --- load model & labels ---
root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
model = xgb.XGBClassifier(); model.load_model(f"{root}/models/xgb_model.json")
labels = json.load(open(f"{root}/models/label_classes.json"))

# --- detect sandbox dynamically by checking features.json existence ---
appdata = os.getenv("APPDATA")
term = os.path.join(appdata, "MetaQuotes", "Terminal")
# find the terminal folder where features.json appears
while True:
    for tid in os.listdir(term):
        sandbox = os.path.join(term, tid, "MQL5", "Files")
        feat = os.path.join(sandbox, "features.json")
        if os.path.isfile(feat):
            FEATURES=feat; PRED=os.path.join(sandbox,"prediction.json")
            print(">>> Using sandbox:", sandbox)
            break
    else:
        time.sleep(0.1)
        continue
    break

# --- loop predict ---
while True:
    try:
        data = json.load(open(FEATURES))
        x = np.array(data["features"],dtype=float).reshape(1,-1)
        p = model.predict_proba(x)[0]
        res = {labels[i]:float(p[i]) for i in range(len(p))}
        res["predicted_class"]=labels[int(p.argmax())]
        json.dump(res, open(PRED,"w"))
        print(">>> Wrote prediction:",res)
    except Exception as e:
        pass
    time.sleep(0.1)
