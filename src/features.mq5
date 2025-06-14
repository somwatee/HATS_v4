//+------------------------------------------------------------------+
//| file: src/features.mq5                                           |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| GetRealTimeFeatures: คำนวณ MSS, FVG, Fibonacci, ATR, VWAP_M1,    |
//| EMA/RSI/ADX (M15), Candlestick patterns                          |
//+------------------------------------------------------------------+
bool GetRealTimeFeatures(
   int      barIndex,
   bool    &isBullMSS,
   double  &swingLow,
   double  &swingHigh,
   datetime&mssTime,
   double  &FVG_Bottom,
   double  &FVG_Top,
   datetime&timeFVG,
   double  &fib61,
   double  &fib50,
   double  &fib38,
   double  &ATR14,
   double  &VWAP_M1,
   double  &EMA50_M15,
   double  &EMA200_M15,
   double  &RSI14_M15,
   double  &ADX14_M15,
   int     &pattern_flag
) {
   // --- ตัวอย่าง ATR14 ---
   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_M1, barIndex-ATR_Period_M1, ATR_Period_M1, rates) != ATR_Period_M1)
      return(false);
   double trSum=0;
   for(int i=1;i<ARRAYSIZE(rates);i++){
      double h=rates[i].high, l=rates[i].low, p=rates[i-1].close;
      trSum+=MathMax(h-l, MathMax(MathAbs(h-p),MathAbs(l-p)));
   }
   ATR14 = trSum/ (ATR_Period_M1-1);

   // --- ตัวอย่าง EMA/RSI/ADX จาก M15 ---
   double buf[];
   if(CopyBuffer(iMA(_Symbol, PERIOD_M15, InpEMA_Fast_M15, 0, MODE_EMA, PRICE_CLOSE),0,0,1,buf)!=1) return(false);
   EMA50_M15 = buf[0];
   if(CopyBuffer(iMA(_Symbol, PERIOD_M15, InpEMA_Slow_M15, 0, MODE_EMA, PRICE_CLOSE),0,0,1,buf)!=1) return(false);
   EMA200_M15 = buf[0];
   if(CopyBuffer(iRSI(_Symbol, PERIOD_M15, InpRSI_Period_M15, PRICE_CLOSE),0,0,1,buf)!=1) return(false);
   RSI14_M15=buf[0];
   if(CopyBuffer(iADX(_Symbol, PERIOD_M15, InpADX_Period_M15),0,0,1,buf)!=1) return(false);
   ADX14_M15=buf[0];

   // --- ตัวอย่าง VWAP_M1 ---
   double volSum=0, pvSum=0;
   for(int i=barIndex-13;i<=barIndex;i++){
      double c=iClose(_Symbol,PERIOD_M1,i);
      long   v=iTickVolume(_Symbol,PERIOD_M1,i);
      pvSum+=c*v;
      volSum+=v;
   }
   if(volSum<=0) VWAP_M1=0; else VWAP_M1=pvSum/volSum;

   // --- MSS/FVG/Fib/Pattern: ใส่ logic ตามเดิมของคุณ ---
   isBullMSS=false; swingLow=swingHigh=0; mssTime=0;
   FVG_Bottom=FVG_Top=0; timeFVG=0;
   fib61=fib50=fib38=0; pattern_flag=0;

   return(true);
}
