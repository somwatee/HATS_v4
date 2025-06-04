// file: src/health_check.mq5
#property strict

#include "config.mq5"

//+------------------------------------------------------------------+
//| ฟังก์ชัน: CheckMT5Connection                                     |
//|   ตรวจว่า MT5 ยังเชื่อมต่ออยู่หรือไม่                              |
//+------------------------------------------------------------------+
bool CheckMT5Connection()
  {
   return(TerminalInfoInteger(TERMINAL_CONNECTED) == 1);
  }

//+------------------------------------------------------------------+
//| ฟังก์ชัน: HasErrorInLog                                          |
//|   อ่านไฟล์ logPath แล้วค้นคำว่า "ERROR"                            |
//+------------------------------------------------------------------+
bool HasErrorInLog(string logPath)
  {
   int fileHandle = FileOpen(logPath, FILE_READ|FILE_TXT|FILE_ANSI);
   if(fileHandle == INVALID_HANDLE)
      return(false);

   while(!FileIsEnding(fileHandle))
     {
      string line = FileReadString(fileHandle);
      if(StringFind(line, "ERROR") >= 0)
        {
         FileClose(fileHandle);
         return(true);
        }
     }
   FileClose(fileHandle);
   return(false);
  }

//+------------------------------------------------------------------+
//| ฟังก์ชัน: SendTelegram                                           |
//|   ส่งข้อความไปที่ Telegram โดยใช้ Bot Token และ Chat ID           |
//+------------------------------------------------------------------+
bool SendTelegram(string text)
  {
   if(StringLen(InpTelegramBotToken) == 0 || StringLen(InpTelegramChatID) == 0)
      return(false);

   // เตรียม URL สำหรับส่ง GET
   string url = "https://api.telegram.org/bot" + InpTelegramBotToken +
                "/sendMessage?chat_id=" + InpTelegramChatID +
                "&text=" + text;

   // เตรียม buffer เปล่าสำหรับ data และผลลัพธ์
   char   postData[1];         // ส่ง GET จึงไม่ต้องส่ง body
   char   result[1024];        // buffer สำหรับรับ response
   string responseHeaders;     // buffer สำหรับรับ response headers
   int    timeout    = 5000;   // 5 วินาที

   // ตรวจสอบว่าอนุญาต WebRequest ไปยัง "https://api.telegram.org" แล้วหรือไม่
   // ต้องตั้งใน MT5: Options → Expert Advisors → Allow WebRequest for listed URL → เพิ่ม "https://api.telegram.org"
   int resp = WebRequest(
      "GET",           // method
      url,             // full URL
      "",              // headers (ไม่มี)
      timeout,         // timeout (ms)
      postData,        // data[] (array เปล่า)
      result,          // result[] buffer
      responseHeaders  // result_headers
   );
   if(resp == -1)
   {
      // WebRequest ล้มเหลว
      return(false);
   }
   // ถ้า HTTP status code อยู่ใน responseHeaders, MT5 จะ return resp=server response size
   // เรสามารถตรวจสอบ responseHeaders เพื่อหา "200 OK" หรือ parse HTTP/1.1 200
   if(StringFind(responseHeaders, "200") >= 0)
      return(true);
   return(false);
  }

//+------------------------------------------------------------------+
//| ฟังก์ชัน: HealthCheck                                            |
//|   ตรวจ MT5 connection และเลื้อง log ถ้ามีปัญหาให้ส่ง Telegram     |
//+------------------------------------------------------------------+
void HealthCheck()
  {
   // 1) ตรวจ MT5 connection
   if(!CheckMT5Connection())
     {
      SendTelegram("MT5 connection lost!");
     }

   // 2) ตรวจไฟล์ log ว่ามี "ERROR" หรือไม่
   string logPath = "logs\\system.log";
   if(HasErrorInLog(logPath))
     {
      SendTelegram("พบ ERROR ใน logs/system.log");
     }
  }
