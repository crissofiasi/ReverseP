//+------------------------------------------------------------------+
//|                                      CombinedScoreFilter.mqh      |
//|                                  Copyright 2024, Criss Strategy     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Criss Strategy"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Combined Score Filter Class                                      |
//+------------------------------------------------------------------+
class CCombinedScoreFilter
{
private:
   // Indicator handles
   int m_SMA_Fast_Handle;
   int m_SMA_Slow_Handle;
   int m_RSI_Handle;
   int m_ATR_Handle;
   
   // Periods
   int m_SMA_Fast_Period;
   int m_SMA_Slow_Period;
   int m_RSI_Period;
   int m_ATR_Period;
   
   // Buffers
   double m_SMA_Fast[];
   double m_SMA_Slow[];
   double m_RSI[];
   double m_ATR[];
   
   // Symbol info
   string m_Symbol;
   ENUM_TIMEFRAMES m_Timeframe;
   double m_Point;
   
   // Score weights (total = 100)
   struct SScoreWeights
   {
      int trend_weight;        // 0-30 points
      int momentum_weight;     // 0-25 points
      int volatility_weight;   // 0-20 points
      int consistency_weight;  // 0-25 points
   };
   SScoreWeights m_Weights;
   
   // Statistics
   struct SFilterStats
   {
      int total_signals;
      int high_score_signals;   // Score >= 75
      int medium_score_signals; // Score 65-74
      int low_score_signals;    // Score < 65
      double avg_score;
      int max_score;
      int min_score;
   };
   SFilterStats m_Stats;

public:
   //--- Constructor
   CCombinedScoreFilter()
   {
      m_SMA_Fast_Period = 4;
      m_SMA_Slow_Period = 24;
      m_RSI_Period = 14;
      m_ATR_Period = 14;
      
      // Default weights
      m_Weights.trend_weight = 30;
      m_Weights.momentum_weight = 25;
      m_Weights.volatility_weight = 20;
      m_Weights.consistency_weight = 25;
      
      // Initialize stats
      m_Stats.total_signals = 0;
      m_Stats.high_score_signals = 0;
      m_Stats.medium_score_signals = 0;
      m_Stats.low_score_signals = 0;
      m_Stats.avg_score = 0.0;
      m_Stats.max_score = 0;
      m_Stats.min_score = 100;
      
      ArraySetAsSeries(m_SMA_Fast, true);
      ArraySetAsSeries(m_SMA_Slow, true);
      ArraySetAsSeries(m_RSI, true);
      ArraySetAsSeries(m_ATR, true);
   }
   
   //--- Destructor
   ~CCombinedScoreFilter()
   {
      Deinitialize();
   }
   
   //--- Initialize indicators
   bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      m_Symbol = symbol;
      m_Timeframe = timeframe;
      m_Point = SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
      
      m_SMA_Fast_Handle = iMA(m_Symbol, m_Timeframe, m_SMA_Fast_Period, 0, MODE_SMA, PRICE_CLOSE);
      m_SMA_Slow_Handle = iMA(m_Symbol, m_Timeframe, m_SMA_Slow_Period, 0, MODE_SMA, PRICE_CLOSE);
      m_RSI_Handle = iRSI(m_Symbol, m_Timeframe, m_RSI_Period, PRICE_CLOSE);
      m_ATR_Handle = iATR(m_Symbol, m_Timeframe, m_ATR_Period);
      
      if(m_SMA_Fast_Handle == INVALID_HANDLE || m_SMA_Slow_Handle == INVALID_HANDLE ||
         m_RSI_Handle == INVALID_HANDLE || m_ATR_Handle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create indicator handles in CombinedScoreFilter!");
         return false;
      }
      
      Print("CombinedScoreFilter initialized successfully");
      Print("Symbol: ", m_Symbol, " | Timeframe: ", EnumToString(m_Timeframe));
      Print("SMA Fast: ", m_SMA_Fast_Period, " | SMA Slow: ", m_SMA_Slow_Period);
      Print("RSI: ", m_RSI_Period, " | ATR: ", m_ATR_Period);
      
      return true;
   }
   
   //--- Deinitialize
   void Deinitialize()
   {
      if(m_SMA_Fast_Handle != INVALID_HANDLE)
         IndicatorRelease(m_SMA_Fast_Handle);
      if(m_SMA_Slow_Handle != INVALID_HANDLE)
         IndicatorRelease(m_SMA_Slow_Handle);
      if(m_RSI_Handle != INVALID_HANDLE)
         IndicatorRelease(m_RSI_Handle);
      if(m_ATR_Handle != INVALID_HANDLE)
         IndicatorRelease(m_ATR_Handle);
   }
   
   //--- Set periods
   void SetPeriods(int sma_fast, int sma_slow, int rsi, int atr)
   {
      m_SMA_Fast_Period = sma_fast;
      m_SMA_Slow_Period = sma_slow;
      m_RSI_Period = rsi;
      m_ATR_Period = atr;
   }
   
   //--- Calculate combined score
   int CalculateScore()
   {
      // Copy indicator data (need 10 bars for slope calculation)
      if(CopyBuffer(m_SMA_Fast_Handle, 0, 0, 10, m_SMA_Fast) <= 0 ||
         CopyBuffer(m_SMA_Slow_Handle, 0, 0, 10, m_SMA_Slow) <= 0 ||
         CopyBuffer(m_RSI_Handle, 0, 0, 3, m_RSI) <= 0 ||
         CopyBuffer(m_ATR_Handle, 0, 0, 3, m_ATR) <= 0)
      {
         Print("ERROR: Failed to copy indicator buffers");
         return 0;
      }
      
      int total_score = 0;
      
      // 1. TREND SCORE (0-30 points)
      total_score += CalculateTrendScore();
      
      // 2. MOMENTUM SCORE (0-25 points)
      total_score += CalculateMomentumScore();
      
      // 3. VOLATILITY SCORE (0-20 points)
      total_score += CalculateVolatilityScore();
      
      // 4. CONSISTENCY SCORE (0-25 points)
      total_score += CalculateConsistencyScore();
      
      // Update statistics
      UpdateStatistics(total_score);
      
      return total_score;
   }
   
   //--- Get trend direction
   int GetTrendDirection()
   {
      if(CopyBuffer(m_SMA_Fast_Handle, 0, 0, 2, m_SMA_Fast) <= 0 ||
         CopyBuffer(m_SMA_Slow_Handle, 0, 0, 2, m_SMA_Slow) <= 0)
      {
         return 0;
      }
      
      // Bullish trend
      if(m_SMA_Fast[0] > m_SMA_Slow[0] && m_SMA_Fast[1] > m_SMA_Slow[1])
         return 1;
      
      // Bearish trend
      if(m_SMA_Fast[0] < m_SMA_Slow[0] && m_SMA_Fast[1] < m_SMA_Slow[1])
         return -1;
      
      return 0;
   }
   
   //--- Get detailed score breakdown
   void GetScoreBreakdown(int &trend, int &momentum, int &volatility, int &consistency)
   {
      if(CopyBuffer(m_SMA_Fast_Handle, 0, 0, 10, m_SMA_Fast) <= 0 ||
         CopyBuffer(m_SMA_Slow_Handle, 0, 0, 10, m_SMA_Slow) <= 0 ||
         CopyBuffer(m_RSI_Handle, 0, 0, 3, m_RSI) <= 0 ||
         CopyBuffer(m_ATR_Handle, 0, 0, 3, m_ATR) <= 0)
      {
         trend = 0;
         momentum = 0;
         volatility = 0;
         consistency = 0;
         return;
      }
      
      trend = CalculateTrendScore();
      momentum = CalculateMomentumScore();
      volatility = CalculateVolatilityScore();
      consistency = CalculateConsistencyScore();
   }
   
   //--- Get statistics
   void GetStatistics(int &total, int &high, int &medium, int &low, double &avg)
   {
      total = m_Stats.total_signals;
      high = m_Stats.high_score_signals;
      medium = m_Stats.medium_score_signals;
      low = m_Stats.low_score_signals;
      avg = m_Stats.avg_score;
   }
   
   //--- Print score details
   void PrintScoreDetails()
   {
      int trend, momentum, volatility, consistency;
      GetScoreBreakdown(trend, momentum, volatility, consistency);
      
      int total = trend + momentum + volatility + consistency;
      
      Print("=== COMBINED SCORE BREAKDOWN ===");
      Print("Trend Score:       ", trend, " / ", m_Weights.trend_weight);
      Print("Momentum Score:    ", momentum, " / ", m_Weights.momentum_weight);
      Print("Volatility Score:  ", volatility, " / ", m_Weights.volatility_weight);
      Print("Consistency Score: ", consistency, " / ", m_Weights.consistency_weight);
      Print("TOTAL SCORE:       ", total, " / 100");
      Print("Quality:           ", GetScoreQuality(total));
      Print("================================");
   }

private:
   //--- Calculate trend score
   int CalculateTrendScore()
   {
      int score = 0;
      
      // 1. SMA Distance Score (0-15 points)
      double sma_distance = MathAbs(m_SMA_Fast[0] - m_SMA_Slow[0]);
      double distance_pips = sma_distance / m_Point / 10.0;
      
      if(distance_pips > 50)
         score += 15;
      else if(distance_pips > 30)
         score += 12;
      else if(distance_pips > 15)
         score += 8;
      else
         score += 3;
      
      // 2. SMA Slope Analysis (0-15 points)
      // Calculate slopes over 5 bars
      double fast_slope = (m_SMA_Fast[0] - m_SMA_Fast[4]) / 5.0;
      double slow_slope = (m_SMA_Slow[0] - m_SMA_Slow[4]) / 5.0;
      
      // Convert to pips per bar
      double fast_slope_pips = fast_slope / m_Point / 10.0;
      double slow_slope_pips = slow_slope / m_Point / 10.0;
      
      // Check if both SMAs trending in same direction
      bool both_rising = (fast_slope > 0 && slow_slope > 0);
      bool both_falling = (fast_slope < 0 && slow_slope < 0);
      
      if(both_rising || both_falling)
      {
         // Strong slope alignment
         double avg_slope = MathAbs((fast_slope_pips + slow_slope_pips) / 2.0);
         
         if(avg_slope > 10.0)        // Strong slope
            score += 15;
         else if(avg_slope > 5.0)     // Medium slope
            score += 10;
         else if(avg_slope > 2.0)     // Weak slope
            score += 6;
         else                          // Very weak slope
            score += 3;
      }
      else
      {
         // SMAs diverging or converging - lower score
         score += 2;
      }
      
      // Cap at max weight
      if(score > m_Weights.trend_weight)
         score = m_Weights.trend_weight;
      
      return score;
   }
   
   //--- Calculate momentum score
   int CalculateMomentumScore()
   {
      int score = 0;
      
      // Check RSI alignment with trend
      bool bullish_trend = (m_SMA_Fast[0] > m_SMA_Slow[0]);
      bool bearish_trend = (m_SMA_Fast[0] < m_SMA_Slow[0]);
      
      // Perfect alignment
      if((bullish_trend && m_RSI[0] > 50 && m_RSI[0] < 70) ||
         (bearish_trend && m_RSI[0] < 50 && m_RSI[0] > 30))
      {
         score = 25;
      }
      // Good alignment
      else if((bullish_trend && m_RSI[0] > 50) ||
              (bearish_trend && m_RSI[0] < 50))
      {
         score = 20;
      }
      // Neutral
      else if(m_RSI[0] > 45 && m_RSI[0] < 55)
      {
         score = 10;
      }
      // Divergence (warning)
      else
      {
         score = 5;
      }
      
      // Bonus for RSI momentum
      if((m_RSI[0] > m_RSI[1] && bullish_trend) ||
         (m_RSI[0] < m_RSI[1] && bearish_trend))
      {
         score += 5;
         if(score > 25) score = 25;
      }
      
      return score;
   }
   
   //--- Calculate volatility score
   int CalculateVolatilityScore()
   {
      // Normalize ATR to pips
      double atr_pips = m_ATR[0] / m_Point / 10.0;
      
      int score = 0;
      
      // Optimal volatility range (15-40 pips)
      if(atr_pips >= 15 && atr_pips <= 40)
         score = 20;
      // Good volatility (10-15 or 40-50 pips)
      else if((atr_pips >= 10 && atr_pips < 15) || (atr_pips > 40 && atr_pips <= 50))
         score = 15;
      // Acceptable (5-10 or 50-60 pips)
      else if((atr_pips >= 5 && atr_pips < 10) || (atr_pips > 50 && atr_pips <= 60))
         score = 10;
      // Too low or too high
      else
         score = 5;
      
      // Check volatility trend
      if(m_ATR[0] > m_ATR[1] && m_ATR[1] > m_ATR[2])
      {
         // Increasing volatility - good for entries
         score += 5;
         if(score > 20) score = 20;
      }
      
      return score;
   }
   
   //--- Calculate consistency score
   int CalculateConsistencyScore()
   {
      int score = 0;
      
      // Check trend consistency (3 bars)
      bool bullish_consistent = (m_SMA_Fast[0] > m_SMA_Slow[0] && 
                                 m_SMA_Fast[1] > m_SMA_Slow[1] && 
                                 m_SMA_Fast[2] > m_SMA_Slow[2]);
      
      bool bearish_consistent = (m_SMA_Fast[0] < m_SMA_Slow[0] && 
                                 m_SMA_Fast[1] < m_SMA_Slow[1] && 
                                 m_SMA_Fast[2] < m_SMA_Slow[2]);
      
      if(bullish_consistent || bearish_consistent)
         score = 25;
      else
         score = 10;
      
      // Check RSI consistency
      bool rsi_consistent = false;
      if(bullish_consistent && m_RSI[0] > 50 && m_RSI[1] > 50)
         rsi_consistent = true;
      if(bearish_consistent && m_RSI[0] < 50 && m_RSI[1] < 50)
         rsi_consistent = true;
      
      if(!rsi_consistent)
         score -= 5;
      
      if(score < 0) score = 0;
      
      return score;
   }
   
   //--- Update statistics
   void UpdateStatistics(int score)
   {
      m_Stats.total_signals++;
      
      if(score >= 75)
         m_Stats.high_score_signals++;
      else if(score >= 65)
         m_Stats.medium_score_signals++;
      else
         m_Stats.low_score_signals++;
      
      // Update average
      m_Stats.avg_score = ((m_Stats.avg_score * (m_Stats.total_signals - 1)) + score) / m_Stats.total_signals;
      
      // Update min/max
      if(score > m_Stats.max_score)
         m_Stats.max_score = score;
      if(score < m_Stats.min_score)
         m_Stats.min_score = score;
   }
   
   //--- Get score quality description
   string GetScoreQuality(int score)
   {
      if(score >= 85)
         return "EXCELLENT";
      else if(score >= 75)
         return "VERY GOOD";
      else if(score >= 65)
         return "GOOD";
      else if(score >= 50)
         return "FAIR";
      else
         return "POOR";
   }
};
//+------------------------------------------------------------------+
