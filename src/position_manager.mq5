// file: src/position_manager.mq5
#property strict

#include "config.mq5"
#include "features.mq5"
#include <Trade\Trade.mqh>

double TP1_Global = 0.0;
double TP2_Global = 0.0;
double ATR14_Global = 0.0;
double VWAP_M1_Global = 0.0;

//+------------------------------------------------------------------+
//| ฟังก์ชัน: ClosePosition                                          |
//|   ปิดตำแหน่งบางส่วนหรือทั้งหมด ตาม ticket และ volume ที่กำหนด   |
//+------------------------------------------------------------------+
void ClosePosition(ulong ticket, double volume)
{
   if(!PositionSelectByTicket(ticket))
      return;

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   req.action   = TRADE_ACTION_DEAL;
   req.symbol   = _Symbol;
   req.volume   = volume;
   req.position = ticket;

   if(posType == POSITION_TYPE_BUY)
   {
      req.type  = ORDER_TYPE_SELL;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   else
   {
      req.type  = ORDER_TYPE_BUY;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   }

   if(!OrderSend(req, res))
      PrintFormat("ClosePosition failed, ticket=%I64u, retcode=%d", ticket, res.retcode);
}

//+------------------------------------------------------------------+
//| ฟังก์ชัน: ModifySL                                               |
//|   ปรับ Stop Loss ของตำแหน่ง (ticket) เป็น newSL                   |
//+------------------------------------------------------------------+
void ModifySL(ulong ticket, double newSL)
{
   if(!PositionSelectByTicket(ticket))
      return;

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action   = TRADE_ACTION_SLTP;
   req.position = ticket;
   req.symbol   = _Symbol;
   req.sl       = newSL;
   req.tp       = PositionGetDouble(POSITION_TP);

   if(!OrderSend(req, res))
      PrintFormat("ModifySL failed, ticket=%I64u, retcode=%d", ticket, res.retcode);
}

//+------------------------------------------------------------------+
//| ฟังก์ชัน: ManagePosition                                         |
//|   จัดการตำแหน่งตามกฎต่อไปนี้:                                      |
//|   1) TimeExit   2) Breakeven   3) TP3   4) TP1  5) TP2  6) Reverse MSS |
//+------------------------------------------------------------------+
void ManagePosition(ulong ticket, datetime openTime, double ATR14, double VWAP_M1)
{
   if(!PositionSelectByTicket(ticket))
      return;

   static bool movedToBreakeven = false;
   static bool closedPart1      = false;
   static bool closedPart2      = false;
   static bool oldIsBull        = false;
   static datetime oldMssTime   = 0;

   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double posVolume           = PositionGetDouble(POSITION_VOLUME);
   double entryPrice          = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice        = (posType == POSITION_TYPE_BUY)
                                 ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                 : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   //--- 1) Time-based Exit
   if(InpUseTimeExit)
   {
      double holdHours = (double)(TimeCurrent() - openTime) / 3600.0;
      if(holdHours >= InpMaxHoldHours)
      {
         ClosePosition(ticket, posVolume);
         PrintFormat("TimeExit: ปิด Position หลัง %d ชั่วโมง", InpMaxHoldHours);
         return;
      }
   }

   //--- 2) Breakeven
   if(!movedToBreakeven)
   {
      bool isBullDummy;
      double swingLowDummy, swingHighDummy;
      datetime mssTimeDummy;
      double FVG_BottomDummy, FVG_TopDummy;
      datetime timeFVGDummy;
      double fib61Dummy, fib50Dummy, fib38Dummy;
      double ATR14_dummy, VWAP_dummy;
      double EMA50_dummy, EMA200_dummy, RSI14_dummy, ADX14_dummy;
      int pattern_dummy;

      if(GetRealTimeFeatures(0,
                             isBullDummy, swingLowDummy, swingHighDummy, mssTimeDummy,
                             FVG_BottomDummy, FVG_TopDummy, timeFVGDummy,
                             fib61Dummy, fib50Dummy, fib38Dummy,
                             ATR14_dummy, VWAP_dummy,
                             EMA50_dummy, EMA200_dummy, RSI14_dummy, ADX14_dummy,
                             pattern_dummy))
      {
         if((posType == POSITION_TYPE_BUY  && currentPrice > VWAP_dummy) ||
            (posType == POSITION_TYPE_SELL && currentPrice < VWAP_dummy))
         {
            ModifySL(ticket, entryPrice);
            movedToBreakeven = true;
            PrintFormat("Breakeven: SL moved to entryPrice=%.5f", entryPrice);
         }
      }
   }

   //--- 3) TP3: ปิด 33% แรก + ปรับ SL ไป Breakeven
   if(!closedPart1)
   {
      double tp3 = PositionGetDouble(POSITION_TP);
      if((posType == POSITION_TYPE_BUY  && currentPrice >= tp3) ||
         (posType == POSITION_TYPE_SELL && currentPrice <= tp3))
      {
         double volToClose = posVolume * 0.33;
         ClosePosition(ticket, volToClose);
         ModifySL(ticket, entryPrice);
         closedPart1 = true;
         PrintFormat("TP3 Hit: ปิด 33%% แรก @ %.5f", tp3);
      }
   }

   //--- 4) TP1: ปิด 33% ที่สอง + ปรับ SL เป็น trailing ตาม ATR
   if(closedPart1 && !closedPart2)
   {
      double savedTP1 = TP1_Global;
      if((posType == POSITION_TYPE_BUY  && currentPrice >= savedTP1) ||
         (posType == POSITION_TYPE_SELL && currentPrice <= savedTP1))
      {
         double volLeft = PositionGetDouble(POSITION_VOLUME) * 0.50;
         ClosePosition(ticket, volLeft);
         double newSL = (posType == POSITION_TYPE_BUY)
                        ? (currentPrice - ATR14)
                        : (currentPrice + ATR14);
         ModifySL(ticket, newSL);
         closedPart2 = true;
         PrintFormat("TP1 Hit: ปิด 33%% ที่สอง @ %.5f (SL trailed to %.5f)", savedTP1, newSL);
      }
   }

   //--- 5) TP2: ปิด 33% สุดท้าย
   if(closedPart2)
   {
      double savedTP2 = TP2_Global;
      if((posType == POSITION_TYPE_BUY  && currentPrice >= savedTP2) ||
         (posType == POSITION_TYPE_SELL && currentPrice <= savedTP2))
      {
         double volLeft = PositionGetDouble(POSITION_VOLUME);
         ClosePosition(ticket, volLeft);
         PrintFormat("TP2 Hit: ปิด 33%% สุดท้าย @ %.5f", savedTP2);
      }
   }

   //--- 6) Reverse MSS: ตรวจ MSS ใหม่ ถ้าเปลี่ยนขั้ว ให้ปิดทั้งหมด
   {
      bool newIsBull;
      double newSwingLow, newSwingHigh;
      datetime newMssTime;
      double newFVG_Bottom, newFVG_Top;
      datetime newTimeFVG;
      double newFib61, newFib50, newFib38;
      double newATR14, newVWAP;
      double newEMA50, newEMA200, newRSI14, newADX14;
      int newPattern;

      if(GetRealTimeFeatures(0,
                             newIsBull, newSwingLow, newSwingHigh, newMssTime,
                             newFVG_Bottom, newFVG_Top, newTimeFVG,
                             newFib61, newFib50, newFib38,
                             newATR14, newVWAP,
                             newEMA50, newEMA200, newRSI14, newADX14,
                             newPattern))
      {
         if(newMssTime > oldMssTime && newIsBull != oldIsBull)
         {
            double remainingVolume = PositionGetDouble(POSITION_VOLUME);
            ClosePosition(ticket, remainingVolume);
            Print("Reverse MSS: ปิด Position ทันที เนื่องจาก MSS เปลี่ยนขั้ว");
         }
         oldIsBull    = newIsBull;
         oldMssTime   = newMssTime;
      }
   }
}
