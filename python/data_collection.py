"""
file: python/data_collection.py
วัตถุประสงค์:
  - โหลดค่า MT5 login จาก config.yaml
  - เชื่อม MT5 พร้อมล็อกอิน → ดึงข้อมูล M1 แล้วเซฟเป็น data/historical.csv
  - ถ้า MT5 ไม่พร้อม หรือดึงข้อมูลไม่สำเร็จ ให้ fallback ใช้ data/historical.csv เดิม (ถ้ามี)
"""

import os
import pandas as pd
import yaml

try:
    import MetaTrader5 as mt5
except ImportError:
    mt5 = None
    print("Warning: MetaTrader5 package not installed. จะใช้ data/historical.csv เป็น fallback เท่านั้น.")

def load_config(config_path: str) -> dict:
    """โหลด config จากไฟล์ YAML (UTF-8) แล้วคืน dict"""
    if not os.path.isfile(config_path):
        raise FileNotFoundError(f"ไม่พบไฟล์ config: {config_path}")
    with open(config_path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)

def fetch_historical(symbol: str, timeframe, bars: int, out_path: str,
                     login: int=None, password: str=None, server: str=None):
    """
    เชื่อม MT5 (พร้อมล็อกอินถ้ามีพารามิเตอร์) แล้วดึงข้อมูล M1
    """
    if mt5 is None:
        raise RuntimeError("MetaTrader5 package not available.")

    # ถ้ามีพารามิเตอร์ล็อกอิน ให้ initialize พร้อมกัน
    if login and password and server:
        if not mt5.initialize(login=login, password=password, server=server):
            raise RuntimeError(f"MT5 initialize with login failed, error code: {mt5.last_error()}")
    else:
        if not mt5.initialize():
            raise RuntimeError(f"MT5 initialize failed, error code: {mt5.last_error()}")

    # ตรวจสถานะล็อกอิน
    account_info = mt5.account_info()
    if account_info is None:
        mt5.shutdown()
        raise RuntimeError("MT5 not logged in or unable to get account info")

    # ดึงข้อมูล rates
    rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, bars)
    mt5.shutdown()

    if rates is None or len(rates) == 0:
        raise RuntimeError("MT5 returned no data (rates is None or empty)")

    df = pd.DataFrame(rates)
    if 'time' not in df.columns:
        raise RuntimeError("'time' column not found in MT5 data")

    df['time'] = pd.to_datetime(df['time'], unit='s')
    df = df[['time', 'open', 'high', 'low', 'close', 'tick_volume']]

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    df.to_csv(out_path, index=False)
    print(f"[INFO] Saved historical data to {out_path}")

if __name__ == "__main__":
    # โหลด config.yaml
    CONFIG_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "../config.yaml"))
    try:
        conf = load_config(CONFIG_PATH)
    except Exception as e:
        print(f"[ERROR] ไม่สามารถโหลด config: {e}")
        exit(1)

    # อ่านค่าใน config
    SYMBOL    = conf.get('Symbol', "XAUUSD")
    TIMEFRAME = mt5.TIMEFRAME_M1 if mt5 else None
    BARS      = conf.get('Bars', 50000)

    # ดึง Credential จาก config
    login    = conf.get('AccountLogin')
    password = conf.get('AccountPassword')
    server   = conf.get('AccountServer')

    OUT_PATH  = os.path.abspath(os.path.join(os.path.dirname(__file__), "../data/historical.csv"))

    if mt5:
        try:
            fetch_historical(SYMBOL, TIMEFRAME, BARS, OUT_PATH, login, password, server)
        except Exception as e:
            print(f"[WARNING] เกิดข้อผิดพลาดระหว่างดึงข้อมูลจาก MT5: {e}")
            if os.path.isfile(OUT_PATH):
                print(f"[INFO] จะใช้ไฟล์ fallback: {OUT_PATH}")
            else:
                print(f"[ERROR] ไม่พบไฟล์ fallback CSV ที่ {OUT_PATH} จบการทำงาน")
    else:
        if os.path.isfile(OUT_PATH):
            print(f"[INFO] ไม่ได้เชื่อม MT5 → ใช้ data/historical.csv ที่มีอยู่")
        else:
            print(f"[ERROR] MetaTrader5 ไม่พร้อมใช้งาน และไม่พบไฟล์ fallback CSV: {OUT_PATH} จบการทำงาน")
