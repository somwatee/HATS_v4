"""
file: python/online_learning.py
วัตถุประสงค์:
  - โหลดโมเดล River (ไฟล์ models/river_model.bin) ถ้ามี
  - ถ้าไม่มี สร้าง Pipeline(StandardScaler, LogisticRegression)
  - ฟังก์ชัน update_online_model(feature_dict, true_label) ให้โมเดลเรียนรู้ข้อมูลใหม่ แล้วบันทึกไฟล์

Usage:
  from online_learning import update_online_model
  sample_features = {
      'diffEMA': 1.2,
      'RSI14': 55,
      'ADX14': 20,
      'FVG_width': 0.5,
      'distFromFVG': 0.1,
      'tickVol': 120,
      'avgVol': 100,
      'hourOfDay': 14
  }
  sample_label = 1  # เช่น 0=Buy, 1=NoTrade, 2=Sell ตามที่กำหนด
  update_online_model(sample_features, sample_label)
"""

import os
import pickle
from river import compose, preprocessing, linear_model

MODEL_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "../models/river_model.bin"))

def init_model():
    """
    โหลดโมเดล River จากไฟล์ models/river_model.bin
    ถ้าไฟล์ไม่มี ให้สร้าง Pipeline(StandardScaler, LogisticRegression)
    คืนค่า model (Pipeline object)
    """
    if os.path.isfile(MODEL_PATH):
        try:
            with open(MODEL_PATH, 'rb') as f:
                model = pickle.load(f)
            return model
        except Exception:
            # ถ้าไฟล์เสียหาย ให้สร้างใหม่
            pass

    # สร้าง pipeline ใหม่
    model = compose.Pipeline(
        preprocessing.StandardScaler(),
        linear_model.LogisticRegression()
    )
    return model

def save_model(model):
    """
    บันทึกโมเดล River ลงไฟล์ models/river_model.bin
    """
    os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
    with open(MODEL_PATH, 'wb') as f:
        pickle.dump(model, f)

def update_online_model(feature_dict: dict, true_label: int):
    """
    ให้โมเดลเรียนรู้ข้อมูลใหม่ทีละตัวอย่าง
    - feature_dict: dict ของฟีเจอร์ (key=ชื่อฟีเจอร์, value=ค่าตัวเลข)
    - true_label: label (int) เช่น 0=Buy, 1=NoTrade, 2=Sell
    """
    # โหลดหรือสร้างโมเดล
    model = init_model()

    # เรียนรู้ (one-pass)
    model.learn_one(feature_dict, true_label)

    # บันทึกโมเดลกลับไป
    save_model(model)

if __name__ == "__main__":
    # ตัวอย่างใช้งาน
    sample_features = {
        'diffEMA': 1.2,
        'RSI14': 55,
        'ADX14': 20,
        'FVG_width': 0.5,
        'distFromFVG': 0.1,
        'tickVol': 120,
        'avgVol': 100,
        'hourOfDay': 14
    }
    sample_label = 1  # เช่น 0=Buy, 1=NoTrade, 2=Sell
    update_online_model(sample_features, sample_label)
    print(f"[INFO] Updated online model saved to {MODEL_PATH}")
