"""
file: python/train_xgboost_weighted.py
วัตถุประสงค์:
  1) อ่าน data/data_with_features.csv -> สร้าง data/ict_labels.csv (label + SL, TP1, TP2, TP3 ตาม ICT Logic)
  2) ทำ Walk‐forward CV ด้วย XGBoost โดยใส่น้ำหนักคลาส (sample_weight) เพื่อชดเชย class imbalance
     -> สร้าง models/walkforward_report.txt
  3) ฝึกโมเดลสุดท้ายบนข้อมูลทั้งหมด (weighted) -> บันทึก models/xgb_model.json, models/label_classes.json

Usage:
  python train_xgboost_weighted.py
"""

import os
import pandas as pd
import yaml
import json
from collections import Counter
from sklearn.model_selection import TimeSeriesSplit
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report
import xgboost as xgb
import numpy as np


def load_config(config_path: str) -> dict:
    """โหลด config จากไฟล์ YAML"""
    if not os.path.isfile(config_path):
        raise FileNotFoundError(f"ไม่พบไฟล์ config: {config_path}")
    with open(config_path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)


def create_ict_labels(features_csv: str, out_csv: str, config: dict):
    """
    อ่าน features CSV แล้วสร้าง ICT labels + SL, TP1, TP2, TP3
    เก็บผลใน out_csv
    """
    df = pd.read_csv(features_csv, parse_dates=['time', 'mssTime', 'timeFVG'])
    df = df.sort_values('time').reset_index(drop=True)

    # เตรียมคอลัมน์สำหรับ label และ SL/TP
    df['label'] = 'NoTrade'
    df['SL'] = 0.0
    df['TP1'] = 0.0
    df['TP2'] = 0.0
    df['TP3'] = 0.0

    # อ่าน threshold จาก config
    adx_th = config.get('ADX_Threshold_M15', 18.0)

    for idx, row in df.iterrows():
        label = 'NoTrade'
        SL = TP1 = TP2 = TP3 = 0.0

        # ค่าเบื้องต้น
        isBull = bool(row['isBullMSS'])
        FVG_Bottom = row['FVG_Bottom']
        FVG_Top = row['FVG_Top']
        fib61 = row['fib61']
        fib38 = row['fib38']
        EMA50 = row['EMA50_M15']
        EMA200 = row['EMA200_M15']
        RSI = row['RSI14_M15']
        ADX = row['ADX14_M15']
        ATR = row['ATR14']
        VWAP = row['VWAP_M1']

        # ราคา Pullback = close ของแถวก่อนหน้า (idx-1) ถ้ามี
        if idx == 0:
            pricePullback = row['close']
        else:
            pricePullback = df.at[idx-1, 'close']

        # เช็คเงื่อนไข ICT Primary
        if not pd.isna(row['mssTime']) and FVG_Bottom != 0:
            # ตรวจ FVG-Fibonacci overlap
            if isBull:
                fibOverlap = (FVG_Top >= fib38) and (FVG_Bottom <= fib61)
            else:
                fibOverlap = (FVG_Bottom <= fib61) and (FVG_Top >= fib38)

            # ตรวจ pullback within FVG
            if isBull:
                pullOK = (pricePullback >= FVG_Bottom and pricePullback <= FVG_Top)
                htfOK = (EMA50 > EMA200 and RSI > 50 and ADX >= adx_th)
            else:
                pullOK = (pricePullback <= FVG_Top and pricePullback >= FVG_Bottom)
                htfOK = (EMA50 < EMA200 and RSI < 50 and ADX >= adx_th)

            if fibOverlap and pullOK and htfOK:
                # เป็นสัญญาณ Buy/Sell ของ ICT
                if isBull:
                    label = 'Buy'
                    SL = FVG_Bottom - 0.5 * ATR
                    TP1 = row['swingLow'] + 1.272 * (row['swingHigh'] - row['swingLow'])
                    TP2 = pricePullback + 2.0 * ATR
                    TP3 = VWAP + 0.5 * ATR
                else:
                    label = 'Sell'
                    SL = FVG_Top + 0.5 * ATR
                    TP1 = row['swingHigh'] - 1.272 * (row['swingHigh'] - row['swingLow'])
                    TP2 = pricePullback - 2.0 * ATR
                    TP3 = VWAP - 0.5 * ATR

        # บันทึกผล
        df.at[idx, 'label'] = label
        df.at[idx, 'SL'] = SL
        df.at[idx, 'TP1'] = TP1
        df.at[idx, 'TP2'] = TP2
        df.at[idx, 'TP3'] = TP3

    # สร้างโฟลเดอร์ถ้ายังไม่มี แล้วบันทึกไฟล์
    os.makedirs(os.path.dirname(out_csv), exist_ok=True)
    df.to_csv(out_csv, index=False)
    print(f"[INFO] Saved ICT labels to {out_csv}")


def compute_class_weights(y_train: np.ndarray) -> np.ndarray:
    """
    คำนวณน้ำหนักตัวอย่าง (sample weights) จากความถี่ของคลาส
    weight_i = total_samples / (num_classes * count_class[y_i])
    """
    counts = Counter(y_train)
    num_classes = len(counts)
    total = len(y_train)
    class_weights = {cls: total / (num_classes * count) for cls, count in counts.items()}
    # สร้าง array weight ตามแต่ละตัวอย่าง
    sample_weights = np.array([class_weights[label] for label in y_train], dtype=float)
    return sample_weights


def train_walkforward(label_csv: str, config: dict):
    """
    อ่าน label CSV -> ทำ Walk‐forward CV (weighted) -> บันทึกรายงาน -> ฝึกโมเดลสุดท้าย (weighted) -> บันทึกโมเดลและ classes
    """
    df = pd.read_csv(label_csv, parse_dates=['time', 'mssTime', 'timeFVG'])
    df = df.sort_values('time').reset_index(drop=True)

    # *** กรองเฉพาะคอลัมน์ตัวเลข (numeric) แล้วตัดคอลัมน์ SL, TP1, TP2, TP3 ออก ***
    numeric_cols = df.select_dtypes(include=['number']).columns.tolist()
    feature_cols = [c for c in numeric_cols if c not in ['SL', 'TP1', 'TP2', 'TP3']]

    X_df = df[feature_cols]
    le = LabelEncoder()
    y = le.fit_transform(df['label'])
    X = X_df.values

    # Walk‐forward CV
    tscv = TimeSeriesSplit(n_splits=5)
    reports = []
    fold = 0

    # อ่านพารามิเตอร์ XGB จาก config
    xgb_params = config.get('XGB_Params', {})

    for train_idx, test_idx in tscv.split(X):
        X_train, X_test = X[train_idx], X[test_idx]
        y_train, y_test = y[train_idx], y[test_idx]

        # คำนวณ sample_weight สำหรับ training ตามความถี่คลาส
        sample_weight = compute_class_weights(y_train)

        model = xgb.XGBClassifier(
            objective='multi:softprob',
            num_class=len(le.classes_),
            eval_metric='mlogloss',
            **xgb_params
        )
        model.fit(X_train, y_train, sample_weight=sample_weight)

        # ทำนายโดยตรงให้ได้ 1D array
        y_pred = model.predict(X_test)
        if y_pred.ndim > 1:
            y_pred = np.argmax(y_pred, axis=1)

        report_dict = classification_report(y_test, y_pred, output_dict=True)
        report_dict['fold'] = fold
        reports.append(report_dict)
        print(f"[INFO] Completed fold {fold} of walk-forward.")
        fold += 1

    # เขียน walkforward_report.txt
    report_path = os.path.abspath(os.path.join(os.path.dirname(label_csv), "../models/walkforward_report.txt"))
    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    with open(report_path, 'w') as f:
        for rep in reports:
            f.write(json.dumps(rep))
            f.write("\n")
    print(f"[INFO] Saved walkforward report to {report_path}")

    # Train final model on all data (weighted)
    sample_weight_all = compute_class_weights(y)
    final_model = xgb.XGBClassifier(
        objective='multi:softprob',
        num_class=len(le.classes_),
        eval_metric='mlogloss',
        **xgb_params
    )
    final_model.fit(X, y, sample_weight=sample_weight_all)

    model_path = os.path.abspath(os.path.join(os.path.dirname(label_csv), "../models/xgb_model.json"))
    os.makedirs(os.path.dirname(model_path), exist_ok=True)
    final_model.save_model(model_path)
    print(f"[INFO] Saved final XGB model to {model_path}")

    # Save label classes
    classes_path = os.path.abspath(os.path.join(os.path.dirname(label_csv), "../models/label_classes.json"))
    with open(classes_path, 'w') as f:
        json.dump(list(le.classes_), f)
    print(f"[INFO] Saved label classes to {classes_path}")


if __name__ == "__main__":
    # Paths
    config_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../config.yaml"))
    features_csv = os.path.abspath(os.path.join(os.path.dirname(__file__), "../data/data_with_features.csv"))
    label_csv = os.path.abspath(os.path.join(os.path.dirname(__file__), "../data/ict_labels.csv"))

    # โหลด config
    try:
        conf = load_config(config_path)
    except Exception as e:
        print(f"[ERROR] Cannot load config: {e}")
        exit(1)

    # สร้าง ICT labels
    create_ict_labels(features_csv, label_csv, conf)

    # ทำ walk-forward weighted และ train final weighted model
    train_walkforward(label_csv, conf)
