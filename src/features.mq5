// file: src/features.mq5
#property strict

// ฟังก์ชันสำหรับคำนวณ MSS, FVG, Fibonacci, ATR, VWAP, Indicators, Candlestick Pattern (Real-time)
// คืนค่าผ่าน parameters by reference พร้อม debug Print() เพื่อเช็กว่าแต่ละขั้นทำงานหรือไม่

#include <Trade\SymbolInfo.mqh>  // สำหรับ SYMBOL_VOLUME, SYMBOL_BID, SYMBOL_ASK ฯลฯ

// รับตัวแปร input จาก config.mq5
extern int    InpATR_Period_M1;
extern int    InpEMA_Fast_M15;
extern int    InpEMA_Slow_M15;
extern int    InpRSI_Period_M15;
extern int    InpADX_Period_M15;

//+------------------------------------------------------------------+
//| GetRealTimeFeatures                                              |
//| คำนวณ MSS, FVG, Fibonacci, ATR, VWAP_M1, EMA15, RSI15, ADX15,   |
//| และ Candlestick Pattern (Hammer, Engulfing, Shooting Star)        |
//| bar_index = 0 หมายถึงแท่งล่าสุด, 1=แท่งก่อนหน้า, ฯลฯ            |
//+------------------------------------------------------------------+
bool GetRealTimeFeatures(int bar_index,
                         bool &isBullMSS, double &swingLow, double &swingHigh, datetime &mssTime,
                         double &FVG_Bottom, double &FVG_Top, datetime &timeFVG,
                         double &fib61, double &fib50, double &fib38,
                         double &ATR14, double &VWAP_M1,
                         double &EMA50_M15, double &EMA200_M15, double &RSI14_M15, double &ADX14_M15,
                         int &pattern_flag)
  {
   // --- (0) โหลด MqlRates ของ M1 (bar_index+2 แท่งเพื่อเช็ค swing)  ---
   PrintFormat(">> features: Calling GetRealTimeFeatures(bar_index=%d)", bar_index);
   MqlRates ratesM1[];
   int barsNeeded = bar_index + 3;
   if(CopyRates(_Symbol, PERIOD_M1, 0, barsNeeded, ratesM1) != barsNeeded)
     {
      PrintFormat(">> features: CopyRates M1 failed (needed %d, got %d)", barsNeeded, ArraySize(ratesM1));
      return(false);
     }

   // เตรียมค่าดีฟอลต์
   isBullMSS   = false;
   swingLow    = 0.0;
   swingHigh   = 0.0;
   mssTime     = 0;
   FVG_Bottom  = 0.0;
   FVG_Top     = 0.0;
   timeFVG     = 0;
   fib61       = 0.0;
   fib50       = 0.0;
   fib38       = 0.0;
   ATR14       = 0.0;
   VWAP_M1     = 0.0;
   EMA50_M15   = 0.0;
   EMA200_M15  = 0.0;
   RSI14_M15   = 0.0;
   ADX14_M15   = 0.0;
   pattern_flag = 0;

   int i = bar_index;  // i ชี้ไปที่แท่งปัจจุบันใน ratesM1[]

   // --- (1) MSS (Market Structure Shift) Debug ---
   Print(">> features: Checking MSS...");
   // Swing High: local max (>= เพื่อนบ้าน)
   if(ratesM1[i+1].high >= ratesM1[i].high && ratesM1[i+1].high >= ratesM1[i+2].high)
     {
      isBullMSS = true;
      swingHigh = ratesM1[i+1].high;
      swingLow  = ratesM1[i+1].low;
      mssTime   = ratesM1[i].time;
      PrintFormat(">> features: Found Bull MSS at time %s, swingHigh=%.5f, swingLow=%.5f",
                  TimeToString(mssTime, TIME_DATE|TIME_MINUTES), swingHigh, swingLow);
     }
   // Swing Low: local min (<= เพื่อนบ้าน)
   if(ratesM1[i+1].low <= ratesM1[i].low && ratesM1[i+1].low <= ratesM1[i+2].low)
     {
      isBullMSS = false;
      swingLow  = ratesM1[i+1].low;
      swingHigh = ratesM1[i+1].high;
      mssTime   = ratesM1[i].time;
      PrintFormat(">> features: Found Bear MSS at time %s, swingLow=%.5f, swingHigh=%.5f",
                  TimeToString(mssTime, TIME_DATE|TIME_MINUTES), swingLow, swingHigh);
     }
   if(mssTime == 0)
     Print(">> features: No MSS found for this bar.");

   // --- (2) FVG (Fair Value Gap) Debug ---
   Print(">> features: Checking FVG...");
   // หา FVG โดยเดินย้อนกลับจาก i-1 ถึง index=2 (อย่างน้อยต้องมี 3 แท่งก่อนหน้า)
   for(int j = i-1; j >= 2; j--)
     {
      // 3 แท่งก่อน j เป็นแท่งเขียว (green)
      bool isGreen1 = (ratesM1[j-2].close > ratesM1[j-2].open);
      bool isGreen2 = (ratesM1[j-1].close > ratesM1[j-1].open);
      bool isGreen3 = (ratesM1[j].close   > ratesM1[j].open);
      if(isGreen1 && isGreen2 && isGreen3)
        {
         double bottom = ratesM1[j-1].low;
         double top    = ratesM1[j].high;
         if(bottom > top)
           {
            FVG_Bottom = top;
            FVG_Top    = bottom;
            timeFVG    = ratesM1[j-2].time;
            PrintFormat(">> features: Found Green FVG at timeFVG=%s, FVG=[%.5f,%.5f]",
                        TimeToString(timeFVG, TIME_DATE|TIME_MINUTES), FVG_Bottom, FVG_Top);
            break;
           }
        }
      // 3 แท่งก่อน j เป็นแท่งแดง (red)
      bool isRed1 = (ratesM1[j-2].close < ratesM1[j-2].open);
      bool isRed2 = (ratesM1[j-1].close < ratesM1[j-1].open);
      bool isRed3 = (ratesM1[j].close   < ratesM1[j].open);
      if(isRed1 && isRed2 && isRed3)
        {
         double bottom = ratesM1[j].low;
         double top    = ratesM1[j-1].high;
         if(top > bottom)
           {
            FVG_Bottom = bottom;
            FVG_Top    = top;
            timeFVG    = ratesM1[j-2].time;
            PrintFormat(">> features: Found Red FVG at timeFVG=%s, FVG=[%.5f,%.5f]",
                        TimeToString(timeFVG, TIME_DATE|TIME_MINUTES), FVG_Bottom, FVG_Top);
            break;
           }
        }
     }
   if(FVG_Bottom == 0.0 && FVG_Top == 0.0)
     Print(">> features: No FVG found for this bar.");

   // --- (3) Fibonacci Levels Debug ---
   if(mssTime != 0)
     {
      double diff = swingHigh - swingLow;
      if(isBullMSS)
        {
         fib61 = swingHigh - 0.618 * diff;
         fib50 = swingHigh - 0.500 * diff;
         fib38 = swingHigh - 0.382 * diff;
        }
      else
        {
         fib61 = swingLow + 0.618 * diff;
         fib50 = swingLow + 0.500 * diff;
         fib38 = swingLow + 0.382 * diff;
        }
      PrintFormat(">> features: Fib levels: fib61=%.5f, fib50=%.5f, fib38=%.5f", fib61, fib50, fib38);
     }
   else
     {
      Print(">> features: Skipping Fib because mssTime=0");
     }

   // --- (4) ATR14 (M1) Debug ---
   Print(">> features: Calculating ATR14...");
   // คำนวณ True Range (TR) สำหรับแต่ละ bar แล้วหา rolling mean 14 บาร์
   int totalBars = ArraySize(ratesM1);
   if(totalBars < 15)
     {
      PrintFormat(">> features: Not enough bars to calculate ATR (have %d, need 15)", totalBars);
      ATR14 = 0.0;
     }
   else
     {
      // คำนวณ TR จาก column ratesM1
      double TRArray[];
      ArrayResize(TRArray, totalBars);
      for(int k = 1; k < totalBars; k++)
        {
         double high_k      = ratesM1[k].high;
         double low_k       = ratesM1[k].low;
         double prevClose   = ratesM1[k-1].close;
         double tr1 = high_k - low_k;
         double tr2 = fabs(high_k - prevClose);
         double tr3 = fabs(low_k  - prevClose);
         TRArray[k] = MathMax(tr1, MathMax(tr2, tr3));
        }
      // คำนวณ rolling mean ของ 14 bars (k from totalBars-14 to totalBars-1 คือล่าสุด)
      double sumTR = 0.0;
      for(int k = totalBars-14; k < totalBars; k++)
         sumTR += TRArray[k];
      ATR14 = sumTR / 14.0;
      PrintFormat(">> features: ATR14 = %.5f", ATR14);
     }

   // --- (5) VWAP_M1 (M1) Debug ---
   Print(">> features: Calculating VWAP_M1...");
   if(totalBars < 14)
     {
      VWAP_M1 = 0.0;
      Print(">> features: Not enough bars to calculate VWAP (need 14 M1 bars).");
     }
   else
     {
      double sumPV  = 0.0;
      double sumVol = 0.0;
      for(int k = totalBars-14; k < totalBars; k++)
        {
         double typical = (ratesM1[k].high + ratesM1[k].low + ratesM1[k].close) / 3.0;
         double vol     = ratesM1[k].tick_volume;
         sumPV  += typical * vol;
         sumVol += vol;
        }
      VWAP_M1 = (sumVol == 0.0) ? ratesM1[totalBars-1].close : (sumPV / sumVol);
      PrintFormat(">> features: VWAP_M1 = %.5f", VWAP_M1);
     }

   // --- (6) Resample to M15, คำนวณ EMA50/EMA200, RSI14, ADX14  Debug ---
   Print(">> features: Resampling to M15 for EMA/RSI/ADX...");
   // สร้าง dataframe จาก ratesM1 ที่มี column time, high, low, close
   int rowsM1 = ArraySize(ratesM1);
   datetime timesM1[];
   double    highsM1[], lowsM1[], closesM1[];
   ArrayResize(timesM1, rowsM1);
   ArrayResize(highsM1, rowsM1);
   ArrayResize(lowsM1, rowsM1);
   ArrayResize(closesM1, rowsM1);
   for(int k = 0; k < rowsM1; k++)
     {
      timesM1[k]  = ratesM1[k].time;
      highsM1[k]  = ratesM1[k].high;
      lowsM1[k]   = ratesM1[k].low;
      closesM1[k] = ratesM1[k].close;
     }

   // นำข้อมูล M1 มา into dynamic array แล้วสร้างช่วง 15-min
   // เนื่องจาก MQL5 ไม่มี pandas, เราจะใช้ iMA / iRSI / iADX โดยตรงบน timeframe M15
   int handleEMA50 = iMA(_Symbol, PERIOD_M15, InpEMA_Fast_M15, 0, MODE_EMA, PRICE_CLOSE);
   int handleEMA200= iMA(_Symbol, PERIOD_M15, InpEMA_Slow_M15, 0, MODE_EMA, PRICE_CLOSE);
   int handleRSI   = iRSI(_Symbol, PERIOD_M15, InpRSI_Period_M15, PRICE_CLOSE);
   int handleADX   = iADX(_Symbol, PERIOD_M15, InpADX_Period_M15, PRICE_MEDIAN);

   double tempArr[];
   // EMA50_M15
   if(CopyBuffer(handleEMA50, 0, 0, 1, tempArr) == 1)
     {
      EMA50_M15 = tempArr[0];
      PrintFormat(">> features: EMA50_M15 = %.5f", EMA50_M15);
     }
   else Print(">> features: CopyBuffer EMA50_M15 failed");

   // EMA200_M15
   if(CopyBuffer(handleEMA200, 0, 0, 1, tempArr) == 1)
     {
      EMA200_M15 = tempArr[0];
      PrintFormat(">> features: EMA200_M15 = %.5f", EMA200_M15);
     }
   else Print(">> features: CopyBuffer EMA200_M15 failed");

   // RSI14_M15
   if(CopyBuffer(handleRSI, 0, 0, 1, tempArr) == 1)
     {
      RSI14_M15 = tempArr[0];
      PrintFormat(">> features: RSI14_M15 = %.2f", RSI14_M15);
     }
   else Print(">> features: CopyBuffer RSI14_M15 failed");

   // ADX14_M15
   if(CopyBuffer(handleADX, 0, 0, 1, tempArr) == 1)
     {
      ADX14_M15 = tempArr[0];
      PrintFormat(">> features: ADX14_M15 = %.2f", ADX14_M15);
     }
   else Print(">> features: CopyBuffer ADX14_M15 failed");

   // --- (7) Candlestick Pattern Flag Debug ---
   Print(">> features: Checking Candlestick Patterns...");
   if(timeFVG != 0)
     {
      // ต้องดึง rates M1 ณ timeFVG และ 2 แท่งก่อนหน้า
      MqlRates patRates[3];
      // CopyRates นำเข้าจาก timeFVG (ตำแหน่ง bar ตาม timestamp)
      if(CopyRates(_Symbol, PERIOD_M1, timeFVG, 3, patRates) == 3)
        {
         MqlRates prev2 = patRates[1];
         MqlRates prev  = patRates[0];
         if(isBullMSS)
           {
            // Bullish Engulfing
            if(prev2.close < prev2.open && prev.close > prev.open &&
               prev.open < prev2.close && prev.close > prev2.open)
              {
               pattern_flag = 1;
               Print(">> features: Found Bullish Engulfing @ timeFVG");
              }
            // Hammer
            double body = fabs(prev.close - prev.open);
            double lowerWick = (prev.open < prev.close ? prev.open : prev.close) - prev.low;
            if(lowerWick >= 2 * body && body <= 0.3 * (prev.high - prev.low))
              {
               pattern_flag = 1;
               Print(">> features: Found Hammer @ timeFVG");
              }
           }
         else
           {
            // Bearish Engulfing
            if(prev2.close > prev2.open && prev.close < prev.open &&
               prev.open > prev2.close && prev.close < prev2.open)
              {
               pattern_flag = 1;
               Print(">> features: Found Bearish Engulfing @ timeFVG");
              }
            // Shooting Star
            double body = fabs(prev.close - prev.open);
            double upperWick = (prev.close < prev.open ? prev.high - prev.open : prev.high - prev.close);
            if(upperWick >= 2 * body && body <= 0.3 * (prev.high - prev.low))
              {
               pattern_flag = 1;
               Print(">> features: Found Shooting Star @ timeFVG");
              }
           }
        }
      else
        {
         Print(">> features: CopyRates for Candlestick Patterns failed at timeFVG");
        }
     }
   else
     {
      Print(">> features: Skipping Candlestick Pattern (timeFVG = 0)");
     }

   // --- (8) จบฟังก์ชัน ---  
   Print(">> features: GetRealTimeFeatures completed successfully");
   return(true);
  }
