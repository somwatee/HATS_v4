# file: python/xgb_server.py
import json
import numpy as np
import xgboost as xgb
from flask import Flask, request, jsonify
import yaml
import os

app = Flask(__name__)

# ——————————————————————————————————————————————
#  Utility: โหลด config (ถ้าอยากอ่าน threshold จาก config.yaml)
# ——————————————————————————————————————————————
def load_config(path="config.yaml"):
    with open(path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)

# ——————————————————————————————————————————————
#  โหลดโมเดล XGBoost และ classes
# ——————————————————————————————————————————————
MODEL_PATH         = os.path.abspath(os.path.join(os.path.dirname(__file__), "../models/xgb_model.json"))
LABEL_CLASSES_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "../models/label_classes.json"))

# โหลด label encoder classes (ลำดับ: ["Buy","NoTrade","Sell"] หรือใดๆ ตามที่ train เก็บไว้)
with open(LABEL_CLASSES_PATH, "r") as f:
    LABEL_CLASSES = json.load(f)

# โหลด XGBoost model
xgb_model = xgb.XGBClassifier()
xgb_model.load_model(MODEL_PATH)


# ——————————————————————————————————————————————
#  ฟังก์ชันช่วย: ตรวจ features array
# ——————————————————————————————————————————————
def validate_features(data):
    """
    data: list หรือ array ขนาด 8 ตัว (order ตามที่ EA/decision_engine ส่งมา)
    return: numpy array shape (1,8) หรือ raise ValueError
    """
    arr = np.array(data, dtype=float)
    if arr.ndim != 1 or arr.shape[0] != 8:
        raise ValueError("Expected feature array of length 8.")
    return arr.reshape(1, -1)


# ——————————————————————————————————————————————
#  Endpoint: /predict
#  รับ JSON payload แบบ:
#    {
#      "features": [val0, val1, ..., val7]
#    }
#  คืน JSON:
#    {
#      "probabilities": {
#         "Buy": 0.12,
#         "NoTrade": 0.83,
#         "Sell": 0.05
#      },
#      "predicted_class": "NoTrade"
#    }
# ——————————————————————————————————————————————
@app.route("/predict", methods=["POST"])
def predict():
    payload = request.get_json(force=True)
    if "features" not in payload:
        return jsonify({"error": "Missing key 'features' in JSON body"}), 400

    try:
        x_feat = validate_features(payload["features"])
    except Exception as e:
        return jsonify({"error": str(e)}), 400

    # ใช้ XGBoost model ทำนาย probability
    probs = xgb_model.predict_proba(x_feat)[0]  # shape (3,)
    # จัดรูปผลลัพธ์เป็น dictionary ตาม LABEL_CLASSES
    prob_dict = {cls: float(probs[idx]) for idx, cls in enumerate(LABEL_CLASSES)}
    # หาค่าคาดการณ์สูงสุด
    pred_index = int(np.argmax(probs))
    pred_label = LABEL_CLASSES[pred_index]

    return jsonify({
        "probabilities": prob_dict,
        "predicted_class": pred_label
    }), 200


# ——————————————————————————————————————————————
#  รันเซิร์ฟเวอร์ (default port: 5000)
# ——————————————————————————————————————————————
if __name__ == "__main__":
    # โหลด threshold จาก config.yaml (ถ้าต้องการ)
    # config = load_config(os.path.abspath(os.path.join(os.path.dirname(__file__), "../config.yaml")))
    # xgb_threshold = config.get("XGB_Threshold", 0.70)

    app.run(host="0.0.0.0", port=5000)
