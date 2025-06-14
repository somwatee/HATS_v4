//+------------------------------------------------------------------+
//| file: src/decision_engine.mq5                                   |
//+------------------------------------------------------------------+
#property strict

enum SignalResult { SIGNAL_NONE=0, SIGNAL_ICT_BUY, SIGNAL_ICT_SELL, SIGNAL_XGB_BUY, SIGNAL_XGB_SELL };

bool GetSignal(
   int barIndex,
   SignalResult &signalType,
   double &entryPrice,
   double &SL,
   double &TP1,
   double &TP2,
   double &TP3,
   double latest_ATR,
   double VWAP_M1
)
{
   signalType=SIGNAL_NONE;
   // (1) ICT primary: ถ้าเจอสัญญาณ Buy/ Sell → set signalType, entryPrice, SL, TP1, TP2, TP3
   // (2) else if(InpUseMLFilter) → เตรียม features[20] แล้วเรียก XGB_PredictProbability(...)
   //       → ถ้า probBuy>=Threshold → signalType=SIGNAL_XGB_BUY, ฯลฯ
   return(true);
}
