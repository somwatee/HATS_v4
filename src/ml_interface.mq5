// file: src/ml_interface.mq5
#property library
#property strict

// ** ตัดบรรทัดนี้ออก **
// #include <Wininet.mqh>  

//+------------------------------------------------------------------+
//| XGB_PredictProbability                                            |
//| รับ features[] (double[8]) → ส่ง POST JSON ไปยัง Flask server    |
//| คืนค่า probBuy, probSell (double)                                 |
//+------------------------------------------------------------------+
bool XGB_PredictProbability(const double &features[], double &probBuy, double &probSell)
  {
   // —————————————— (1) สร้าง JSON payload ——————————————
   string jsonBody;
   {
     string arr = "[";
     for(int i = 0; i < 8; i++)
       {
        arr += DoubleToString(features[i], 6);
        if(i < 7) arr += ",";
       }
     arr += "]";
     jsonBody = "{\"features\":" + arr + "}";
   }

   // ————————— (2) แปลง JSON เป็น uchar[] (UTF-8) —————————
   uchar postData[];
   int postLen = StringToCharArray(jsonBody, postData, CP_UTF8);
   if(postLen <= 0)
     {
      probBuy  = 0.0;
      probSell = 0.0;
      return false;
     }

   // ————————— (3) ตั้ง URL และ Headers —————————
   string url     = "http://127.0.0.1:5000/predict";               
   string headers = "Content-Type: application/json\r\n";

   // ————————— (4) ประกาศตัวแปรรับผล —————————
   uchar   response[];           
   string  result_headers;       
   int     statusCode;           

   // ————————— (5) เรียก WebRequest (7-parameter overload) —————————
   int timeout_ms = 5000;  
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
      probBuy  = 0.0;
      probSell = 0.0;
      return false;
     }

   // ————————— (6) แปลง response (uchar[]) → string —————————
   string respText = CharArrayToString(response, 0, ArraySize(response));

   // ————————— (7) ดึงค่า probability ออกจาก JSON —————————
   int posBuy  = StringFind(respText, "\"Buy\":");
   int posSell = StringFind(respText, "\"Sell\":");
   if(posBuy < 0 || posSell < 0)
     {
      probBuy  = 0.0;
      probSell = 0.0;
      return false;
     }

   probBuy  = StringToDouble( StringSubstr(respText, posBuy + 6, 6) );
   probSell = StringToDouble( StringSubstr(respText, posSell + 7, 6) );

   return true;
  }
