//+------------------------------------------------------------------+
//|                                          EthMagneto_DuoPro.mq5 |
//|                                     Copyright 2024, Teenodi Ltd. |
//|                                         https://www.jukwaese.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Teenodi Ltd."
#property link      "https://www.jukwaese.com"
#property version   "2.00"
#property strict
#define magnetoMagic 137973

//+------------------------------------------------------------------+
//| Enumeration Definitions                                           |
//+------------------------------------------------------------------+
enum SymbolSource { Native_Chart, Input_Symbols };
enum PeriodSource { Native_Chart_Period, Input_Periods };

//+------------------------------------------------------------------+
//| Structure Definitions                                             |
//+------------------------------------------------------------------+
struct MagnetoLine
{
   double price;
   datetime expiry;
};

struct SymbolData
{
   string symbol;
   ENUM_TIMEFRAMES periods[];
   MagnetoLine lines[];
   double lastBuyPrice;
   double lastSellPrice;
   double lastBuyExit;
   double lastSellExit;
   double buySl;
   double buyTp;
   double sellSl;
   double sellTp;
   bool freshBuy;
   bool freshSell;
   
   // Cached symbol-specific values
   double point;
   int digits;
   double tickSize;
   double tickValue;
   double minLot;
   double maxLot;
   double lotStep;
   double contractSize;
   datetime lastBarTime;
   
   // Normalized parameter values for this symbol
   double norm_firstSpacerPoints;
   double norm_minimumSpacerPoints;
   double norm_slTrailerPoints;
   double norm_tpLeaderPoints;
   double norm_firstTpPoints;
   double norm_maximumTpPoints;
   double norm_slFixPoints;
   double norm_tpFixPoints;
   double norm_spreadFilterPoints;
   double norm_failedCloseSltpPoints;
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
// Functionality Controls
input group "Functionality Controls"
input bool goLong=true,goShort=true,stopsTrailer=false,tpShifter=true,equityLimits=false,
   stacksAfterStopTime=true,stacksAfterExpiry=true;

// Symbol and Timeframe Settings
input group "Symbol and Timeframe Settings"
input SymbolSource Symbol_Source = Native_Chart;
input string Comma_Separated_Symbols = "EURUSD,USDJPY,AUDUSD,USDCHF,USDCAD,XAUUSD";
input bool AutoCorrect_Symbol_List = true;
input int maxSymbolsTradedPerTimePerType = 5;
input PeriodSource Period_Source = Native_Chart_Period;
input string Comma_Separated_Timeframes = "M1,M5,H1";

// ETH Line Settings
input group "ETH Line Settings"
input int lineRetentionDays = 7;
input int ETH_Hour = 16;
input int ETH_Minute = 30;
input ENUM_APPLIED_PRICE ETH_PriceType = PRICE_CLOSE;

// Signal Processing Settings
input group "Signal Processing Settings"
input int minimumRangeNoTouchingLine = 3;
input double wickToBodyFactor = 2.0;

// Trade Settings (Base values for 5-digit forex pairs)
input group "Trade Settings"
input uint tpLeaderPoints=15,slTrailerPoints=30,slFixPoints=0,tpFixPoints=250,
   spreadFilterPoints=10,failedCloseSltpPoints=2;

// Spacer Function Settings
input group "Spacer Function Settings"
input uint firstSpacerPoints=50,minimumSpacerPoints=5;
input double spacerMultiplier=0.9;

// Lot Function Settings
input group "Lot Function Settings"
input double firstLot=0.3,maxLot=5,lotMultiplier=1.10;

// TP Function Settings
input group "TP Function Settings"
input uint firstTpPoints=100,maximumTpPoints=200;
input double tpMultiplier=1.10;

// Max and Min filters
input group "Max and Min filters"
input datetime startTime=1730768400,stopTime=1730847600;
input double MaxEquity=5500,MinEquity=6500;
input int maxTrades=30;

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
SymbolData symbolStructArray[];
int totalSymbols;
datetime lastCheckedDate;

// Time settings
int start,stop;
string lineName = "magLine";
bool timePass=false;
ENUM_ORDER_TYPE_FILLING orderFill;

// Base currency info
string accountCurrency;

//+------------------------------------------------------------------+
//| EA Management Class                                               |
//+------------------------------------------------------------------+
class EthMagnetoEA
{
public:
   bool Initialize()
   {
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)){
         Alert("First Enable autotrading on terminal to take trades");
      }
      
      accountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
      
      if(!InitializeTimeSettings()) return false;
      if(!InitializeSymbols()) return false;
      if(!InitializeTimeframes()) return false;
      if(!InitializeTradeSettings()) return false;
      if(!InitializeLines()) return false;
      
      lastCheckedDate = TimeCurrent();
      
      Print("EthMagneto_DuoPro EA initialized successfully with ", totalSymbols, " symbols");
      return true;
   }
   
   void Deinitialize()
   {
      // Clean up all line objects
      for(int i = 0; i < totalSymbols; i++)
      {
         string symbolName = symbolStructArray[i].symbol;
         for(int j = 0; j < ArraySize(symbolStructArray[i].lines); j++)
         {
            string objName = lineName + "_" + symbolName + "_" + IntegerToString(j);
            ObjectDelete(0, objName);
         }
      }
      ChartRedraw(0);
   }
   
   void OnTick()
   {
      UpdateTrailingStops();
      CheckTimeSession();
      ProcessSignals();
      ExecuteStackingLogic();
      UpdateLineManagement();
      ManageEquityLimits();
   }
   
private:
   bool InitializeTimeSettings()
   {
      MqlDateTime inputTime;
      TimeToStruct(startTime, inputTime);
      start = inputTime.hour*3600 + inputTime.min*60 + inputTime.sec;
      TimeToStruct(stopTime, inputTime);
      stop = inputTime.hour*3600 + inputTime.min*60 + inputTime.sec;
      
      if(start >= stop){
         Alert("stopTime of the day must be further or greater than startTime!");
         return false;
      }
      
      return true;
   }
   
   bool InitializeSymbols()
   {
      if(Symbol_Source == Native_Chart)
      {
         totalSymbols = 1;
         ArrayResize(symbolStructArray, 1);
         symbolStructArray[0].symbol = _Symbol;
      }
      else
      {
         string tempSymbols[];
         int count = StringSplit(Comma_Separated_Symbols, ',', tempSymbols);
         ArrayResize(symbolStructArray, 0);
         
         for(int i = 0; i < count; i++)
         {
            string cleanSymbol = tempSymbols[i];
            StringTrimLeft(cleanSymbol);
            StringTrimRight(cleanSymbol);
            
            if(SymbolSelect(cleanSymbol, true))
            {
               bool isDuplicate = false;
               for(int j = 0; j < totalSymbols; j++)
               {
                  if(symbolStructArray[j].symbol == cleanSymbol)
                  {
                     isDuplicate = true;
                     break;
                  }
               }
               
               if(!isDuplicate)
               {
                  ArrayResize(symbolStructArray, totalSymbols + 1);
                  symbolStructArray[totalSymbols].symbol = cleanSymbol;
                  totalSymbols++;
               }
            }
            else if(AutoCorrect_Symbol_List)
            {
               string correctedSymbol = FindCorrectedSymbol(cleanSymbol);
               if(correctedSymbol != "" && SymbolSelect(correctedSymbol, true))
               {
                  bool isDuplicate = false;
                  for(int j = 0; j < totalSymbols; j++)
                  {
                     if(symbolStructArray[j].symbol == correctedSymbol)
                     {
                        isDuplicate = true;
                        break;
                     }
                  }
                  
                  if(!isDuplicate)
                  {
                     ArrayResize(symbolStructArray, totalSymbols + 1);
                     symbolStructArray[totalSymbols].symbol = correctedSymbol;
                     totalSymbols++;
                  }
               }
            }
         }
         
         if(totalSymbols == 0)
         {
            totalSymbols = 1;
            ArrayResize(symbolStructArray, 1);
            symbolStructArray[0].symbol = _Symbol;
         }
      }
      
      // Initialize symbol-specific data and normalize parameters
      for(int i = 0; i < totalSymbols; i++)
      {
         InitializeSymbolData(i);
         NormalizeSymbolParameters(i);
      }
      
      return true;
   }
   
   void InitializeSymbolData(int index)
   {
      string symbol = symbolStructArray[index].symbol;
      
      // Basic initialization
      symbolStructArray[index].lastBuyPrice = 0;
      symbolStructArray[index].lastSellPrice = 0;
      symbolStructArray[index].lastBuyExit = 0;
      symbolStructArray[index].lastSellExit = 0;
      symbolStructArray[index].buySl = 0;
      symbolStructArray[index].buyTp = 0;
      symbolStructArray[index].sellSl = 0;
      symbolStructArray[index].sellTp = 0;
      symbolStructArray[index].freshBuy = false;
      symbolStructArray[index].freshSell = false;
      symbolStructArray[index].lastBarTime = iTime(symbol, PERIOD_M1, 0);
      
      // Cache symbol information
      symbolStructArray[index].point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      symbolStructArray[index].digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      symbolStructArray[index].tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      symbolStructArray[index].tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      symbolStructArray[index].minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      symbolStructArray[index].maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      symbolStructArray[index].lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      symbolStructArray[index].contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      
      ArrayResize(symbolStructArray[index].lines, 0);
      ArrayResize(symbolStructArray[index].periods, 0);
   }
   
   void NormalizeSymbolParameters(int index)
   {
      string symbol = symbolStructArray[index].symbol;
      double normalizationFactor = GetParameterNormalizationFactor(symbol);
      
      // Normalize all point-based parameters
      symbolStructArray[index].norm_firstSpacerPoints = firstSpacerPoints * normalizationFactor;
      symbolStructArray[index].norm_minimumSpacerPoints = minimumSpacerPoints * normalizationFactor;
      symbolStructArray[index].norm_slTrailerPoints = slTrailerPoints * normalizationFactor;
      symbolStructArray[index].norm_tpLeaderPoints = tpLeaderPoints * normalizationFactor;
      symbolStructArray[index].norm_firstTpPoints = firstTpPoints * normalizationFactor;
      symbolStructArray[index].norm_maximumTpPoints = maximumTpPoints * normalizationFactor;
      symbolStructArray[index].norm_slFixPoints = slFixPoints * normalizationFactor;
      symbolStructArray[index].norm_tpFixPoints = tpFixPoints * normalizationFactor;
      symbolStructArray[index].norm_spreadFilterPoints = spreadFilterPoints * normalizationFactor;
      symbolStructArray[index].norm_failedCloseSltpPoints = failedCloseSltpPoints * normalizationFactor;
      
      Print("Symbol ", symbol, " normalized with factor: ", normalizationFactor);
   }
   
   double GetParameterNormalizationFactor(string symbol)
   {
      // Base parameters are calibrated for 5-digit forex pairs (like EURUSD)
      // Need to adjust for different symbol types
      
      if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
      {
         // Gold: Price around $2000-3000, much higher than forex pairs
         // For equivalent dollar value moves, need to reduce point values
         // EURUSD: 1 pip = 0.0001, XAUUSD: 1 point = 0.01 (100x larger)
         // But gold price is ~20000x higher than EURUSD (2500 vs 1.1)
         // Net effect: need to reduce parameters by factor of ~200
         return 0.005; // Approximately 200x smaller
      }
      else if(StringFind(symbol, "JPY") >= 0)
      {
         // JPY pairs: 3 digits (e.g., 150.123), pip is 0.01
         // Compared to 5-digit pairs where pip is 0.0001
         // JPY pip is 100x larger, so need 100x smaller parameters
         return 0.01;
      }
      else if(StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "SILVER") >= 0)
      {
         // Silver: Similar to gold but lower price (around $25-30)
         // Need moderate reduction
         return 0.1;
      }
      else if(StringFind(symbol, "WTI") >= 0 || StringFind(symbol, "BRENT") >= 0 || StringFind(symbol, "OIL") >= 0)
      {
         // Oil: Price around $70-90
         // Moderate adjustment needed
         return 0.2;
      }
      else if(StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "BITCOIN") >= 0)
      {
         // Bitcoin: Very high price, needs significant reduction
         return 0.001;
      }
      else if(symbolStructArray[GetSymbolIndex(symbol)].digits <= 3)
      {
         // 3-digit or less symbols (like some indices)
         return 0.1;
      }
      else if(symbolStructArray[GetSymbolIndex(symbol)].digits >= 5)
      {
         // 5-digit forex pairs (standard)
         return 1.0;
      }
      else
      {
         // 4-digit symbols
         return 0.1;
      }
   }
   
   string FindCorrectedSymbol(string originalSymbol)
   {
      string upperOriginal = originalSymbol;
      StringToUpper(upperOriginal);
      StringReplace(upperOriginal, " ", "");
      
      for(int i = 0; i < SymbolsTotal(true); i++)
      {
         string marketSymbol = SymbolName(i, true);
         string upperMarket = marketSymbol;
         StringToUpper(upperMarket);
         StringReplace(upperMarket, " ", "");
         
         if(StringFind(upperMarket, upperOriginal) >= 0)
         {
            return marketSymbol;
         }
      }
      
      return "";
   }
   
   bool InitializeTimeframes()
   {
      for(int i = 0; i < totalSymbols; i++)
      {
         if(Period_Source == Native_Chart_Period)
         {
            ArrayResize(symbolStructArray[i].periods, 1);
            symbolStructArray[i].periods[0] = (ENUM_TIMEFRAMES)Period();
         }
         else
         {
            string tempPeriods[];
            int count = StringSplit(Comma_Separated_Timeframes, ',', tempPeriods);
            ArrayResize(symbolStructArray[i].periods, 0);
            
            for(int j = 0; j < count; j++)
            {
               string cleanPeriod = tempPeriods[j];
               StringTrimLeft(cleanPeriod);
               StringTrimRight(cleanPeriod);
               StringToUpper(cleanPeriod);
               
               ENUM_TIMEFRAMES tf = StringToPeriod(cleanPeriod);
               if(tf != PERIOD_CURRENT)
               {
                  int currentSize = ArraySize(symbolStructArray[i].periods);
                  ArrayResize(symbolStructArray[i].periods, currentSize + 1);
                  symbolStructArray[i].periods[currentSize] = tf;
               }
            }
            
            if(ArraySize(symbolStructArray[i].periods) == 0)
            {
               ArrayResize(symbolStructArray[i].periods, 1);
               symbolStructArray[i].periods[0] = (ENUM_TIMEFRAMES)Period();
            }
         }
      }
      
      return true;
   }
   
   ENUM_TIMEFRAMES StringToPeriod(string periodStr)
   {
      if(periodStr == "M1") return PERIOD_M1;
      if(periodStr == "M2") return PERIOD_M2;
      if(periodStr == "M3") return PERIOD_M3;
      if(periodStr == "M4") return PERIOD_M4;
      if(periodStr == "M5") return PERIOD_M5;
      if(periodStr == "M6") return PERIOD_M6;
      if(periodStr == "M10") return PERIOD_M10;
      if(periodStr == "M12") return PERIOD_M12;
      if(periodStr == "M15") return PERIOD_M15;
      if(periodStr == "M20") return PERIOD_M20;
      if(periodStr == "M30") return PERIOD_M30;
      if(periodStr == "H1") return PERIOD_H1;
      if(periodStr == "H2") return PERIOD_H2;
      if(periodStr == "H3") return PERIOD_H3;
      if(periodStr == "H4") return PERIOD_H4;
      if(periodStr == "H6") return PERIOD_H6;
      if(periodStr == "H8") return PERIOD_H8;
      if(periodStr == "H12") return PERIOD_H12;
      if(periodStr == "D1") return PERIOD_D1;
      if(periodStr == "W1") return PERIOD_W1;
      if(periodStr == "MN1") return PERIOD_MN1;
      
      return PERIOD_CURRENT;
   }
   
   bool InitializeTradeSettings()
   {
      uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
      if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK){
         orderFill = ORDER_FILLING_FOK;
      }
      else if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC){
         orderFill = ORDER_FILLING_IOC;
      }
      else{
         orderFill = ORDER_FILLING_RETURN;
      }
      
      return true;
   }
   
   bool InitializeLines()
   {
      datetime timeChecked = TimeCurrent();
      
      for(int i = 0; i < totalSymbols; i++)
      {
         string symbol = symbolStructArray[i].symbol;
         datetime startSearch = timeChecked - (lineRetentionDays * 86400);
         
         // Find all ETH lines within retention period
         for(datetime searchTime = startSearch; searchTime <= timeChecked; searchTime += 86400)
         {
            MqlDateTime dt;
            TimeToStruct(searchTime, dt);
            dt.hour = ETH_Hour;
            dt.min = ETH_Minute;
            dt.sec = 0;
            
            datetime ethTime = StructToTime(dt);
            int gmtOffset = (int)TimeGMT() - (int)TimeCurrent();
            ethTime -= gmtOffset; // Adjust for broker timezone
            
            int shift = iBarShift(symbol, PERIOD_M1, ethTime);
            if(shift >= 0)
            {
               double linePrice = 0;
               if(ETH_PriceType == PRICE_CLOSE)
                  linePrice = iClose(symbol, PERIOD_M1, shift);
               else if(ETH_PriceType == PRICE_OPEN)
                  linePrice = iOpen(symbol, PERIOD_M1, shift);
               
               if(linePrice > 0)
               {
                  int lineCount = ArraySize(symbolStructArray[i].lines);
                  ArrayResize(symbolStructArray[i].lines, lineCount + 1);
                  symbolStructArray[i].lines[lineCount].price = linePrice;
                  symbolStructArray[i].lines[lineCount].expiry = ethTime + (lineRetentionDays * 86400);
                  
                  // Draw line if it's the chart symbol
                  if(symbol == _Symbol)
                  {
                     string objName = lineName + "_" + symbol + "_" + IntegerToString(lineCount);
                     ObjectCreate(0, objName, OBJ_HLINE, 0, TimeCurrent(), linePrice);
                     ObjectSetString(0, objName, OBJPROP_TEXT, "ETH Line " + TimeToString(ethTime));
                     ObjectSetInteger(0, objName, OBJPROP_COLOR, clrYellow);
                     ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                  }
               }
            }
         }
      }
      
      lastCheckedDate = timeChecked;
      ChartRedraw(0);
      return true;
   }
   
   void UpdateTrailingStops()
   {
      if(!stopsTrailer) return;
      
      for(int s = 0; s < totalSymbols; s++)
      {
         string symbol = symbolStructArray[s].symbol;
         double symbolTpLead = NormalizeDouble(symbolStructArray[s].norm_tpLeaderPoints * symbolStructArray[s].point, symbolStructArray[s].digits);
         double symbolSlTrail = NormalizeDouble(symbolStructArray[s].norm_slTrailerPoints * symbolStructArray[s].point, symbolStructArray[s].digits);
         
         double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
         
         // Trail buy positions
         for(int j = PositionsTotal() - 1; j >= 0; j--)
         {
            ulong ticket = PositionGetTicket(j);
            if(PositionGetString(POSITION_SYMBOL) == symbol && 
               PositionGetInteger(POSITION_MAGIC) == magnetoMagic &&
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               double tpi = PositionGetDouble(POSITION_TP);
               if(tpi > 0 && bid > (tpi - symbolTpLead))
               {
                  GroupTrailer(symbol, POSITION_TYPE_BUY, bid - symbolSlTrail, 0);
                  break;
               }
            }
         }
         
         // Trail sell positions
         for(int j = PositionsTotal() - 1; j >= 0; j--)
         {
            ulong ticket = PositionGetTicket(j);
            if(PositionGetString(POSITION_SYMBOL) == symbol && 
               PositionGetInteger(POSITION_MAGIC) == magnetoMagic &&
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
               double tpi = PositionGetDouble(POSITION_TP);
               if(tpi > 0 && ask < (tpi + symbolTpLead))
               {
                  GroupTrailer(symbol, POSITION_TYPE_SELL, ask + symbolSlTrail, 0);
                  break;
               }
            }
         }
      }
   }
   
   void CheckTimeSession()
   {
      if(timePass)
      {
         MqlDateTime currentTime;
         TimeToStruct(TimeCurrent(), currentTime);
         int current = currentTime.hour*3600 + currentTime.min*60 + currentTime.sec;
         if(current < start || current >= stop)
         {
            timePass = false;
         }
      }
      else
      {
         MqlDateTime currentTime;
         TimeToStruct(TimeCurrent(), currentTime);
         int current = currentTime.hour*3600 + currentTime.min*60 + currentTime.sec;
         if(current >= start && current < stop)
         {
            timePass = true;
         }
      }
   }
   
   void ProcessSignals()
   {
      if(!timePass) return;
      
      for(int s = 0; s < totalSymbols; s++)
      {
         string symbol = symbolStructArray[s].symbol;
         
         // Check for new bars for line management only
         datetime currentBarTime = iTime(symbol, PERIOD_M1, 0);
         if(currentBarTime != symbolStructArray[s].lastBarTime)
         {
            symbolStructArray[s].lastBarTime = currentBarTime;
         }
         
         // Process signals every tick
         ProcessLongSignals(s);
         ProcessShortSignals(s);
      }
   }
   
   void ProcessLongSignals(int symbolIndex)
   {
      if(!goLong) return;
      
      string symbol = symbolStructArray[symbolIndex].symbol;
      
      // Check max symbols limit
      if(GetActiveSymbolCount(POSITION_TYPE_BUY) >= maxSymbolsTradedPerTimePerType) return;
      
      // Check if symbol already has buy positions
      if(TypeCount(symbol, POSITION_TYPE_BUY) > 0) return;
      
      // Check max trades per symbol
      if(TypeCount(symbol, POSITION_TYPE_BUY) >= maxTrades) return;
      
      // Check signal conditions across all timeframes
      for(int tf = 0; tf < ArraySize(symbolStructArray[symbolIndex].periods); tf++)
      {
         ENUM_TIMEFRAMES timeframe = symbolStructArray[symbolIndex].periods[tf];
         
         for(int l = 0; l < ArraySize(symbolStructArray[symbolIndex].lines); l++)
         {
            if(CheckLongSignal(symbol, timeframe, symbolStructArray[symbolIndex].lines[l].price))
            {
               ExecuteLongTrade(symbolIndex);
               return;
            }
         }
      }
   }
   
   void ProcessShortSignals(int symbolIndex)
   {
      if(!goShort) return;
      
      string symbol = symbolStructArray[symbolIndex].symbol;
      
      // Check max symbols limit
      if(GetActiveSymbolCount(POSITION_TYPE_SELL) >= maxSymbolsTradedPerTimePerType) return;
      
      // Check if symbol already has sell positions
      if(TypeCount(symbol, POSITION_TYPE_SELL) > 0) return;
      
      // Check max trades per symbol
      if(TypeCount(symbol, POSITION_TYPE_SELL) >= maxTrades) return;
      
      // Check signal conditions across all timeframes
      for(int tf = 0; tf < ArraySize(symbolStructArray[symbolIndex].periods); tf++)
      {
         ENUM_TIMEFRAMES timeframe = symbolStructArray[symbolIndex].periods[tf];
         
         for(int l = 0; l < ArraySize(symbolStructArray[symbolIndex].lines); l++)
         {
            if(CheckShortSignal(symbol, timeframe, symbolStructArray[symbolIndex].lines[l].price))
            {
               ExecuteShortTrade(symbolIndex);
               return;
            }
         }
      }
   }
   
   bool CheckLongSignal(string symbol, ENUM_TIMEFRAMES timeframe, double linePrice)
   {
      // Current candle: opening price > line, closing price <= line
      double currentOpen = iOpen(symbol, timeframe, 0);
      double currentClose = iClose(symbol, timeframe, 0);
      
      if(!(currentOpen > linePrice && currentClose <= linePrice)) return false;
      
      // Previous candle: open > line, low <= line, wick > wickToBodyFactor * body
      double prevOpen = iOpen(symbol, timeframe, 1);
      double prevClose = iClose(symbol, timeframe, 1);
      double prevLow = iLow(symbol, timeframe, 1);
      
      if(!(prevOpen > linePrice && prevLow <= linePrice)) return false;
      
      double wick = prevClose - prevLow;
      double body = MathAbs(prevClose - prevOpen);
      if(body > 0 && !(wick > wickToBodyFactor * body)) return false;
      
      // Range check: minimumRangeNoTouchingLine bars should have low > line
      for(int i = 2; i < 2 + minimumRangeNoTouchingLine; i++)
      {
         double rangeLow = iLow(symbol, timeframe, i);
         if(rangeLow <= linePrice) return false;
      }
      
      return true;
   }
   
   bool CheckShortSignal(string symbol, ENUM_TIMEFRAMES timeframe, double linePrice)
   {
      // Current candle: opening price < line, closing price >= line
      double currentOpen = iOpen(symbol, timeframe, 0);
      double currentClose = iClose(symbol, timeframe, 0);
      
      if(!(currentOpen < linePrice && currentClose >= linePrice)) return false;
      
      // Previous candle: open < line, high >= line, wick > wickToBodyFactor * body
      double prevOpen = iOpen(symbol, timeframe, 1);
      double prevClose = iClose(symbol, timeframe, 1);
      double prevHigh = iHigh(symbol, timeframe, 1);
      
      if(!(prevOpen < linePrice && prevHigh >= linePrice)) return false;
      
      double wick = prevHigh - prevClose;
      double body = MathAbs(prevClose - prevOpen);
      if(body > 0 && !(wick > wickToBodyFactor * body)) return false;
      
      // Range check: minimumRangeNoTouchingLine bars should have high < line
      for(int i = 2; i < 2 + minimumRangeNoTouchingLine; i++)
      {
         double rangeHigh = iHigh(symbol, timeframe, i);
         if(rangeHigh >= linePrice) return false;
      }
      
      return true;
   }
   
   void ExecuteLongTrade(int symbolIndex)
   {
      string symbol = symbolStructArray[symbolIndex].symbol;
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double spread = NormalizeDouble(ask - bid, symbolStructArray[symbolIndex].digits);
      double maxSpread = NormalizeDouble(symbolStructArray[symbolIndex].norm_spreadFilterPoints * symbolStructArray[symbolIndex].point, symbolStructArray[symbolIndex].digits);
      
      if(spread <= maxSpread)
      {
         double slVal = 0, tpVal = 0;
         
         if(symbolStructArray[symbolIndex].norm_slFixPoints > 0)
         {
            slVal = NormalizeDouble(bid - (symbolStructArray[symbolIndex].norm_slFixPoints * symbolStructArray[symbolIndex].point), symbolStructArray[symbolIndex].digits);
         }
         
         if(symbolStructArray[symbolIndex].norm_tpFixPoints > 0)
         {
            tpVal = NormalizeDouble(ask + (symbolStructArray[symbolIndex].norm_tpFixPoints * symbolStructArray[symbolIndex].point), symbolStructArray[symbolIndex].digits);
         }
         
         symbolStructArray[symbolIndex].buySl = slVal;
         symbolStructArray[symbolIndex].buyTp = tpVal;
         
         double lotSize = CalculateOptimalLotSize(symbol, ORDER_TYPE_BUY, slVal, ask);
         
         if(AddPosition(symbol, ORDER_TYPE_BUY, lotSize, tpVal, slVal))
         {
            symbolStructArray[symbolIndex].lastBuyPrice = ask;
            symbolStructArray[symbolIndex].freshBuy = false;
            int buyCount = TypeCount(symbol, POSITION_TYPE_BUY);
            SetGroupSlTp(symbol, buyCount, POSITION_TYPE_BUY);
         }
      }
   }
   
   void ExecuteShortTrade(int symbolIndex)
   {
      string symbol = symbolStructArray[symbolIndex].symbol;
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double spread = NormalizeDouble(ask - bid, symbolStructArray[symbolIndex].digits);
      double maxSpread = NormalizeDouble(symbolStructArray[symbolIndex].norm_spreadFilterPoints * symbolStructArray[symbolIndex].point, symbolStructArray[symbolIndex].digits);
      
      if(spread <= maxSpread)
      {
         double slVal = 0, tpVal = 0;
         
         if(symbolStructArray[symbolIndex].norm_slFixPoints > 0)
         {
            slVal = NormalizeDouble(ask + (symbolStructArray[symbolIndex].norm_slFixPoints * symbolStructArray[symbolIndex].point), symbolStructArray[symbolIndex].digits);
         }
         
         if(symbolStructArray[symbolIndex].norm_tpFixPoints > 0)
         {
            tpVal = NormalizeDouble(bid - (symbolStructArray[symbolIndex].norm_tpFixPoints * symbolStructArray[symbolIndex].point), symbolStructArray[symbolIndex].digits);
         }
         
         symbolStructArray[symbolIndex].sellSl = slVal;
         symbolStructArray[symbolIndex].sellTp = tpVal;
         
         double lotSize = CalculateOptimalLotSize(symbol, ORDER_TYPE_SELL, slVal, bid);
         
         if(AddPosition(symbol, ORDER_TYPE_SELL, lotSize, tpVal, slVal))
         {
            symbolStructArray[symbolIndex].lastSellPrice = bid;
            symbolStructArray[symbolIndex].freshSell = false;
            int sellCount = TypeCount(symbol, POSITION_TYPE_SELL);
            SetGroupSlTp(symbol, sellCount, POSITION_TYPE_SELL);
         }
      }
   }
   
   double CalculateOptimalLotSize(string symbol, ENUM_ORDER_TYPE orderType, double stopLoss, double entryPrice)
   {
      // Risk management: Calculate lot size based on account currency conversion and margin requirements
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskPercentage = 1.0; // 1% risk per trade
      double riskAmount = accountBalance * riskPercentage / 100.0;
      
      int symbolIndex = GetSymbolIndex(symbol);
      if(symbolIndex < 0) return firstLot;
      
      // Calculate stop loss distance in points
      double slDistance = 0;
      if(stopLoss > 0)
      {
         if(orderType == ORDER_TYPE_BUY)
            slDistance = MathAbs(entryPrice - stopLoss);
         else
            slDistance = MathAbs(stopLoss - entryPrice);
      }
      else
      {
         // Default to 50 normalized points if no SL
         slDistance = 50 * symbolStructArray[symbolIndex].norm_firstSpacerPoints * symbolStructArray[symbolIndex].point;
      }
      
      if(slDistance <= 0) return firstLot;
      
      // Calculate pip value for this symbol
      double pipValue = CalculatePipValue(symbol);
      
      // Calculate lot size based on risk
      double lotSize = 0;
      if(pipValue > 0)
      {
         double slInPips = slDistance / symbolStructArray[symbolIndex].point;
         lotSize = riskAmount / (slInPips * pipValue);
      }
      else
      {
         lotSize = firstLot;
      }
      
      // Normalize and constrain lot size
      double minLot = symbolStructArray[symbolIndex].minLot;
      double maxiLot = symbolStructArray[symbolIndex].maxLot;
      double lotStep = symbolStructArray[symbolIndex].lotStep;
      
      lotSize = NormalizeDouble(lotSize, 2);
      lotSize = MathMax(minLot, MathMin(maxiLot, lotSize));
      lotSize = NormalizeDouble(MathFloor(lotSize / lotStep) * lotStep, 2);
      
      return lotSize;
   }
   
   double CalculatePipValue(string symbol)
   {
      int symbolIndex = GetSymbolIndex(symbol);
      if(symbolIndex < 0) return 10.0; // Default for EURUSD
      
      double tickValue = symbolStructArray[symbolIndex].tickValue;
      double tickSize = symbolStructArray[symbolIndex].tickSize;
      double point = symbolStructArray[symbolIndex].point;
      
      // Convert tick value to pip value
      double pipValue = tickValue * (point / tickSize);
      
      // Convert to account currency if needed
      if(accountCurrency != "USD")
      {
         string conversionPair = "";
         
         // Determine conversion pair
         if(StringFind(symbol, accountCurrency) >= 0)
         {
            // Symbol contains account currency
            if(StringFind(symbol, accountCurrency) == 0)
            {
               // Account currency is base currency
               conversionPair = symbol;
            }
            else
            {
               // Account currency is quote currency
               conversionPair = symbol;
            }
         }
         else
         {
            // Need to find conversion pair
            conversionPair = "USD" + accountCurrency;
            if(!SymbolSelect(conversionPair, true))
            {
               conversionPair = accountCurrency + "USD";
               if(!SymbolSelect(conversionPair, true))
               {
                  // Cannot find conversion pair, use default
                  return pipValue;
               }
            }
         }
         
         double conversionRate = SymbolInfoDouble(conversionPair, SYMBOL_ASK);
         if(conversionRate > 0)
         {
            if(StringFind(conversionPair, accountCurrency) == 0)
            {
               // Account currency is base, divide
               pipValue = pipValue / conversionRate;
            }
            else
            {
               // Account currency is quote, multiply
               pipValue = pipValue * conversionRate;
            }
         }
      }
      
      return pipValue;
   }
   
   void ExecuteStackingLogic()
   {
      if(!(stacksAfterStopTime || timePass)) return;
      
      for(int s = 0; s < totalSymbols; s++)
      {
         string symbol = symbolStructArray[s].symbol;
         
         // Check for expired signals
         bool hasActiveSignal = false;
         for(int l = 0; l < ArraySize(symbolStructArray[s].lines); l++)
         {
            if(TimeCurrent() <= symbolStructArray[s].lines[l].expiry)
            {
               hasActiveSignal = true;
               break;
            }
         }
         
         if(!(stacksAfterExpiry || hasActiveSignal)) continue;
         
         // Long stackers
         int buyCount = TypeCount(symbol, POSITION_TYPE_BUY);
         if(buyCount > 0 && buyCount < maxTrades)
         {
            if(symbolStructArray[s].lastBuyPrice == 0)
            {
               symbolStructArray[s].lastBuyPrice = FindLastPrice(symbol, POSITION_TYPE_BUY);
            }
            
            if(symbolStructArray[s].lastBuyPrice != 0)
            {
               double spacing = symbolStructArray[s].norm_firstSpacerPoints * symbolStructArray[s].point * MathPow(spacerMultiplier, (double)(buyCount - 1));
               double minSpacing = symbolStructArray[s].norm_minimumSpacerPoints * symbolStructArray[s].point;
               spacing = spacing < minSpacing ? minSpacing : spacing;
               
               double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
               double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
               
               if(spacing > 0 && ask < (symbolStructArray[s].lastBuyPrice - spacing))
               {
                  double spread = NormalizeDouble(ask - bid, symbolStructArray[s].digits);
                  double maxSpread = NormalizeDouble(symbolStructArray[s].norm_spreadFilterPoints * symbolStructArray[s].point, symbolStructArray[s].digits);
                  
                  if(spread <= maxSpread)
                  {
                     double lot = firstLot * MathPow(lotMultiplier, (double)buyCount);
                     lot = lot > maxLot ? maxLot : lot;
                     lot = MathMax(symbolStructArray[s].minLot, MathMin(symbolStructArray[s].maxLot, lot));
                     
                     double lotSize = CalculateOptimalLotSize(symbol, ORDER_TYPE_BUY, symbolStructArray[s].buySl, ask);
                     lotSize = lot; // Use progression lot for stacking
                     
                     if(AddPosition(symbol, ORDER_TYPE_BUY, lotSize, symbolStructArray[s].buyTp, symbolStructArray[s].buySl))
                     {
                        symbolStructArray[s].lastBuyPrice = ask;
                        buyCount = TypeCount(symbol, POSITION_TYPE_BUY);
                        SetGroupSlTp(symbol, buyCount, POSITION_TYPE_BUY);
                     }
                  }
               }
            }
         }
         
         // Short stackers
         int sellCount = TypeCount(symbol, POSITION_TYPE_SELL);
         if(sellCount > 0 && sellCount < maxTrades)
         {
            if(symbolStructArray[s].lastSellPrice == 0)
            {
               symbolStructArray[s].lastSellPrice = FindLastPrice(symbol, POSITION_TYPE_SELL);
            }
            
            if(symbolStructArray[s].lastSellPrice != 0)
            {
               double spacing = symbolStructArray[s].norm_firstSpacerPoints * symbolStructArray[s].point * MathPow(spacerMultiplier, (double)(sellCount - 1));
               double minSpacing = symbolStructArray[s].norm_minimumSpacerPoints * symbolStructArray[s].point;
               spacing = spacing < minSpacing ? minSpacing : spacing;
               
               double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
               double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
               
               if(spacing > 0 && bid > (symbolStructArray[s].lastSellPrice + spacing))
               {
                  double spread = NormalizeDouble(ask - bid, symbolStructArray[s].digits);
                  double maxSpread = NormalizeDouble(symbolStructArray[s].norm_spreadFilterPoints * symbolStructArray[s].point, symbolStructArray[s].digits);
                  
                  if(spread <= maxSpread)
                  {
                     double lot = firstLot * MathPow(lotMultiplier, (double)sellCount);
                     lot = lot > maxLot ? maxLot : lot;
                     lot = MathMax(symbolStructArray[s].minLot, MathMin(symbolStructArray[s].maxLot, lot));
                     
                     double lotSize = CalculateOptimalLotSize(symbol, ORDER_TYPE_SELL, symbolStructArray[s].sellSl, bid);
                     lotSize = lot; // Use progression lot for stacking
                     
                     if(AddPosition(symbol, ORDER_TYPE_SELL, lotSize, symbolStructArray[s].sellTp, symbolStructArray[s].sellSl))
                     {
                        symbolStructArray[s].lastSellPrice = bid;
                        sellCount = TypeCount(symbol, POSITION_TYPE_SELL);
                        SetGroupSlTp(symbol, sellCount, POSITION_TYPE_SELL);
                     }
                  }
               }
            }
         }
         
         // Update last exit variables
         if(TypeCount(symbol, POSITION_TYPE_BUY) > 0)
         {
            symbolStructArray[s].lastBuyExit = SymbolInfoDouble(symbol, SYMBOL_BID);
         }
         if(TypeCount(symbol, POSITION_TYPE_SELL) > 0)
         {
            symbolStructArray[s].lastSellExit = SymbolInfoDouble(symbol, SYMBOL_ASK);
         }
      }
   }
   
   void UpdateLineManagement()
   {
      MqlDateTime currentDt;
      TimeToStruct(TimeCurrent(), currentDt);
      
      MqlDateTime lastCheckedDt;
      TimeToStruct(lastCheckedDate, lastCheckedDt);
      
      // Check if day changed and time reached
      if(currentDt.day != lastCheckedDt.day && 
         currentDt.hour >= ETH_Hour && currentDt.min >= ETH_Minute)
      {
         for(int s = 0; s < totalSymbols; s++)
         {
            string symbol = symbolStructArray[s].symbol;
            
            // Remove expired lines
            for(int l = ArraySize(symbolStructArray[s].lines) - 1; l >= 0; l--)
            {
               if(TimeCurrent() > symbolStructArray[s].lines[l].expiry)
               {
                  // Delete line object if it's the chart symbol
                  if(symbol == _Symbol)
                  {
                     string objName = lineName + "_" + symbol + "_" + IntegerToString(l);
                     ObjectDelete(0, objName);
                  }
                  
                  // Remove from array
                  ArrayRemove(symbolStructArray[s].lines, l, 1);
               }
            }
            
            // Add new ETH line
            MqlDateTime ethDt = currentDt;
            ethDt.hour = ETH_Hour;
            ethDt.min = ETH_Minute;
            ethDt.sec = 0;
            
            datetime ethTime = StructToTime(ethDt);
            int gmtOffset = (int)TimeGMT() - (int)TimeCurrent();
            ethTime -= gmtOffset; // Adjust for broker timezone
            
            int shift = iBarShift(symbol, PERIOD_M1, ethTime);
            if(shift >= 0)
            {
               double linePrice = 0;
               if(ETH_PriceType == PRICE_CLOSE)
                  linePrice = iClose(symbol, PERIOD_M1, shift);
               else if(ETH_PriceType == PRICE_OPEN)
                  linePrice = iOpen(symbol, PERIOD_M1, shift);
               
               if(linePrice > 0)
               {
                  int lineCount = ArraySize(symbolStructArray[s].lines);
                  ArrayResize(symbolStructArray[s].lines, lineCount + 1);
                  symbolStructArray[s].lines[lineCount].price = linePrice;
                  symbolStructArray[s].lines[lineCount].expiry = ethTime + (lineRetentionDays * 86400);
                  
                  // Draw line if it's the chart symbol
                  if(symbol == _Symbol)
                  {
                     string objName = lineName + "_" + symbol + "_" + IntegerToString(lineCount);
                     ObjectCreate(0, objName, OBJ_HLINE, 0, TimeCurrent(), linePrice);
                     ObjectSetString(0, objName, OBJPROP_TEXT, "ETH Line " + TimeToString(ethTime));
                     ObjectSetInteger(0, objName, OBJPROP_COLOR, clrYellow);
                     ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
                  }
               }
            }
         }
         
         lastCheckedDate = TimeCurrent();
         ChartRedraw(0);
      }
   }
   
   void ManageEquityLimits()
   {
      if(!equityLimits) return;
      
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity < MinEquity || equity > MaxEquity)
      {
         CloseAllTrades();
         Alert("Equity Limits Reached!");
         ExpertRemove();
      }
   }
   
   // Utility functions
   bool AddPosition(string symbol, ENUM_ORDER_TYPE type, double vol, double tpx, double slx)
   {
      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);
      
      request.action = TRADE_ACTION_DEAL;
      request.symbol = symbol;
      request.volume = NormalizeDouble(vol, 2);
      request.type_filling = orderFill;
      
      int symbolIndex = GetSymbolIndex(symbol);
      if(symbolIndex >= 0)
      {
         request.tp = NormalizeDouble(tpx, symbolStructArray[symbolIndex].digits);
         if(slx > 0)
         {
            request.sl = NormalizeDouble(slx, symbolStructArray[symbolIndex].digits);
         }
      }
      else
      {
         request.tp = NormalizeDouble(tpx, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
         if(slx > 0)
         {
            request.sl = NormalizeDouble(slx, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
         }
      }
      
      request.magic = magnetoMagic;
      request.type = type;
      
      if(OrderSend(request, result))
      {
         return true;
      }
      return false;
   }
   
   void GroupTrailer(string symbol, ENUM_POSITION_TYPE type, double Sl, double Tp)
   {
      MqlTradeRequest request;
      MqlTradeResult result;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetString(POSITION_SYMBOL) == symbol && 
            PositionGetInteger(POSITION_MAGIC) == magnetoMagic)
         {
            if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type)
            {
               SetSLTP(ticket, Sl, Tp, request, result);
            }
         }
      }
   }
   
   void SetSLTP(ulong ticket, double tsl, double ttp, MqlTradeRequest &request, MqlTradeResult &result)
   {
      ZeroMemory(request);
      ZeroMemory(result);
      request.action = TRADE_ACTION_SLTP;
      request.position = ticket;
      
      PositionSelectByTicket(ticket);
      string symbol = PositionGetString(POSITION_SYMBOL);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      request.symbol = symbol;
      
      double stops = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(symbol, SYMBOL_POINT);
      double lower = SymbolInfoDouble(symbol, SYMBOL_BID) - stops;
      double upper = SymbolInfoDouble(symbol, SYMBOL_ASK) + stops;
      
      double sls = type == POSITION_TYPE_BUY ? (tsl < lower ? tsl : lower) : ((tsl > upper || tsl == 0) ? tsl : upper);
      double tps = type == POSITION_TYPE_BUY ? ((ttp > upper || ttp == 0) ? ttp : upper) : (ttp < lower ? ttp : lower);
      
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      request.sl = NormalizeDouble(sls, digits);
      request.tp = NormalizeDouble(tps, digits);
      
      if(OrderSendAsync(request, result)){};
   }
   
   int TypeCount(string symbol, ENUM_POSITION_TYPE type)
   {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetString(POSITION_SYMBOL) == symbol && 
            PositionGetInteger(POSITION_MAGIC) == magnetoMagic)
         {
            if(PositionGetInteger(POSITION_TYPE) == type)
            {
               count++;
            }
         }
      }
      return count;
   }
   
   int GetActiveSymbolCount(ENUM_POSITION_TYPE type)
   {
      string activeSymbols[];
      ArrayResize(activeSymbols, 0);
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetInteger(POSITION_MAGIC) == magnetoMagic &&
            PositionGetInteger(POSITION_TYPE) == type)
         {
            string symbol = PositionGetString(POSITION_SYMBOL);
            bool found = false;
            for(int j = 0; j < ArraySize(activeSymbols); j++)
            {
               if(activeSymbols[j] == symbol)
               {
                  found = true;
                  break;
               }
            }
            if(!found)
            {
               int size = ArraySize(activeSymbols);
               ArrayResize(activeSymbols, size + 1);
               activeSymbols[size] = symbol;
            }
         }
      }
      
      return ArraySize(activeSymbols);
   }
   
   double FindLastPrice(string symbol, ENUM_POSITION_TYPE type)
   {
      double lastPrice = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetString(POSITION_SYMBOL) == symbol && 
            PositionGetInteger(POSITION_MAGIC) == magnetoMagic)
         {
            if(PositionGetInteger(POSITION_TYPE) == type)
            {
               double open = PositionGetDouble(POSITION_PRICE_OPEN);
               if(type == POSITION_TYPE_BUY)
               {
                  if(open < lastPrice || lastPrice == 0)
                  {
                     lastPrice = open;
                  }
               }
               else
               {
                  if(open > lastPrice || lastPrice == 0)
                  {
                     lastPrice = open;
                  }
               }
            }
         }
      }
      return lastPrice;
   }
   
   void GroupTp(string symbol, double totalTp, ENUM_POSITION_TYPE type, double &groupSl, double &groupTp)
   {
      double sums = 0;
      int n = 0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetString(POSITION_SYMBOL) == symbol && 
            PositionGetInteger(POSITION_MAGIC) == magnetoMagic)
         {
            if(PositionGetInteger(POSITION_TYPE) == type)
            {
               sums += PositionGetDouble(POSITION_PRICE_OPEN);
               n++;
            }
         }
      }
      
      double slVal = 0, tpVal = 0;
      int symbolIndex = GetSymbolIndex(symbol);
      
      if(type == POSITION_TYPE_BUY)
      {
         slVal = symbolIndex >= 0 ? symbolStructArray[symbolIndex].buySl : 0;
         tpVal = (sums + totalTp) / n;
      }
      else
      {
         slVal = symbolIndex >= 0 ? symbolStructArray[symbolIndex].sellSl : 0;
         tpVal = (sums - totalTp) / n;
      }
      
      groupTp = tpVal;
      groupSl = slVal;
   }
   
   int GetSymbolIndex(string symbol)
   {
      for(int i = 0; i < totalSymbols; i++)
      {
         if(symbolStructArray[i].symbol == symbol)
         {
            return i;
         }
      }
      return -1;
   }
   
   void SetGroupSlTp(string symbol, int typeCount, ENUM_POSITION_TYPE type)
   {
      MqlTradeRequest request;
      MqlTradeResult result;
      
      int symbolIndex = GetSymbolIndex(symbol);
      if(symbolIndex < 0) return;
      
      double symbolTp1 = symbolStructArray[symbolIndex].norm_firstTpPoints * symbolStructArray[symbolIndex].point;
      double symbolTpMax = symbolStructArray[symbolIndex].norm_maximumTpPoints * symbolStructArray[symbolIndex].point;
      
      double tp = symbolTp1 * MathPow(tpMultiplier, (double)(typeCount - 1));
      tp = tp > symbolTpMax ? symbolTpMax : tp;
      
      double gsl, gtp;
      GroupTp(symbol, tp, type, gsl, gtp);
      
      for(int j = PositionsTotal() - 1; j >= 0; j--)
      {
         ulong ticket = PositionGetTicket(j);
         if(PositionGetInteger(POSITION_TYPE) == type)
         {
            if(PositionGetString(POSITION_SYMBOL) == symbol && 
               PositionGetInteger(POSITION_MAGIC) == magnetoMagic)
            {
               SetSLTP(ticket, gsl, gtp, request, result);
            }
         }
      }
   }
   
   void CloseAllTrades()
   {
      MqlTradeRequest request;
      MqlTradeResult result;
      
      for(int a = PositionsTotal() - 1; a >= 0; a--)
      {
         ulong ticket = PositionGetTicket(a);
         if(PositionGetInteger(POSITION_MAGIC) == magnetoMagic)
         {
            double volume = PositionGetDouble(POSITION_VOLUME);
            string symbol = PositionGetString(POSITION_SYMBOL);
            ZeroMemory(request);
            ZeroMemory(result);
            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = symbol;
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            request.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.volume = volume;
            request.type_filling = orderFill;
            
            if(!OrderSend(request, result))
            {
               double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
               int symbolIndex = GetSymbolIndex(symbol);
               double symbolEmergencySltp = 0;
               
               if(symbolIndex >= 0)
               {
                  symbolEmergencySltp = symbolStructArray[symbolIndex].norm_failedCloseSltpPoints * symbolStructArray[symbolIndex].point;
               }
               else
               {
                  symbolEmergencySltp = failedCloseSltpPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
               }
               
               int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
               double lower = NormalizeDouble(currentPrice - symbolEmergencySltp, digits);
               double upper = NormalizeDouble(currentPrice + symbolEmergencySltp, digits);
               double newSL = (type == POSITION_TYPE_BUY) ? lower : upper;
               double newTP = (type == POSITION_TYPE_BUY) ? upper : lower;
               SetSLTP(ticket, newSL, newTP, request, result);
            }
         }
      }
   }
};

// Global EA instance
EthMagnetoEA ea;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!ea.Initialize())
   {
      Print("EthMagneto_DuoPro EA initialization failed!");
      return INIT_FAILED;
   }
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ea.Deinitialize();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   ea.OnTick();
}

//+------------------------------------------------------------------+
//| Expert tester function                                           |
//+------------------------------------------------------------------+
double OnTester()
{
   double profit = TesterStatistics(STAT_PROFIT);
   double maxDrawdown = TesterStatistics(STAT_EQUITY_DD_RELATIVE);
   double trades = TesterStatistics(STAT_TRADES);
   
   if(maxDrawdown == 0 || profit <= 0)
   {
      return 0.0;
   }
   
   double balanceDrawdownRatio = profit / maxDrawdown;
   return balanceDrawdownRatio * profit;
}