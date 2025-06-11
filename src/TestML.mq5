// Scripts/TestML_FileIPC.mq5
#property script_show_inputs
#include "ml_interface.mq5"

void OnStart()
  {
   double features[20];
   for(int i=0;i<20;i++) features[i]=i*0.1;
   if(!SaveFeatures(features,20)) { Print("SaveFeatures FAILED"); return; }
   Print("features.json written");
   Sleep(200);
   double b,s;
   if(!LoadPrediction(b,s)) { Print("LoadPrediction FAILED"); return; }
   PrintFormat("Received buy=%.3f sell=%.3f", b,s);
  }
