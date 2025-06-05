// file: src/ml_interface.mq5
#property library
#property strict

//+------------------------------------------------------------------+
//| XGB_PredictProbability                                           |
//| - รับ features[] (double[20])                                    |
//| - สร้าง JSON payload แล้วส่ง POST ไปยัง Flask server             |
//| - แปลง response JSON → ดึง probBuy, probSell กลับไป              |
//+------------------------------------------------------------------+
bool XGB_PredictProbability(const double &features[], double &probBuy, double &probSell)
  {
   // (1) สร้าง JSON payload จากฟีเจอร์ 20 ค่า
   string jsonBody;
   {
     string arr = "[";
     for(int i = 0; i < 20; i++)
       {
         arr += DoubleToString(features[i], 6);
         if(i < 19) arr += ",";
       }
     arr += "]";
     jsonBody = "{\"features\":" + arr + "}";
   }

   // (2) แปลง jsonBody (string) → uchar[] (UTF-8)
   uchar postData[];
   int postLen = StringToCharArray(jsonBody, postData, CP_UTF8);
   if(postLen <= 0)
     {
      probBuy  = 0.0;
      probSell = 0.0;
      return false;
     }

   // (3) ตั้ง URL + HTTP Headers
   string url     = "http://127.0.0.1:5000/predict";
   string headers = "Content-Type: application/json\r\n";

   // (4) เตรียม buffer รับ response
   uchar   response[];      // dynamic uchar array
   string  result_headers;  // รับ header กลับ (ไม่ใช้ต่อ)
   int     statusCode;      

   // (5) เรียก WebRequest (7-parameter overload)
   int timeout_ms = 5000;  // 5 วินาที
   statusCode = WebRequest(
                    "POST",       // method
                    url,          
                    headers,      // headers
                    timeout_ms,   // timeout (ms)
                    postData,     // data (uchar[])
                    response,     // result (uchar[])
                    result_headers// result_headers (string&)
                );
   if(statusCode != 200)
     {
      // เมื่อ HTTP status ไม่ใช่ 200 → คืนค่า default
      probBuy  = 0.0;
      probSell = 0.0;
      return false;
     }

   // (6) แปลง response (uchar[]) → string (UTF-8)
   string respText = CharArrayToString(response, 0, ArraySize(response));

   // (7) ดึงค่า "Buy" ออกจาก JSON
   int posBuyKey = StringFind(respText, "\"Buy\":");
   if(posBuyKey < 0)
     {
      probBuy  = 0.0;
      probSell = 0.0;
      return false;
     }
   int startBuy = posBuyKey + StringLen("\"Buy\":");
   int endBuy   = StringFind(respText, ",", startBuy);
   if(endBuy < 0) endBuy = StringFind(respText, "}", startBuy);
   if(endBuy < 0)
     {
      probBuy  = 0.0;
      probSell = 0.0;
      return false;
     }
   // ดึง substring แล้ว trim whitespace
   string tmpBuy = StringSubstr(respText, startBuy, endBuy - startBuy);
   tmpBuy = StringTrimLeft(tmpBuy);   // ตัด whitespace ซ้าย
   tmpBuy = StringTrimRight(tmpBuy);  // ตัด whitespace ขวา
   probBuy = StringToDouble(tmpBuy);

   // (8) ดึงค่า "Sell" ออกจาก JSON
   int posSellKey = StringFind(respText, "\"Sell\":");
   if(posSellKey < 0)
     {
      probBuy  = 0.0;
      probSell = 0.0;
      return false;
     }
   int startSell = posSellKey + StringLen("\"Sell\":");
   int endSell   = StringFind(respText, ",", startSell);
   if(endSell < 0) endSell = StringFind(respText, "}", startSell);
   if(endSell < 0)
     {
      probBuy  = 0.0;
      probSell = 0.0;
      return false;
     }
   string tmpSell = StringSubstr(respText, startSell, endSell - startSell);
   tmpSell = StringTrimLeft(tmpSell);   // ตัด whitespace ซ้าย
   tmpSell = StringTrimRight(tmpSell);  // ตัด whitespace ขวา
   probSell = StringToDouble(tmpSell);

   return true;
  }
