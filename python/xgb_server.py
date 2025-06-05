# file: python/xgb_server.py
import json
import numpy as np
import xgboost as xgb
from flask import Flask, request, jsonify
import yaml
import os
import traceback

app = Flask(__name__)

# Utility: โหลด config (หากต้องการ)
def load_config(path="config.yaml"):
    with open(path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)

# โหลดโมเดล XGBoost และ classes
MODEL_PATH         = os.path.abspath(os.path.join(os.path.dirname(__file__), "../models/xgb_model.json"))
LABEL_CLASSES_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "../models/label_classes.json"))

if not os.path.isfile(MODEL_PATH) or not os.path.isfile(LABEL_CLASSES_PATH):
    print(f"[ERROR] โมเดลหรือไฟล์ classes ไม่พบ: {MODEL_PATH} or {LABEL_CLASSES_PATH}")
    exit(1)

with open(LABEL_CLASSES_PATH, "r") as f:
    LABEL_CLASSES = json.load(f)

xgb_model = xgb.XGBClassifier()
xgb_model.load_model(MODEL_PATH)

def validate_features(data):
    # เปลี่ยนเป็นต้องรับลิสต์ความยาว 20
    arr = np.array(data, dtype=float)
    if arr.ndim != 1 or arr.shape[0] != 20:
        raise ValueError("Expected feature array of length 20, but got length {}".format(arr.shape[0]))
    return arr.reshape(1, -1)

@app.route("/predict", methods=["POST"])
def predict():
    try:
        payload = request.get_json(force=True)
        if "features" not in payload:
            return jsonify({"error": "Missing key 'features'"}), 400

        x_feat = validate_features(payload["features"])
        probs = xgb_model.predict_proba(x_feat)[0]
        prob_dict = {cls: float(probs[idx]) for idx, cls in enumerate(LABEL_CLASSES)}
        pred_label = LABEL_CLASSES[int(np.argmax(probs))]

        return jsonify({
            "probabilities": prob_dict,
            "predicted_class": pred_label
        }), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
