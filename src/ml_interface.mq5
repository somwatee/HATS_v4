// file: src/ml_interface.mq5
#property library
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| XGB_PredictProbability                                           |
//+------------------------------------------------------------------+
bool XGB_PredictProbability(const double &features[], double &probBuy, double &probSell)
{
   // (1) สร้าง JSON payload
   string jsonBody = "{\"features\":[";
   for(int i=0; i<ArraySize(features); i++)
   {
      jsonBody += DoubleToString(features[i], 6);
      if(i < ArraySize(features)-1)
         jsonBody += ",";
   }
   jsonBody += "]}";

   // (2) แปลง JSON เป็น uchar[] (UTF-8)
   uchar postData[];
   int postLen = StringToCharArray(jsonBody, postData, CP_UTF8);
   if(postLen <= 0)
   {
      probBuy = probSell = 0.0;
      return false;
   }

   // (3) เตรียม headers และ URL
   string url     = "http://127.0.0.1:5000/predict";
   string headers = "Content-Type: application/json\r\n";

   // (4) ประกาศ buffer รับผลลัพธ์
   uchar   response[];          // รับ response body
   string  response_headers;    // รับ response headers

   // (5) เรียก WebRequest (overload ที่รับ uchar[])
   int timeout_ms = 5000;
   int statusCode = WebRequest(
                        "POST",         // method
                        url,            // URL
                        headers,        // headers
                        timeout_ms,     // timeout (ms)
                        postData,       // data[]
                        response,       // result[]
                        response_headers// result_headers &
                    );
   PrintFormat(">> ml_interface: HTTP status code = %d", statusCode);
   if(statusCode != 200)
   {
      PrintFormat(">> ml_interface: Non-200 status, headers: %s", response_headers);
      probBuy = probSell = 0.0;
      return false;
   }

   // (6) แปลง response[] → string
   string respText = CharArrayToString(response, 0, ArraySize(response));

   // (7) ดึงค่า probabilities จาก JSON
   int posBuy  = StringFind(respText, "\"Buy\":");
   int posSell = StringFind(respText, "\"Sell\":");
   if(posBuy < 0 || posSell < 0)
   {
      probBuy = probSell = 0.0;
      return false;
   }
   probBuy  = StringToDouble(StringSubstr(respText, posBuy +6, 10));
   probSell = StringToDouble(StringSubstr(respText, posSell+7, 10));

   return true;
}
