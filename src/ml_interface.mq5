// file: src/ml_interface.mq5
#property library
#property strict

// +------------------------------------------------------------------+
// | XGB_PredictProbability                                           |
// | ส่ง POST JSON ไปยัง Flask server แล้วแปลง Response เป็น probBuy, |
// | probSell                                                         |
// +------------------------------------------------------------------+
bool XGB_PredictProbability(const double &features[], double &probBuy, double &probSell)
  {
   // ————— (1) สร้าง JSON payload —————
   string jsonBody = "{\"features\":[";
   for(int i = 0; i < 8; i++)
     {
      // 6 ทศนิยมก็พอสำหรับ weight
      jsonBody += DoubleToString(features[i], 6);
      if(i < 7) jsonBody += ",";
     }
   jsonBody += "]}";
   PrintFormat(">> ml_interface: JSON payload = %s", jsonBody);

   // ————— (2) แปลง JSON เป็น uchar[] (UTF-8) —————
   uchar postData[];
   int postLen = StringToCharArray(jsonBody, postData, CP_UTF8);
   if(postLen <= 0)
     {
      Print(">> ml_interface: Failed to convert JSON to UTF-8 uchar[]");
      probBuy  = 0.0;
      probSell = 0.0;
      return(false);
     }

   // ————— (3) ตั้ง URL และ Headers —————
   string url     = "http://127.0.0.1:5000/predict";
   string headers = "Content-Type: application/json\r\n";
   PrintFormat(">> ml_interface: Sending WebRequest to URL = %s", url);

   // ————— (4) ประกาศตัวแปรรับผล —————
   uchar   response[];      // จะเก็บ response body (UTF-8)
   string  result_headers;  // จะเก็บ response headers (ถ้ามี)
   int     statusCode;      // จะเก็บ HTTP status code

   // ————— (5) เรียก WebRequest —————
   int timeout_ms = 5000;  
   statusCode = WebRequest(
                   "POST",        // HTTP method
                   url,           // URL
                   headers,       // headers
                   timeout_ms,    // timeout (ms)
                   postData,      // body: uchar[]
                   response,      // response body: uchar[]
                   result_headers // response headers: string&
                );

   // Debug: พิมพ์สถานะการเรียก WebRequest
   if(statusCode < 0)
     {
      // ถ้า statusCode < 0 แปลว่าเกิดข้อผิดพลาดระดับ transport
      PrintFormat(">> ml_interface: WebRequest error code = %d (transport/API)", statusCode);
      probBuy  = 0.0;
      probSell = 0.0;
      return(false);
     }
   PrintFormat(">> ml_interface: HTTP status code = %d", statusCode);

   if(statusCode != 200)
     {
      PrintFormat(">> ml_interface: Non-200 status code. ResponseHeaders: %s", result_headers);
      probBuy  = 0.0;
      probSell = 0.0;
      return(false);
     }

   // ————— (6) แปลง response (uchar[]) → string —————
   string respText = CharArrayToString(response, 0, ArraySize(response));
   PrintFormat(">> ml_interface: Response JSON = %s", respText);

   // ————— (7) ดึงค่า probability ออกจาก JSON —————
   // สมมติ JSON รูปแบบ: {"predicted_class":"NoTrade","probabilities":{"Buy":0.123456,"NoTrade":0.876543,"Sell":0.000001}}
   // หา key "Buy": และ "Sell":
   int posBuy  = StringFind(respText, "\"Buy\":");
   int posSell = StringFind(respText, "\"Sell\":");
   if(posBuy < 0 || posSell < 0)
     {
      Print(">> ml_interface: JSON parsing error: ไม่พบ \"Buy\" หรือ \"Sell\" ใน response");
      probBuy  = 0.0;
      probSell = 0.0;
      return(false);
     }

   // อ่านตัวเลข  (สมมติตัวเลขตามหลัง colon อย่างน้อย 1–10 ตัวอักษร)
   // เอา substring ยาวๆ มาค่อย trim / แปลง
   string substrBuy  = StringSubstr(respText, posBuy + 6, 12);
   string substrSell = StringSubstr(respText, posSell + 7, 12);
   // ลบอักขระที่ไม่ใช่ตัวเลข . e E - + 
   string strBuy  = "";
   string strSell = "";
   for(int i = 0; i < StringLen(substrBuy); i++)
     {
      char c = substrBuy[i];
      if((c >= '0' && c <= '9') || c == '.' || c == 'e' || c == 'E' || c == '-' || c == '+')
         strBuy += c;
     }
   for(int i = 0; i < StringLen(substrSell); i++)
     {
      char c = substrSell[i];
      if((c >= '0' && c <= '9') || c == '.' || c == 'e' || c == 'E' || c == '-' || c == '+')
         strSell += c;
     }
   probBuy  = StringToDouble(strBuy);
   probSell = StringToDouble(strSell);
   PrintFormat(">> ml_interface: Parsed probBuy=%.6f, probSell=%.6f", probBuy, probSell);

   return(true);
  }
