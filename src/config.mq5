// file: src/config.mq5
#property strict

//--- Input Parameters for Hybrid AI Trading EA
input string InpSymbol            = "XAUUSD";    // Symbol to trade
input double InpRiskPercent        = 1.0;        // Risk percent per trade
input int    InpATR_Period_M1      = 14;         // ATR period on M1
input int    InpEMA_Fast_M15       = 50;         // Fast EMA period on M15
input int    InpEMA_Slow_M15       = 200;        // Slow EMA period on M15
input int    InpRSI_Period_M15     = 14;         // RSI period on M15
input int    InpADX_Period_M15     = 14;         // ADX period on M15
input double InpADX_Threshold_M15  = 18.0;       // ADX threshold on M15

input int    InpSessionStartHour   = 7;          // Trading session start (GMT+7)
input int    InpSessionEndHour     = 15;         // Trading session end (GMT+7)

input double InpLotStep            = 0.01;       // Lot size step
input double InpMinLot             = 0.01;       // Minimum lot size
input double InpMaxLot             = 10.0;       // Maximum lot size

input bool   InpUseTimeExit        = true;       // Enable time-based exit
input int    InpMaxHoldHours       = 6;          // Max holding hours before forced exit

input double InpXGB_Threshold      = 0.70;       // Probability threshold for XGB fallback
input bool   InpUseVolumeSpike     = true;       // Enable volume spike secondary filter
input bool   InpUsePatternFilter   = true;       // Enable candlestick pattern filter
input bool   InpUseMLFilter        = true;       // Enable ML secondary filter

input string InpTelegramBotToken   = "";         // Telegram Bot Token
input string InpTelegramChatID     = "";         // Telegram Chat ID
input int    InpCooldownSeconds    = 60;         // Cooldown between OnTick loops (seconds)

//--- แก้ปัญหา “event handling function not found” โดยเพิ่ม stub event handlers
int OnInit()
{
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   // ไม่มีการทำงานเพิ่มเติม ณ การปิด EA
}
