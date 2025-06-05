// file: src/TestML.mq5
#property strict
#property script_show_inputs

#include "config.mq5"
#include "ml_interface.mq5"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== TestML: Starting ML interface debug script ===");

   // ตัวอย่าง features[] ยาว 8 ค่า (dummy)
   double features[8] = {0.5, -0.2,  10.0,   // diffEMA, RSI14, ADX14
                         0.15, 0.02,  200.0,  // FVG_width, distFromFVG, tickVol
                         150.0, 14.0};       // avgVol, HourOfDay

   double probBuy, probSell;

   // เรียกฟังก์ชัน XGB_PredictProbability()
   bool ok = XGB_PredictProbability(features, probBuy, probSell);
   if(!ok)
     {
      Print(">>> TestML: XGB_PredictProbability returned FALSE");
      return;
     }

   // ถ้าส่งสำเร็จให้พิมพ์ probBuy, probSell
   PrintFormat(">>> TestML: probBuy = %.6f, probSell = %.6f", probBuy, probSell);
   Print("=== TestML: Completed ===");
  }
