//+------------------------------------------------------------------+
//|                                        PyramidingManager.mqh      |
//|                                  Copyright 2024, Criss Strategy     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Criss Strategy"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Pyramiding Manager Class                                         |
//+------------------------------------------------------------------+
class CPyramidingManager
{
private:
   CTrade m_Trade;
   
   // Cluster structure
   struct SCluster
   {
      ulong cluster_id;
      int direction;           // 1=BUY, -1=SELL
      datetime open_time;
      double entry1_price;
      double entry1_volume;
      ulong entry1_ticket;
      
      double entry2_price;
      double entry2_volume;
      ulong entry2_ticket;
      bool entry2_opened;
      
      double entry3_price;
      double entry3_volume;
      ulong entry3_ticket;
      bool entry3_opened;
      
      double entry4_price;
      double entry4_volume;
      ulong entry4_ticket;
      bool entry4_opened;
      
      double entry5_price;
      double entry5_volume;
      ulong entry5_ticket;
      bool entry5_opened;
      
      double sl_price;
      double tp_price;
      
      bool is_active;
      double total_volume;
      double avg_price;
   };
   
   SCluster m_Clusters[];
   int m_MaxClusters;
   int m_ActiveClusters;
   
   // Pyramiding settings
   double m_Entry2Distance;    // 15 pips
   double m_Entry3Distance;    // 30 pips
   double m_Entry4Distance;    // 40 pips
   double m_Entry5Distance;    // 50 pips
   
   double m_Entry2Multiplier;  // 1.5x
   double m_Entry3Multiplier;  // 2.0x
   double m_Entry4Multiplier;  // 1.5x
   double m_Entry5Multiplier;  // 1.0x
   
   double m_SL_Pips;
   double m_TP_Pips;
   
   // Trailing Stop settings
   bool m_EnableTrailingStop;
   double m_TrailingStopPips;
   double m_TrailingStepPips;
   
   // Symbol info
   string m_Symbol;
   double m_Point;
   double m_TickValue;
   
   // Magic number
   int m_MagicNumber;
   string m_TradeComment;
   
   // Statistics
   struct SStatistics
   {
      int total_clusters;
      int winning_clusters;
      int losing_clusters;
      double total_profit;
      double total_loss;
      double win_rate;
      double avg_profit;
      double avg_loss;
   };
   SStatistics m_Stats;

public:
   //--- Constructor
   CPyramidingManager()
   {
      m_MaxClusters = 5;
      m_ActiveClusters = 0;
      ArrayResize(m_Clusters, m_MaxClusters);
      
      // Initialize clusters
      for(int i = 0; i < m_MaxClusters; i++)
      {
         m_Clusters[i].is_active = false;
         m_Clusters[i].cluster_id = 0;
      }
      
      // Default pyramiding settings
      m_Entry2Distance = 15.0;
      m_Entry3Distance = 30.0;
      m_Entry4Distance = 40.0;
      m_Entry5Distance = 50.0;
      
      m_Entry2Multiplier = 1.5;
      m_Entry3Multiplier = 2.0;
      m_Entry4Multiplier = 1.5;
      m_Entry5Multiplier = 1.0;
      
      m_SL_Pips = 25.0;
      m_TP_Pips = 60.0;
      
      // Initialize trailing stop
      m_EnableTrailingStop = true;
      m_TrailingStopPips = 20.0;
      m_TrailingStepPips = 5.0;
      
      m_MagicNumber = 123456;
      m_TradeComment = "PyramInv";
      
      // Initialize stats
      m_Stats.total_clusters = 0;
      m_Stats.winning_clusters = 0;
      m_Stats.losing_clusters = 0;
      m_Stats.total_profit = 0.0;
      m_Stats.total_loss = 0.0;
      m_Stats.win_rate = 0.0;
      m_Stats.avg_profit = 0.0;
      m_Stats.avg_loss = 0.0;
   }
   
   //--- Initialize
   bool Initialize(string symbol, int magic_number, string comment)
   {
      m_Symbol = symbol;
      m_MagicNumber = magic_number;
      m_TradeComment = comment;
      
      m_Point = SymbolInfoDouble(m_Symbol, SYMBOL_POINT);
      m_TickValue = SymbolInfoDouble(m_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
      m_Trade.SetExpertMagicNumber(m_MagicNumber);
      m_Trade.SetDeviationInPoints(10);
      m_Trade.SetTypeFilling(ORDER_FILLING_FOK);
      
      Print("PyramidingManager initialized for ", m_Symbol);
      Print("Magic Number: ", m_MagicNumber);
      Print("Max Clusters: ", m_MaxClusters);
      
      return true;
   }
   
   //--- Set pyramiding distances
   void SetDistances(double entry2, double entry3, double entry4, double entry5)
   {
      m_Entry2Distance = entry2;
      m_Entry3Distance = entry3;
      m_Entry4Distance = entry4;
      m_Entry5Distance = entry5;
   }
   
   //--- Set pyramiding multipliers
   void SetMultipliers(double mult2, double mult3, double mult4, double mult5)
   {
      m_Entry2Multiplier = mult2;
      m_Entry3Multiplier = mult3;
      m_Entry4Multiplier = mult4;
      m_Entry5Multiplier = mult5;
   }
   
   //--- Set SL/TP
   void SetSLTP(double sl_pips, double tp_pips)
   {
      m_SL_Pips = sl_pips;
      m_TP_Pips = tp_pips;
   }
   
   //--- Set Trailing Stop
   void SetTrailingStop(bool enable, double trailing_pips, double step_pips)
   {
      m_EnableTrailingStop = enable;
      m_TrailingStopPips = trailing_pips;
      m_TrailingStepPips = step_pips;
   }
   
   //--- Open new cluster
   bool OpenCluster(int direction, double base_volume)
   {
      // Check if we can open new cluster
      if(m_ActiveClusters >= m_MaxClusters)
      {
         Print("Cannot open cluster: Max clusters reached (", m_MaxClusters, ")");
         return false;
      }
      
      // Find free cluster slot
      int cluster_index = -1;
      for(int i = 0; i < m_MaxClusters; i++)
      {
         if(!m_Clusters[i].is_active)
         {
            cluster_index = i;
            break;
         }
      }
      
      if(cluster_index < 0)
      {
         Print("ERROR: No free cluster slot found!");
         return false;
      }
      
      // Get current price
      double current_price = (direction == 1) ? SymbolInfoDouble(m_Symbol, SYMBOL_ASK) : 
                                                 SymbolInfoDouble(m_Symbol, SYMBOL_BID);
      
      // Calculate SL and TP
      double sl_price, tp_price;
      if(direction == 1) // BUY
      {
         sl_price = current_price - m_SL_Pips * m_Point * 10;
         tp_price = current_price + m_TP_Pips * m_Point * 10;
      }
      else // SELL
      {
         sl_price = current_price + m_SL_Pips * m_Point * 10;
         tp_price = current_price - m_TP_Pips * m_Point * 10;
      }
      
      // Open Entry 1
      bool success = false;
      if(direction == 1)
         success = m_Trade.Buy(base_volume, m_Symbol, current_price, sl_price, tp_price, m_TradeComment + "_E1");
      else
         success = m_Trade.Sell(base_volume, m_Symbol, current_price, sl_price, tp_price, m_TradeComment + "_E1");
      
      if(!success)
      {
         Print("ERROR: Failed to open Entry 1. Error: ", GetLastError());
         return false;
      }
      
      // Initialize cluster
      m_Clusters[cluster_index].cluster_id = m_Trade.ResultOrder();
      m_Clusters[cluster_index].direction = direction;
      m_Clusters[cluster_index].open_time = TimeCurrent();
      m_Clusters[cluster_index].entry1_price = current_price;
      m_Clusters[cluster_index].entry1_volume = base_volume;
      m_Clusters[cluster_index].entry1_ticket = m_Trade.ResultOrder();
      m_Clusters[cluster_index].sl_price = sl_price;
      m_Clusters[cluster_index].tp_price = tp_price;
      m_Clusters[cluster_index].is_active = true;
      m_Clusters[cluster_index].total_volume = base_volume;
      m_Clusters[cluster_index].avg_price = current_price;
      
      // Calculate entry prices for pyramiding
      if(direction == 1) // BUY
      {
         m_Clusters[cluster_index].entry2_price = current_price - m_Entry2Distance * m_Point * 10;
         m_Clusters[cluster_index].entry3_price = current_price - m_Entry3Distance * m_Point * 10;
         m_Clusters[cluster_index].entry4_price = current_price - m_Entry4Distance * m_Point * 10;
         m_Clusters[cluster_index].entry5_price = current_price - m_Entry5Distance * m_Point * 10;
      }
      else // SELL
      {
         m_Clusters[cluster_index].entry2_price = current_price + m_Entry2Distance * m_Point * 10;
         m_Clusters[cluster_index].entry3_price = current_price + m_Entry3Distance * m_Point * 10;
         m_Clusters[cluster_index].entry4_price = current_price + m_Entry4Distance * m_Point * 10;
         m_Clusters[cluster_index].entry5_price = current_price + m_Entry5Distance * m_Point * 10;
      }
      
      m_Clusters[cluster_index].entry2_volume = base_volume * m_Entry2Multiplier;
      m_Clusters[cluster_index].entry3_volume = base_volume * m_Entry3Multiplier;
      m_Clusters[cluster_index].entry4_volume = base_volume * m_Entry4Multiplier;
      m_Clusters[cluster_index].entry5_volume = base_volume * m_Entry5Multiplier;
      
      m_Clusters[cluster_index].entry2_opened = false;
      m_Clusters[cluster_index].entry3_opened = false;
      m_Clusters[cluster_index].entry4_opened = false;
      m_Clusters[cluster_index].entry5_opened = false;
      
      m_ActiveClusters++;
      m_Stats.total_clusters++;
      
      Print("=== NEW CLUSTER OPENED ===");
      Print("Cluster ID: ", m_Clusters[cluster_index].cluster_id);
      Print("Direction: ", (direction == 1) ? "BUY" : "SELL");
      Print("Entry 1 Price: ", current_price);
      Print("Entry 1 Volume: ", base_volume);
      Print("SL: ", sl_price);
      Print("TP: ", tp_price);
      Print("Active Clusters: ", m_ActiveClusters, "/", m_MaxClusters);
      
      return true;
   }
   
   //--- Update clusters (check for pyramiding entries and trailing stop)
   void UpdateClusters()
   {
      for(int i = 0; i < m_MaxClusters; i++)
      {
         if(!m_Clusters[i].is_active)
            continue;
         
         double current_price = (m_Clusters[i].direction == 1) ? 
                                SymbolInfoDouble(m_Symbol, SYMBOL_BID) : 
                                SymbolInfoDouble(m_Symbol, SYMBOL_ASK);
         
         // Apply trailing stop to all positions in cluster
         if(m_EnableTrailingStop)
            ApplyTrailingStop(i, current_price);
         
         // Check Entry 2
         if(!m_Clusters[i].entry2_opened)
         {
            bool trigger = false;
            if(m_Clusters[i].direction == 1 && current_price <= m_Clusters[i].entry2_price)
               trigger = true;
            if(m_Clusters[i].direction == -1 && current_price >= m_Clusters[i].entry2_price)
               trigger = true;
            
            if(trigger)
            {
               OpenPyramidingEntry(i, 2);
            }
         }
         
         // Check Entry 3
         if(!m_Clusters[i].entry3_opened && m_Clusters[i].entry2_opened)
         {
            bool trigger = false;
            if(m_Clusters[i].direction == 1 && current_price <= m_Clusters[i].entry3_price)
               trigger = true;
            if(m_Clusters[i].direction == -1 && current_price >= m_Clusters[i].entry3_price)
               trigger = true;
            
            if(trigger)
            {
               OpenPyramidingEntry(i, 3);
            }
         }
         
         // Check Entry 4
         if(!m_Clusters[i].entry4_opened && m_Clusters[i].entry3_opened)
         {
            bool trigger = false;
            if(m_Clusters[i].direction == 1 && current_price <= m_Clusters[i].entry4_price)
               trigger = true;
            if(m_Clusters[i].direction == -1 && current_price >= m_Clusters[i].entry4_price)
               trigger = true;
            
            if(trigger)
            {
               OpenPyramidingEntry(i, 4);
            }
         }
         
         // Check Entry 5
         if(!m_Clusters[i].entry5_opened && m_Clusters[i].entry4_opened)
         {
            bool trigger = false;
            if(m_Clusters[i].direction == 1 && current_price <= m_Clusters[i].entry5_price)
               trigger = true;
            if(m_Clusters[i].direction == -1 && current_price >= m_Clusters[i].entry5_price)
               trigger = true;
            
            if(trigger)
            {
               OpenPyramidingEntry(i, 5);
            }
         }
      }
   }
   
   //--- Check closed positions
   void CheckClosedPositions()
   {
      for(int i = 0; i < m_MaxClusters; i++)
      {
         if(!m_Clusters[i].is_active)
            continue;
         
         // Check if all positions in cluster are closed
         bool all_closed = true;
         
         if(m_Clusters[i].entry1_ticket > 0 && PositionSelectByTicket(m_Clusters[i].entry1_ticket))
            all_closed = false;
         if(m_Clusters[i].entry2_opened && m_Clusters[i].entry2_ticket > 0 && PositionSelectByTicket(m_Clusters[i].entry2_ticket))
            all_closed = false;
         if(m_Clusters[i].entry3_opened && m_Clusters[i].entry3_ticket > 0 && PositionSelectByTicket(m_Clusters[i].entry3_ticket))
            all_closed = false;
         if(m_Clusters[i].entry4_opened && m_Clusters[i].entry4_ticket > 0 && PositionSelectByTicket(m_Clusters[i].entry4_ticket))
            all_closed = false;
         if(m_Clusters[i].entry5_opened && m_Clusters[i].entry5_ticket > 0 && PositionSelectByTicket(m_Clusters[i].entry5_ticket))
            all_closed = false;
         
         if(all_closed)
         {
            // Calculate cluster profit
            double cluster_profit = CalculateClusterProfit(i);
            
            // Update statistics
            if(cluster_profit > 0)
            {
               m_Stats.winning_clusters++;
               m_Stats.total_profit += cluster_profit;
            }
            else
            {
               m_Stats.losing_clusters++;
               m_Stats.total_loss += MathAbs(cluster_profit);
            }
            
            // Calculate win rate
            if(m_Stats.total_clusters > 0)
            {
               m_Stats.win_rate = (double)m_Stats.winning_clusters / m_Stats.total_clusters * 100.0;
            }
            
            m_Stats.avg_profit = (m_Stats.winning_clusters > 0) ? (m_Stats.total_profit / m_Stats.winning_clusters) : 0.0;
            m_Stats.avg_loss = (m_Stats.losing_clusters > 0) ? (m_Stats.total_loss / m_Stats.losing_clusters) : 0.0;
            
            Print("=== CLUSTER CLOSED ===");
            Print("Cluster ID: ", m_Clusters[i].cluster_id);
            Print("Profit: ", cluster_profit, " EUR");
            Print("Win Rate: ", m_Stats.win_rate, "%");
            
            // Deactivate cluster
            m_Clusters[i].is_active = false;
            m_ActiveClusters--;
         }
      }
   }
   
   //--- Get active clusters count
   int GetActiveClusters() { return m_ActiveClusters; }
   
   //--- Get max clusters
   int GetMaxClusters() { return m_MaxClusters; }
   
   //--- Get win rate
   double GetWinRate() { return m_Stats.win_rate; }
   
   //--- Get total clusters
   int GetTotalClusters() { return m_Stats.total_clusters; }
   
   //--- Print statistics
   void PrintStatistics()
   {
      Print("=== PYRAMIDING STATISTICS ===");
      Print("Total Clusters: ", m_Stats.total_clusters);
      Print("Winning Clusters: ", m_Stats.winning_clusters);
      Print("Losing Clusters: ", m_Stats.losing_clusters);
      Print("Win Rate: ", m_Stats.win_rate, "%");
      Print("Total Profit: ", m_Stats.total_profit, " EUR");
      Print("Total Loss: ", m_Stats.total_loss, " EUR");
      Print("Avg Profit: ", m_Stats.avg_profit, " EUR");
      Print("Avg Loss: ", m_Stats.avg_loss, " EUR");
      Print("Active Clusters: ", m_ActiveClusters, "/", m_MaxClusters);
   }

private:
   //--- Apply trailing stop to all positions in cluster
   void ApplyTrailingStop(int cluster_index, double current_price)
   {
      if(!m_Clusters[cluster_index].is_active)
         return;
      
      // Calculate profit in pips for BUY or SELL
      double profit_pips = 0.0;
      if(m_Clusters[cluster_index].direction == 1) // BUY
         profit_pips = (current_price - m_Clusters[cluster_index].entry1_price) / m_Point / 10.0;
      else // SELL
         profit_pips = (m_Clusters[cluster_index].entry1_price - current_price) / m_Point / 10.0;
      
      // Only trail if profit >= trailing stop distance
      if(profit_pips < m_TrailingStopPips)
         return;
      
      // Calculate new SL
      double new_sl = 0.0;
      if(m_Clusters[cluster_index].direction == 1) // BUY
         new_sl = current_price - m_TrailingStopPips * m_Point * 10;
      else // SELL
         new_sl = current_price + m_TrailingStopPips * m_Point * 10;
      
      // Check if new SL is better than current SL (+ step)
      bool should_update = false;
      if(m_Clusters[cluster_index].direction == 1) // BUY
         should_update = (new_sl > m_Clusters[cluster_index].sl_price + m_TrailingStepPips * m_Point * 10);
      else // SELL
         should_update = (new_sl < m_Clusters[cluster_index].sl_price - m_TrailingStepPips * m_Point * 10);
      
      if(!should_update)
         return;
      
      // Update SL for ALL positions in cluster
      bool updated = false;
      
      // Entry 1
      if(m_Clusters[cluster_index].entry1_ticket > 0 && PositionSelectByTicket(m_Clusters[cluster_index].entry1_ticket))
      {
         if(m_Trade.PositionModify(m_Clusters[cluster_index].entry1_ticket, new_sl, m_Clusters[cluster_index].tp_price))
            updated = true;
      }
      
      // Entry 2
      if(m_Clusters[cluster_index].entry2_opened && m_Clusters[cluster_index].entry2_ticket > 0 && 
         PositionSelectByTicket(m_Clusters[cluster_index].entry2_ticket))
      {
         m_Trade.PositionModify(m_Clusters[cluster_index].entry2_ticket, new_sl, m_Clusters[cluster_index].tp_price);
      }
      
      // Entry 3
      if(m_Clusters[cluster_index].entry3_opened && m_Clusters[cluster_index].entry3_ticket > 0 && 
         PositionSelectByTicket(m_Clusters[cluster_index].entry3_ticket))
      {
         m_Trade.PositionModify(m_Clusters[cluster_index].entry3_ticket, new_sl, m_Clusters[cluster_index].tp_price);
      }
      
      // Entry 4
      if(m_Clusters[cluster_index].entry4_opened && m_Clusters[cluster_index].entry4_ticket > 0 && 
         PositionSelectByTicket(m_Clusters[cluster_index].entry4_ticket))
      {
         m_Trade.PositionModify(m_Clusters[cluster_index].entry4_ticket, new_sl, m_Clusters[cluster_index].tp_price);
      }
      
      // Entry 5
      if(m_Clusters[cluster_index].entry5_opened && m_Clusters[cluster_index].entry5_ticket > 0 && 
         PositionSelectByTicket(m_Clusters[cluster_index].entry5_ticket))
      {
         m_Trade.PositionModify(m_Clusters[cluster_index].entry5_ticket, new_sl, m_Clusters[cluster_index].tp_price);
      }
      
      if(updated)
      {
         m_Clusters[cluster_index].sl_price = new_sl;
         Print("Trailing Stop activated for Cluster ", m_Clusters[cluster_index].cluster_id);
         Print("New SL: ", new_sl, " | Profit: ", profit_pips, " pips");
      }
   }
   
   //--- Open pyramiding entry
   bool OpenPyramidingEntry(int cluster_index, int entry_number)
   {
      double volume = 0.0;
      double price = 0.0;
      string comment = "";
      
      switch(entry_number)
      {
         case 2:
            volume = m_Clusters[cluster_index].entry2_volume;
            price = m_Clusters[cluster_index].entry2_price;
            comment = m_TradeComment + "_E2";
            break;
         case 3:
            volume = m_Clusters[cluster_index].entry3_volume;
            price = m_Clusters[cluster_index].entry3_price;
            comment = m_TradeComment + "_E3";
            break;
         case 4:
            volume = m_Clusters[cluster_index].entry4_volume;
            price = m_Clusters[cluster_index].entry4_price;
            comment = m_TradeComment + "_E4";
            break;
         case 5:
            volume = m_Clusters[cluster_index].entry5_volume;
            price = m_Clusters[cluster_index].entry5_price;
            comment = m_TradeComment + "_E5";
            break;
         default:
            return false;
      }
      
      // Get current price for new entry
      double entry_price = (m_Clusters[cluster_index].direction == 1) ? 
                           SymbolInfoDouble(m_Symbol, SYMBOL_ASK) : 
                           SymbolInfoDouble(m_Symbol, SYMBOL_BID);
      
      // RECALCULATE SL/TP based on NEW entry price
      double new_sl, new_tp;
      if(m_Clusters[cluster_index].direction == 1) // BUY
      {
         new_sl = entry_price - m_SL_Pips * m_Point * 10;
         new_tp = entry_price + m_TP_Pips * m_Point * 10;
      }
      else // SELL
      {
         new_sl = entry_price + m_SL_Pips * m_Point * 10;
         new_tp = entry_price - m_TP_Pips * m_Point * 10;
      }
      
      // Open new position with NEW SL/TP
      bool success = false;
      if(m_Clusters[cluster_index].direction == 1)
         success = m_Trade.Buy(volume, m_Symbol, 0, new_sl, new_tp, comment);
      else
         success = m_Trade.Sell(volume, m_Symbol, 0, new_sl, new_tp, comment);
      
      if(success)
      {
         ulong ticket = m_Trade.ResultOrder();
         
         switch(entry_number)
         {
            case 2:
               m_Clusters[cluster_index].entry2_ticket = ticket;
               m_Clusters[cluster_index].entry2_opened = true;
               break;
            case 3:
               m_Clusters[cluster_index].entry3_ticket = ticket;
               m_Clusters[cluster_index].entry3_opened = true;
               break;
            case 4:
               m_Clusters[cluster_index].entry4_ticket = ticket;
               m_Clusters[cluster_index].entry4_opened = true;
               break;
            case 5:
               m_Clusters[cluster_index].entry5_ticket = ticket;
               m_Clusters[cluster_index].entry5_opened = true;
               break;
         }
         
         m_Clusters[cluster_index].total_volume += volume;
         
         // UPDATE cluster SL/TP to NEW values
         m_Clusters[cluster_index].sl_price = new_sl;
         m_Clusters[cluster_index].tp_price = new_tp;
         
         Print("Pyramiding Entry ", entry_number, " opened for Cluster ", m_Clusters[cluster_index].cluster_id);
         Print("Volume: ", volume, " | Total Volume: ", m_Clusters[cluster_index].total_volume);
         Print("NEW SL/TP: ", new_sl, " / ", new_tp, " (based on Entry ", entry_number, " price)");
         
         // MODIFY all existing positions in cluster to use NEW SL/TP
         UpdateClusterSLTP(cluster_index, new_sl, new_tp);
         
         return true;
      }
      
      Print("ERROR: Failed to open Entry ", entry_number);
      return false;
   }
   
   //--- Update SL/TP for all positions in cluster
   void UpdateClusterSLTP(int cluster_index, double new_sl, double new_tp)
   {
      int modified_count = 0;
      
      // Update Entry 1
      if(m_Clusters[cluster_index].entry1_ticket > 0 && PositionSelectByTicket(m_Clusters[cluster_index].entry1_ticket))
      {
         if(m_Trade.PositionModify(m_Clusters[cluster_index].entry1_ticket, new_sl, new_tp))
            modified_count++;
      }
      
      // Update Entry 2
      if(m_Clusters[cluster_index].entry2_opened && m_Clusters[cluster_index].entry2_ticket > 0 && 
         PositionSelectByTicket(m_Clusters[cluster_index].entry2_ticket))
      {
         if(m_Trade.PositionModify(m_Clusters[cluster_index].entry2_ticket, new_sl, new_tp))
            modified_count++;
      }
      
      // Update Entry 3
      if(m_Clusters[cluster_index].entry3_opened && m_Clusters[cluster_index].entry3_ticket > 0 && 
         PositionSelectByTicket(m_Clusters[cluster_index].entry3_ticket))
      {
         if(m_Trade.PositionModify(m_Clusters[cluster_index].entry3_ticket, new_sl, new_tp))
            modified_count++;
      }
      
      // Update Entry 4
      if(m_Clusters[cluster_index].entry4_opened && m_Clusters[cluster_index].entry4_ticket > 0 && 
         PositionSelectByTicket(m_Clusters[cluster_index].entry4_ticket))
      {
         if(m_Trade.PositionModify(m_Clusters[cluster_index].entry4_ticket, new_sl, new_tp))
            modified_count++;
      }
      
      if(modified_count > 0)
      {
         Print("Updated SL/TP for ", modified_count, " existing positions in Cluster ", m_Clusters[cluster_index].cluster_id);
         Print("New SL: ", new_sl, " | New TP: ", new_tp);
      }
   }
   
   //--- Calculate cluster profit
   double CalculateClusterProfit(int cluster_index)
   {
      double total_profit = 0.0;
      
      // Get profit from history
      HistorySelect(m_Clusters[cluster_index].open_time, TimeCurrent());
      
      for(int i = 0; i < HistoryDealsTotal(); i++)
      {
         ulong deal_ticket = HistoryDealGetTicket(i);
         if(deal_ticket > 0)
         {
            ulong position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
            
            if(position_id == m_Clusters[cluster_index].entry1_ticket ||
               position_id == m_Clusters[cluster_index].entry2_ticket ||
               position_id == m_Clusters[cluster_index].entry3_ticket ||
               position_id == m_Clusters[cluster_index].entry4_ticket ||
               position_id == m_Clusters[cluster_index].entry5_ticket)
            {
               total_profit += HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
            }
         }
      }
      
      return total_profit;
   }
};
//+------------------------------------------------------------------+
