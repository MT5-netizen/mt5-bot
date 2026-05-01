#include <Trade/Trade.mqh>
CTrade trade;

input double BaseRisk = 1.0;
input int ATR_Period = 14;
input int EMA_Fast = 20;
input int EMA_Slow = 50;
input int RSI_Period = 14;
input int MaxLossStreak = 3;
input double MaxSpread = 25;

double dynamicRisk = 1.0;
int loss_streak = 0;

// حساب اللوت
double LotSize(double sl_points)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk = balance * dynamicRisk / 100.0;
   double lot = risk / (sl_points * _Point * 10);

   if(lot < 0.01) lot = 0.01;
   return NormalizeDouble(lot,2);
}

// السبريد
double Spread()
{
   return (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID))/_Point;
}

// AI بسيط (تحليل أداء)
void UpdateAI()
{
   if(HistoryDealsTotal() < 2) return;

   double last = HistoryDealGetDouble(HistoryDealsTotal()-1, DEAL_PROFIT);

   if(last < 0)
   {
      loss_streak++;
      dynamicRisk = BaseRisk * 0.5;
   }
   else
   {
      loss_streak = 0;
      dynamicRisk = BaseRisk * 1.2;
   }
}

// فلتر وقت
bool TradingTime()
{
   int hour = TimeHour(TimeCurrent());
   return (hour >= 9 && hour <= 20);
}

// فلتر مناطق
bool NearLevel()
{
   double high = iHigh(Symbol(), PERIOD_M15, 1);
   double low  = iLow(Symbol(), PERIOD_M15, 1);
   double price = SymbolInfoDouble(Symbol(), SYMBOL_BID);

   if(MathAbs(price - high) < 100 * _Point) return true;
   if(MathAbs(price - low)  < 100 * _Point) return true;

   return false;
}

// إدارة الصفقة
void ManageTrade()
{
   if(!PositionSelect(Symbol())) return;

   double price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);

   // Break Even
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      if(price - open > 150 * _Point)
         trade.PositionModify(Symbol(), open, tp);
   }

   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
   {
      if(open - price > 150 * _Point)
         trade.PositionModify(Symbol(), open, tp);
   }
}

void OnTick()
{
   UpdateAI();
   ManageTrade();

   if(loss_streak >= MaxLossStreak) return;
   if(!TradingTime()) return;
   if(Spread() > MaxSpread) return;

   double price = SymbolInfoDouble(Symbol(), SYMBOL_BID);

   // فريم صغير
   double emaFast = iMA(Symbol(), PERIOD_M5, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaSlow = iMA(Symbol(), PERIOD_M5, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE, 0);

   // فريم أعلى
   double emaHTF = iMA(Symbol(), PERIOD_M15, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE, 0);

   double rsi = iRSI(Symbol(), PERIOD_M5, RSI_Period, PRICE_CLOSE, 0);
   double atr = iATR(Symbol(), PERIOD_M5, ATR_Period, 0);

   // فلترة السوق
   if(atr < 50 * _Point) return;
   if(!NearLevel()) return;

   double sl_points = atr * 2;
   double tp_points = atr * 5;

   double lot = LotSize(sl_points);

   if(PositionSelect(Symbol()))
      return;

   double sl, tp;

   // BUY
   if(emaFast > emaSlow && price > emaHTF && rsi < 40)
   {
      sl = price - sl_points;
      tp = price + tp_points;
      trade.Buy(lot, Symbol(), price, sl, tp);
   }

   // SELL
   if(emaFast < emaSlow && price < emaHTF && rsi > 60)
   {
      sl = price + sl_points;
      tp = price - tp_points;
      trade.Sell(lot, Symbol(), price, sl, tp);
   }
}
