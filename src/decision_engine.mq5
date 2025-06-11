// file: src/decision_engine.mq5
#property strict

#include "features.mq5"      // ต้องมี GetRealTimeFeatures()
#include "ml_interface.mq5"  // ต้องมี SaveFeatures() และ LoadPrediction()

enum SignalType
  {
   SIGNAL_NONE      = 0,
   SIGNAL_ICT_BUY   = 1,
   SIGNAL_ICT_SELL  = 2,
   SIGNAL_XGB_BUY   = 3,
   SIGNAL_XGB_SELL  = 4
  };

//+------------------------------------------------------------------+
//| GetSignal: ICT primary + XGB fallback via File-based IPC        |
//+------------------------------------------------------------------+
bool GetSignal(int bar_index,
               int    &signalType,
               double &entryPrice,
               double &SL, double &TP1, double &TP2, double &TP3,
               double &latest_ATR, double &VWAP_M1)
  {
   signalType = SIGNAL_NONE;

   // 1) Real-time features
   bool     isBullMSS    = false;
   double   swingLow     = 0.0, swingHigh = 0.0;
   datetime mssTime      = 0;
   double   FVG_Bottom   = 0.0, FVG_Top   = 0.0;
   datetime timeFVG      = 0;
   double   fib61        = 0.0, fib50 = 0.0, fib38 = 0.0;
   double   ATR14        = 0.0;
   double   EMA50_M15    = 0.0, EMA200_M15 = 0.0, RSI14_M15 = 0.0, ADX14_M15 = 0.0;
   int      pattern_flag = 0;

   if(!GetRealTimeFeatures(
         bar_index,
         isBullMSS,
         swingLow, swingHigh, mssTime,
         FVG_Bottom, FVG_Top, timeFVG,
         fib61, fib50, fib38,
         ATR14, VWAP_M1,
         EMA50_M15, EMA200_M15, RSI14_M15, ADX14_M15,
         pattern_flag))
     {
      return(false);
     }
   latest_ATR = ATR14;

   // 2) Pullback price
   MqlRates prevRates[1];
   if(CopyRates(_Symbol, PERIOD_M1, 1, 1, prevRates) != 1)
      return(false);
   double pricePullback = prevRates[0].close;

   // 3) ICT Primary Filter
   bool primaryOK = false;
   if(mssTime != 0 && FVG_Bottom != 0.0)
     {
      bool fibOverlap = isBullMSS
        ? (FVG_Top >= fib38 && FVG_Bottom <= fib61)
        : (FVG_Bottom <= fib61 && FVG_Top >= fib38);
      bool pullbackOK = isBullMSS
        ? (pricePullback >= FVG_Bottom && pricePullback <= FVG_Top)
        : (pricePullback <= FVG_Top   && pricePullback >= FVG_Bottom);
      bool htfOK = isBullMSS
        ? (EMA50_M15 > EMA200_M15 && RSI14_M15 > 50 && ADX14_M15 >= InpADX_Threshold_M15)
        : (EMA50_M15 < EMA200_M15 && RSI14_M15 < 50 && ADX14_M15 >= InpADX_Threshold_M15);

      if(fibOverlap && pullbackOK && htfOK)
        {
         primaryOK = true;
         if(isBullMSS)
           {
            signalType = SIGNAL_ICT_BUY;
            entryPrice = pricePullback;
            SL         = FVG_Bottom - 0.5 * ATR14;
            TP1        = swingLow + 1.272 * (swingHigh - swingLow);
            TP2        = pricePullback + 2.0 * ATR14;
            TP3        = VWAP_M1 + 0.5 * ATR14;
           }
         else
           {
            signalType = SIGNAL_ICT_SELL;
            entryPrice = pricePullback;
            SL         = FVG_Top + 0.5 * ATR14;
            TP1        = swingHigh - 1.272 * (swingHigh - swingLow);
            TP2        = pricePullback - 2.0 * ATR14;
            TP3        = VWAP_M1 - 0.5 * ATR14;
           }
        }
     }
   if(primaryOK)
      return(true);

   // 4) Fallback XGB via File-based IPC
   double featuresArr[20];
   ArrayInitialize(featuresArr, 0.0);
   featuresArr[0] = EMA50_M15 - EMA200_M15;
   featuresArr[1] = RSI14_M15;
   featuresArr[2] = ADX14_M15;
   featuresArr[3] = FVG_Top - FVG_Bottom;
   featuresArr[4] = MathAbs(pricePullback - (isBullMSS ? FVG_Bottom : FVG_Top));
   featuresArr[5] = pricePullback;
   featuresArr[6] = ATR14;
   featuresArr[7] = VWAP_M1;
   featuresArr[8] = swingLow;
   featuresArr[9] = swingHigh;
   // ... เติม featuresArr[10..19] ตามโมเดลของคุณ ...

   if(!SaveFeatures(featuresArr, ArraySize(featuresArr)))
     {
      Print("GetSignal: SaveFeatures FAILED");
      return(false);
     }

   // 5) รอ Python predictor สร้าง prediction.json (timeout 1s)
   bool got = false;
   for(int i=0; i<10; i++)
     {
      int fh = FileOpen("prediction.json", FILE_READ|FILE_TXT|FILE_ANSI);
      if(fh != INVALID_HANDLE)
        {
         FileClose(fh);
         got = true;
         break;
        }
      Sleep(100);
     }
   if(!got)
     {
      Print("GetSignal: prediction.json not found");
      return(false);
     }

   // 6) โหลด probabilities
   double pBuy=0.0, pSell=0.0;
   if(!LoadPrediction(pBuy, pSell))
     {
      Print("GetSignal: LoadPrediction FAILED");
      return(false);
     }
   PrintFormat("GetSignal: XGB fallback – Buy=%.3f, Sell=%.3f", pBuy, pSell);

   // 7) ตัดสินใจตาม threshold
   if(pBuy >= InpXGB_Threshold)
     {
      signalType = SIGNAL_XGB_BUY;
      entryPrice = pricePullback;
      SL         = FVG_Bottom - 0.5 * ATR14;
      TP1        = swingLow + 1.272 * (swingHigh - swingLow);
      TP2        = pricePullback + 2.0 * ATR14;
      TP3        = VWAP_M1 + 0.5 * ATR14;
     }
   else if(pSell >= InpXGB_Threshold)
     {
      signalType = SIGNAL_XGB_SELL;
      entryPrice = pricePullback;
      SL         = FVG_Top + 0.5 * ATR14;
      TP1        = swingHigh - 1.272 * (swingHigh - swingLow);
      TP2        = pricePullback - 2.0 * ATR14;
      TP3        = VWAP_M1 - 0.5 * ATR14;
     }

   return(true);
  }
//+------------------------------------------------------------------+
