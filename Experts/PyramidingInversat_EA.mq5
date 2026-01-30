//+------------------------------------------------------------------+
//|                                    PyramidingInversat_EA.mq5      |
//|                                  Copyright 2024, Criss Strategy     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Criss Strategy"
#property link      "https://vio-strategy.com"
#property version   "1.00"
#property description "Pyramiding Inversat EA with Combined Score Filter"
#property description "Capital Growth Management Strategy"
#property strict

#include <Trade\Trade.mqh>
#include <CapitalGrowth.mqh>
#include <PyramidingManager.mqh>
#include <CombinedScoreFilter.mqh>
#include <Dashboard.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+

//--- Capital Growth Settings
input group "=== CAPITAL GROWTH SETTINGS ==="
input double InpInitialCapital = 2000.0;           // Initial Capital (EUR)
input double InpTargetCapital = 10000.0;           // Target Capital - Stop Deposits (EUR)
input double InpFinalTarget = 500000.0;            // Final Target (EUR)
input bool   InpAutoWithdrawal = true;             // Enable Auto Withdrawal Alerts
input double InpWithdrawalPhase1 = 0.0;            // Withdrawal Phase 1 (0-10k): %
input double InpWithdrawalPhase2 = 30.0;           // Withdrawal Phase 2 (10k-50k): %
input double InpWithdrawalPhase3 = 50.0;           // Withdrawal Phase 3 (50k-500k): %
input double InpWithdrawalPhase4 = 85.0;           // Withdrawal Phase 4 (>500k): %

//--- Trading Settings
input group "=== TRADING SETTINGS ==="
input double InpBaseLotSize = 0.02;                // Base Lot Size (Entry 1)
input double InpMaxVolumeMultiplier = 5.0;         // Max Volume Multiplier
input int    InpMagicNumber = 123456;              // Magic Number
input string InpTradeComment = "PyramInv";         // Trade Comment

//--- Pyramiding Inversat Settings
input group "=== PYRAMIDING INVERSAT ==="
input bool   InpEnablePyramiding = true;           // Enable Pyramiding
input double InpEntry2Distance = 15.0;             // Entry 2 Distance (pips)
input double InpEntry3Distance = 30.0;             // Entry 3 Distance (pips)
input double InpEntry4Distance = 40.0;             // Entry 4 Distance (pips)
input double InpEntry5Distance = 50.0;             // Entry 5 Distance (pips)
input double InpEntry2Multiplier = 1.5;            // Entry 2 Multiplier
input double InpEntry3Multiplier = 2.0;            // Entry 3 Multiplier
input double InpEntry4Multiplier = 1.5;            // Entry 4 Multiplier
input double InpEntry5Multiplier = 1.0;            // Entry 5 Multiplier

//--- Combined Score Filter
input group "=== COMBINED SCORE FILTER ==="
input bool   InpEnableFilter = true;               // Enable Combined Score Filter
input int    InpMinCombinedScore = 65;             // Minimum Combined Score (0-100)
input ENUM_TIMEFRAMES InpEntryTimeframe = PERIOD_H1; // Entry Timeframe
input int    InpSMA_Fast = 4;                      // Entry TF: SMA Fast Period
input int    InpSMA_Slow = 24;                     // Entry TF: SMA Slow Period
input int    InpRSI_Period = 14;                   // Entry TF: RSI Period
input int    InpATR_Period = 14;                   // Entry TF: ATR Period

//--- Multi-TimeFrame Analysis
input group "=== MULTI-TIMEFRAME ANALYSIS ==="
input bool   InpEnableMTF = true;                  // Enable MTF Analysis
input bool   InpMTF_UseH4 = true;                  // Use H4 Timeframe
input int    InpMTF_H4_SMA_Fast = 4;               // H4: SMA Fast Period
input int    InpMTF_H4_SMA_Slow = 24;              // H4: SMA Slow Period
input bool   InpMTF_UseD1 = true;                  // Use D1 Timeframe
input int    InpMTF_D1_SMA_Fast = 4;               // D1: SMA Fast Period
input int    InpMTF_D1_SMA_Slow = 24;              // D1: SMA Slow Period
input bool   InpMTF_UseW1 = false;                 // Use W1 Timeframe
input int    InpMTF_W1_SMA_Fast = 4;               // W1: SMA Fast Period
input int    InpMTF_W1_SMA_Slow = 24;              // W1: SMA Slow Period
input int    InpMTF_MinConfirmations = 2;          // Min MTF Confirmations (1-3)

//--- Risk Management
input group "=== RISK MANAGEMENT ==="
input double InpMaxRiskPercent = 3.5;              // Max Risk per Cluster (%)
input double InpSL_Pips = 25.0;                    // Stop Loss (pips)
input double InpTP_Pips = 60.0;                    // Take Profit (pips)
input double InpMaxDailyDD = 5.0;                  // Max Daily Drawdown (%)
input int    InpMaxSimultaneousClusters = 5;       // Max Simultaneous Clusters
input bool   InpEnableTrailingStop = true;         // Enable Trailing Stop
input double InpTrailingStopPips = 20.0;           // Trailing Stop Distance (pips)
input double InpTrailingStepPips = 5.0;            // Trailing Stop Step (pips)

//--- Trading Schedule
input group "=== TRADING SCHEDULE ==="
input int    InpStartHour = 0;                     // Start Hour (0-23)
input int    InpEndHour = 23;                      // End Hour (0-23)
input bool   InpTradeMonday = true;                // Trade on Monday
input bool   InpTradeTuesday = true;               // Trade on Tuesday
input bool   InpTradeWednesday = true;             // Trade on Wednesday
input bool   InpTradeThursday = true;              // Trade on Thursday
input bool   InpTradeFriday = true;                // Trade on Friday

//--- Dashboard Settings
input group "=== DASHBOARD SETTINGS ==="
input bool   InpShowDashboard = true;              // Show Dashboard
input int    InpDashboardX = 20;                   // Dashboard X Position
input int    InpDashboardY = 50;                   // Dashboard Y Position
input color  InpDashboardColor = clrWhite;         // Dashboard Color

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CCapitalGrowth*       g_CapitalGrowth = NULL;
CPyramidingManager*   g_PyramidingMgr = NULL;
CCombinedScoreFilter* g_ScoreFilter = NULL;
CDashboard*           g_Dashboard = NULL;

// Multi-Timeframe Filters
CCombinedScoreFilter* g_MTF_H4 = NULL;
CCombinedScoreFilter* g_MTF_D1 = NULL;
CCombinedScoreFilter* g_MTF_W1 = NULL;

CTrade g_Trade;

string g_Symbol;
ENUM_TIMEFRAMES g_Timeframe; // Entry timeframe (from input)

datetime g_LastBarTime = 0;
datetime g_DailyResetTime = 0;
double g_DailyStartBalance = 0.0;
bool g_TradingAllowed = true;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("  Pyramiding Inversat EA - Initialization");
   Print("========================================");
   
   g_Symbol = _Symbol;
   g_Timeframe = InpEntryTimeframe;
   
   // Initialize Capital Growth Manager
   g_CapitalGrowth = new CCapitalGrowth(InpInitialCapital, InpTargetCapital, InpFinalTarget);
   if(g_CapitalGrowth == NULL)
   {
      Print("ERROR: Failed to create Capital Growth Manager!");
      return INIT_FAILED;
   }
   
   // Update with current balance
   g_CapitalGrowth.UpdateCapital(AccountInfoDouble(ACCOUNT_BALANCE));
   
   // Initialize Pyramiding Manager
   g_PyramidingMgr = new CPyramidingManager();
   if(g_PyramidingMgr == NULL)
   {
      Print("ERROR: Failed to create Pyramiding Manager!");
      return INIT_FAILED;
   }
   
   if(!g_PyramidingMgr.Initialize(g_Symbol, InpMagicNumber, InpTradeComment))
   {
      Print("ERROR: Failed to initialize Pyramiding Manager!");
      return INIT_FAILED;
   }
   
   g_PyramidingMgr.SetDistances(InpEntry2Distance, InpEntry3Distance, InpEntry4Distance, InpEntry5Distance);
   g_PyramidingMgr.SetMultipliers(InpEntry2Multiplier, InpEntry3Multiplier, InpEntry4Multiplier, InpEntry5Multiplier);
   g_PyramidingMgr.SetSLTP(InpSL_Pips, InpTP_Pips);
   g_PyramidingMgr.SetTrailingStop(InpEnableTrailingStop, InpTrailingStopPips, InpTrailingStepPips);
   
   // Initialize Combined Score Filter
   g_ScoreFilter = new CCombinedScoreFilter();
   if(g_ScoreFilter == NULL)
   {
      Print("ERROR: Failed to create Combined Score Filter!");
      return INIT_FAILED;
   }
   
   if(!g_ScoreFilter.Initialize(g_Symbol, g_Timeframe))
   {
      Print("ERROR: Failed to initialize Combined Score Filter!");
      return INIT_FAILED;
   }
   
   g_ScoreFilter.SetPeriods(InpSMA_Fast, InpSMA_Slow, InpRSI_Period, InpATR_Period);
   
   // Initialize Multi-Timeframe Filters (if enabled)
   if(InpEnableMTF)
   {
      Print("--- Initializing Multi-Timeframe Analysis ---");
      
      // H4 Filter
      if(InpMTF_UseH4)
      {
         g_MTF_H4 = new CCombinedScoreFilter();
         if(g_MTF_H4 == NULL)
         {
            Print("ERROR: Failed to create H4 MTF Filter!");
            return INIT_FAILED;
         }
         
         if(!g_MTF_H4.Initialize(g_Symbol, PERIOD_H4))
         {
            Print("ERROR: Failed to initialize H4 MTF Filter!");
            return INIT_FAILED;
         }
         
         g_MTF_H4.SetPeriods(InpMTF_H4_SMA_Fast, InpMTF_H4_SMA_Slow, InpRSI_Period, InpATR_Period);
         Print("H4 MTF Filter initialized (SMA Fast: ", InpMTF_H4_SMA_Fast, ", Slow: ", InpMTF_H4_SMA_Slow, ")");
      }
      
      // D1 Filter
      if(InpMTF_UseD1)
      {
         g_MTF_D1 = new CCombinedScoreFilter();
         if(g_MTF_D1 == NULL)
         {
            Print("ERROR: Failed to create D1 MTF Filter!");
            return INIT_FAILED;
         }
         
         if(!g_MTF_D1.Initialize(g_Symbol, PERIOD_D1))
         {
            Print("ERROR: Failed to initialize D1 MTF Filter!");
            return INIT_FAILED;
         }
         
         g_MTF_D1.SetPeriods(InpMTF_D1_SMA_Fast, InpMTF_D1_SMA_Slow, InpRSI_Period, InpATR_Period);
         Print("D1 MTF Filter initialized (SMA Fast: ", InpMTF_D1_SMA_Fast, ", Slow: ", InpMTF_D1_SMA_Slow, ")");
      }
      
      // W1 Filter
      if(InpMTF_UseW1)
      {
         g_MTF_W1 = new CCombinedScoreFilter();
         if(g_MTF_W1 == NULL)
         {
            Print("ERROR: Failed to create W1 MTF Filter!");
            return INIT_FAILED;
         }
         
         if(!g_MTF_W1.Initialize(g_Symbol, PERIOD_W1))
         {
            Print("ERROR: Failed to initialize W1 MTF Filter!");
            return INIT_FAILED;
         }
         
         g_MTF_W1.SetPeriods(InpMTF_W1_SMA_Fast, InpMTF_W1_SMA_Slow, InpRSI_Period, InpATR_Period);
         Print("W1 MTF Filter initialized (SMA Fast: ", InpMTF_W1_SMA_Fast, ", Slow: ", InpMTF_W1_SMA_Slow, ")");
      }
      
      Print("MTF Analysis enabled with min confirmations: ", InpMTF_MinConfirmations);
   }
   
   // Initialize Dashboard
   if(InpShowDashboard)
   {
      g_Dashboard = new CDashboard();
      if(g_Dashboard == NULL)
      {
         Print("ERROR: Failed to create Dashboard!");
         return INIT_FAILED;
      }
      
      g_Dashboard.Initialize(InpDashboardX, InpDashboardY, InpDashboardColor);
   }
   
   // Initialize trade object
   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(10);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Initialize daily tracking
   g_DailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_DailyResetTime = TimeCurrent();
   
   Print("========================================");
   Print("  Initialization Successful!");
   Print("========================================");
   Print("Symbol: ", g_Symbol);
   Print("Timeframe: ", EnumToString(g_Timeframe));
   Print("Initial Capital: ", InpInitialCapital, " EUR");
   Print("Current Balance: ", AccountInfoDouble(ACCOUNT_BALANCE), " EUR");
   Print("Current Phase: ", g_CapitalGrowth.GetCurrentPhase());
   Print("Volume Multiplier: ", g_CapitalGrowth.GetVolumeMultiplier(), "x");
   Print("Max Clusters: ", InpMaxSimultaneousClusters);
   Print("Min Combined Score: ", InpMinCombinedScore);
   Print("========================================");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("========================================");
   Print("  Pyramiding Inversat EA - Deinitialization");
   Print("  Reason: ", reason);
   Print("========================================");
   
   // Print final statistics
   if(g_CapitalGrowth != NULL)
      g_CapitalGrowth.PrintStatus();
   
   if(g_PyramidingMgr != NULL)
      g_PyramidingMgr.PrintStatistics();
   
   // Clean up
   if(g_CapitalGrowth != NULL)
   {
      delete g_CapitalGrowth;
      g_CapitalGrowth = NULL;
   }
   
   if(g_PyramidingMgr != NULL)
   {
      delete g_PyramidingMgr;
      g_PyramidingMgr = NULL;
   }
   
   if(g_ScoreFilter != NULL)
   {
      delete g_ScoreFilter;
      g_ScoreFilter = NULL;
   }
   
   if(g_MTF_H4 != NULL)
   {
      delete g_MTF_H4;
      g_MTF_H4 = NULL;
   }
   
   if(g_MTF_D1 != NULL)
   {
      delete g_MTF_D1;
      g_MTF_D1 = NULL;
   }
   
   if(g_MTF_W1 != NULL)
   {
      delete g_MTF_W1;
      g_MTF_W1 = NULL;
   }
   
   if(g_Dashboard != NULL)
   {
      g_Dashboard.RemoveAll();
      delete g_Dashboard;
      g_Dashboard = NULL;
   }
   
   Print("Deinitialization complete.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update capital
   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_CapitalGrowth.UpdateCapital(current_balance);
   
   // Check for closed positions
   g_PyramidingMgr.CheckClosedPositions();
   
   // Update pyramiding entries
   if(InpEnablePyramiding)
      g_PyramidingMgr.UpdateClusters();
   
   // Check daily drawdown
   CheckDailyDrawdown();
   
   // Update dashboard
   if(InpShowDashboard && g_Dashboard != NULL)
      UpdateDashboard();
   
   // Check for new bar
   datetime current_bar_time = iTime(g_Symbol, g_Timeframe, 0);
   if(current_bar_time == g_LastBarTime)
      return;
   
   g_LastBarTime = current_bar_time;
   
   // Check trading conditions
   if(!IsTradingAllowed())
      return;
   
   // Check if we can open new cluster
   if(g_PyramidingMgr.GetActiveClusters() >= InpMaxSimultaneousClusters)
      return;
   
   // Calculate combined score
   int combined_score = g_ScoreFilter.CalculateScore();
   
   // Check if score meets minimum requirement
   if(InpEnableFilter && combined_score < InpMinCombinedScore)
   {
      Print("Signal rejected: Combined Score (", combined_score, ") < Minimum (", InpMinCombinedScore, ")");
      return;
   }
   
   // Get trend direction
   int trend_direction = g_ScoreFilter.GetTrendDirection();
   
   if(trend_direction == 0)
      return; // No clear trend
   
   // Check Multi-Timeframe Confirmation
   if(!CheckMTFConfirmation(trend_direction))
   {
      Print("Entry blocked by MTF analysis - higher timeframes don't confirm trend");
      return;
   }
   
   // Calculate lot size
   double base_lot = InpBaseLotSize * g_CapitalGrowth.GetVolumeMultiplier();
   
   // Normalize lot size
   double min_lot = SymbolInfoDouble(g_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(g_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(g_Symbol, SYMBOL_VOLUME_STEP);
   
   base_lot = MathFloor(base_lot / lot_step) * lot_step;
   
   if(base_lot < min_lot)
      base_lot = min_lot;
   if(base_lot > max_lot)
      base_lot = max_lot;
   
   // Open new cluster
   Print("========================================");
   Print("  NEW SIGNAL DETECTED");
   Print("========================================");
   Print("Combined Score: ", combined_score, "/100");
   
   int trend_score, momentum_score, volatility_score, consistency_score;
   g_ScoreFilter.GetScoreBreakdown(trend_score, momentum_score, volatility_score, consistency_score);
   
   Print("Trend: ", trend_score, " | Momentum: ", momentum_score);
   Print("Volatility: ", volatility_score, " | Consistency: ", consistency_score);
   Print("Direction: ", (trend_direction == 1) ? "BUY" : "SELL");
   Print("Base Lot: ", base_lot);
   Print("Volume Multiplier: ", g_CapitalGrowth.GetVolumeMultiplier(), "x");
   Print("========================================");
   
   if(g_PyramidingMgr.OpenCluster(trend_direction, base_lot))
   {
      Print("Cluster opened successfully!");
      
      if(g_Dashboard != NULL)
         g_Dashboard.UpdateStatus(true, (trend_direction == 1) ? "BUY" : "SELL");
   }
   else
   {
      Print("Failed to open cluster!");
   }
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   // Check if trading is globally allowed
   if(!g_TradingAllowed)
      return false;
   
   // Check trading hours
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   if(dt.hour < InpStartHour || dt.hour >= InpEndHour)
      return false;
   
   // Check trading days
   switch(dt.day_of_week)
   {
      case 1: if(!InpTradeMonday) return false; break;
      case 2: if(!InpTradeTuesday) return false; break;
      case 3: if(!InpTradeWednesday) return false; break;
      case 4: if(!InpTradeThursday) return false; break;
      case 5: if(!InpTradeFriday) return false; break;
      default: return false; // Weekend
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check daily drawdown                                             |
//+------------------------------------------------------------------+
void CheckDailyDrawdown()
{
   MqlDateTime dt_now, dt_last;
   TimeToStruct(TimeCurrent(), dt_now);
   TimeToStruct(g_DailyResetTime, dt_last);
   
   // Reset daily tracking at midnight
   if(dt_now.day != dt_last.day)
   {
      g_DailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_DailyResetTime = TimeCurrent();
      g_TradingAllowed = true;
      
      Print("Daily reset - New trading day started");
      Print("Starting Balance: ", g_DailyStartBalance, " EUR");
   }
   
   // Calculate daily drawdown
   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double daily_dd = 0.0;
   
   if(g_DailyStartBalance > 0)
      daily_dd = (g_DailyStartBalance - current_balance) / g_DailyStartBalance * 100.0;
   
   // Check if daily DD limit exceeded
   if(daily_dd > InpMaxDailyDD)
   {
      if(g_TradingAllowed)
      {
         g_TradingAllowed = false;
         
         Print("========================================");
         Print("  DAILY DRAWDOWN LIMIT EXCEEDED!");
         Print("========================================");
         Print("Daily DD: ", daily_dd, "%");
         Print("Max Allowed: ", InpMaxDailyDD, "%");
         Print("Trading stopped for today.");
         Print("========================================");
         
         // Close all positions (optional - comment out if you don't want this)
         // CloseAllPositions();
      }
   }
}

//+------------------------------------------------------------------+
//| Check Multi-Timeframe Trend Confirmations                        |
//+------------------------------------------------------------------+
bool CheckMTFConfirmation(int direction)
{
   if(!InpEnableMTF)
      return true; // MTF not enabled, allow entry
   
   int confirmations = 0;
   int total_enabled = 0;
   
   // Check H4
   if(InpMTF_UseH4 && g_MTF_H4 != NULL)
   {
      total_enabled++;
      int score = g_MTF_H4.CalculateScore();
      
      // Score > 60 = bullish, score < 40 = bearish
      if(direction > 0 && score >= 60)
         confirmations++;
      else if(direction < 0 && score <= 40)
         confirmations++;
   }
   
   // Check D1
   if(InpMTF_UseD1 && g_MTF_D1 != NULL)
   {
      total_enabled++;
      int score = g_MTF_D1.CalculateScore();
      
      if(direction > 0 && score >= 60)
         confirmations++;
      else if(direction < 0 && score <= 40)
         confirmations++;
   }
   
   // Check W1
   if(InpMTF_UseW1 && g_MTF_W1 != NULL)
   {
      total_enabled++;
      int score = g_MTF_W1.CalculateScore();
      
      if(direction > 0 && score >= 60)
         confirmations++;
      else if(direction < 0 && score <= 40)
         confirmations++;
   }
   
   // No MTF filters enabled
   if(total_enabled == 0)
      return true;
   
   // Check if we have minimum confirmations
   bool confirmed = confirmations >= InpMTF_MinConfirmations;
   
   if(!confirmed)
   {
      Print("MTF Confirmation failed: ", confirmations, "/", total_enabled, " confirmations (min required: ", InpMTF_MinConfirmations, ")");
   }
   
   return confirmed;
}

//+------------------------------------------------------------------+
//| Update dashboard                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(g_Dashboard == NULL)
      return;
   
   // Update capital data
   g_Dashboard.UpdateCapital(
      g_CapitalGrowth.GetCurrentCapital(),
      InpInitialCapital,
      g_CapitalGrowth.GetTotalDeposited(),
      g_CapitalGrowth.GetTotalWithdrawn(),
      g_CapitalGrowth.GetTotalProfit(),
      g_CapitalGrowth.GetROI()
   );
   
   // Update phase data
   g_Dashboard.UpdatePhase(
      g_CapitalGrowth.GetCurrentPhase(),
      g_CapitalGrowth.GetVolumeMultiplier(),
      g_CapitalGrowth.GetWithdrawalPercent()
   );
   
   // Update trading data
   g_Dashboard.UpdateTrading(
      g_PyramidingMgr.GetActiveClusters(),
      g_PyramidingMgr.GetMaxClusters(),
      g_PyramidingMgr.GetTotalClusters(),
      g_PyramidingMgr.GetWinRate()
   );
   
   // Update score data
   int combined_score = g_ScoreFilter.CalculateScore();
   int trend_score, momentum_score, volatility_score, consistency_score;
   g_ScoreFilter.GetScoreBreakdown(trend_score, momentum_score, volatility_score, consistency_score);
   
   g_Dashboard.UpdateScore(
      combined_score,
      trend_score,
      momentum_score,
      volatility_score,
      consistency_score
   );
   
   // Update performance data
   g_Dashboard.UpdatePerformance(
      g_CapitalGrowth.GetMaxDrawdown(),
      g_CapitalGrowth.GetMonthlyProfit(),
      0.0 // Monthly ROI - calculate if needed
   );
   
   // Update MTF data
   int h4_score = (g_MTF_H4 != NULL) ? g_MTF_H4.CalculateScore() : 0;
   int d1_score = (g_MTF_D1 != NULL) ? g_MTF_D1.CalculateScore() : 0;
   int w1_score = (g_MTF_W1 != NULL) ? g_MTF_W1.CalculateScore() : 0;
   
   g_Dashboard.UpdateMTF(
      InpEnableMTF,
      InpMTF_UseH4,
      InpMTF_UseD1,
      InpMTF_UseW1,
      h4_score,
      d1_score,
      w1_score
   );
   
   // Update status
   g_Dashboard.UpdateStatus(
      g_TradingAllowed,
      "MONITORING"
   );
   
   // Draw dashboard
   g_Dashboard.Draw();
}

//+------------------------------------------------------------------+
//| Close all positions (emergency function)                         |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            g_Trade.PositionClose(ticket);
            Print("Emergency close: Position #", ticket);
         }
      }
   }
}
//+------------------------------------------------------------------+
