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
   //--Variables
struct signal{double price;datetime expiry;bool active;bool fresh;};
signal buySignal,sellSignal;
bool timePass=false;
double lastBuyPrice=0, lastSellPrice=0, sellSl=0, buySl=0,
   sellTp=0, buyTp=0, lastBuyExit=0, lastSellExit=0;
bool newBar=false;
datetime prevBarTime=0;
enum barType{down, null, up};
   //--Fill in with Calendar datelines
datetime calendar[]={
1704294000,
1704308400,
1704353340,
1704374100,
1704375000,
1704461400,
1704461400,
1704466800,
1704699000,
1704846600,
1704896100,
1704979800,
1705023000,
1705042800,
1705066200,
1705388400,
1705411800,
1705411800,
1705417200,
1705456800,
1705474800,
1705498200,
1705537800,
1705584600,
1705647600,
1705676400,
1705979340,
1705991400,
1706046300,
1706084100,
1706085000,
1706088600,
1706107500,
1706107500,
1706110200,
1706188500,
1706189400,
1706190300,
1706275800,
1706626800,
1706661000,
1706664600,
1706686140,
1706706900,
1706707800,
1706707800,
1706727600,
1706729400,
1706788800,
1706790600,
1706794200,
1706799600,
1706805000,
1706880600,
1706886000,
1707091200,
1707145200,
1707190200,
1707193800,
1707241500,
1707255900,
1707399000,
1707431400,
1707485400,
1707760800,
1707790800,
1707807600,
1707809400,
1707831000,
1707894000,
1707922800,
1707948000,
1707957000,
1707980400,
1708003800,
1708066800,
1708090200,
1708095600,
1708389000,
1708435800,
1708475400,
1708542000,
1708589700,
1708590600,
1708594200,
1708608600,
1708613100,
1709040600,
1709046000,
1709080200,
1709082000,
1709127000,
1709191740,
1709213400,
1709213400,
1709256600,
1709305200,
1709537400,
1709611200,
1709650800,
1709685000,
1709728440,
1709730900,
1709736300,
1709737200,
1709739000,
1709817300,
1709818200,
1709819100,
1709823600,
1709904600,
1709904600,
1710226800,
1710246600,
1710262860,
1710313200,
1710349260,
1710419400,
1710505800,
1710511200,
1710727200,
1710819000,
1710819360,
1710822600,
1710829800,
1710851400,
1710918000,
1710957600,
1710959400,
1710971100,
1710981000,
1711008900,
1711009800,
1711009800,
1711011600,
1711013400,
1711022400,
1711024200,
1711028700,
1711090800,
1711102500,
1711112400,
1711461600,
1711499400,
1711576800,
1711629000,
1711629000,
1711634400,
1711715400,
1711726200,
1711848600,
1711980000,
1712039340,
1712066400,
1712146500,
1712152800,
1712160600,
1712212200,
1712233800,
1712320200,
1712320200,
1712714400,
1712752200,
1712756700,
1712759400,
1712772000,
1712837700,
1712838600,
1712839500,
1712854860,
1712901600,
1712930400,
1713184200,
1713232800,
1713247200,
1713270600,
1713286800,
1713287700,
1713287700,
1713307500,
1713333600,
1713369600,
1713403800,
1713443400,
1713506400,
1713856500,
1713857400,
1713861000,
1713879900,
1713922200,
1714048200,
1714053600,
1714101720,
1714113000,
1714134600,
1714140000,
1714372140,
1714480200,
1714480200,
1714485600,
1714517100,
1714565700,
1714571100,
1714572000,
1714586400,
1714588200,
1714594500,
1714631400,
1714653000,
1714653900,
1714739400,
1714744800,
1715056200,
1715252400,
1715254200,
1715257800,
1715266800,
1715274060,
1715320800,
1715344200,
1715349600,
1715569200,
1715666400,
1715689800,
1715695200,
1715736600,
1715776200,
1715823000,
1715862600,
1716294600,
1716310800,
1716343200,
1716357600,
1716400800,
1716448500,
1716449400,
1716453000,
1716467400,
1716471900,
1716530400,
1716559200,
1716768300,
1716904800,
1716946200,
1716964140,
1717072200,
1717077600,
1717146000,
1717158600,
1717158600,
1717422300,
1717423200,
1717482600,
1717509600,
1717551000,
1717589700,
1717595100,
1717596000,
1717597800,
1717676100,
1717677000,
1717677900,
1717763400,
1717763400,
1717928160,
1718085600,
1718172000,
1718195400,
1718215200,
1718217000,
1718219700,
1718242200,
1718281800,
1718298000,
1718335380,
1718346600,
1718373600,
1718627400,
1718685000,
1718713800,
1718776800,
1718837100,
1718868600,
1718870400,
1718881200,
1718886600,
1718913600,
1718949600,
1718954100,
1718955000,
1718958600,
1718977500,
1719250200,
1719318600,
1719324000,
1719365400,
1719410400,
1719480600,
1719491400,
1719496800,
1719577800,
1719577800,
1719736200,
1719815340,
1719842400,
1719910800,
1719927000,
1719928800,
1720008900,
1720009800,
1720015200,
1720029600,
1720074600,
1720078200,
1720182600,
1720182600,
1720341000,
1720533600,
1720576800,
1720620000,
1720677600,
1720701000,
1720787400,
1720792800,
1721046600,
1721061000,
1721133000,
1721133000,
1721169900,
1721196000,
1721266200,
1721282400,
1721304900,
1721305800,
1721306700,
1721368800,
1721392200,
1721805300,
1721806200,
1721809800,
1721828700,
1721828700,
1721831400,
1721910600,
1721997000,
1722320940,
1722348000,
1722389400,
1722398220,
1722407400,
1722416400,
1722428100,
1722429000,
1722429000,
1722434400,
1722448800,
1722450600,
1722510000,
1722511800,
1722515400,
1722520800,
1722580200,
1722601800,
1722866400,
1722918600,
1722984300,
1723084800,
1723086000,
1723120200,
1723206600,
1723512600,
1723528800,
1723552200,
1723600800,
1723615200,
1723638600,
1723685400,
1723701600,
1723725000,
1723764600,
1723788000,
1724157000,
1724263200,
1724310900,
1724311800,
1724315400,
1724329800,
1724334300,
1724373180,
1724385600,
1724416200,
1724421600,
1724425200,
1724429700,
1724767200,
1724808600,
1724912940,
1724934600,
1725008400,
1725021000,
1725021000,
1725345000,
1725372000,
1725413400,
1725457500,
1725458400,
1725460200,
1725505500,
1725538500,
1725539400,
1725544800,
1725625800,
1725625800,
1725634800,
1725948000,
1725970200,
1726034400,
1726057800,
1726143300,
1726144200,
1726145100,
1726576200,
1726576200,
1726639200,
1726682400,
1726684200,
1726699500,
1726709400,
1726743600,
1726749000,
1726800720,
1726812000,
1726813800,
1726834500,
1726835400,
1727075700,
1727076600,
1727080200,
1727099100,
1727152200,
1727154300,
1727186400,
1727197800,
1727227800,
1727335800,
1727337600,
1727353800,
1727356800,
1727440200,
1727440200,
1727677740,
1727718900,
1727773200,
1727791200,
1727795700,
1727871300,
1727937000,
1727958600,
1727964000,
1728045000,
1728435600,
1728496800,
1728563400,
1728626400,
1728649800,
1728649800,
1728972000,
1728995400,
1729028700,
1729058400,
1729125000,
1729167300,
1729168200,
1729169100,
1729231200,
1729603500,
1729691100,
1729693800,
1729709100,
1729754100,
1729755000,
1729758600,
1729773000,
1729777500,
1729799100,
1729859400,
1730005200,
1730136600,
1730210400,
1730224800,
1730230200,
1730248200,
1730269740,
1730278800,
1730290500,
1730291400,
1730319300,
1730342880,
1730356200,
1730377800,
1730377800,
1730446200,
1730464200,
1730469600,
1730777400,
1730818800,
1730819700,
1730819760,
1730843100,
1730930400,
1730980800,
1730982600,
1730986200,
1731006000,
1731007800,
1731072600,
1731290400,
1731394800,
1731457800,
1731504600,
1731538800,
1731544200,
1731591000,
1731614400,
1731616980,
1731654000,
1731677400,
1731891900,
1732010400,
1732023000,
1732086000,
1732165920,
1732176000,
1732195800,
1732258800,
1732263300,
1732264200,
1732267800,
1732279200,
1732282200,
1732286700,
1732633200,
1732647600,
1732667400,
1732669200,
1732672800,
1732714200,
1732719600,
1732778940,
1732784100,
1732878000,
1732887000,
1733151600,
1733211000,
1733238000,
1733272200,
1733318100,
1733324400,
1733337900,
1733405400,
1733491800,
1733491800,
1733801400,
1733923800,
1733928300,
1733931000,
1733963400,
1733992200,
1733994000,
1734009300,
1734010200,
1734011100,
1734073200,
1734336900,
1734337800,
1734341400,
1734360300,
1734380400,
1734418800,
1734442200,
1734442200,
1734505200,
1734548400,
1734550200,
1734558300,
1734576720,
1734589800,
1734609600,
1734615000,
1734678000,
1734701400,
1734701400,
1734960600,
1735219800,
1735824600,
1735916400,
1736148540,
1736235000,
1736262000,
1736296200,
1736342100,
1736343000,
1736362800,
1736515800,
1736515800,
1736861400,
1736924400,
1736947800,
1736987400,
1737010800,
1737034200,
1737097200,
1737442800,
1737466200,
1737495900,
1737639000,
1737639000,
1737689400,
1737690480,
1737700200,
1737706500,
1737707400,
1737711000,
1737729900,
1738076400,
1738110600,
1738161900,
1738164600,
1738177200,
1738179000,
1738242900,
1738243800,
1738244700,
1738308540,
1738330200,
1738330200,
1738594800,
1738654200,
1738681200,
1738705500,
1738761300,
1738767600,
1738843200,
1738848600,
1738935000,
1738935000,
1739367000,
1739412000,
1739430000,
1739453400,
1739539800,
1739849400,
1739862000,
1739885400,
1739926800,
1739930400,
1739948400,
1739991600,
1740011400,
1740058200,
1740121200,
1740125700,
1740126600,
1740130200,
1740144600,
1740149100,
1740303000,
1740443400,
1740495600,
1740529800,
1740663000,
1740727740,
1740749400,
1740749400
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
   buySignal.price=0;buySignal.expiry=0;buySignal.active=false;buySignal.fresh=false;
   sellSignal=buySignal;
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
      double open = iOpen(_Symbol,PERIOD_M1,1);
      double height = iHigh(_Symbol,PERIOD_M1,1) - iLow(_Symbol,PERIOD_M1,1);
      datetime time = iTime(_Symbol,PERIOD_M1,1);
      if(open > close){
         double body = open-close;
         if(body>=barBody && height>=barHeightMin && height<=barHeightMax){
            if(!calendarChecks || checkCalendar(time)){
               buySignal.price=close;
               buySignal.expiry=iTime(_Symbol,PERIOD_M1,0)+signalTimeout;
               buySignal.active=true;
               buySignal.fresh=true;
            }
         }
      }
      else if(close > open){
         double body = close-open;
         if(body>=barBody && height>=barHeightMin && height<=barHeightMax){
            if(!calendarChecks || checkCalendar(time)){
               sellSignal.price=close;
               sellSignal.expiry=iTime(_Symbol,PERIOD_M1,0)+signalTimeout;
               sellSignal.active=true;
               sellSignal.fresh=true;
            }
         }
      }
   }
//=========================== First executions ===============================
   if(timePass){
      if(newBar || !entryAtNewBars){
         if(goLong && buySignal.active && !posTypeCheck(POSITION_TYPE_BUY)){
            ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
            if(   (buySignal.fresh && (firstEntryCheckSkip || ask<=(buySignal.price-firstEntrySpacing)))
               || (!buySignal.fresh && ask<=(lastBuyExit-postExitEntry) && ask<=buySignal.price)   ){ //price crosses first entry
               ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); //redone to update
               double spread=NormalizeDouble(ask-bid,_Digits);
               if(spread <= maxSpread){ //check spread
                  buySl = slFixPoints==0 ? 0 : bid-slFix;
                  buyTp = tpFixPoints==0 ? 0 : ask+tpFix;
                  if(addPosition(ORDER_TYPE_BUY,firstLot,buyTp,buySl,request,result)){ //exe.
                     lastBuyPrice=result.price;
                     buySignal.fresh = false;
                     int buyCount = typeCount(POSITION_TYPE_BUY);
                     setGroupSlTp(buyCount,POSITION_TYPE_BUY,request,result);
                  }
               }
            }
         }
         if(goShort && sellSignal.active && !posTypeCheck(POSITION_TYPE_SELL)){
            bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
            if(   (sellSignal.fresh && (firstEntryCheckSkip || bid>=(sellSignal.price+firstEntrySpacing)))
               || (!sellSignal.fresh && bid>=(lastSellExit+postExitEntry) && bid>=sellSignal.price)   ){ //price crosses first entry
               ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); //redone to update
               double spread=NormalizeDouble(ask-bid,_Digits);
               if(spread <= maxSpread){ //check spread
                  sellSl = slFixPoints==0 ? 0 : ask+slFix;
                  sellTp = tpFixPoints==0 ? 0 : bid-tpFix;
                  if(addPosition(ORDER_TYPE_SELL,firstLot,sellTp,sellSl,request,result)){ //exe.
                     lastSellPrice=result.price;
                     sellSignal.fresh = false;
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
   if(stacksAfterStopTime || timePass){
      if(newBar || !entryAtNewBars){
      //long stackers
         int buyCount = typeCount(POSITION_TYPE_BUY);
         if(buyCount>0 && buyCount<maxTrades && (stacksAfterExpiry || buySignal.active)){
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
         if(sellCount>0 && sellCount<maxTrades && (stacksAfterExpiry || sellSignal.active)){
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
   if(TimeCurrent()>buySignal.expiry){
      buySignal.active=false;
   }
   if(TimeCurrent()>sellSignal.expiry){
      sellSignal.active=false;
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
   return(balanceDrawdownRatio + (trades/100));
  }
//+------------------------------------------------------------------+