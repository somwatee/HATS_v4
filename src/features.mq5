// file: src/features.mq5
#property strict

#include "config.mq5"

//+------------------------------------------------------------------+
//| ฟังก์ชัน: GetRealTimeFeatures                                   |
//| วัตถุประสงค์:                                                   |
//|   คำนวณฟีเจอร์ต่างๆ แบบเรียลไทม์ สำหรับ EA:                     |
//|   - MSS (Market Structure Shift)                                  |
//|   - FVG (Fair Value Gap)                                          |
//|   - Fibonacci Levels (fib61, fib50, fib38)                        |
//|   - ATR14 (M1)                                                    |
//|   - VWAP_M1 (M1)                                                  |
//|   - EMA50_M15, EMA200_M15, RSI14_M15, ADX14_M15 (M15)              |
//|   - Candlestick Pattern Flag (Bullish Engulfing, Hammer,          |
//|     Bearish Engulfing, Shooting Star)                              |
//|                                                                  |
//| พารามิเตอร์นำเข้า:                                               |
//|   int bar_index          : ดัชนีบาร์ (0 = แท่งปัจจุบัน, 1 = บาร์ก่อนหน้า, ...)    |
//| พารามิเตอร์ส่งออก (by reference):                              |
//|   bool   &isBullMSS      : true=Bull MSS, false=Bear MSS          |
//|   double &swingLow       : ราคาสวิง Low ของ MSS                     |
//|   double &swingHigh      : ราคาสวิง High ของ MSS                    |
//|   datetime &mssTime      : เวลาของ bar ที่เกิด MSS                  |
//|   double &FVG_Bottom     : ราคาด้านล่างของ Fair Value Gap          |
//|   double &FVG_Top        : ราคาด้านบนของ Fair Value Gap            |
//|   datetime &timeFVG      : เวลาของ bar แรกที่พบ FVG                 |
//|   double &fib61          : ราคาระดับ Fibonacci 61.8%                |
//|   double &fib50          : ราคาระดับ Fibonacci 50%                  |
//|   double &fib38          : ราคาระดับ Fibonacci 38.2%                |
//|   double &ATR14          : ค่า ATR14 (M1)                            |
//|   double &VWAP_M1        : ค่า VWAP M1 (14 แท่ง)                     |
//|   double &EMA50_M15      : ค่า EMA50 บนกรอบเวลา M15                  |
//|   double &EMA200_M15     : ค่า EMA200 บนกรอบเวลา M15                 |
//|   double &RSI14_M15      : ค่า RSI14 บนกรอบเวลา M15                  |
//|   double &ADX14_M15      : ค่า ADX14 บนกรอบเวลา M15                  |
//|   int    &pattern_flag   : 0 = ไม่มี, 1 = พบ pattern (Secondary Filter)  |
//|                                                                  |
//| คืนค่า:                                                          |
//|   true  = คำนวณสำเร็จ                                              |
//|   false = เกิดข้อผิดพลาด                                            |
//+------------------------------------------------------------------+
 
bool GetRealTimeFeatures(int bar_index,
                         bool   &isBullMSS,
                         double &swingLow,
                         double &swingHigh,
                         datetime &mssTime,
                         double &FVG_Bottom,
                         double &FVG_Top,
                         datetime &timeFVG,
                         double &fib61,
                         double &fib50,
                         double &fib38,
                         double &ATR14,
                         double &VWAP_M1,
                         double &EMA50_M15,
                         double &EMA200_M15,
                         double &RSI14_M15,
                         double &ADX14_M15,
                         int    &pattern_flag)
{
   //--- ดึง M1 rates จำนวน bar_index+3 แท่ง (เพื่อเข้าถึง bar[i], bar[i+1], bar[i+2])
   MqlRates ratesM1[];
   int need_copied = bar_index + 3;
   if(CopyRates(_Symbol, PERIOD_M1, 0, need_copied, ratesM1) != need_copied)
      return(false);

   //--- เริ่มต้นค่า default
   isBullMSS    = false;
   swingLow     = 0.0;
   swingHigh    = 0.0;
   mssTime      = 0;
   FVG_Bottom   = 0.0;
   FVG_Top      = 0.0;
   timeFVG      = 0;
   fib61        = 0.0;
   fib50        = 0.0;
   fib38        = 0.0;
   ATR14        = 0.0;
   VWAP_M1      = 0.0;
   EMA50_M15    = 0.0;
   EMA200_M15   = 0.0;
   RSI14_M15    = 0.0;
   ADX14_M15    = 0.0;
   pattern_flag = 0;

   int i = bar_index; // ดัชนีแท่งล่าสุด (0 = แท่งปัจจุบัน, 1 = บาร์ก่อนหน้า, ...)

   //--- 1) MSS: หา Swing High/Low โดยใช้เงื่อนไข >=, <= (ผ่อนคลาย)
   // Swing High (Bull MSS)
   if(ratesM1[i+1].high >= ratesM1[i].high && ratesM1[i+1].high >= ratesM1[i+2].high)
   {
      if(ratesM1[i].close > ratesM1[i+1].high)
      {
         isBullMSS  = true;
         swingHigh  = ratesM1[i+1].high;
         swingLow   = ratesM1[i+1].low;
         mssTime    = ratesM1[i].time;
      }
   }
   // Swing Low (Bear MSS)
   if(ratesM1[i+1].low <= ratesM1[i].low && ratesM1[i+1].low <= ratesM1[i+2].low)
   {
      if(ratesM1[i].close < ratesM1[i+1].low)
      {
         isBullMSS   = false;
         swingLow    = ratesM1[i+1].low;
         swingHigh   = ratesM1[i+1].high;
         mssTime     = ratesM1[i].time;
      }
   }

   //--- 2) FVG: วนหา 3-bar cluster ก่อน mssTime (ตรวจ j = i+1 ... i+10)
   for(int j = i+1; j < (i+11) && j+2 < ArraySize(ratesM1); j++)
   {
      // เช็ค 3 แท่งก่อนหน้านี้เป็นแท่งเขียว (green)
      bool isGreen1 = (ratesM1[j].close > ratesM1[j].open);
      bool isGreen2 = (ratesM1[j+1].close > ratesM1[j+1].open);
      bool isGreen3 = (ratesM1[j+2].close > ratesM1[j+2].open);
      if(isGreen1 && isGreen2 && isGreen3)
      {
         double bottom = ratesM1[j+1].low;
         double top    = ratesM1[j+2].high;
         if(bottom > top)
         {
            FVG_Bottom = top;
            FVG_Top    = bottom;
            timeFVG    = ratesM1[j].time;
            break;
         }
      }
      // เช็ค 3 แท่งก่อนหน้านี้เป็นแท่งแดง (red)
      bool isRed1 = (ratesM1[j].close < ratesM1[j].open);
      bool isRed2 = (ratesM1[j+1].close < ratesM1[j+1].open);
      bool isRed3 = (ratesM1[j+2].close < ratesM1[j+2].open);
      if(isRed1 && isRed2 && isRed3)
      {
         double bottom = ratesM1[j+2].low;
         double top    = ratesM1[j+1].high;
         if(top > bottom)
         {
            FVG_Bottom = bottom;
            FVG_Top    = top;
            timeFVG    = ratesM1[j].time;
            break;
         }
      }
   }

   //--- 3) Fibonacci Levels (กรณีมี MSS)
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
   }

   //--- 4) ATR14 (M1) โดยสร้าง handle และใช้ CopyBuffer
   int handleATR = iATR(_Symbol, PERIOD_M1, InpATR_Period_M1);
   if(handleATR == INVALID_HANDLE)
      return(false);
   double arrATR[];
   if(CopyBuffer(handleATR, 0, 0, 1, arrATR) != 1)
   {
      IndicatorRelease(handleATR);
      return(false);
   }
   ATR14 = arrATR[0];
   IndicatorRelease(handleATR);

   //--- 5) VWAP_M1: คำนวณจาก 14 bar ล่าสุด
   MqlRates recentRates[];
   if(CopyRates(_Symbol, PERIOD_M1, 0, InpATR_Period_M1 + 1, recentRates) != (InpATR_Period_M1 + 1))
      return(false);
   double sumPV = 0.0, sumVol = 0.0;
   for(int k = 0; k < InpATR_Period_M1 + 1; k++)
   {
      double typical = (recentRates[k].high + recentRates[k].low + recentRates[k].close) / 3.0;
      double vol     = (double)recentRates[k].tick_volume;
      sumPV  += typical * vol;
      sumVol += vol;
   }
   VWAP_M1 = (sumVol == 0.0) ? recentRates[0].close : (sumPV / sumVol);

   //--- 6) EMA50_M15, EMA200_M15, RSI14_M15, ADX14_M15 (M15)
   int handleEMA50  = iMA(_Symbol, PERIOD_M15, InpEMA_Fast_M15, 0, MODE_EMA, PRICE_CLOSE);
   int handleEMA200 = iMA(_Symbol, PERIOD_M15, InpEMA_Slow_M15, 0, MODE_EMA, PRICE_CLOSE);
   int handleRSI   = iRSI(_Symbol, PERIOD_M15, InpRSI_Period_M15, PRICE_CLOSE);
   int handleADX   = iADX(_Symbol, PERIOD_M15, InpADX_Period_M15, PRICE_CLOSE);

   if(handleEMA50  == INVALID_HANDLE ||
      handleEMA200 == INVALID_HANDLE ||
      handleRSI    == INVALID_HANDLE ||
      handleADX    == INVALID_HANDLE)
   {
      // ถ้ามี handle ใดล้มเหลว ขอปล่อย handlers ที่สร้างแล้ว
      if(handleEMA50  != INVALID_HANDLE) IndicatorRelease(handleEMA50);
      if(handleEMA200 != INVALID_HANDLE) IndicatorRelease(handleEMA200);
      if(handleRSI    != INVALID_HANDLE) IndicatorRelease(handleRSI);
      if(handleADX    != INVALID_HANDLE) IndicatorRelease(handleADX);
      return(false);
   }

   double arrEMA50[], arrEMA200[], arrRSI[], arrADX[];
   if(CopyBuffer(handleEMA50,  0, 0, 1, arrEMA50)  != 1 ||
      CopyBuffer(handleEMA200, 0, 0, 1, arrEMA200) != 1 ||
      CopyBuffer(handleRSI,    0, 0, 1, arrRSI)     != 1 ||
      CopyBuffer(handleADX,    0, 0, 1, arrADX)     != 1)
   {
      // ปล่อย handlers ที่สร้างแล้ว
      IndicatorRelease(handleEMA50);
      IndicatorRelease(handleEMA200);
      IndicatorRelease(handleRSI);
      IndicatorRelease(handleADX);
      return(false);
   }

   EMA50_M15  = arrEMA50[0];
   EMA200_M15 = arrEMA200[0];
   RSI14_M15  = arrRSI[0];
   ADX14_M15  = arrADX[0];

   IndicatorRelease(handleEMA50);
   IndicatorRelease(handleEMA200);
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleADX);

   //--- 7) Candlestick Pattern Flag (M1) ณ timeFVG
   pattern_flag = 0;
   if(timeFVG != 0)
   {
      MqlRates patRates[3];
      int cnt = CopyRates(_Symbol, PERIOD_M1, timeFVG, 3, patRates);
      if(cnt == 3)
      {
         MqlRates prev2 = patRates[1];
         MqlRates prev  = patRates[0];
         if(isBullMSS)
         {
            // Bullish Engulfing
            if(prev2.close < prev2.open &&
               prev.close  > prev.open &&
               prev.open   < prev2.close &&
               prev.close  > prev2.open)
            {
               pattern_flag = 1;
            }
            // Hammer
            double body       = MathAbs(prev.close - prev.open);
            double lowerWick  = ((prev.open < prev.close) ? (prev.open - prev.low) : (prev.close - prev.low));
            if(lowerWick >= 2 * body && body <= 0.3 * (prev.high - prev.low))
            {
               pattern_flag = 1;
            }
         }
         else
         {
            // Bearish Engulfing
            if(prev2.close > prev2.open &&
               prev.close  < prev.open &&
               prev.open   > prev2.close &&
               prev.close  < prev2.open)
            {
               pattern_flag = 1;
            }
            // Shooting Star
            double body      = MathAbs(prev.close - prev.open);
            double upperWick = ((prev.close < prev.open) ? (prev.high - prev.open) : (prev.high - prev.close));
            if(upperWick >= 2 * body && body <= 0.3 * (prev.high - prev.low))
            {
               pattern_flag = 1;
            }
         }
      }
   }

   return(true);
}
