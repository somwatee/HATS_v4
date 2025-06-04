import pandas as pd

# โหลด historical.csv
df = pd.read_csv(r"C:/HATS_v4/data/historical.csv", parse_dates=["time"])
df = df.sort_values("time").reset_index(drop=True)

# สร้างคอลัมน์ previous high/low
df["prev_high"] = df["high"].shift(1)
df["prev_low"]  = df["low"].shift(1)

# นับจำนวน bar ที่ close ทะลุ high ของ bar ก่อนหน้า (Bull signal)
count_bull = (df["close"] > df["prev_high"]).sum()

# นับจำนวน bar ที่ close ทะลุ low ของ bar ก่อนหน้า (Bear signal)
count_bear = (df["close"] < df["prev_low"]).sum()

print(f"จำนวน bar ที่ close > previous high: {count_bull}")
print(f"จำนวน bar ที่ close < previous low : {count_bear}")

# แสดงตัวอย่าง 10 บาร์แรกที่เกิด bull MSS (ถ้ามี)
bull_indices = df.index[df["close"] > df["prev_high"]].tolist()
bear_indices = df.index[df["close"] < df["prev_low"]].tolist()
print("\nตัวอย่าง bar ที่ close > previous high (Bull MSS):")
print(df.loc[bull_indices[:10], ["time", "open", "high", "low", "close", "prev_high", "prev_low"]])
print("\nตัวอย่าง bar ที่ close < previous low (Bear MSS):")
print(df.loc[bear_indices[:10], ["time", "open", "high", "low", "close", "prev_high", "prev_low"]])
