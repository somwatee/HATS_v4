// file: src/TestICT.mq5
#property strict
#property script_show_inputs

#include "config.mq5"
#include "features.mq5"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== TestICT: Starting feature debug script ===");

   // เปลี่ยน bar_index เป็นค่าอย่างน้อย 14 เพื่อให้มีข้อมูล M1 ย้อนหลังเพียงพอ
   int  bar_index   = 20;  // ปรับตามความยาวของข้อมูลในกราฟของคุณ
   bool isBullMSS;
   double swingLow, swingHigh;
   datetime mssTime;
   double FVG_Bottom, FVG_Top;
   datetime timeFVG;
   double fib61, fib50, fib38;
   double ATR14, VWAP_M1;
   double EMA50_M15, EMA200_M15, RSI14_M15, ADX14_M15;
   int    pattern_flag;

   // เรียกฟังก์ชัน GetRealTimeFeatures()
   bool ok = GetRealTimeFeatures(
                bar_index,
                isBullMSS, swingLow, swingHigh, mssTime,
                FVG_Bottom, FVG_Top, timeFVG,
                fib61, fib50, fib38,
                ATR14, VWAP_M1,
                EMA50_M15, EMA200_M15, RSI14_M15, ADX14_M15,
                pattern_flag
             );

   if(!ok)
     {
      Print(">>> TestICT: GetRealTimeFeatures returned FALSE. Check logs for errors.");
      return;
     }

   // พิมพ์ผลลัพธ์ทั้งหมดเพื่อตรวจสอบ
   PrintFormat(">>> TestICT: isBullMSS = %s",          isBullMSS ? "TRUE" : "FALSE");
   PrintFormat(">>> TestICT: swingHigh = %.5f, swingLow = %.5f", swingHigh, swingLow);
   PrintFormat(">>> TestICT: mssTime = %s",            (mssTime>0 ? TimeToString(mssTime, TIME_DATE|TIME_MINUTES) : "N/A"));

   PrintFormat(">>> TestICT: FVG_Bottom = %.5f, FVG_Top = %.5f", FVG_Bottom, FVG_Top);
   PrintFormat(">>> TestICT: timeFVG = %s",            (timeFVG>0 ? TimeToString(timeFVG, TIME_DATE|TIME_MINUTES) : "N/A"));

   PrintFormat(">>> TestICT: fib61 = %.5f, fib50 = %.5f, fib38 = %.5f", fib61, fib50, fib38);

   PrintFormat(">>> TestICT: ATR14 = %.5f, VWAP_M1 = %.5f",    ATR14, VWAP_M1);

   PrintFormat(">>> TestICT: EMA50_M15 = %.5f, EMA200_M15 = %.5f", EMA50_M15, EMA200_M15);
   PrintFormat(">>> TestICT: RSI14_M15 = %.2f, ADX14_M15 = %.2f",   RSI14_M15,  ADX14_M15);

   PrintFormat(">>> TestICT: pattern_flag = %d", pattern_flag);

   Print("=== TestICT: Feature extraction completed ===");
  }
