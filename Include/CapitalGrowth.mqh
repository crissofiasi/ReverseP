//+------------------------------------------------------------------+
//|                                            CapitalGrowth.mqh      |
//|                                  Copyright 2024, Criss Strategy     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Criss Strategy"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Capital Growth Manager Class                                     |
//+------------------------------------------------------------------+
class CCapitalGrowth
{
private:
   // Capital tracking
   double m_InitialCapital;
   double m_CurrentCapital;
   double m_TotalDeposited;
   double m_TotalWithdrawn;
   double m_TargetCapital;
   double m_FinalTarget;
   
   // Phase tracking
   enum ENUM_PHASE
   {
      PHASE_ACCUMULATION,     // 0-10k
      PHASE_CONSOLIDATION,    // 10k-50k
      PHASE_ACCELERATION,     // 50k-500k
      PHASE_EXTRACTION        // >500k
   };
   ENUM_PHASE m_CurrentPhase;
   
   // Withdrawal settings
   double m_WithdrawalPhase1;  // 0%
   double m_WithdrawalPhase2;  // 30%
   double m_WithdrawalPhase3;  // 50%
   double m_WithdrawalPhase4;  // 85%
   
   // Volume scaling
   double m_BaseVolume;
   double m_CurrentMultiplier;
   double m_MaxMultiplier;
   
   // Monthly tracking
   datetime m_LastMonthChecked;
   double m_MonthStartCapital;
   double m_MonthlyProfit;
   
   // Performance tracking
   struct SPerformanceMetrics
   {
      double total_profit;
      double total_loss;
      double max_capital;
      double min_capital;
      double max_dd;
      int total_months;
      int positive_months;
      double avg_monthly_roi;
   };
   SPerformanceMetrics m_Performance;

public:
   //--- Constructor
   CCapitalGrowth(double initial_capital, double target_capital, double final_target)
   {
      m_InitialCapital = initial_capital;
      m_CurrentCapital = initial_capital;
      m_TotalDeposited = initial_capital;
      m_TotalWithdrawn = 0.0;
      m_TargetCapital = target_capital;
      m_FinalTarget = final_target;
      
      m_CurrentPhase = PHASE_ACCUMULATION;
      
      m_WithdrawalPhase1 = 0.0;
      m_WithdrawalPhase2 = 30.0;
      m_WithdrawalPhase3 = 50.0;
      m_WithdrawalPhase4 = 85.0;
      
      m_BaseVolume = 0.02;
      m_CurrentMultiplier = 1.0;
      m_MaxMultiplier = 5.0;
      
      m_LastMonthChecked = TimeCurrent();
      m_MonthStartCapital = initial_capital;
      m_MonthlyProfit = 0.0;
      
      // Initialize performance
      m_Performance.total_profit = 0.0;
      m_Performance.total_loss = 0.0;
      m_Performance.max_capital = initial_capital;
      m_Performance.min_capital = initial_capital;
      m_Performance.max_dd = 0.0;
      m_Performance.total_months = 0;
      m_Performance.positive_months = 0;
      m_Performance.avg_monthly_roi = 0.0;
   }
   
   //--- Update capital
   void UpdateCapital(double current_balance)
   {
      m_CurrentCapital = current_balance;
      
      // Update performance metrics
      if(m_CurrentCapital > m_Performance.max_capital)
         m_Performance.max_capital = m_CurrentCapital;
      
      if(m_CurrentCapital < m_Performance.min_capital)
         m_Performance.min_capital = m_CurrentCapital;
      
      // Calculate drawdown
      double dd = (m_Performance.max_capital - m_CurrentCapital) / m_Performance.max_capital * 100.0;
      if(dd > m_Performance.max_dd)
         m_Performance.max_dd = dd;
      
      // Update phase
      UpdatePhase();
      
      // Update volume multiplier
      UpdateVolumeMultiplier();
      
      // Check monthly update
      CheckMonthlyUpdate();
   }
   
   //--- Get current phase
   string GetCurrentPhase()
   {
      switch(m_CurrentPhase)
      {
         case PHASE_ACCUMULATION: return "ACCUMULATION";
         case PHASE_CONSOLIDATION: return "CONSOLIDATION";
         case PHASE_ACCELERATION: return "ACCELERATION";
         case PHASE_EXTRACTION: return "EXTRACTION";
         default: return "UNKNOWN";
      }
   }
   
   //--- Get withdrawal percent for current phase
   double GetWithdrawalPercent()
   {
      switch(m_CurrentPhase)
      {
         case PHASE_ACCUMULATION: return m_WithdrawalPhase1;
         case PHASE_CONSOLIDATION: return m_WithdrawalPhase2;
         case PHASE_ACCELERATION: return m_WithdrawalPhase3;
         case PHASE_EXTRACTION: return m_WithdrawalPhase4;
         default: return 0.0;
      }
   }
   
   //--- Get volume multiplier
   double GetVolumeMultiplier() { return m_CurrentMultiplier; }
   
   //--- Get current capital
   double GetCurrentCapital() { return m_CurrentCapital; }
   
   //--- Get total deposited
   double GetTotalDeposited() { return m_TotalDeposited; }
   
   //--- Get total withdrawn
   double GetTotalWithdrawn() { return m_TotalWithdrawn; }
   
   //--- Get total profit
   double GetTotalProfit() { return m_CurrentCapital + m_TotalWithdrawn - m_TotalDeposited; }
   
   //--- Get ROI
   double GetROI() { return (m_TotalDeposited > 0) ? (GetTotalProfit() / m_TotalDeposited * 100.0) : 0.0; }
   
   //--- Get monthly profit
   double GetMonthlyProfit() { return m_MonthlyProfit; }
   
   //--- Get max drawdown
   double GetMaxDrawdown() { return m_Performance.max_dd; }
   
   //--- Print status
   void PrintStatus()
   {
      Print("=== CAPITAL GROWTH STATUS ===");
      Print("Current Capital: ", m_CurrentCapital, " EUR");
      Print("Total Deposited: ", m_TotalDeposited, " EUR");
      Print("Total Withdrawn: ", m_TotalWithdrawn, " EUR");
      Print("Total Profit: ", GetTotalProfit(), " EUR");
      Print("ROI: ", GetROI(), "%");
      Print("Phase: ", GetCurrentPhase());
      Print("Volume Multiplier: ", m_CurrentMultiplier, "x");
      Print("Max DD: ", m_Performance.max_dd, "%");
   }

private:
   //--- Update phase
   void UpdatePhase()
   {
      ENUM_PHASE old_phase = m_CurrentPhase;
      
      if(m_CurrentCapital < m_TargetCapital)
         m_CurrentPhase = PHASE_ACCUMULATION;
      else if(m_CurrentCapital < 50000.0)
         m_CurrentPhase = PHASE_CONSOLIDATION;
      else if(m_CurrentCapital < m_FinalTarget)
         m_CurrentPhase = PHASE_ACCELERATION;
      else
         m_CurrentPhase = PHASE_EXTRACTION;
      
      if(old_phase != m_CurrentPhase)
      {
         Print("PHASE CHANGE: ", EnumToString(old_phase), " -> ", EnumToString(m_CurrentPhase));
         Print("Capital: ", m_CurrentCapital, " EUR");
      }
   }
   
   //--- Update volume multiplier
   void UpdateVolumeMultiplier()
   {
      if(m_CurrentCapital < 10000)
      {
         // 2k-10k: 1.0x -> 2.0x
         m_CurrentMultiplier = 1.0 + (m_CurrentCapital - m_InitialCapital) / 8000.0;
      }
      else if(m_CurrentCapital < 25000)
      {
         // 10k-25k: 2.0x -> 2.5x
         m_CurrentMultiplier = 2.0 + (m_CurrentCapital - 10000) / 30000.0;
      }
      else if(m_CurrentCapital < 50000)
      {
         // 25k-50k: 2.5x -> 3.5x
         m_CurrentMultiplier = 2.5 + (m_CurrentCapital - 25000) / 25000.0;
      }
      else if(m_CurrentCapital < 100000)
      {
         // 50k-100k: 3.5x -> 4.5x
         m_CurrentMultiplier = 3.5 + (m_CurrentCapital - 50000) / 50000.0;
      }
      else if(m_CurrentCapital < m_FinalTarget)
      {
         // 100k-500k: 4.5x -> 5.0x
         m_CurrentMultiplier = 4.5 + (m_CurrentCapital - 100000) / 800000.0;
      }
      else
      {
         // >500k: 3.0x (extraction - reduce risk)
         m_CurrentMultiplier = 3.0;
      }
      
      if(m_CurrentMultiplier > m_MaxMultiplier)
         m_CurrentMultiplier = m_MaxMultiplier;
      
      if(m_CurrentMultiplier < 1.0)
         m_CurrentMultiplier = 1.0;
   }
   
   //--- Check monthly update
   void CheckMonthlyUpdate()
   {
      MqlDateTime dt_now, dt_last;
      TimeToStruct(TimeCurrent(), dt_now);
      TimeToStruct(m_LastMonthChecked, dt_last);
      
      if(dt_now.mon != dt_last.mon || dt_now.year != dt_last.year)
      {
         // New month
         m_MonthlyProfit = m_CurrentCapital - m_MonthStartCapital;
         
         // Update performance
         m_Performance.total_months++;
         if(m_MonthlyProfit > 0)
         {
            m_Performance.total_profit += m_MonthlyProfit;
            m_Performance.positive_months++;
         }
         else
         {
            m_Performance.total_loss += MathAbs(m_MonthlyProfit);
         }
         
         // Calculate average monthly ROI
         if(m_Performance.total_months > 0)
         {
            m_Performance.avg_monthly_roi = (m_Performance.total_profit - m_Performance.total_loss) / 
                                           (m_MonthStartCapital * m_Performance.total_months) * 100.0;
         }
         
         Print("=== MONTHLY REPORT ===");
         Print("Month: ", TimeToString(m_LastMonthChecked, TIME_DATE));
         Print("Monthly Profit: ", m_MonthlyProfit, " EUR");
         Print("Monthly ROI: ", (m_MonthStartCapital > 0) ? (m_MonthlyProfit / m_MonthStartCapital * 100.0) : 0.0, "%");
         
         // Reset for new month
         m_LastMonthChecked = TimeCurrent();
         m_MonthStartCapital = m_CurrentCapital;
         m_MonthlyProfit = 0.0;
      }
   }
};
//+------------------------------------------------------------------+
