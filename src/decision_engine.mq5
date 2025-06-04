// file: src/decision_engine.mq5
#property strict

#include "config.mq5"
#include "features.mq5"
#include "ml_interface.mq5"

enum SignalType
  {
   SIGNAL_NONE      = 0,
   SIGNAL_ICT_BUY   = 1,
   SIGNAL_ICT_SELL  = 2,
   SIGNAL_XGB_BUY   = 3,
   SIGNAL_XGB_SELL  = 4
  };

//+------------------------------------------------------------------+
//| ฟังก์ชัน: GetSignal                                             |
//| วัตถุประสงค์:                                                   |
//|   ตรวจ Primary ICT Logic แล้วถ้าไม่เข้า ให้ fallback ไป XGBoost   |
//|                                                                  |
//| พารามิเตอร์นำเข้า:                                               |
//|   int    bar_index   : ดัชนีแท่ง (0 = แท่งปัจจุบัน)               |
//| พารามิเตอร์ส่งออก:                                               |
//|   int    &signalType : ค่า SignalType                             |
//|   double &entryPrice : ราคาจุดเข้า (close[1])                     |
//|   double &SL         : ราคาสำหรับ Stop Loss                       |
//|   double &TP1        : ราคาสำหรับ Take Profit 1                   |
//|   double &TP2        : ราคาสำหรับ Take Profit 2                   |
//|   double &TP3        : ราคาสำหรับ Take Profit 3                   |
//|   double &latest_ATR : ค่า ATR14 ปัจจุบัน                         |
//|   double &VWAP_M1    : ค่า VWAP M1 ปัจจุบัน                        |
//|                                                                  |
//| คืนค่า:                                                          |
//|   true  = คำนวณสำเร็จ (ค่า signalType, entryPrice, SL, TP1, TP2, TP3 ถูกกำหนด) |
//|   false = เกิดข้อผิดพลาด                                         |
//+------------------------------------------------------------------+
bool GetSignal(int bar_index,
               int    &signalType,
               double &entryPrice,
               double &SL,
               double &TP1,
               double &TP2,
               double &TP3,
               double &latest_ATR,
               double &VWAP_M1)
  {
   // เริ่มต้น
   signalType = SIGNAL_NONE;
   entryPrice = 0.0;
   SL         = 0.0;
   TP1        = 0.0;
   TP2        = 0.0;
   TP3        = 0.0;
   latest_ATR = 0.0;
   VWAP_M1    = 0.0;

   // 1) ดึงฟีเจอร์เรียลไทม์
   bool   isBullMSS;
   double swingLow, swingHigh;
   datetime mssTime;
   double FVG_Bottom, FVG_Top;
   datetime timeFVG;
   double fib61, fib50, fib38;
   double ATR14_local, VWAP_local;
   double EMA50_M15, EMA200_M15, RSI14_M15, ADX14_M15;
   int    pattern_flag;

   if(!GetRealTimeFeatures(bar_index,
                           isBullMSS, swingLow, swingHigh, mssTime,
                           FVG_Bottom, FVG_Top, timeFVG,
                           fib61, fib50, fib38,
                           ATR14_local, VWAP_local,
                           EMA50_M15, EMA200_M15, RSI14_M15, ADX14_M15,
                           pattern_flag))
     {
      // ไม่สามารถคำนวณฟีเจอร์ได้
      return(false);
     }

   latest_ATR = ATR14_local;
   VWAP_M1    = VWAP_local;

   // 2) ดึงราคาปิดแท่งก่อนหน้า (pullback price)
   MqlRates prevBar[];
   if(CopyRates(_Symbol, PERIOD_M1, 1, 1, prevBar) != 1)
     {
      return(false);
     }
   double pricePullback = prevBar[0].close;

   // 3) Primary ICT Filter
   if(mssTime != 0 && FVG_Bottom != 0.0)
     {
      bool fibOverlap = false;
      if(isBullMSS)
         fibOverlap = (FVG_Top >= fib38 && FVG_Bottom <= fib61);
      else
         fibOverlap = (FVG_Bottom <= fib61 && FVG_Top >= fib38);

      bool pullbackOK = false;
      if(isBullMSS)
         pullbackOK = (pricePullback >= FVG_Bottom && pricePullback <= FVG_Top);
      else
         pullbackOK = (pricePullback <= FVG_Top && pricePullback >= FVG_Bottom);

      bool htfOK = false;
      if(isBullMSS)
         htfOK = (EMA50_M15 > EMA200_M15 && RSI14_M15 > 50.0 && ADX14_M15 >= InpADX_Threshold_M15);
      else
         htfOK = (EMA50_M15 < EMA200_M15 && RSI14_M15 < 50.0 && ADX14_M15 >= InpADX_Threshold_M15);

      if(fibOverlap && pullbackOK && htfOK)
        {
         if(isBullMSS)
           {
            signalType = SIGNAL_ICT_BUY;
            entryPrice = pricePullback;
            SL         = FVG_Bottom - 0.5 * ATR14_local;
            TP1        = swingLow + 1.272 * (swingHigh - swingLow);
            TP2        = pricePullback + 2.0 * ATR14_local;
            TP3        = VWAP_local + 0.5 * ATR14_local;
           }
         else
           {
            signalType = SIGNAL_ICT_SELL;
            entryPrice = pricePullback;
            SL         = FVG_Top + 0.5 * ATR14_local;
            TP1        = swingHigh - 1.272 * (swingHigh - swingLow);
            TP2        = pricePullback - 2.0 * ATR14_local;
            TP3        = VWAP_local - 0.5 * ATR14_local;
           }
         return(true);
        }
     }

   // 4) Fallback XGBoost
   double featuresArr[8];
   // diffEMA = EMA50_M15 - EMA200_M15
   featuresArr[0] = EMA50_M15 - EMA200_M15;
   featuresArr[1] = RSI14_M15;
   featuresArr[2] = ADX14_M15;
   featuresArr[3] = (FVG_Top - FVG_Bottom);
   featuresArr[4] = MathAbs(pricePullback - (isBullMSS ? FVG_Bottom : FVG_Top));
   // tick volume at timeFVG (approximate using SymbolInfoInteger)
   featuresArr[5] = (double)SymbolInfoInteger(_Symbol, SYMBOL_VOLUME);
   // avgVol placeholder (ยังไม่ได้คำนวณจริง)
   featuresArr[6] = featuresArr[5]; 
   // hour of day
   MqlDateTime dt; 
   TimeToStruct(TimeCurrent(), dt);
   featuresArr[7] = (double)dt.hour;

   double probBuy = 0.0, probSell = 0.0;
   if(!XGB_PredictProbability(featuresArr, probBuy, probSell))
     {
      signalType = SIGNAL_NONE;
      return(false);
     }

   if(probBuy >= InpXGB_Threshold)
     {
      signalType = SIGNAL_XGB_BUY;
      entryPrice = pricePullback;
      SL         = FVG_Bottom - 0.5 * ATR14_local;
      TP1        = swingLow + 1.272 * (swingHigh - swingLow);
      TP2        = pricePullback + 2.0 * ATR14_local;
      TP3        = VWAP_local + 0.5 * ATR14_local;
      return(true);
     }
   if(probSell >= InpXGB_Threshold)
     {
      signalType = SIGNAL_XGB_SELL;
      entryPrice = pricePullback;
      SL         = FVG_Top + 0.5 * ATR14_local;
      TP1        = swingHigh - 1.272 * (swingHigh - swingLow);
      TP2        = pricePullback - 2.0 * ATR14_local;
      TP3        = VWAP_local - 0.5 * ATR14_local;
      return(true);
     }

   // ถ้าไม่มีสัญญาณใดๆ
   signalType = SIGNAL_NONE;
   return(true);
  }
