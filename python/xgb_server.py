# file: python/xgb_server.py

import json
import numpy as np
from flask import Flask, request, jsonify
import xgboost as xgb

app = Flask(__name__)

# --------------------------------------------
#  โหลดโมเดล XGBoost และ label classes ที่เซฟไว้
# --------------------------------------------
# (สมมติว่าไฟล์นี้อยู่ในโฟลเดอร์ models/)
MODEL_PATH = "models/xgb_model.json"
LABEL_PATH = "models/label_classes.json"

# 1. โหลดโมเดล
xgb_model = xgb.XGBClassifier()
xgb_model.load_model(MODEL_PATH)

# 2. โหลด mapping ของ class labels
with open(LABEL_PATH, 'r', encoding='utf-8') as f:
    label_classes = json.load(f)  
    # คาดว่าไฟล์นี้เก็บ string list เช่น ["Buy", "NoTrade", "Sell"] หรือคล้ายๆ กัน

# --------------------------------------------
#  ฟังก์ชันช่วย “clean” ข้อมูล raw จาก MQL5
# --------------------------------------------
def clean_mql5_payload(raw_bytes: bytes) -> str:
    """
    MQL5 ส่งข้อมูล JSON มาในรูปของ uchar[] (byte array) ซึ่งจะถูก padding ด้วย '\x00'
    ตรงนี้ให้ decode เป็น UTF-8 (ignore errors) แล้วตัด \x00, \x1a (EOF) ทิ้งก่อน
    """
    # แปลงไบต์เป็นสตริง (UTF-8) — บอก ignore errors เผื่อเจอไบต์หลุด
    txt = raw_bytes.decode('utf-8', errors='ignore')
    # ตัด null bytes (\x00) และอักขระ EOF (\x1a) ทิ้ง (ซึ่งมักจะอยู่ท้ายๆ)
    # (บางครั้ง MQL5 จะ append \x1a เพื่อจบข้อมูล)
    cleaned = txt.replace('\x00', '').replace('\x1a', '')
    return cleaned

# --------------------------------------------
#  Route สำหรับรับ POST /predict
# --------------------------------------------
@app.route('/predict', methods=['POST'])
def predict():
    try:
        # 1. อ่าน raw data (bytes) จาก MQL5
        raw = request.data  
        
        # 2. “Clean” ให้เหลือแค่ JSON ที่เป็นตัวอักษร
        cleaned = clean_mql5_payload(raw)
        app.logger.debug(f"Flask: Raw request.data (first 200 bytes) = {raw[:200]}")
        app.logger.debug(f"Flask: Cleaned text (first 200 chars) = {cleaned[:200]}")
        
        # 3. ต้องแน่ใจว่า cleaned ไม่ใช่สตริงเปล่า
        if not cleaned:
            return jsonify({
                "error": "Empty payload after cleaning null bytes"
            }), 400
        
        # 4. แปลงเป็น dict ด้วย json.loads()
        try:
            payload = json.loads(cleaned)
        except json.JSONDecodeError as e:
            return jsonify({
                "error": "JSON decode error",
                "message": str(e),
                "cleaned_payload": cleaned[:200]  # ส่งตัวอย่างไปช่วย debug
            }), 400
        
        # 5. ตรวจโครงสร้าง JSON ว่ามี key "features" หรือไม่
        if "features" not in payload:
            return jsonify({
                "error": "Missing key 'features' in payload"
            }), 400
        
        features = payload["features"]
        # 6. ตรวจว่า features เป็นลิสต์ความยาว 20 จริงหรือไม่
        if not isinstance(features, list) or len(features) != 20:
            return jsonify({
                "error": "Key 'features' must be a list of length 20",
                "received_length": len(features) if isinstance(features, list) else "not a list"
            }), 400
        
        # 7. แปลง features → numpy array (shape = (1, 20))
        x_feat = np.array(features, dtype=float).reshape(1, -1)
        
        # 8. predict_proba
        probs = xgb_model.predict_proba(x_feat)[0]  
        #    ได้ออกมาเป็น array เช่น [prob_class0, prob_class1, prob_class2]
        
        # 9. สร้าง JSON response กลับไป
        #    สมมติว่า label_classes = ["Buy", "NoTrade", "Sell"]
        #    เราจะจับคู่ probs[i] → label_classes[i]
        result = {
            "predicted_class": label_classes[np.argmax(probs)],
            "probabilities": {
                label_classes[i]: float(probs[i]) for i in range(len(probs))
            }
        }
        return jsonify(result), 200
    
    except Exception as e:
        # กรณีเกิด exception อื่นๆ ให้ log แล้วส่งกลับ 500
        app.logger.error(f"Exception in /predict: {str(e)}", exc_info=True)
        return jsonify({
            "error": "Internal Server Error",
            "message": str(e)
        }), 500

# --------------------------------------------
#  Main: รัน Flask app
# --------------------------------------------
if __name__ == "__main__":
    # เปิด debug mode เพื่อดู log
    app.run(host="0.0.0.0", port=5000, debug=True)
