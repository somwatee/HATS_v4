//+------------------------------------------------------------------+
//|                                                       TestML.mq5 |
//|  สคริปต์ทดสอบเรียก features → XGB_PredictProbability           |
//+------------------------------------------------------------------+
#property script_show_inputs

#include "ml_interface.mq5"  // ประกอบด้วย GetRealTimeFeatures() และ XGB_PredictProbability()

void OnStart()
  {
   Print("=== TestML: Starting ML interface debug script ===");

   // (1) ตรวจสอบจำนวนแท่ง M1 ปัจจุบัน
   int totalBars = iBars(_Symbol, PERIOD_M1);
   if(totalBars < 20)
     {
      Print(">> TestML: กราฟ M1 มีแค่ ", totalBars, " แท่ง ยังไม่เพียงพอสำหรับ lookback");
      return;
     }

   // (2) กำหนด lookbackNeeded ตามที่ features.mq5 ต้องการ
   //     จาก Log เราเห็น needed=bar_index+3 แต่ features คำนวณ ATR14/VWAP14/MSS/FVG 
   //     รวม ๆ น่าจะต้องการย้อนหลังมากกว่า 3 แท่ง ผมเผื่อไว้ 15 แท่ง
   int lookbackNeeded = 15;

   // (3) เลือก barIndex โดยเผื่อพื้นที่ lookbackNeeded
   int maxIndex = totalBars - 1;      // index สูงสุดที่มี (0-based)
   int barIndex = maxIndex - lookbackNeeded;
   if(barIndex < 0) 
     {
      Print(">> TestML: ไม่สามารถหา bar_index ได้ เพราะ totalBars=", totalBars, " < lookbackNeeded=", lookbackNeeded);
      return;
     }

   PrintFormat(">> TestML: totalBars=%d → เลือก barIndex=%d (เผื่อ lookback=%d)", 
               totalBars, barIndex, lookbackNeeded);

   // (4) เรียกฟังก์ชันทดสอบ
   Test_XGB_Call(barIndex);
  }

//+------------------------------------------------------------------+
void Test_XGB_Call(int barIndex)
  {
   PrintFormat(">> TestML: Calling GetRealTimeFeatures(bar_index=%d)", barIndex);

   bool     isBullMSS       = false;
   double   swingLow        = 0.0;
   double   swingHigh       = 0.0;
   datetime mssTime         = 0;
   double   FVG_Bottom      = 0.0;
   double   FVG_Top         = 0.0;
   datetime timeFVG         = 0;
   double   fib61           = 0.0;
   double   fib50           = 0.0;
   double   fib38           = 0.0;
   double   ATR14           = 0.0;
   double   VWAP_M1         = 0.0;
   double   EMA50_M15       = 0.0;
   double   EMA200_M15      = 0.0;
   double   RSI14_M15       = 0.0;
   double   ADX14_M15       = 0.0;
   int      pattern_flag    = 0;

   // เรียก GetRealTimeFeatures ด้วย barIndex ที่ปรับแล้ว
   bool okFeat = GetRealTimeFeatures(
                    barIndex,
                    isBullMSS,
                    swingLow,
                    swingHigh,
                    mssTime,
                    FVG_Bottom,
                    FVG_Top,
                    timeFVG,
                    fib61,
                    fib50,
                    fib38,
                    ATR14,
                    VWAP_M1,
                    EMA50_M15,
                    EMA200_M15,
                    RSI14_M15,
                    ADX14_M15,
                    pattern_flag
                 );
   if(!okFeat)
     {
      Print(">> TestML: GetRealTimeFeatures failed");
      return;
     }

   // แพ็กค่าจาก GetRealTimeFeatures ทั้งหมด + ราคา M1 ไปไว้ใน arr20[20]
   double arr20[20];
   ArrayInitialize(arr20, 0.0);

   arr20[0]  = isBullMSS ? 1.0 : 0.0;
   arr20[1]  = swingLow;
   arr20[2]  = swingHigh;
   arr20[3]  = 0.0;               // mssTime ถ้าโมเดลไม่ได้ใช้ ให้ 0.0
   arr20[4]  = FVG_Bottom;
   arr20[5]  = FVG_Top;
   arr20[6]  = 0.0;               // timeFVG ถ้าไม่ใช้ ให้ 0.0
   arr20[7]  = fib61;
   arr20[8]  = fib50;
   arr20[9]  = fib38;
   arr20[10] = ATR14;
   arr20[11] = VWAP_M1;
   arr20[12] = EMA50_M15;
   arr20[13] = EMA200_M15;
   arr20[14] = RSI14_M15;
   arr20[15] = ADX14_M15;
   arr20[16] = pattern_flag;      // int → double

   // 3 Feature สุดท้าย (ตัวอย่าง ถ้าโมเดลต้องการ)
   arr20[17] = iClose(_Symbol, PERIOD_M1, barIndex);
   arr20[18] = iHigh(_Symbol, PERIOD_M1, barIndex);
   arr20[19] = iTickVolume(_Symbol, PERIOD_M1, barIndex);

   // (5) เรียก XGB_PredictProbability
   double pBuy  = 0.0;
   double pSell = 0.0;
   bool okXGB = XGB_PredictProbability(arr20, pBuy, pSell);
   if(okXGB)
     {
      PrintFormat(">> TestML: Received probBuy=%.6f, probSell=%.6f", 
                  pBuy, 
                  pSell);
     }
   else
     {
      Print(">> TestML: XGB_PredictProbability returned FALSE");
     }
  }
//+------------------------------------------------------------------+
