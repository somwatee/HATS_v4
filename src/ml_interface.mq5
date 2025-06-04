// file: src/ml_interface.mq5
#property strict

#include "config.mq5"

//+------------------------------------------------------------------+
//| ฟังก์ชัน: XGB_PredictProbability                                 |
//| วัตถุประสงค์:                                                   |
//|   คืนค่าความน่าจะเป็นของคลาส Buy และ Sell จาก XGBoost Model   |
//|   - features[] : อาร์เรย์ฟีเจอร์ที่เตรียมไว้ (ขนาด 8)            |
//|   - probBuy    : ค่าความน่าจะเป็นของคลาส Buy                   |
//|   - probSell   : ค่าความน่าจะเป็นของคลาส Sell                  |
//|                                                                  |
//| วิธีใช้งาน:                                                       |
//|   EA จะเรียกฟังก์ชันนี้ทุกครั้งเมื่อไม่มีสัญญาณ ICT             |
//|   ถ้ามี DLL หรือ HTTP endpoint ให้ uncomment ส่วน import ด้านล่าง|
//|   หรือใช้ stub ที่กำหนดไว้ (probBuy=0.8, probSell=0.2)           |
//|                                                                  |
//| คืนค่า:                                                          |
//|   true  = คำนวณ/เรียกเรียบร้อย (probBuy, probSell ถูกกำหนด)      |
//|   false = เกิดข้อผิดพลาด                                          |
//+------------------------------------------------------------------+

//--- หากมี DLL สำหรับ XGBoost ให้ uncomment ส่วนนี้และคอมไพล์ DLL ตาม API ที่กำหนด
/*
#import "xgb_model_wrapper.dll"
bool XGB_Predict(const double &features[], int size, double &probBuy, double &probSell);
#import
*/

//--- Stub implementation (ใช้สำหรับทดสอบ ถ้ายังไม่มี DLL หรือ HTTP server)
bool XGB_PredictProbability(const double &features[], double &probBuy, double &probSell)
{
   // ตัวอย่าง: คืนค่า dummy probability
   probBuy  = 0.80;  // สมมติโมเดลให้ความน่าจะเป็น Buy = 80%
   probSell = 0.20;  // สมมติโมเดลให้ความน่าจะเป็น Sell = 20%
   return(true);
}

/*
//--- ถ้าใช้งานผ่าน DLL จริง ให้ให้ฟังก์ชันเรียก XGB_Predict จาก DLL เช่นนี้:
bool XGB_PredictProbability(const double &features[], double &probBuy, double &probSell)
{
   int size = 8;  // ขนาดอาร์เรย์ฟีเจอร์
   if(XGB_Predict(features, size, probBuy, probSell))
      return(true);
   // ถ้า DLL คืนค่า false ให้ตั้งค่า default
   probBuy  = 0.0;
   probSell = 0.0;
   return(false);
}
*/

/*
//--- หรือถ้าจะเรียก HTTP endpoint (Flask server) ทดสอบเปลี่ยนเป็นโค้ดประมาณนี้:
#include <Wininet.mqh>

bool XGB_PredictProbability(const double &features[], double &probBuy, double &probSell)
{
   // สร้าง JSON payload จาก features[]
   string jsonPayload = "{";
   for(int i = 0; i < 8; i++)
   {
      jsonPayload += StringFormat("\"f%d\":%f", i, features[i]);
      if(i < 7) jsonPayload += ",";
   }
   jsonPayload += "}";

   // ตัวอย่าง URL ของ Flask server: http://127.0.0.1:5000/predict
   string url = "http://127.0.0.1:5000/predict";

   char result[];
   char headers[] = "Content-Type: application/json\r\n";
   int    res_code;
   int    timeout = 5000; // 5 วินาที

   // ส่ง HTTP POST
   int resp = WebRequest("POST", url, headers, 0, jsonPayload, 0, NULL, 0, result, res_code, timeout);
   if(resp != 200 || res_code != 200)
   {
      probBuy  = 0.0;
      probSell = 0.0;
      return(false);
   }

   // แปลงผลลัพธ์ (เช่น {"probBuy":0.75,"probSell":0.25})
   string responseStr = CharArrayToString(result, 0, ArraySize(result));
   // สามารถใช้ StringFind/Parse ได้ตามต้องการ
   // สำหรับตัวอย่าง สมมติ parse สำเร็จ:
   probBuy  = 0.75;
   probSell = 0.25;
   return(true);
}
