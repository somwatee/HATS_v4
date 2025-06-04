# file: python/utils.py

import os
import yaml
import requests
import pandas as pd
import numpy as np

def load_config(path="config.yaml") -> dict:
    """
    โหลดไฟล์ YAML config แล้วคืนค่าเป็น dict
    """
    if not os.path.isfile(path):
        raise FileNotFoundError(f"ไม่พบไฟล์ config: {path}")
    with open(path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)

def send_telegram_message(bot_token: str, chat_id: str, text: str) -> None:
    """
    ส่งข้อความผ่าน Telegram Bot
    """
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    data = {
        "chat_id": chat_id,
        "text": text
    }
    try:
        requests.post(url, data=data, timeout=5)
    except Exception as e:
        print(f"[WARNING] ไม่สามารถส่งข้อความ Telegram: {e}")

def max_drawdown(equity_series: pd.Series) -> float:
    """
    คำนวณ Max Drawdown จาก Series ของ equity (cumulative PnL)
    equity_series: pandas Series ของผลรวมกำไรสะสม over time
    คืนค่า Max Drawdown (positive float)
    """
    # คำนวณ peak-to-trough ใน equity curve
    cummax = equity_series.cummax()
    drawdowns = cummax - equity_series
    return float(drawdowns.max()) if not drawdowns.empty else 0.0
