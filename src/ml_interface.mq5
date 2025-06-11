// src/ml_interface.mq5
#property library
#property strict

bool SaveFeatures(const double &features[], int n)
  {
   int fh = FileOpen("features.json", FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(fh==INVALID_HANDLE) { Print("SaveFeatures Err=",GetLastError()); return(false); }
   FileWriteString(fh, "{ \"features\":[");
   for(int i=0;i<n;i++)
     {
      FileWriteString(fh, DoubleToString(features[i],6));
      if(i<n-1) FileWriteString(fh,",");
     }
   FileWriteString(fh, "] }");
   FileClose(fh);
   return(true);
  }

bool LoadPrediction(double &buyProb,double &sellProb)
  {
   int fh = FileOpen("prediction.json", FILE_READ|FILE_TXT|FILE_ANSI);
   if(fh==INVALID_HANDLE) { Print("LoadPrediction Err=",GetLastError()); return(false); }
   string txt = FileReadString(fh);
   FileClose(fh);
   int pB=StringFind(txt,"\"Buy\":"), pS=StringFind(txt,"\"Sell\":");
   buyProb  = StringToDouble(StringSubstr(txt,pB+6,10));
   sellProb = StringToDouble(StringSubstr(txt,pS+7,10));
   return(true);
  }
