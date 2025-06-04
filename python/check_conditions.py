import pandas as pd

# 1. โหลดไฟล์ `ict_labels.csv` ที่มีคอลัมน์ฟีเจอร์ต่างๆ
df = pd.read_csv(r"C:/HATS_v4/data/ict_labels.csv", parse_dates=["time"])

# 2. นับจำนวนแถวที่เกิด MSS (Market Structure Shift)
#    เงื่อนไข: mssTime ไม่เป็น NaT (แปลว่าโค้ด MSS เคยจับ swing ได้)
mss_count = df["mssTime"].notna().sum()
print(f"จำนวน bar ที่เกิด MSS (มี mssTime): {mss_count}")

# 3. นับจำนวนแถวที่ตรวจเจอ FVG (FVG_Bottom != 0)
fvg_count = (df["FVG_Bottom"] != 0).sum()
print(f"จำนวน bar ที่ตรวจเจอ FVG (FVG_Bottom != 0): {fvg_count}")

# 4. เช็คเงื่อนไข Fib–FVG Overlap
#    แบ่งเป็นกรณี bull และ bear 
#    - Bull: FVG_Top >= fib38 และ FVG_Bottom <= fib61
#    - Bear: FVG_Bottom <= fib61 และ FVG_Top >= fib38
fib_overlap_bull = ((df["isBullMSS"]) &
                    (df["FVG_Top"] >= df["fib38"]) &
                    (df["FVG_Bottom"] <= df["fib61"])
                   ).sum()
fib_overlap_bear = ((~df["isBullMSS"]) &
                    (df["FVG_Bottom"] <= df["fib61"]) &
                    (df["FVG_Top"] >= df["fib38"])
                   ).sum()
fib_overlap_count = fib_overlap_bull + fib_overlap_bear
print(f"จำนวน bar ที่ fib–FVG overlap (ทั้ง bull + bear): {fib_overlap_count}")
print(f"  • Bull overlap: {fib_overlap_bull}")
print(f"  • Bear overlap: {fib_overlap_bear}")

# 5. เช็คเงื่อนไข HTF (High Timeframe Filter) บน M15
#    ใช้ ADX_Threshold = 18 (ค่าตั้งต้น)
adx_th = 18.0
htf_bull = ((df["isBullMSS"]) &
            (df["EMA50_M15"] > df["EMA200_M15"]) &
            (df["RSI14_M15"] > 50) &
            (df["ADX14_M15"] >= adx_th)
           ).sum()
htf_bear = ((~df["isBullMSS"]) &
            (df["EMA50_M15"] < df["EMA200_M15"]) &
            (df["RSI14_M15"] < 50) &
            (df["ADX14_M15"] >= adx_th)
           ).sum()
htf_count = htf_bull + htf_bear
print(f"จำนวน bar ที่ผ่าน HTF (ทั้ง bull + bear): {htf_count}")
print(f"  • HTF bull: {htf_bull}")
print(f"  • HTF bear: {htf_bear}")

# 6. เช็คเงื่อนไข Pullback (bar ก่อนหน้าอยู่ใน FVG)
#    pricePullback = close.shift(1)
prev_close = df["close"].shift(1)
pullback_bull = ((df["isBullMSS"]) &
                 (prev_close >= df["FVG_Bottom"]) &
                 (prev_close <= df["FVG_Top"])
                ).sum()
pullback_bear = ((~df["isBullMSS"]) &
                 (prev_close <= df["FVG_Top"]) &
                 (prev_close >= df["FVG_Bottom"])
                ).sum()
pullback_count = pullback_bull + pullback_bear
print(f"จำนวน bar ที่เกิด Pullback (ทั้ง bull + bear): {pullback_count}")
print(f"  • Pullback bull: {pullback_bull}")
print(f"  • Pullback bear: {pullback_bear}")

# 7. เช็คเงื่อนไข ICT Primary ครบทุกข้อพร้อมกัน
#    รวมนับทั้ง bull + bear ครั้งเดียว
#    (Fib overlap) & (Pullback) & (HTF)
cond_bull = ((df["isBullMSS"]) &
             # Fib overlap
             (df["FVG_Top"] >= df["fib38"]) &
             (df["FVG_Bottom"] <= df["fib61"]) &
             # Pullback
             (prev_close >= df["FVG_Bottom"]) &
             (prev_close <= df["FVG_Top"]) &
             # HTF
             (df["EMA50_M15"] > df["EMA200_M15"]) &
             (df["RSI14_M15"] > 50) &
             (df["ADX14_M15"] >= adx_th)
            )

cond_bear = ((~df["isBullMSS"]) &
             # Fib overlap
             (df["FVG_Bottom"] <= df["fib61"]) &
             (df["FVG_Top"] >= df["fib38"]) &
             # Pullback
             (prev_close <= df["FVG_Top"]) &
             (prev_close >= df["FVG_Bottom"]) &
             # HTF
             (df["EMA50_M15"] < df["EMA200_M15"]) &
             (df["RSI14_M15"] < 50) &
             (df["ADX14_M15"] >= adx_th)
            )

combined_count = (cond_bull | cond_bear).sum()
print(f"จำนวน bar ที่ผ่าน ICT Primary ครบทุกเงื่อนไข (Buy/Sell) ทั้งหมด: {combined_count}")
