//+------------------------------------------------------------------+
//| file: src/config.mq5                                             |
//+------------------------------------------------------------------+
#property strict
#property description "EA configuration"

//--- EA Input parameters --------------------------------------------
input string  InpSymbol            = "XAUUSD";
input double  InpRiskPercent       = 1.0;
input int     InpATR_Period_M1     = 14;
input int     InpEMA_Fast_M15      = 50;
input int     InpEMA_Slow_M15      = 200;
input int     InpRSI_Period_M15    = 14;
input int     InpADX_Period_M15    = 14;
input double  InpADX_Threshold_M15 = 18.0;
input int     InpSessionStartHour  = 7;
input int     InpSessionEndHour    = 15;
input double  InpLotStep           = 0.01;
input double  InpMinLot            = 0.01;
input double  InpMaxLot            = 10.0;
input bool    InpUseTimeExit       = true;
input int     InpMaxHoldHours      = 6;
input double  InpXGB_Threshold     = 0.50;
input bool    InpUseVolumeSpike    = true;
input bool    InpUsePatternFilter  = true;
input bool    InpUseMLFilter       = true;
input string  InpTelegramBotToken  = "";
input string  InpTelegramChatID    = "";
input int     InpCooldownSeconds   = 60;
