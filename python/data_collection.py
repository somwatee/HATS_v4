# file: python/data_collection.py
import pandas as pd
import MetaTrader5 as mt5
import os
import time

def fetch_historical_from_mt5(symbol: str, timeframe, bars: int, out_path: str):
    """
    เชื่อมต่อ MT5 ดึงข้อมูลราคาย้อนหลัง
    - symbol: เช่น "XAUUSD"
    - timeframe: mt5.TIMEFRAME_M1, mt5.TIMEFRAME_M15 ฯลฯ
    - bars: จำนวนแท่งเทียนที่จะดึง (เช่น 100000)
    - out_path: path ของไฟล์ CSV ที่จะเก็บ (เช่น "../data/historical.csv")
    """
    # ตรวจสอบโฟลเดอร์ปลายทาง ถ้ายังไม่มี สร้างขึ้น
    folder = os.path.dirname(out_path)
    os.makedirs(folder, exist_ok=True)

    # เริ่มต้นการเชื่อมต่อ MT5
    if not mt5.initialize():
        raise RuntimeError(f"MT5 initialize failed, error code = {mt5.last_error()}")

    # ดึงข้อมูล rates จากตำแหน่ง 0 (ล่าสุด) ย้อนกลับ 'bars' แท่ง
    rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, bars)
    if rates is None or len(rates) == 0:
        mt5.shutdown()
        raise RuntimeError("mt5.copy_rates_from_pos ไม่ได้ข้อมูลคืนมา")

    # แปลงเป็น DataFrame
    df = pd.DataFrame(rates)
    # แปลง timestamp เป็น datetime
    df['time'] = pd.to_datetime(df['time'], unit='s')
    # เก็บเฉพาะคอลัมน์ที่ต้องการ
    df = df[['time', 'open', 'high', 'low', 'close', 'tick_volume']]
    # บันทึกเป็น CSV
    df.to_csv(out_path, index=False)
    print(f"Saved {len(df)} bars to {out_path}")

    # ปิดการเชื่อมต่อ MT5
    mt5.shutdown()


def fetch_historical_from_csv(in_path: str, out_path: str):
    """
    อ่านข้อมูลจากไฟล์ CSV เดิม (ถ้ามี) แล้วคัดเลือกเฉพาะคอลัมน์ time, open, high, low, close, tick_volume
    - in_path: path ของ CSV ต้นทาง
    - out_path: path ของ CSV ปลายทาง (../data/historical.csv)
    """
    if not os.path.exists(in_path):
        raise FileNotFoundError(f"ไม่พบไฟล์ต้นทาง: {in_path}")

    df = pd.read_csv(in_path, parse_dates=['time'])
    # หากไฟล์ต้นทางมีคอลัมน์มากกว่า ให้กรองเฉพาะคอลัมน์ที่ต้องการ
    df = df[['time', 'open', 'high', 'low', 'close', 'tick_volume']]
    # สร้างโฟลเดอร์ปลายทางถ้ายังไม่มี
    folder = os.path.dirname(out_path)
    os.makedirs(folder, exist_ok=True)
    df.to_csv(out_path, index=False)
    print(f"Copied {len(df)} bars from {in_path} to {out_path}")


if __name__ == "__main__":
    """
    เมื่อรันไฟล์นี้ จะพยายามดึงจาก MT5 ก่อน
    ถ้า MT5 ไม่สามารถเชื่อมต่อได้ ให้ fallback มาอ่านจาก CSV ต้นทาง (ปรับ path ตามสะดวก)
    """
    symbol = "XAUUSD"
    timeframe = mt5.TIMEFRAME_M1
    bars = 100000
    out_csv = "../data/historical.csv"

    try:
        fetch_historical_from_mt5(symbol, timeframe, bars, out_csv)
    except Exception as e:
        print(f"MT5 fetch failed: {e}")
        # fallback: อ่านจาก CSV ต้นทาง (ถ้ามี)
        in_csv = "../data/historical_source.csv"  # ถ้ามีไฟล์สำรอง
        try:
            fetch_historical_from_csv(in_csv, out_csv)
        except Exception as ex:
            print(f"CSV fallback failed: {ex}")
