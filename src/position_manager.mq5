//+------------------------------------------------------------------+
//| file: src/position_manager.mq5                                   |
//+------------------------------------------------------------------+
#property strict

void ManagePosition(ulong ticket, datetime openTime, double ATR14, double VWAP_M1)
{
   // (1) TimeExit: ถ้าเกิน InpMaxHoldHours → ปิด
   // (2) Breakeven: price ผ่าน TP1 → เลื่อนไป BE
   // (3) ขยับ TP2 → TP3 ตามเงื่อนไข
   // (4) Reverse MSS (ถ้าใช้)
}
