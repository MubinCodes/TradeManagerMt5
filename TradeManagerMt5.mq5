//+------------------------------------------------------------------+
//| TradeManagerUI.mq5                                               |
//| MetaTrader 5 Chart-Based Trade Manager EA                        |
//| Author: MubinCodes                                               |
//| GitHub: https://github.com/MubinCodes                            |
//|                                                                  |
//| This EA provides a chart-based trading panel for quick manual    |
//| trade execution, fixed lot or risk-based lot sizing, SL/TP input,|
//| and one-click position management.                               |
//|                                                                  |
//| Disclaimer: This project is for educational and portfolio        |
//| demonstration purposes only. Trading involves risk.              |
//+------------------------------------------------------------------+
#property copyright "MubinCodes"
#property link      "https://github.com/MubinCodes"
#property version   "1.00"
#property strict



#include <Trade/Trade.mqh>
CTrade trade;

//-------------------- Lot Mode --------------------
enum ENUM_TM_LOT_MODE
{
   TM_FIXED_LOT    = 0,   // Fixed Lot
   TM_RISK_PERCENT = 1    // Risk Percentage
};

//-------------------- Inputs --------------------
input ENUM_TM_LOT_MODE LotMode              = TM_FIXED_LOT;

input double FixedLotSizeDefault            = 0.10;
input double RiskPercentDefault             = 1.00;

input double StopLossPipsDefault            = 50.0;
input double TakeProfitPipsDefault          = 100.0;

input ulong  MagicNumber                    = 123456;
input int    SlippagePoints                 = 30;

input bool   ManageOnlyCurrentSymbol        = true;
input bool   ManageOnlyMagicNumber          = false;
input bool   UseEquityForRiskCalculation    = true;

 bool   ShowTradeManagerPanel          = true;

// Panel position
input int    PanelX                         = 20;
input int    PanelY                         = 30;

//-------------------- Global --------------------
string Prefix = "TM_UI_";

// Panel size
int PanelW = 390;
int PanelH = 520;

// Object names
string ObjPanel;
string ObjTitle;
string ObjModeText;
string ObjMainLabel;
string ObjEditMain;
string ObjEditSL;
string ObjEditTP;
string ObjBtnBuy;
string ObjBtnSell;
string ObjBtnCloseBuys;
string ObjBtnCloseSells;
string ObjBtnCloseAll;
string ObjStatus;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);

   ObjPanel          = Prefix + "Panel";
   ObjTitle          = Prefix + "Title";
   ObjModeText       = Prefix + "ModeText";
   ObjMainLabel      = Prefix + "MainLabel";
   ObjEditMain       = Prefix + "EditMain";
   ObjEditSL         = Prefix + "EditSL";
   ObjEditTP         = Prefix + "EditTP";
   ObjBtnBuy         = Prefix + "BtnBuy";
   ObjBtnSell        = Prefix + "BtnSell";
   ObjBtnCloseBuys   = Prefix + "BtnCloseBuys";
   ObjBtnCloseSells  = Prefix + "BtnCloseSells";
   ObjBtnCloseAll    = Prefix + "BtnCloseAll";
   ObjStatus         = Prefix + "Status";

   if(ShowTradeManagerPanel)
      CreatePanel();

   EventSetTimer(1);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeletePanelObjects();
}

//+------------------------------------------------------------------+
//| Expert tick                                                       |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateStatus();
}

//+------------------------------------------------------------------+
//| Timer                                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateStatus();
}

//+------------------------------------------------------------------+
//| Chart events                                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   if(sparam == ObjBtnBuy)
   {
      ResetButton(ObjBtnBuy);
      OpenMarketTrade(ORDER_TYPE_BUY);
   }
   else if(sparam == ObjBtnSell)
   {
      ResetButton(ObjBtnSell);
      OpenMarketTrade(ORDER_TYPE_SELL);
   }
   else if(sparam == ObjBtnCloseBuys)
   {
      ResetButton(ObjBtnCloseBuys);
      ClosePositions(true, false);
   }
   else if(sparam == ObjBtnCloseSells)
   {
      ResetButton(ObjBtnCloseSells);
      ClosePositions(false, true);
   }
   else if(sparam == ObjBtnCloseAll)
   {
      ResetButton(ObjBtnCloseAll);
      ClosePositions(true, true);
   }

   UpdateStatus();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create full UI panel                                              |
//+------------------------------------------------------------------+
void CreatePanel()
{
   DeletePanelObjects();

   int x = PanelX;
   int y = PanelY;

   CreateRect(ObjPanel, x, y, PanelW, PanelH, C'15,23,32', C'70,85,100');

   CreateLabel(ObjTitle, x + 20, y + 18, "Trade Manager", 16, clrWhite);

   string modeText = "Mode: ";
   if(LotMode == TM_FIXED_LOT)
      modeText += "Fixed Lot";
   else
      modeText += "Risk %";

   CreateRect(Prefix + "ModeBox", x + 15, y + 55, PanelW - 30, 80, C'21,31,43', C'55,70,85');
   CreateLabel(Prefix + "ModeLabel", x + 30, y + 70, "MODE", 9, C'80,160,255');
   CreateLabel(ObjModeText, x + 30, y + 95, modeText, 11, clrWhite);

   if(LotMode == TM_FIXED_LOT)
      CreateLabel(Prefix + "ModeHint", x + 30, y + 115, "Change EA input to Risk % to use risk-based lot.", 8, C'170,180,190');
   else
      CreateLabel(Prefix + "ModeHint", x + 30, y + 115, "Lot size will be calculated from SL and Risk %.", 8, C'170,180,190');

   CreateRect(Prefix + "OrderBox", x + 15, y + 145, PanelW - 30, 175, C'21,31,43', C'55,70,85');
   CreateLabel(Prefix + "OrderTitle", x + 30, y + 160, "ORDER ENTRY", 9, C'80,160,255');

   string mainLabel;
   string mainValue;

   if(LotMode == TM_FIXED_LOT)
   {
      mainLabel = "Lot Size";
      mainValue = DoubleToString(FixedLotSizeDefault, 2);
   }
   else
   {
      mainLabel = "Risk (%)";
      mainValue = DoubleToString(RiskPercentDefault, 2);
   }

   CreateLabel(ObjMainLabel, x + 30, y + 195, mainLabel, 10, clrWhite);
   CreateEdit(ObjEditMain, x + 205, y + 187, 135, 28, mainValue);

   CreateLabel(Prefix + "SLLabel", x + 30, y + 235, "Stop Loss (pips)", 10, clrWhite);
   CreateEdit(ObjEditSL, x + 205, y + 227, 135, 28, DoubleToString(StopLossPipsDefault, 1));

   CreateLabel(Prefix + "TPLabel", x + 30, y + 275, "Take Profit (pips)", 10, clrWhite);
   CreateEdit(ObjEditTP, x + 205, y + 267, 135, 28, DoubleToString(TakeProfitPipsDefault, 1));

   CreateButton(ObjBtnBuy,  x + 15,  y + 335, 175, 50, "BUY",  C'45,150,65',  clrWhite, 13);
   CreateButton(ObjBtnSell, x + 200, y + 335, 175, 50, "SELL", C'180,55,55',  clrWhite, 13);

   CreateRect(Prefix + "ManageBox", x + 15, y + 400, PanelW - 30, 95, C'21,31,43', C'55,70,85');
   CreateLabel(Prefix + "ManageTitle", x + 30, y + 413, "POSITION MANAGEMENT", 9, C'80,160,255');

   CreateButton(ObjBtnCloseBuys,  x + 25,  y + 438, 160, 30, "Close All Buys",  C'35,90,160',   clrWhite, 9);
   CreateButton(ObjBtnCloseSells, x + 205, y + 438, 160, 30, "Close All Sells", C'190,95,25',   clrWhite, 9);
   CreateButton(ObjBtnCloseAll,   x + 25,  y + 472, 340, 28, "Close All",       C'55,65,75',    clrWhite, 9);

   CreateLabel(ObjStatus, x + 20, y + 503, "EA: ON", 8, C'160,255,160');

   UpdateStatus();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create rectangle                                                  |
//+------------------------------------------------------------------+
void CreateRect(string name, int x, int y, int w, int h, color bg, color border)
{
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
}

//+------------------------------------------------------------------+
//| Create label                                                      |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, int fontSize, color textColor)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 2);
}

//+------------------------------------------------------------------+
//| Create edit box                                                   |
//+------------------------------------------------------------------+
void CreateEdit(string name, int x, int y, int w, int h, string text)
{
   ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'10,16,23');
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'75,90,105');
   ObjectSetInteger(0, name, OBJPROP_READONLY, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 3);
}

//+------------------------------------------------------------------+
//| Create button                                                     |
//+------------------------------------------------------------------+
void CreateButton(string name, int x, int y, int w, int h, string text, color bg, color textColor, int fontSize)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 4);
}

//+------------------------------------------------------------------+
//| Reset button state                                                |
//+------------------------------------------------------------------+
void ResetButton(string name)
{
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
}

//+------------------------------------------------------------------+
//| Delete panel objects                                              |
//+------------------------------------------------------------------+
void DeletePanelObjects()
{
   int total = ObjectsTotal(0, -1, -1);

   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, -1);

      if(StringFind(name, Prefix) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Get edit double                                                   |
//+------------------------------------------------------------------+
double GetEditDouble(string name)
{
   string txt = ObjectGetString(0, name, OBJPROP_TEXT);
   return StringToDouble(txt);
}

//+------------------------------------------------------------------+
//| Pip size                                                          |
//+------------------------------------------------------------------+
double PipSize()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(digits == 3 || digits == 5)
      return point * 10.0;

   return point;
}

//+------------------------------------------------------------------+
//| Convert pips to price                                             |
//+------------------------------------------------------------------+
double PipsToPrice(double pips)
{
   return pips * PipSize();
}

//+------------------------------------------------------------------+
//| Normalize volume                                                  |
//+------------------------------------------------------------------+
double NormalizeVolume(double volume)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(volume < minLot)
      volume = minLot;

   if(volume > maxLot)
      volume = maxLot;

   volume = MathFloor(volume / stepLot) * stepLot;

   int digits = 0;
   double step = stepLot;

   while(step < 1.0 && digits < 8)
   {
      step *= 10.0;
      digits++;
   }

   return NormalizeDouble(volume, digits);
}

//+------------------------------------------------------------------+
//| Calculate lot size                                                |
//+------------------------------------------------------------------+
double CalculateLotSize(ENUM_ORDER_TYPE orderType, double slPips)
{
   double mainValue = GetEditDouble(ObjEditMain);

   if(LotMode == TM_FIXED_LOT)
   {
      if(mainValue <= 0.0)
      {
         Alert("Invalid lot size.");
         return 0.0;
      }

      return NormalizeVolume(mainValue);
   }

   // Risk percentage mode
   double riskPercent = mainValue;

   if(riskPercent <= 0.0)
   {
      Alert("Invalid Risk (%).");
      return 0.0;
   }

   if(slPips <= 0.0)
   {
      Alert("Risk % mode requires Stop Loss pips greater than 0.");
      return 0.0;
   }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      Alert("Could not read symbol tick.");
      return 0.0;
   }

   double entryPrice = 0.0;
   double slPrice    = 0.0;

   if(orderType == ORDER_TYPE_BUY)
   {
      entryPrice = tick.ask;
      slPrice    = entryPrice - PipsToPrice(slPips);
   }
   else
   {
      entryPrice = tick.bid;
      slPrice    = entryPrice + PipsToPrice(slPips);
   }

   double baseAmount = AccountInfoDouble(ACCOUNT_BALANCE);

   if(UseEquityForRiskCalculation)
      baseAmount = AccountInfoDouble(ACCOUNT_EQUITY);

   double riskMoney = baseAmount * riskPercent / 100.0;

   double profitForOneLot = 0.0;

   if(!OrderCalcProfit(orderType, _Symbol, 1.0, entryPrice, slPrice, profitForOneLot))
   {
      Alert("Could not calculate risk lot size.");
      return 0.0;
   }

   double lossForOneLot = MathAbs(profitForOneLot);

   if(lossForOneLot <= 0.0)
   {
      Alert("Invalid loss calculation for 1 lot.");
      return 0.0;
   }

   double calculatedLot = riskMoney / lossForOneLot;

   return NormalizeVolume(calculatedLot);
}

//+------------------------------------------------------------------+
//| Validate SL/TP distance                                           |
//+------------------------------------------------------------------+
bool ValidateStops(double entryPrice, double sl, double tp)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

   double minDistance = stopsLevel * point;

   if(minDistance <= 0.0)
      return true;

   if(sl > 0.0 && MathAbs(entryPrice - sl) < minDistance)
   {
      Alert("Stop Loss is too close to current price. Broker minimum stop distance is not met.");
      return false;
   }

   if(tp > 0.0 && MathAbs(entryPrice - tp) < minDistance)
   {
      Alert("Take Profit is too close to current price. Broker minimum stop distance is not met.");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Open market trade                                                 |
//+------------------------------------------------------------------+
void OpenMarketTrade(ENUM_ORDER_TYPE orderType)
{
   double slPips = GetEditDouble(ObjEditSL);
   double tpPips = GetEditDouble(ObjEditTP);

   if(slPips < 0.0)
   {
      Alert("Stop Loss pips cannot be negative.");
      return;
   }

   if(tpPips < 0.0)
   {
      Alert("Take Profit pips cannot be negative.");
      return;
   }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      Alert("Could not read current market price.");
      return;
   }

   bool isBuy = (orderType == ORDER_TYPE_BUY);

   double entryPrice = isBuy ? tick.ask : tick.bid;
   double sl = 0.0;
   double tp = 0.0;

   if(slPips > 0.0)
   {
      if(isBuy)
         sl = entryPrice - PipsToPrice(slPips);
      else
         sl = entryPrice + PipsToPrice(slPips);
   }

   if(tpPips > 0.0)
   {
      if(isBuy)
         tp = entryPrice + PipsToPrice(tpPips);
      else
         tp = entryPrice - PipsToPrice(tpPips);
   }

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(sl > 0.0)
      sl = NormalizeDouble(sl, digits);

   if(tp > 0.0)
      tp = NormalizeDouble(tp, digits);

   if(!ValidateStops(entryPrice, sl, tp))
      return;

   double lot = CalculateLotSize(orderType, slPips);

   if(lot <= 0.0)
      return;

   bool result = false;

   if(isBuy)
      result = trade.Buy(lot, _Symbol, 0.0, sl, tp, "Trade Manager Buy");
   else
      result = trade.Sell(lot, _Symbol, 0.0, sl, tp, "Trade Manager Sell");

   if(!result)
   {
      string msg = "Trade failed. Retcode: " +
                   IntegerToString((int)trade.ResultRetcode()) +
                   " - " +
                   trade.ResultRetcodeDescription();

      Alert(msg);
      Print(msg);
   }
   else
   {
      Print("Trade opened successfully. Lot: ", DoubleToString(lot, 2));
   }
}

//+------------------------------------------------------------------+
//| Check if selected position is allowed                             |
//+------------------------------------------------------------------+
bool IsSelectedPositionAllowed()
{
   string symbol = PositionGetString(POSITION_SYMBOL);

   if(ManageOnlyCurrentSymbol && symbol != _Symbol)
      return false;

   ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);

   if(ManageOnlyMagicNumber && magic != MagicNumber)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Close positions                                                   |
//+------------------------------------------------------------------+
void ClosePositions(bool closeBuys, bool closeSells)
{
   int total = PositionsTotal();

   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(!IsSelectedPositionAllowed())
         continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      bool shouldClose = false;

      if(type == POSITION_TYPE_BUY && closeBuys)
         shouldClose = true;

      if(type == POSITION_TYPE_SELL && closeSells)
         shouldClose = true;

      if(!shouldClose)
         continue;

      bool result = trade.PositionClose(ticket, SlippagePoints);

      if(!result)
      {
         Print("Failed to close position ticket: ", ticket,
               " Retcode: ", trade.ResultRetcode(),
               " - ", trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| Update status text                                                |
//+------------------------------------------------------------------+
void UpdateStatus()
{
   if(!ShowTradeManagerPanel)
      return;

   if(ObjectFind(0, ObjStatus) < 0)
      return;

   int buyCount = 0;
   int sellCount = 0;
   double totalProfit = 0.0;

   int total = PositionsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(!IsSelectedPositionAllowed())
         continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(type == POSITION_TYPE_BUY)
         buyCount++;

      if(type == POSITION_TYPE_SELL)
         sellCount++;

      double profit = PositionGetDouble(POSITION_PROFIT);
      double swap   = PositionGetDouble(POSITION_SWAP);

      totalProfit += profit + swap;
   }

   MqlTick tick;
   double spreadPips = 0.0;

   if(SymbolInfoTick(_Symbol, tick))
      spreadPips = (tick.ask - tick.bid) / PipSize();

   string status =
      "Magic: " + IntegerToString((int)MagicNumber) +
      " | Spread: " + DoubleToString(spreadPips, 1) + " pips" +
      " | Buy: " + IntegerToString(buyCount) +
      " | Sell: " + IntegerToString(sellCount) +
      " | P/L: " + DoubleToString(totalProfit, 2) +
      " | EA: ON";

   ObjectSetString(0, ObjStatus, OBJPROP_TEXT, status);

   if(totalProfit >= 0.0)
      ObjectSetInteger(0, ObjStatus, OBJPROP_COLOR, C'160,255,160');
   else
      ObjectSetInteger(0, ObjStatus, OBJPROP_COLOR, C'255,150,150');
}