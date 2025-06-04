// file: src/ea_hybrid.mq5
#property strict

#include "config.mq5"
#include "features.mq5"
#include "decision_engine.mq5"
#include "position_manager.mq5"
#include "ml_interface.mq5"
#include "health_check.mq5"

// Indicator handles
int handle_ATR_M1;
int handle_EMA_Fast_M15;
int handle_EMA_Slow_M15;
int handle_RSI_M15;
int handle_ADX_M15;

// สถานะตำแหน่ง
bool   hasOpenPosition = false;
ulong  ticketCurrent   = 0;

// ตัวแปรเก็บสถานะคำสั่งซื้อขาย (นิยามใน config.mq5/position_manager.mq5):
//   extern double TP1_Global;
//   extern double TP2_Global;
//   extern double ATR14_Global;
//   extern double VWAP_M1_Global;

// ตัวแปรเพิ่มเติมที่ต้องประกาศในไฟล์นี้
datetime openTimeGlobal   = 0;
double   entryPriceGlobal = 0.0;
double   SL_Global        = 0.0;
double   TP3_Global       = 0.0;

//+------------------------------------------------------------------+
//| ฟังก์ชัน InitEA: สร้าง indicator handles และตั้ง Timer         |
//+------------------------------------------------------------------+
void InitEA()
  {
   handle_ATR_M1       = iATR(_Symbol, PERIOD_M1, InpATR_Period_M1);
   handle_EMA_Fast_M15 = iMA(_Symbol, PERIOD_M15, InpEMA_Fast_M15, 0, MODE_EMA, PRICE_CLOSE);
   handle_EMA_Slow_M15 = iMA(_Symbol, PERIOD_M15, InpEMA_Slow_M15, 0, MODE_EMA, PRICE_CLOSE);
   handle_RSI_M15      = iRSI(_Symbol, PERIOD_M15, InpRSI_Period_M15, PRICE_CLOSE);
   handle_ADX_M15      = iADX(_Symbol, PERIOD_M15, InpADX_Period_M15); // ถูกต้อง: 3 พารามิเตอร์

   if(handle_ATR_M1 < 0 || handle_EMA_Fast_M15 < 0 || handle_EMA_Slow_M15 < 0 ||
      handle_RSI_M15 < 0 || handle_ADX_M15 < 0)
     {
      Print("Error creating indicator handles");
     }

   hasOpenPosition = false;
   EventSetMillisecondTimer(InpCooldownSeconds * 1000);
  }

//+------------------------------------------------------------------+
//| ฟังก์ชัน DeinitEA: ยกเลิก Timer                                  |
//+------------------------------------------------------------------+
void DeinitEA()
  {
   EventKillTimer();
  }

//+------------------------------------------------------------------+
//| OnTimer: เรียก OnTick เมื่อ Timer เต็ม                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
   OnTick();
  }

//+------------------------------------------------------------------+
//| OnTick: หลักการทำงานของ EA                                        |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1) Session Filter (GMT+7)
   datetime nowLocal = TimeLocal();
   MqlDateTime dt; TimeToStruct(nowLocal, dt);
   if(dt.hour < InpSessionStartHour || dt.hour >= InpSessionEndHour)
      return;

   // 2) ตรวจตำแหน่งที่เปิดอยู่
   hasOpenPosition = false;
   if(PositionSelect(_Symbol))
     {
      ticketCurrent   = PositionGetInteger(POSITION_TICKET);
      // ใส่ cast เพื่อหลีกเลี่ยง warning การแปลง long → datetime
      openTimeGlobal  = (datetime)PositionGetInteger(POSITION_TIME);
      hasOpenPosition = true;
     }

   if(hasOpenPosition)
     {
      ManagePosition(ticketCurrent, openTimeGlobal, ATR14_Global, VWAP_M1_Global);
      HealthCheck();
      return;
     }

   // 3) ไม่มีตำแหน่ง: ดึงค่าตัวชี้วัดปัจจุบัน
   double arrATR[];
   double arrEMA_Fast[];
   double arrEMA_Slow[];
   double arrRSI[];
   double arrADX[];

   if(CopyBuffer(handle_ATR_M1, 0, 0, 1, arrATR) != 1)             return;
   if(CopyBuffer(handle_EMA_Fast_M15, 0, 0, 1, arrEMA_Fast) != 1)   return;
   if(CopyBuffer(handle_EMA_Slow_M15, 0, 0, 1, arrEMA_Slow) != 1)   return;
   if(CopyBuffer(handle_RSI_M15, 0, 0, 1, arrRSI) != 1)             return;
   if(CopyBuffer(handle_ADX_M15, 0, 0, 1, arrADX) != 1)             return;

   double latest_ATR   = arrATR[0];
   double EMA50_M15    = arrEMA_Fast[0];
   double EMA200_M15   = arrEMA_Slow[0];
   double RSI14_M15    = arrRSI[0];
   double ADX14_M15    = arrADX[0];
   double VWAP_M1      = 0.0;

   int    signalType;
   double entryPrice, SL, TP1, TP2, TP3;

   // 4) ขอสัญญาณ ICT หรือ XGB
   if(!GetSignal(0, signalType, entryPrice, SL, TP1, TP2, TP3, latest_ATR, VWAP_M1))
     {
      HealthCheck();
      return;
     }
   if(signalType == SIGNAL_NONE)
     {
      HealthCheck();
      return;
     }

   // 5) คำนวณ BaseLot
   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmt    = equity * (InpRiskPercent / 100.0);
   double slPoints   = MathAbs(entryPrice - SL) / _Point;
   double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double oneLotRisk = slPoints * tickValue;
   if(oneLotRisk <= 0.0)
     {
      HealthCheck();
      return;
     }
   double baseLot = riskAmt / oneLotRisk;

   // 6) Secondary Filters: Volume Spike, Pattern Flag, ML Filter
   int    score       = 0;
   bool   volume_ok   = false;
   bool   pattern_ok  = false;
   bool   ml_ok       = false;

   bool   isBullRTC;
   double swingLowRTC, swingHighRTC;
   datetime mssTimeRTC;
   double FVG_BottomRTC, FVG_TopRTC;
   datetime timeFVGR;
   double fib61RTC, fib50RTC, fib38RTC;
   double ATR14_RTC, VWAP_RTC;
   double EMA50_RTC, EMA200_RTC, RSI14_RTC, ADX14_RTC;
   int    pattern_flag;

   if(GetRealTimeFeatures(0,
                          isBullRTC, swingLowRTC, swingHighRTC, mssTimeRTC,
                          FVG_BottomRTC, FVG_TopRTC, timeFVGR,
                          fib61RTC, fib50RTC, fib38RTC,
                          ATR14_RTC, VWAP_RTC,
                          EMA50_RTC, EMA200_RTC, RSI14_RTC, ADX14_RTC,
                          pattern_flag))
     {
      double volAtFVG = (double)SymbolInfoInteger(_Symbol, SYMBOL_VOLUME);
      double avgVol   = ATR14_RTC * 10.0;
      if(InpUseVolumeSpike && volAtFVG >= avgVol * 1.2)
        {
         volume_ok = true;
         score++;
        }
      if(InpUsePatternFilter && pattern_flag == 1)
        {
         pattern_ok = true;
         score++;
        }
     }

   if(InpUseMLFilter)
     {
      double featuresArr[8];
      featuresArr[0] = EMA50_M15 - EMA200_M15;
      featuresArr[1] = RSI14_M15;
      featuresArr[2] = ADX14_M15;
      featuresArr[3] = (FVG_TopRTC - FVG_BottomRTC);
      featuresArr[4] = MathAbs(entryPrice - (isBullRTC ? FVG_BottomRTC : FVG_TopRTC));
      featuresArr[5] = (double)SymbolInfoInteger(_Symbol, SYMBOL_VOLUME);
      featuresArr[6] = featuresArr[5];
      featuresArr[7] = (double)dt.hour;

      double probBuy  = 0.0, probSell = 0.0;
      if(XGB_PredictProbability(featuresArr, probBuy, probSell))
        {
         if(signalType == SIGNAL_ICT_BUY || signalType == SIGNAL_XGB_BUY)
           {
            if(probBuy >= InpXGB_Threshold) { ml_ok = true; score++; }
           }
         if(signalType == SIGNAL_ICT_SELL || signalType == SIGNAL_XGB_SELL)
           {
            if(probSell >= InpXGB_Threshold) { ml_ok = true; score++; }
           }
        }
     }

   // 7) กำหนด LotSize ตามคะแนน
   double lotSize = 0.0;
   if(score == 3)       lotSize = baseLot;
   else if(score == 2)  lotSize = baseLot * 0.75;
   else if(score == 1)  lotSize = baseLot * 0.50;
   else                 { HealthCheck(); return; }

   // 8) Normalize lot
   double stepCount = MathFloor(lotSize / InpLotStep);
   lotSize = stepCount * InpLotStep;
   if(lotSize < InpMinLot) { HealthCheck(); return; }
   if(lotSize > InpMaxLot) lotSize = InpMaxLot;

   // 9) เปิด Order
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = _Symbol;
   req.volume       = lotSize;
   if(signalType == SIGNAL_ICT_BUY || signalType == SIGNAL_XGB_BUY)
     {
      req.type  = ORDER_TYPE_BUY;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     }
   else
     {
      req.type  = ORDER_TYPE_SELL;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
     }
   req.sl           = SL;
   req.tp           = TP3;
   req.deviation    = 5;
   req.type_filling = ORDER_FILLING_FOK;
   req.type_time    = ORDER_TIME_GTC;

   if(!OrderSend(req, res))
     {
      PrintFormat("OrderSend failed, retcode=%d", res.retcode);
      HealthCheck();
      return;
     }

   // บันทึกสถานะหลังเปิด order
   ticketCurrent     = res.order;
   entryPriceGlobal  = entryPrice;
   SL_Global         = SL;
   TP3_Global        = TP3;
   ATR14_Global      = latest_ATR;
   VWAP_M1_Global    = VWAP_M1;
   openTimeGlobal    = TimeCurrent();

   HealthCheck();
  }

//+------------------------------------------------------------------+
//| หมายเหตุ: config.mq5 ต้องมีฟังก์ชันต่อไปนี้                    |
//|   void OnInit()    { InitEA(); }                                   |
//|   void OnDeinit(…) { DeinitEA(); }                                |
//+------------------------------------------------------------------+
