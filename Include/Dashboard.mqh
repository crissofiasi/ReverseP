//+------------------------------------------------------------------+
//|                                              Dashboard.mqh        |
//|                                  Copyright 2024, Criss Strategy     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Criss Strategy"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Dashboard Class - On-Chart Display                               |
//+------------------------------------------------------------------+
class CDashboard
{
private:
   // Display settings
   int m_X;
   int m_Y;
   color m_Color;
   int m_FontSize;
   string m_FontName;
   
   // Object names prefix
   string m_Prefix;
   
   // Dashboard data structure
   struct SDashboardData
   {
      // Capital
      double current_capital;
      double initial_capital;
      double total_deposited;
      double total_withdrawn;
      double total_profit;
      double roi;
      
      // Phase
      string current_phase;
      double volume_multiplier;
      double withdrawal_percent;
      
      // Trading
      int active_clusters;
      int max_clusters;
      int total_clusters;
      double win_rate;
      
      // Score
      int combined_score;
      int trend_score;
      int momentum_score;
      int volatility_score;
      int consistency_score;
      
      // Performance
      double max_dd;
      double monthly_profit;
      double monthly_roi;
      
      // Status
      bool ea_active;
      string last_signal;
      datetime last_update;
   };
   SDashboardData m_Data;
   
   // Layout
   int m_LineHeight;
   int m_CurrentY;

public:
   //--- Constructor
   CDashboard()
   {
      m_X = 20;
      m_Y = 50;
      m_Color = clrWhite;
      m_FontSize = 9;
      m_FontName = "Consolas";
      m_Prefix = "Dashboard_";
      m_LineHeight = 16;
      
      // Initialize data
      m_Data.current_capital = 0.0;
      m_Data.initial_capital = 0.0;
      m_Data.total_deposited = 0.0;
      m_Data.total_withdrawn = 0.0;
      m_Data.total_profit = 0.0;
      m_Data.roi = 0.0;
      m_Data.current_phase = "ACCUMULATION";
      m_Data.volume_multiplier = 1.0;
      m_Data.withdrawal_percent = 0.0;
      m_Data.active_clusters = 0;
      m_Data.max_clusters = 5;
      m_Data.total_clusters = 0;
      m_Data.win_rate = 0.0;
      m_Data.combined_score = 0;
      m_Data.trend_score = 0;
      m_Data.momentum_score = 0;
      m_Data.volatility_score = 0;
      m_Data.consistency_score = 0;
      m_Data.max_dd = 0.0;
      m_Data.monthly_profit = 0.0;
      m_Data.monthly_roi = 0.0;
      m_Data.ea_active = true;
      m_Data.last_signal = "NONE";
      m_Data.last_update = TimeCurrent();
   }
   
   //--- Destructor
   ~CDashboard()
   {
      RemoveAll();
   }
   
   //--- Initialize
   void Initialize(int x, int y, color clr)
   {
      m_X = x;
      m_Y = y;
      m_Color = clr;
      
      Print("Dashboard initialized at position: ", m_X, ", ", m_Y);
   }
   
   //--- Update capital data
   void UpdateCapital(double current, double initial, double deposited, double withdrawn, double profit, double roi)
   {
      m_Data.current_capital = current;
      m_Data.initial_capital = initial;
      m_Data.total_deposited = deposited;
      m_Data.total_withdrawn = withdrawn;
      m_Data.total_profit = profit;
      m_Data.roi = roi;
   }
   
   //--- Update phase data
   void UpdatePhase(string phase, double volume_mult, double withdrawal_pct)
   {
      m_Data.current_phase = phase;
      m_Data.volume_multiplier = volume_mult;
      m_Data.withdrawal_percent = withdrawal_pct;
   }
   
   //--- Update trading data
   void UpdateTrading(int active, int max, int total, double win_rate)
   {
      m_Data.active_clusters = active;
      m_Data.max_clusters = max;
      m_Data.total_clusters = total;
      m_Data.win_rate = win_rate;
   }
   
   //--- Update score data
   void UpdateScore(int combined, int trend, int momentum, int volatility, int consistency)
   {
      m_Data.combined_score = combined;
      m_Data.trend_score = trend;
      m_Data.momentum_score = momentum;
      m_Data.volatility_score = volatility;
      m_Data.consistency_score = consistency;
   }
   
   //--- Update performance data
   void UpdatePerformance(double max_dd, double monthly_profit, double monthly_roi)
   {
      m_Data.max_dd = max_dd;
      m_Data.monthly_profit = monthly_profit;
      m_Data.monthly_roi = monthly_roi;
   }
   
   //--- Update status
   void UpdateStatus(bool active, string last_signal)
   {
      m_Data.ea_active = active;
      m_Data.last_signal = last_signal;
      m_Data.last_update = TimeCurrent();
   }
   
   //--- Draw dashboard
   void Draw()
   {
      m_CurrentY = m_Y;
      
      // Header
      DrawHeader();
      
      // Capital section
      DrawSection("CAPITAL");
      DrawLine("Balance", DoubleToString(m_Data.current_capital, 2) + " EUR", GetColorByValue(m_Data.current_capital, m_Data.initial_capital));
      DrawLine("Profit", DoubleToString(m_Data.total_profit, 2) + " EUR", GetColorByProfit(m_Data.total_profit));
      DrawLine("ROI", DoubleToString(m_Data.roi, 2) + "%", GetColorByProfit(m_Data.roi));
      DrawLine("Withdrawn", DoubleToString(m_Data.total_withdrawn, 2) + " EUR", clrGray);
      
      m_CurrentY += 5;
      
      // Phase section
      DrawSection("PHASE");
      DrawLine("Current", m_Data.current_phase, GetPhaseColor(m_Data.current_phase));
      DrawLine("Volume Mult", DoubleToString(m_Data.volume_multiplier, 2) + "x", clrYellow);
      DrawLine("Withdrawal", DoubleToString(m_Data.withdrawal_percent, 0) + "%", clrCyan);
      
      m_CurrentY += 5;
      
      // Trading section
      DrawSection("TRADING");
      DrawLine("Clusters", IntegerToString(m_Data.active_clusters) + "/" + IntegerToString(m_Data.max_clusters), 
               GetColorByClusterLoad(m_Data.active_clusters, m_Data.max_clusters));
      DrawLine("Total", IntegerToString(m_Data.total_clusters), clrGray);
      DrawLine("Win Rate", DoubleToString(m_Data.win_rate, 1) + "%", GetColorByWinRate(m_Data.win_rate));
      DrawLine("Max DD", DoubleToString(m_Data.max_dd, 2) + "%", GetColorByDD(m_Data.max_dd));
      
      m_CurrentY += 5;
      
      // Score section
      DrawSection("COMBINED SCORE");
      DrawLine("Total", IntegerToString(m_Data.combined_score) + "/100", GetColorByScore(m_Data.combined_score));
      DrawLine("Trend", IntegerToString(m_Data.trend_score) + "/30", clrGray);
      DrawLine("Momentum", IntegerToString(m_Data.momentum_score) + "/25", clrGray);
      DrawLine("Volatility", IntegerToString(m_Data.volatility_score) + "/20", clrGray);
      DrawLine("Consistency", IntegerToString(m_Data.consistency_score) + "/25", clrGray);
      
      m_CurrentY += 5;
      
      // Monthly section
      DrawSection("MONTHLY");
      DrawLine("Profit", DoubleToString(m_Data.monthly_profit, 2) + " EUR", GetColorByProfit(m_Data.monthly_profit));
      DrawLine("ROI", DoubleToString(m_Data.monthly_roi, 2) + "%", GetColorByProfit(m_Data.monthly_roi));
      
      m_CurrentY += 5;
      
      // Status section
      DrawSection("STATUS");
      DrawLine("EA", m_Data.ea_active ? "ACTIVE" : "STOPPED", m_Data.ea_active ? clrLime : clrRed);
      DrawLine("Last Signal", m_Data.last_signal, clrGray);
      DrawLine("Updated", TimeToString(m_Data.last_update, TIME_MINUTES), clrGray);
      
      ChartRedraw();
   }
   
   //--- Remove all objects
   void RemoveAll()
   {
      ObjectsDeleteAll(0, m_Prefix);
   }

private:
   //--- Draw header
   void DrawHeader()
   {
      string obj_name = m_Prefix + "Header";
      
      ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, m_X);
      ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, m_CurrentY);
      ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, obj_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetString(0, obj_name, OBJPROP_TEXT, "=== PYRAMIDING INVERSAT EA ===");
      ObjectSetString(0, obj_name, OBJPROP_FONT, m_FontName);
      ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, m_FontSize + 1);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrYellow);
      
      m_CurrentY += m_LineHeight + 5;
   }
   
   //--- Draw section header
   void DrawSection(string title)
   {
      string obj_name = m_Prefix + "Section_" + title;
      
      ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, m_X);
      ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, m_CurrentY);
      ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, obj_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetString(0, obj_name, OBJPROP_TEXT, "[ " + title + " ]");
      ObjectSetString(0, obj_name, OBJPROP_FONT, m_FontName);
      ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, m_FontSize);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrAqua);
      
      m_CurrentY += m_LineHeight;
   }
   
   //--- Draw line (label + value)
   void DrawLine(string label, string value, color clr)
   {
      // Label
      string obj_label = m_Prefix + "Label_" + label;
      ObjectCreate(0, obj_label, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, obj_label, OBJPROP_XDISTANCE, m_X + 10);
      ObjectSetInteger(0, obj_label, OBJPROP_YDISTANCE, m_CurrentY);
      ObjectSetInteger(0, obj_label, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, obj_label, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetString(0, obj_label, OBJPROP_TEXT, label + ":");
      ObjectSetString(0, obj_label, OBJPROP_FONT, m_FontName);
      ObjectSetInteger(0, obj_label, OBJPROP_FONTSIZE, m_FontSize);
      ObjectSetInteger(0, obj_label, OBJPROP_COLOR, m_Color);
      
      // Value
      string obj_value = m_Prefix + "Value_" + label;
      ObjectCreate(0, obj_value, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, obj_value, OBJPROP_XDISTANCE, m_X + 120);
      ObjectSetInteger(0, obj_value, OBJPROP_YDISTANCE, m_CurrentY);
      ObjectSetInteger(0, obj_value, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, obj_value, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetString(0, obj_value, OBJPROP_TEXT, value);
      ObjectSetString(0, obj_value, OBJPROP_FONT, m_FontName);
      ObjectSetInteger(0, obj_value, OBJPROP_FONTSIZE, m_FontSize);
      ObjectSetInteger(0, obj_value, OBJPROP_COLOR, clr);
      
      m_CurrentY += m_LineHeight;
   }
   
   //--- Get color by value comparison
   color GetColorByValue(double current, double reference)
   {
      if(current > reference)
         return clrLime;
      else if(current < reference)
         return clrRed;
      else
         return clrGray;
   }
   
   //--- Get color by profit
   color GetColorByProfit(double profit)
   {
      if(profit > 0)
         return clrLime;
      else if(profit < 0)
         return clrRed;
      else
         return clrGray;
   }
   
   //--- Get phase color
   color GetPhaseColor(string phase)
   {
      if(phase == "ACCUMULATION")
         return clrYellow;
      else if(phase == "CONSOLIDATION")
         return clrOrange;
      else if(phase == "ACCELERATION")
         return clrGold;
      else if(phase == "EXTRACTION")
         return clrLime;
      else
         return clrGray;
   }
   
   //--- Get color by cluster load
   color GetColorByClusterLoad(int active, int max)
   {
      double load = (max > 0) ? ((double)active / max * 100.0) : 0.0;
      
      if(load < 40)
         return clrLime;
      else if(load < 70)
         return clrYellow;
      else if(load < 90)
         return clrOrange;
      else
         return clrRed;
   }
   
   //--- Get color by win rate
   color GetColorByWinRate(double win_rate)
   {
      if(win_rate >= 70)
         return clrLime;
      else if(win_rate >= 60)
         return clrYellow;
      else if(win_rate >= 50)
         return clrOrange;
      else
         return clrRed;
   }
   
   //--- Get color by drawdown
   color GetColorByDD(double dd)
   {
      if(dd < 3)
         return clrLime;
      else if(dd < 5)
         return clrYellow;
      else if(dd < 8)
         return clrOrange;
      else
         return clrRed;
   }
   
   //--- Get color by score
   color GetColorByScore(int score)
   {
      if(score >= 85)
         return clrLime;
      else if(score >= 75)
         return clrGreenYellow;
      else if(score >= 65)
         return clrYellow;
      else if(score >= 50)
         return clrOrange;
      else
         return clrRed;
   }
};
//+------------------------------------------------------------------+
