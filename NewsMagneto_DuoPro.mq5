//+------------------------------------------------------------------+
//|                                              NewsMagneto_Pro.mq5 |
//|                                     Copyright 2024, Teenodi Ltd. |
//|                                         https://www.jukwaese.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Teenodi Ltd."
#property link      "https://www.jukwaese.com"
#property version   "1.00"
#property strict
#define magnetoMagic 137973
//============================ inputs ===============================
input group "Functionality Controls"
input bool entryAtNewBars=false,goLong=true,goShort=true,stopsTrailer=false,tpShifter=true,equityLimits=false,
   stacksAfterStopTime=true,stacksAfterExpiry=true,firstEntryCheckSkip=true,calendarChecks=false;
   //--Trade Settings
input group "Trade Settings"
input uint tpLeaderPoints=15,slTrailerPoints=30,firstEntryPoints=0,postExitEntryPoints=10,
   slFixPoints=0,tpFixPoints=250,spreadFilterPoints=10,failedCloseSltpPoints=2;
   //--increment and decrement equation parameters
   //--spacer
input group "Spacer Function Settings" //spacing between trades
input uint firstSpacerPoints=50,minimumSpacerPoints=5;
input double spacerMultiplier=0.9;
   //--lot
input group "Lot Function Settings" //lot size increments
input double firstLot=0.3,maxLot=5,lotMultiplier=1.10;
   //--tp
input group "TP Function Settings" //group profit target
input uint firstTpPoints=100,maximumTpPoints=200;
input double tpMultiplier=1.10;
   //--Max and Min filters
input group "Max and Min filters"
input datetime startTime=1730768400,stopTime=1730847600;
input double MaxEquity=5500,MinEquity=6500;
input uint signalTimeout=480;
input int maxTrades=30;
   //--Bar height and body Params
input group "Bar height and body Params"
input uint barBodyPoints=40,barHeightMinPoints=50,barHeightMaxPoints=650;
//=========================== globals ===============================
   //--constant inputs
double tp1,tpMax,spacer1,spacerMin,
   firstEntrySpacing,postExitEntry,slFix,tpFix,
   barBody,barHeightMin,barHeightMax,
   emergencySltp,maxSpread,tpLead,slTrail;
int start,stop;
string name = "magLine";
   //--Variables
struct signal{double price;datetime expiry;bool active;bool freshBuy;bool freshSell;};
signal duoSignal;
bool timePass=false;
double lastBuyPrice=0, lastSellPrice=0, sellSl=0, buySl=0,
   sellTp=0, buyTp=0, lastBuyExit=0, lastSellExit=0;
bool newBar=false;
datetime prevBarTime=0;
enum barType{down, null, up};
   //--Fill in with Calendar datelines
datetime calendar[]={

};
//============================ functions =============================
//------------------------------ trade --------------------------------+
ENUM_ORDER_TYPE_FILLING orderFill;
bool addPosition(ENUM_ORDER_TYPE type,double vol,double tpx,double slx,MqlTradeRequest &request,MqlTradeResult &result){
   ZeroMemory(request);
   ZeroMemory(result);
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = NormalizeDouble(vol, 2);
   request.type_filling = orderFill;
   request.tp = NormalizeDouble(tpx,_Digits);
   if(!(slFixPoints==0)){
      request.sl = NormalizeDouble(slx,_Digits);
   }
   request.magic = magnetoMagic;
   request.type = type;
   if(OrderSend(request, result)){return true;}
   return false;
}
void closeAll(MqlTradeRequest &request,MqlTradeResult &result){
   for(int a=PositionsTotal()-1; a>=0; a--){ // backwards to avoid effect of queue movement
      ulong ticket = PositionGetTicket(a);
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==magnetoMagic){
         double volume = PositionGetDouble(POSITION_VOLUME);
         ZeroMemory(request);
         ZeroMemory(result);
         request.action = TRADE_ACTION_DEAL;
         request.position = ticket;
         request.symbol = _Symbol;
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         request.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
         request.volume = volume;
         request.type_filling = orderFill;
         if(!OrderSend(request, result)){
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            double lower = NormalizeDouble(currentPrice-emergencySltp,_Digits);
            double upper = NormalizeDouble(currentPrice+emergencySltp,_Digits);
            double newSL = (type == POSITION_TYPE_BUY) ? lower : upper;
            double newTP = (type == POSITION_TYPE_BUY) ? upper : lower;
            setSLTP(ticket, newSL, newTP,request,result);
         }
      }
   }
}
void setSLTP(ulong ticket,double tsl,double ttp,MqlTradeRequest &request,MqlTradeResult &result){
   ZeroMemory(request);
   ZeroMemory(result);
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = _Symbol;
   PositionSelectByTicket(ticket);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double stops = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double lower = SymbolInfoDouble(_Symbol,SYMBOL_BID) - stops;
   double upper = SymbolInfoDouble(_Symbol,SYMBOL_ASK) + stops;
   double sls = type==POSITION_TYPE_BUY ? (tsl<lower ? tsl : lower) : ((tsl>upper || tsl==0) ? tsl : upper);
   double tps = type==POSITION_TYPE_BUY ? ((ttp>upper || ttp==0) ? ttp : upper) : (ttp<lower ? ttp : lower);
   request.sl = NormalizeDouble(sls,_Digits);
   request.tp = NormalizeDouble(tps,_Digits);
   if(OrderSendAsync(request, result)){}
}
void groupTrailer(ENUM_POSITION_TYPE type,double Sl,double Tp){
//--- order structures
   MqlTradeRequest request;
   MqlTradeResult result;
   for(int i=PositionsTotal()-1; i>=0; i--){
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==magnetoMagic){
         if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type){
            setSLTP(ticket,Sl,Tp,request,result);
         }
      }
   }
}
int typeCount(ENUM_POSITION_TYPE type){
   int count=0;
   for(int i=PositionsTotal()-1; i>=0; i--){
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==magnetoMagic){
         if(PositionGetInteger(POSITION_TYPE) == type){
            count++;
         }
      }
   }
   return count;
}
void groupTp(double totalTp,ENUM_POSITION_TYPE type,double &groupSl,double &groupTp){ //based on points moved, not money made
   //sum opening prices and keep count
   double sums=0; int n=0;
   for(int i=PositionsTotal()-1; i>=0; i--){
   ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==magnetoMagic){
         if(PositionGetInteger(POSITION_TYPE) == type){
            sums+=PositionGetDouble(POSITION_PRICE_OPEN);
            n++;
         }
      }
   }
   //calculate sl & tp values
   double slVal=0,tpVal=0;
   if(type==POSITION_TYPE_BUY){
      slVal=buySl;
      tpVal=(sums+totalTp)/n;
   }
   else{
      slVal=sellSl;
      tpVal=(sums-totalTp)/n;
   }
   //return values
   groupTp=tpVal;groupSl=slVal;
}
void setGroupSlTp(int typeCount,ENUM_POSITION_TYPE type,MqlTradeRequest &request,MqlTradeResult &result){
   double tp = tp1*MathPow(tpMultiplier,(double)(typeCount-1));
   tp = tp>tpMax ? tpMax : tp;
   double gsl,gtp;
   groupTp(tp,type,gsl,gtp);
   for(int j=PositionsTotal()-1; j>=0; j--){
      ulong ticket = PositionGetTicket(j);
      if(PositionGetInteger(POSITION_TYPE) == type){
         if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==magnetoMagic){
            setSLTP(ticket,gsl,gtp,request,result);
         }
      }
   }
}
bool checkCalendar(datetime time){
   int size=ArraySize(calendar);
   for(int i=0; i<size-1; i++){
      if(calendar[i] == time){
         return true;
      }
   }
   return false;
}
bool posTypeCheck(ENUM_POSITION_TYPE type){
   for(int i=PositionsTotal()-1; i>=0; i--){
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==magnetoMagic){
         if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==type){
            return true;
         }
      }
   }
   return false;
}
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
//--- check that autotrading is enabled
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)){
      Alert("First Enable autotrading on terminal to take trades");
   }   
// Initialize time variables
   MqlDateTime inputTime;
   TimeToStruct(startTime,inputTime);
   start = inputTime.hour*3600 + inputTime.min*60 + inputTime.sec;
   TimeToStruct(stopTime,inputTime);
   stop = inputTime.hour*3600 + inputTime.min*60 + inputTime.sec;
//--- check that starttime is less than stoptime
   if(start>=stop){
      Alert("stopTime of the day must be further or greater than startTime!");
      return INIT_FAILED;
   }
//--- get possible filling policy types by symbol
   uint filling=(uint)SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   //--- if the required filling policy is supported, add it to the request
   if((filling&SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK){
      orderFill=ORDER_FILLING_FOK;
   }
   if((filling&SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC){
      orderFill=ORDER_FILLING_IOC;
   }
// Set up symbol-specific variables
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   slTrail = NormalizeDouble(slTrailerPoints*point,_Digits);
   tpLead = NormalizeDouble(tpLeaderPoints*point,_Digits);
   maxSpread = NormalizeDouble(spreadFilterPoints*point,_Digits);
   emergencySltp = NormalizeDouble(failedCloseSltpPoints*point,_Digits);
   firstEntrySpacing = NormalizeDouble(firstEntryPoints*point,_Digits);
   tp1 = NormalizeDouble(firstTpPoints*point,_Digits);
   tpMax = NormalizeDouble(maximumTpPoints*point,_Digits);
   spacer1 = NormalizeDouble(firstSpacerPoints*point,_Digits);
   spacerMin = NormalizeDouble(minimumSpacerPoints*point,_Digits);
   postExitEntry = NormalizeDouble(postExitEntryPoints*point,_Digits);
   slFix = NormalizeDouble(slFixPoints*point,_Digits);
   tpFix = NormalizeDouble(tpFixPoints*point,_Digits);
   barBody = NormalizeDouble(barBodyPoints*point,_Digits);
   barHeightMin = NormalizeDouble(barHeightMinPoints*point,_Digits);
   barHeightMax = NormalizeDouble(barHeightMaxPoints*point,_Digits);
//--- sort calendar
   if(calendarChecks){
      ArraySort(calendar);
   }
//--- initialize Signals
   duoSignal.price=0;duoSignal.expiry=0;duoSignal.active=false;duoSignal.freshBuy=false;duoSignal.freshSell=false;
//--- initialize previous Bar Time
   prevBarTime=iTime(_Symbol,PERIOD_M1,0);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- order structures
   MqlTradeRequest request;
   MqlTradeResult result;
//--- current tick data
   double bid,ask;
//============================= SLTP trail ==================================
   if(stopsTrailer){
      double ttpShort = 0; //ask-tpLead;
      double ttpLong = 0; //bid+tpLead;
      //loop for long trades
      for(int j=PositionsTotal()-1; j>=0; j--){
         ulong ticket = PositionGetTicket(j);
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){ //long position found
            if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==magnetoMagic){ //skip magic check to help older session's trades
               double tpi = PositionGetDouble(POSITION_TP);
               if(!(tpi==0)){
                  bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
                  if(bid > (tpi-tpLead)){
                     groupTrailer(POSITION_TYPE_BUY,bid-slTrail,ttpLong);
                     break;
                  }
               }
               else{ //tpi is 0, use sli
                  double sli = PositionGetDouble(POSITION_SL);
                  bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
                  if(bid > (sli+slTrail)){
                     groupTrailer(POSITION_TYPE_BUY,bid-slTrail,ttpLong);
                     break;
                  }
               }
            }
         }
      }
      //loop for short trades
      for(int j=PositionsTotal()-1; j>=0; j--){
         ulong ticket = PositionGetTicket(j);
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){ //short position found
            if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==magnetoMagic){ //skip magic check to help older session's trades
               double tpi = PositionGetDouble(POSITION_TP);
               if(!(tpi==0)){
                  ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
                  if(ask < (tpi+tpLead)){
                     groupTrailer(POSITION_TYPE_SELL,ask+slTrail,ttpShort);
                     break;
                  }
               }
               else{ //tpi is 0, use sli
                  double sli = PositionGetDouble(POSITION_SL);
                  ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
                  if(ask < (sli-slTrail)){
                     groupTrailer(POSITION_TYPE_SELL,ask+slTrail,ttpShort);
                     break;
                  }
               }
            }
         }
      }
   }
//=========================== Signal Processing ===============================
   //check for new bar
   if(!newBar){
      datetime barTime = iTime(_Symbol, PERIOD_M1, 0);
      if(barTime != prevBarTime){ // checks if bar time has changed
         newBar = true;
         prevBarTime = barTime;
      }
   }
   if(newBar){
   //--- Get last complete bar data
      double close = iClose(_Symbol,PERIOD_M1,1);
      double body = MathAbs(close - iOpen(_Symbol,PERIOD_M1,1));
      double height = iHigh(_Symbol,PERIOD_M1,1) - iLow(_Symbol,PERIOD_M1,1);
      if(body>=barBody && height>=barHeightMin && height<=barHeightMax){
         if(!calendarChecks || checkCalendar(iTime(_Symbol,PERIOD_M1,1))){
            duoSignal.price=close;
            duoSignal.expiry=iTime(_Symbol,PERIOD_M1,0)+signalTimeout;
            duoSignal.active=true;
            duoSignal.freshBuy=true;
            duoSignal.freshSell=true;
            ObjectCreate(0,name,OBJ_HLINE,0,TimeCurrent(),close);
            ObjectSetString(0,name,OBJPROP_LEVELTEXT,"Active Magneto Line");
            ObjectSetInteger(0,name,OBJPROP_COLOR,clrGreenYellow);
            ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
            ChartRedraw(0);
         }
      }
   }
//=========================== First executions ===============================
   if(timePass){
      if((newBar || !entryAtNewBars) && duoSignal.active){
         if(goLong && !posTypeCheck(POSITION_TYPE_BUY)){
            ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
            if(   (duoSignal.freshBuy && (firstEntryCheckSkip || ask<=(duoSignal.price-firstEntrySpacing)))
               || (!duoSignal.freshBuy && ask<=(lastBuyExit-postExitEntry) && ask<=duoSignal.price)   ){ //price crosses first entry
               ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); //redone to update
               double spread=NormalizeDouble(ask-bid,_Digits);
               if(spread <= maxSpread){ //check spread
                  buySl = slFixPoints==0 ? 0 : bid-slFix;
                  buyTp = tpFixPoints==0 ? 0 : ask+tpFix;
                  if(addPosition(ORDER_TYPE_BUY,firstLot,buyTp,buySl,request,result)){ //exe.
                     lastBuyPrice=result.price;
                     duoSignal.freshBuy = false;
                     int buyCount = typeCount(POSITION_TYPE_BUY);
                     setGroupSlTp(buyCount,POSITION_TYPE_BUY,request,result);
                  }
               }
            }
         }
         if(goShort && !posTypeCheck(POSITION_TYPE_SELL)){
            bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
            if(   (duoSignal.freshSell && (firstEntryCheckSkip || bid>=(duoSignal.price+firstEntrySpacing)))
               || (!duoSignal.freshSell && bid>=(lastSellExit+postExitEntry) && bid>=duoSignal.price)   ){ //price crosses first entry
               ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); //redone to update
               double spread=NormalizeDouble(ask-bid,_Digits);
               if(spread <= maxSpread){ //check spread
                  sellSl = slFixPoints==0 ? 0 : ask+slFix;
                  sellTp = tpFixPoints==0 ? 0 : bid-tpFix;
                  if(addPosition(ORDER_TYPE_SELL,firstLot,sellTp,sellSl,request,result)){ //exe.
                     lastSellPrice=result.price;
                     duoSignal.freshSell = false;
                     int sellCount = typeCount(POSITION_TYPE_SELL);
                     setGroupSlTp(sellCount,POSITION_TYPE_SELL,request,result);
                  }
               }
            }
         }
      }
   //Check if session active
      MqlDateTime currentTime;
      TimeToStruct(TimeCurrent(),currentTime);
      int current = currentTime.hour*3600 + currentTime.min*60 + currentTime.sec;
      if(current<start || current>=stop){
         timePass=false;
      }
   }
   else{
   // Check is session active
      MqlDateTime currentTime;
      TimeToStruct(TimeCurrent(),currentTime);
      int current = currentTime.hour*3600 + currentTime.min*60 + currentTime.sec;
      if(current>=start && current<stop){
         timePass=true;
      }
   }

//=========================== stacker executions ==============================
   if((stacksAfterStopTime || timePass) && (stacksAfterExpiry || duoSignal.active)){
      if(newBar || !entryAtNewBars){
      //long stackers
         int buyCount = typeCount(POSITION_TYPE_BUY);
         if(buyCount>0 && buyCount<maxTrades){
            if(lastBuyPrice != 0){
               double spacing = spacer1*MathPow(spacerMultiplier,(double)(buyCount-1));
               spacing = spacing<spacerMin ? spacerMin : spacing;
               ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
               if((spacing!=0) && ask < (lastBuyPrice-spacing)){
                  double spread=NormalizeDouble(ask-bid,_Digits);
                  if(spread <= maxSpread){ //check spread
                     double lot = firstLot*MathPow(lotMultiplier,(double)buyCount);
                     lot = lot>maxLot ? maxLot : lot;
                     if(addPosition(ORDER_TYPE_BUY,lot,buyTp,buySl,request,result)){ //exe.
                        lastBuyPrice=result.price;
                        buyCount = typeCount(POSITION_TYPE_BUY);
                        setGroupSlTp(buyCount,POSITION_TYPE_BUY,request,result);
                     }
                  }
               }
            }
            else{ //find lastBuyPrice
               for(int i=PositionsTotal(); i>=0; i++){
                  ulong ticket = PositionGetTicket(i);
                  if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==magnetoMagic){ //skip magic check to cater for manual entries
                     if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){ //long position found
                        double open = PositionGetDouble(POSITION_PRICE_OPEN);
                        if(open < lastBuyPrice || lastBuyPrice==0){
                           lastBuyPrice = open;
                        }
                     }
                  }
               }
            }
         }
      //short stackers
         int sellCount = typeCount(POSITION_TYPE_SELL);
         if(sellCount>0 && sellCount<maxTrades){
            if(lastSellPrice != 0){
               double spacing = spacer1*MathPow(spacerMultiplier,(double)(sellCount-1));
               spacing = spacing<spacerMin ? spacerMin : spacing;
               ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
               if((spacing!=0) && bid > (lastSellPrice+spacing)){
                  double spread=NormalizeDouble(ask-bid,_Digits);
                  if(spread <= maxSpread){ //check spread
                     double lot = firstLot*MathPow(lotMultiplier,(double)sellCount);
                     lot = lot>maxLot ? maxLot : lot;
                     if(addPosition(ORDER_TYPE_SELL,lot,sellTp,sellSl,request,result)){ //exe.
                        lastSellPrice=result.price;
                        sellCount = typeCount(POSITION_TYPE_SELL);
                        setGroupSlTp(sellCount,POSITION_TYPE_SELL,request,result);
                     }
                  }
               }
            }
            else{ //find lastBuyPrice
               for(int i=PositionsTotal(); i>=0; i++){
                  ulong ticket = PositionGetTicket(i);
                  if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==magnetoMagic){ //skip magic check to cater for manual entries
                     if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){ //short position found
                        double open = PositionGetDouble(POSITION_PRICE_OPEN);
                        if(open > lastSellPrice || lastSellPrice==0){
                           lastSellPrice = open;
                        }
                     }
                  }
               }
            }
         }
      }
   }
//====================== deactivate newbar ======================
//--deactivate after some time
   if(newBar){
      newBar = false;
   }
//==================== update last exit variables ======================
   if(posTypeCheck(POSITION_TYPE_BUY)){
      lastBuyExit = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   }
   if(posTypeCheck(POSITION_TYPE_SELL)){
      lastSellExit = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   }
//=============== deactivate expired signals ========================
   if(TimeCurrent()>duoSignal.expiry){
      duoSignal.active=false;
      ObjectSetString(0,name,OBJPROP_TEXT,"Inactive Magneto Line");
      ObjectSetInteger(0,name,OBJPROP_COLOR,clrDarkGray);
      ChartRedraw(0);
   }
//=============== remove exceeded calendar entries ========================
   if(calendarChecks){
      int size = ArraySize(calendar);
      for(int i=0; i<size; i++){
         if(calendar[i]>TimeCurrent()){
            if(i>1){
               ArrayRemove(calendar,0,i-1);
            }
            break;
         }
      }
   }
//========================== equity controller ==============================
   if(equityLimits){
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity<MinEquity || equity>MaxEquity){
         MqlTradeRequest request;
         MqlTradeResult result;
         closeAll(request,result);
         Alert("Equity Limits Reached!");
         ExpertRemove();
      }
   }
  }
//+------------------------------------------------------------------+
//| Expert tester function                                           |
//+------------------------------------------------------------------+
double OnTester()
  {
   double profit = TesterStatistics(STAT_PROFIT);
   double maxDrawdown = TesterStatistics(STAT_EQUITY_DD_RELATIVE);
   double trades = TesterStatistics(STAT_TRADES);
   
   // Basic validation
   if(maxDrawdown == 0 || profit <= 0){
     return(0.0);
   }
   // Simple balance to drawdown ratio
   double balanceDrawdownRatio = profit / maxDrawdown;
   
   // Add weight for number of trades to favor more active strategies
   return(balanceDrawdownRatio * profit);
  }
//+------------------------------------------------------------------+