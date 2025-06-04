"""
file: python/backtest_hybrid.py
วัตถุประสงค์:
  - อ่าน data/ict_labels.csv (ไฟล์นี้มีทั้งราคา, ฟีเจอร์, label, SL/TP)
  - โหลดโมเดล XGBoost จาก models/xgb_model.json และ classes จาก models/label_classes.json
  - จำลองการเข้า–ออก order (ICT Primary + XGB Fallback) ตลอดช่วงข้อมูล
  - บันทึกผล trade log เป็น data/backtest_trade_log.csv
  - คำนวณ metrics (Win Rate, Profit Factor, Max Drawdown, Expectancy) และบันทึกเป็น models/backtest_metrics.txt

Usage:
  python backtest_hybrid.py
"""

import os
import pandas as pd
import numpy as np
import yaml
import json
import xgboost as xgb

def load_config(config_path: str) -> dict:
    """โหลด config จาก YAML"""
    if not os.path.isfile(config_path):
        raise FileNotFoundError(f"ไม่พบไฟล์ config: {config_path}")
    with open(config_path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)

def backtest_hybrid(labels_csv: str,
                    model_path: str,
                    classes_path: str,
                    config_path: str):
    """
    - labels_csv: path ไปยัง data/ict_labels.csv (มีราคา + ฟีเจอร์ + label + SL/TP)
    - model_path: path ไปยัง models/xgb_model.json
    - classes_path: path ไปยัง models/label_classes.json
    - config_path: path ไปยัง config.yaml
    """
    # โหลด config
    conf = load_config(config_path)
    threshold = conf.get('XGB_Threshold', 0.70)

    # โหลดไฟล์ ict_labels.csv ซึ่งมีทั้งราคาและฟีเจอร์แล้ว
    df = pd.read_csv(labels_csv, parse_dates=['time'])
    df = df.sort_values('time').reset_index(drop=True)

    # เตรียม X_all จากคอลัมน์ตัวเลข (numeric) ยกเว้นคอลัมน์ที่ไม่ใช้เป็นฟีเจอร์ (SL, TP1, TP2, TP3)
    numeric_cols = df.select_dtypes(include=['number']).columns.tolist()
    drop_cols = ['SL', 'TP1', 'TP2', 'TP3']
    feature_cols = [c for c in numeric_cols if c not in drop_cols]
    X_all = df[feature_cols].fillna(0).values

    # โหลด XGBoost model และ classes
    xgb_model = xgb.XGBClassifier()
    xgb_model.load_model(model_path)
    with open(classes_path, 'r') as f:
        classes = json.load(f)  # เช่น ["Buy","NoTrade","Sell"]

    n = len(df)
    trades = []
    i = 0

    while i < n:
        row = df.loc[i]
        entry_label = row['label']
        side = None
        entry_price = row['close']
        SL = row['SL']
        TP1 = row['TP1']
        TP2 = row['TP2']
        TP3 = row['TP3']
        latest_ATR = row['ATR14']
        VWAP = row['VWAP_M1']

        # --- ICT Primary ---
        if entry_label in ['Buy', 'Sell']:
            side = entry_label
        else:
            # --- Fallback: XGB ---
            x_feat = X_all[i].reshape(1, -1)
            probs = xgb_model.predict_proba(x_feat)[0]
            idx_buy = classes.index('Buy')
            idx_sell = classes.index('Sell')
            if probs[idx_buy] >= threshold:
                side = 'Buy'
                # คำนวณ SL/TP ใหม่ตาม ICT logic (fallback XGB)
                SL = row['FVG_Bottom'] - 0.5 * row['ATR14']
                TP1 = row['swingLow'] + 1.272 * (row['swingHigh'] - row['swingLow'])
                TP2 = entry_price + 2.0 * row['ATR14']
                TP3 = VWAP + 0.5 * row['ATR14']
            elif probs[idx_sell] >= threshold:
                side = 'Sell'
                SL = row['FVG_Top'] + 0.5 * row['ATR14']
                TP1 = row['swingHigh'] - 1.272 * (row['swingHigh'] - row['swingLow'])
                TP2 = entry_price - 2.0 * row['ATR14']
                TP3 = VWAP - 0.5 * row['ATR14']

        if side is None:
            i += 1
            continue

        # เวลาที่เข้า order
        entry_time = row['time']

        # --- ค้นหา exit ตั้งแต่ bar ถัดไป ---
        exit_price = None
        exit_time = None
        for j in range(i + 1, n):
            high_j = df.loc[j, 'high']
            low_j = df.loc[j, 'low']
            t_j = df.loc[j, 'time']

            if side == 'Buy':
                if high_j >= TP1:
                    exit_price = TP1
                elif high_j >= TP2:
                    exit_price = TP2
                elif high_j >= TP3:
                    exit_price = TP3
                elif low_j <= SL:
                    exit_price = SL
            else:  # Sell
                if low_j <= TP1:
                    exit_price = TP1
                elif low_j <= TP2:
                    exit_price = TP2
                elif low_j <= TP3:
                    exit_price = TP3
                elif high_j >= SL:
                    exit_price = SL

            if exit_price is not None:
                exit_time = t_j
                pnl = (exit_price - entry_price) if side == 'Buy' else (entry_price - exit_price)
                trades.append({
                    'entryTime': entry_time,
                    'exitTime': exit_time,
                    'side': side,
                    'entryPrice': entry_price,
                    'exitPrice': exit_price,
                    'pnl': pnl,
                    'ATR_at_entry': latest_ATR,
                    'VWAP_at_entry': VWAP
                })
                i = j + 1
                break
        else:
            # ถ้าไม่เจอ exit จนถึงบาร์สุดท้าย
            last_close = df.loc[n - 1, 'close']
            exit_time = df.loc[n - 1, 'time']
            pnl = (last_close - entry_price) if side == 'Buy' else (entry_price - last_close)
            trades.append({
                'entryTime': entry_time,
                'exitTime': exit_time,
                'side': side,
                'entryPrice': entry_price,
                'exitPrice': last_close,
                'pnl': pnl,
                'ATR_at_entry': latest_ATR,
                'VWAP_at_entry': VWAP
            })
            i = n

    # บันทึก trade log
    df_trades = pd.DataFrame(trades)
    log_path = os.path.abspath(os.path.join(os.path.dirname(labels_csv), "../data/backtest_trade_log.csv"))
    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    df_trades.to_csv(log_path, index=False)

    # คำนวณ metrics
    wins = df_trades[df_trades['pnl'] > 0]['pnl'].sum()
    losses = abs(df_trades[df_trades['pnl'] < 0]['pnl'].sum())
    total_trades = len(df_trades)
    win_count = len(df_trades[df_trades['pnl'] > 0])
    loss_count = len(df_trades[df_trades['pnl'] < 0])
    win_rate = win_count / total_trades if total_trades > 0 else 0
    profit_factor = (wins / losses) if losses > 0 else np.inf

    equity_curve = df_trades['pnl'].cumsum()
    max_dd = (equity_curve.cummax() - equity_curve).max()

    avg_win = df_trades[df_trades['pnl'] > 0]['pnl'].mean() if win_count > 0 else 0
    avg_loss = df_trades[df_trades['pnl'] < 0]['pnl'].mean() if loss_count > 0 else 0
    loss_rate = 1 - win_rate
    expectancy = avg_win * win_rate + avg_loss * loss_rate

    # บันทึก metrics
    metrics_path = os.path.abspath(os.path.join(os.path.dirname(labels_csv), "../models/backtest_metrics.txt"))
    os.makedirs(os.path.dirname(metrics_path), exist_ok=True)
    with open(metrics_path, 'w') as f:
        f.write(f"Total Trades: {total_trades}\n")
        f.write(f"Win Rate: {win_rate:.4f}\n")
        f.write(f"Profit Factor: {profit_factor:.4f}\n")
        f.write(f"Max Drawdown: {max_dd:.4f}\n")
        f.write(f"Expectancy: {expectancy:.4f}\n")
    print(f"[INFO] Backtest complete. Trade log saved to {log_path}")
    print(f"[INFO] Metrics saved to {metrics_path}")

if __name__ == "__main__":
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../"))
    labels_csv = os.path.join(base_dir, "data/ict_labels.csv")
    model_path = os.path.join(base_dir, "models/xgb_model.json")
    classes_path = os.path.join(base_dir, "models/label_classes.json")
    config_path = os.path.join(base_dir, "config.yaml")

    backtest_hybrid(labels_csv,
                    model_path,
                    classes_path,
                    config_path)
