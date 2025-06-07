// file: src/TestDecision.mq5
#property strict
#property script_show_inputs

// รวมไฟล์ config เพื่อดึง extern inputs
#include "config.mq5"
// รวมฟังก์ชันคำนวณฟีเจอร์แบบเรียลไทม์
#include "features.mq5"
// รวมฟังก์ชันเรียก XGB (WebRequest) หรือ stub
#include "ml_interface.mq5"
// รวม decision engine ที่ใช้ฟีเจอร์ + XGB fallback
#include "decision_engine.mq5"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== TestDecision: Starting ICT + XGB decision debug ===");

   // เลือกบาร์ที่ต้องการทดสอบ (ค่า ≥ 20 เพื่อให้มีข้อมูล ATR/VWAP เพียงพอ)
   int bar_index = 20;

   // ตัวแปรคืนค่าจาก GetSignal
   int    signalType;
   double entryPrice, SL, TP1, TP2, TP3;
   double latest_ATR, VWAP_M1;

   // เรียกฟังก์ชัน GetSignal
   bool ok = GetSignal(
                bar_index,
                signalType,
                entryPrice, SL, TP1, TP2, TP3,
                latest_ATR, VWAP_M1
             );

   if(!ok)
     {
      Print(">>> TestDecision: GetSignal returned FALSE. ตรวจสอบ logs ใน features หรือ ml_interface");
      return;
     }

   // พิมพ์ผลลัพธ์ signalType (รหัส) และแปลความหมาย
   string signalName;
   switch(signalType)
     {
      case SIGNAL_NONE:      signalName = "NONE";      break;
      case SIGNAL_ICT_BUY:   signalName = "ICT_BUY";   break;
      case SIGNAL_ICT_SELL:  signalName = "ICT_SELL";  break;
      case SIGNAL_XGB_BUY:   signalName = "XGB_BUY";   break;
      case SIGNAL_XGB_SELL:  signalName = "XGB_SELL";  break;
      default:               signalName = "UNKNOWN";   break;
     }

   PrintFormat(">>> TestDecision: signalType = %d (%s)", signalType, signalName);
   if(signalType != SIGNAL_NONE)
     {
      PrintFormat(">>> TestDecision: entryPrice = %.5f", entryPrice);
      PrintFormat(">>> TestDecision: SL         = %.5f", SL);
      PrintFormat(">>> TestDecision: TP1        = %.5f", TP1);
      PrintFormat(">>> TestDecision: TP2        = %.5f", TP2);
      PrintFormat(">>> TestDecision: TP3        = %.5f", TP3);
     }
   else
     {
      Print(">>> TestDecision: No trade signal (SIGNAL_NONE)");
     }

   PrintFormat(">>> TestDecision: latest_ATR = %.5f, VWAP_M1 = %.5f", latest_ATR, VWAP_M1);
   Print("=== TestDecision: Completed ===");
  }
