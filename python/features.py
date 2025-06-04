"""
file: python/features.py
วัตถุประสงค์:
  - อ่าน data/historical.csv
  - คำนวณฟีเจอร์ตาม ICT GoldenPulse Logic (MSS, FVG, Fibonacci, ATR, VWAP, EMA/RSI/ADX, pattern)
  - เซฟเป็น data/data_with_features.csv
"""

import os
import pandas as pd
import numpy as np
import talib

def compute_features(historical_csv: str, output_csv: str):
    # อ่านข้อมูล historical.csv
    if not os.path.isfile(historical_csv):
        raise FileNotFoundError(f"ไม่พบไฟล์ historical: {historical_csv}")
    df = pd.read_csv(historical_csv, parse_dates=['time'])
    df = df.sort_values('time').reset_index(drop=True)

    # เตรียมคอลัมน์ MSS และ Swing
    df['swingHigh'] = np.nan
    df['swingLow']  = np.nan
    df['isBullMSS'] = False
    df['mssTime']   = pd.NaT

    # 1. คำนวณ MSS (Market Structure Shift) — ใช้เกณฑ์ “close ทะลุ high/low ของ bar ก่อนหน้า”
    for i in range(1, len(df)):
        # Bull MSS: ถ้า close[i] > high[i-1]
        if df.loc[i, 'close'] > df.loc[i-1, 'high']:
            df.loc[i, 'isBullMSS'] = True
            df.loc[i, 'swingHigh'] = df.loc[i, 'high']
            df.loc[i, 'swingLow']  = df.loc[i, 'low']
            df.loc[i, 'mssTime']   = df.loc[i, 'time']
        # Bear MSS: ถ้า close[i] < low[i-1]
        elif df.loc[i, 'close'] < df.loc[i-1, 'low']:
            df.loc[i, 'isBullMSS'] = False
            df.loc[i, 'swingLow']  = df.loc[i, 'low']
            df.loc[i, 'swingHigh'] = df.loc[i, 'high']
            df.loc[i, 'mssTime']   = df.loc[i, 'time']

    # 2. คำนวณ FVG (Fair Value Gap)
    df['FVG_Bottom'] = 0.0
    df['FVG_Top']    = 0.0
    df['timeFVG']    = pd.NaT

    for idx in df.index:
        if pd.isna(df.loc[idx, 'mssTime']):
            continue
        for j in range(idx-1, 1, -1):
            # ถ้า 3 แท่งก่อนหน้าเป็นแท่งเขียว (green)
            if (
                df.loc[j-2, 'close'] > df.loc[j-2, 'open'] and
                df.loc[j-1, 'close'] > df.loc[j-1, 'open'] and
                df.loc[j,   'close'] > df.loc[j,   'open']
            ):
                bottom = df.loc[j-1, 'low']
                top    = df.loc[j,   'high']
                if bottom > top:
                    df.loc[idx, 'FVG_Bottom'] = top
                    df.loc[idx, 'FVG_Top']    = bottom
                    df.loc[idx, 'timeFVG']    = df.loc[j-2, 'time']
                    break
            # ถ้า 3 แท่งก่อนหน้าเป็นแท่งแดง (red)
            if (
                df.loc[j-2, 'close'] < df.loc[j-2, 'open'] and
                df.loc[j-1, 'close'] < df.loc[j-1, 'open'] and
                df.loc[j,   'close'] < df.loc[j,   'open']
            ):
                bottom = df.loc[j,   'low']
                top    = df.loc[j-1, 'high']
                if top > bottom:
                    df.loc[idx, 'FVG_Bottom'] = bottom
                    df.loc[idx, 'FVG_Top']    = top
                    df.loc[idx, 'timeFVG']    = df.loc[j-2, 'time']
                    break

    # 3. คำนวณ Fibonacci levels
    df['fib61'] = np.nan
    df['fib50'] = np.nan
    df['fib38'] = np.nan

    for idx in df.index:
        if not pd.isna(df.loc[idx, 'mssTime']):
            swingLow  = df.loc[idx, 'swingLow']
            swingHigh = df.loc[idx, 'swingHigh']
            diff = swingHigh - swingLow
            if df.loc[idx, 'isBullMSS']:
                df.loc[idx, 'fib61'] = swingHigh - 0.618 * diff
                df.loc[idx, 'fib50'] = swingHigh - 0.50  * diff
                df.loc[idx, 'fib38'] = swingHigh - 0.382 * diff
            else:
                df.loc[idx, 'fib61'] = swingLow + 0.618 * diff
                df.loc[idx, 'fib50'] = swingLow + 0.50  * diff
                df.loc[idx, 'fib38'] = swingLow + 0.382 * diff

    # 4. คำนวณ ATR14 (M1)
    df['TR'] = np.maximum.reduce([
        df['high'] - df['low'],
        (df['high'] - df['close'].shift(1)).abs(),
        (df['low']  - df['close'].shift(1)).abs()
    ])
    df['ATR14'] = df['TR'].rolling(window=14).mean()

    # 5. VWAP (M1) over last 14 bars
    df['typical'] = (df['high'] + df['low'] + df['close']) / 3.0
    df['PV']      = df['typical'] * df['tick_volume']
    df['VWAP_M1'] = df['PV'].rolling(window=14).sum() / df['tick_volume'].rolling(window=14).sum()

    # 6. Resample to M15 for EMA, RSI, ADX (ใช้ '15min')
    df_15 = df[['time', 'high', 'low', 'close']].copy()
    df_15 = df_15.set_index('time').resample('15min').agg({
        'high': 'max',
        'low':  'min',
        'close':'last'
    }).dropna()
    df_15['EMA50'] = talib.EMA(df_15['close'], timeperiod=50)
    df_15['EMA200']= talib.EMA(df_15['close'], timeperiod=200)
    df_15['RSI14'] = talib.RSI(df_15['close'], timeperiod=14)
    df_15['ADX14'] = talib.ADX(df_15['high'], df_15['low'], df_15['close'], timeperiod=14)
    df_15 = df_15[['EMA50', 'EMA200', 'RSI14', 'ADX14']].reset_index()

    # Merge indicators กลับลง M1 dataframe
    df = pd.merge_asof(
        df.sort_values('time'),
        df_15.sort_values('time'),
        on='time',
        direction='backward'
    )
    df.rename(columns={
        'EMA50':  'EMA50_M15',
        'EMA200': 'EMA200_M15',
        'RSI14':  'RSI14_M15',
        'ADX14':  'ADX14_M15'
    }, inplace=True)

    # 7. Candlestick Pattern Flags (M1) for Secondary Filter
    df['pattern_flag'] = 0
    for idx in df.index[2:]:
        if df.loc[idx, 'time'] == df.loc[idx, 'timeFVG']:
            prev2 = df.loc[idx-2]
            prev  = df.loc[idx-1]
            if df.loc[idx, 'isBullMSS']:
                # Bullish Engulfing
                if (prev2['close'] < prev2['open'] and
                    prev['close'] > prev['open'] and
                    prev['open'] < prev2['close'] and
                    prev['close'] > prev2['open']):
                    df.loc[idx, 'pattern_flag'] = 1
                # Hammer
                body = abs(prev['close'] - prev['open'])
                lowerWick = (prev['open'] if prev['open'] < prev['close'] else prev['close']) - prev['low']
                if lowerWick >= 2 * body and body <= 0.3 * (prev['high'] - prev['low']):
                    df.loc[idx, 'pattern_flag'] = 1
            else:
                # Bearish Engulfing
                if (prev2['close'] > prev2['open'] and
                    prev['close'] < prev['open'] and
                    prev['open'] > prev2['close'] and
                    prev['close'] < prev2['open']):
                    df.loc[idx, 'pattern_flag'] = 1
                # Shooting Star
                body = abs(prev['close'] - prev['open'])
                upperWick = (prev['high'] - prev['open'] if prev['close'] < prev['open'] 
                             else prev['high'] - prev['close'])
                if upperWick >= 2 * body and body <= 0.3 * (prev['high'] - prev['low']):
                    df.loc[idx, 'pattern_flag'] = 1

    # 8. บันทึกไฟล์ data_with_features.csv
    df_out = df[[
        'time', 'open', 'high', 'low', 'close', 'tick_volume',
        'isBullMSS', 'swingLow', 'swingHigh', 'mssTime',
        'FVG_Bottom', 'FVG_Top', 'timeFVG',
        'fib61', 'fib50', 'fib38', 'ATR14', 'VWAP_M1',
        'EMA50_M15', 'EMA200_M15', 'RSI14_M15', 'ADX14_M15',
        'tick_volume', 'pattern_flag'
    ]]
    os.makedirs(os.path.dirname(output_csv), exist_ok=True)
    df_out.to_csv(output_csv, index=False)
    print(f"[INFO] Saved features data to {output_csv}")

if __name__ == "__main__":
    # Paths
    historical_csv = os.path.abspath(os.path.join(os.path.dirname(__file__), "../data/historical.csv"))
    output_csv     = os.path.abspath(os.path.join(os.path.dirname(__file__), "../data/data_with_features.csv"))
    compute_features(historical_csv, output_csv)
