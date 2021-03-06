//+------------------------------------------------------------------+
//|                                                   TakeProfit.mq4 |
//|                                        Copyright 2018, FRT Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, FRT Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//--- input parameters
input int      input_time_schedule=10;//定时器(单位：秒)
input int      input_point_diff=5;//波动值
input int      input_take_profit=20;//止盈(用于计算，大于市场的时候作为止盈)
input int      input_stop_loss=60;//止损(用于计算，大于市场的时候作为止损)
input int      input_slip=1;//滑点
input double   input_shares_num=0.1;//执行数量
input string   input_sa_1 = "USOIL";//资产1
input string   input_sa_2 = "UKOIL";//资产2
input int      input_close_order_time = 6;//持仓时间（单位：次）

string us_file_path;//美油数据保存路径
string uk_file_path;//
int    order_timer;
double usoil_point;
double ukoil_point;
double usoil_sl;
double usoil_tp;

double ukoil_sl;
double ukoil_tp;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(input_time_schedule);
   usoil_point = MarketInfo(input_sa_1, MODE_POINT);
   ukoil_point = MarketInfo(input_sa_2, MODE_POINT);
   
   double usoil_stop_level = MarketInfo(input_sa_1, MODE_STOPLEVEL);
   if(input_stop_loss < usoil_stop_level){
      usoil_sl = usoil_stop_level;    
   } else {
      usoil_sl = input_stop_loss;
   }
   
   if(input_take_profit < usoil_stop_level){
      usoil_tp = usoil_stop_level;    
   } else {
      usoil_tp = input_take_profit;
   }
   
   double ukoil_stop_level = MarketInfo(input_sa_2, MODE_STOPLEVEL);
   if(input_stop_loss < ukoil_stop_level){
      ukoil_sl = ukoil_stop_level;    
   } else {
      ukoil_sl = input_stop_loss;
   }
   
   if(input_take_profit < ukoil_stop_level){
      ukoil_tp = ukoil_stop_level;    
   } else {
      ukoil_tp = input_take_profit;
   }
   
   us_file_path = "usrecord.txt";   
   uk_file_path = "ukrecord.txt";
   PrintFormat("Oninit::us_p= %.3f, uk_p= %.3f, us_sl= %.3f, uk_sl= %.3f, us_sl1= %.3f, us_tp1= %.3f, uk_sl1= %.3f, uk_tp1= %.3f,", 
            usoil_point, ukoil_point, usoil_stop_level, ukoil_stop_level, usoil_sl, usoil_tp, ukoil_sl, ukoil_tp);
//---
   return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();  
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   //获取行情数据
   MqlRates usoil_rates[];
   MqlRates ukoil_rates[];
   ArraySetAsSeries(usoil_rates,true);
   ArraySetAsSeries(ukoil_rates,true);
   
   int usoil_copied = CopyRates(input_sa_1, PERIOD_M1, 0, 10, usoil_rates);
   int ukoil_copied = CopyRates(input_sa_2, PERIOD_M1, 0, 10, ukoil_rates);
   
   //获取各个品种的价差
   double usoil_diff = usoil_rates[0].close - usoil_rates[0].open;
   double ukoil_diff = ukoil_rates[0].close - ukoil_rates[0].open;
   
   PrintFormat("onTimer::us_o= %.3f , us_c= %.3f, uk_o= %.3f, uk_c= %.3f, us_diff=%.3f, uk_diff=%.3f, us_count= %d, uk_count= %d", 
      usoil_rates[0].open, usoil_rates[0].close, ukoil_rates[0].open, ukoil_rates[0].close, usoil_diff, ukoil_diff, usoil_copied, ukoil_diff);
   
   if (hasOrder()) {
     PrintFormat("onTimer::Wait order handled=================");
     if(order_timer < input_close_order_time) {
         order_timer = order_timer + 1;
         PrintFormat("onTimer::Order hold: %d", order_timer);
         handleTakeProfit();
     } else {
         PrintFormat("onTimer::Order over time=============================");
         closeMyOrder();
         order_timer = 0;
     }
   } else {       
      //达成变化条件
      if (MathAbs((usoil_diff/usoil_point) - (ukoil_diff/ukoil_point)) >= 
         (input_point_diff + input_take_profit)){
         PrintFormat("OnTimer:can due====================");
         if(isUSTradeTime() == true) {//美盘交易时间
            PrintFormat("OnTimer:can due::is_us_time");
            double ukoil_price_bid = MarketInfo(input_sa_2, MODE_BID);
            double ukoil_price_ask = MarketInfo(input_sa_2, MODE_ASK);
            double ukoil_price_sl_buy = ukoil_price_bid - (MarketInfo(input_sa_2, MODE_POINT) * ukoil_sl);
            double ukoil_price_tp_buy = ukoil_price_bid + (MarketInfo(input_sa_2, MODE_POINT) * ukoil_tp); 
            double ukoil_price_sl_sell = ukoil_price_ask + (MarketInfo(input_sa_2, MODE_POINT) * ukoil_sl);
            double ukoil_price_tp_sell = ukoil_price_ask - (MarketInfo(input_sa_2, MODE_POINT) * ukoil_tp); 
            
            if (usoil_diff > 0) {
               OrderSend(input_sa_2, OP_BUY, input_shares_num, ukoil_price_bid, 
                         input_slip, ukoil_price_sl_buy, ukoil_price_tp_buy, "x1");     
               order_timer = 0;
            } else if (usoil_diff < 0) {
               OrderSend(input_sa_2, OP_SELL, input_shares_num, ukoil_price_ask, 
                         input_slip, ukoil_price_sl_sell, ukoil_price_tp_sell, "x2");     
               order_timer = 0;
            }
         } else if (isUETradeTime() == true) {//欧盘交易时间
            PrintFormat("OnTimer:can due::is_ue_time");
            double usoil_price_bid = MarketInfo(input_sa_1, MODE_BID);
            double usoil_price_ask = MarketInfo(input_sa_1, MODE_ASK);
            double usoil_price_sl_buy = usoil_price_bid - (MarketInfo(input_sa_1, MODE_POINT) * usoil_sl);
            double usoil_price_tp_buy = usoil_price_bid + (MarketInfo(input_sa_1, MODE_POINT) * usoil_tp); 
            double usoil_price_sl_sell = usoil_price_ask + (MarketInfo(input_sa_1, MODE_POINT) * usoil_sl);
            double usoil_price_tp_sell = usoil_price_ask - (MarketInfo(input_sa_1, MODE_POINT) * usoil_tp); 
            
            if ( ukoil_diff > 0 ) {
               OrderSend(input_sa_1, OP_BUY, input_shares_num, usoil_price_bid, 
                         input_slip, usoil_price_sl_buy, usoil_price_tp_buy, "x3");     
               order_timer = 0;
            } else if (ukoil_diff < 0) {
               OrderSend(input_sa_1, OP_SELL, input_shares_num, usoil_price_ask, 
                         input_slip, usoil_price_sl_sell, usoil_price_tp_sell, "x4");
               order_timer = 0;
            }
         }
      } else {
         PrintFormat("onTimer::Can not deal");
      }
   }
  }
//+------------------------------------------------------------------+

//判断是否有交易记录
bool hasOrder()
{
  int orders_count = OrdersTotal();
  bool is_targeted = false;
  PrintFormat("hasOrder::order_count= %d", orders_count);
  for(int order_index = 0; order_index < orders_count; order_index++)
  {
    if (OrderSelect(order_index, SELECT_BY_POS, MODE_TRADES) == true){
      OrderPrint();
      string order_comment = StringSubstr(OrderComment(), 0, 1);
      PrintFormat("hasOrder::orderx= %d, comm= %s, comm1= %s", order_index, OrderComment(), order_comment);
      if (StringCompare(order_comment, "x") == 0){
        is_targeted = true;
        break;
      }
    } else {
      PrintFormat("Order select %d false=====", order_index);
    }
  };
  return(is_targeted);
};

void closeMyOrder()
{
   int orders_count = OrdersTotal();
   double usoil_ask = MarketInfo(input_sa_1, MODE_ASK);
   double usoil_bid = MarketInfo(input_sa_1, MODE_BID);
   double ukoil_ask = MarketInfo(input_sa_2, MODE_ASK);
   double ukoil_bid = MarketInfo(input_sa_2, MODE_BID);
   PrintFormat("closeMyOrder::orders_count= %d, us_ask= .5f%, us_bid= %.5f, uk_ask= %.5f, uk_bid= %.5f", 
            orders_count, usoil_ask, usoil_bid, ukoil_ask, ukoil_bid);
            
   for(int order_index = 0; order_index < orders_count; order_index++){
      if(OrderSelect(order_index, SELECT_BY_POS, MODE_TRADES) == true) {
         string order_comm = OrderComment();
         if(StringCompare(order_comm, "x1")) {
            OrderClose(OrderTicket(), OrderLots(), ukoil_ask, input_slip, clrFireBrick);
         } else if(StringCompare(order_comm, "x2")){
            OrderClose(OrderTicket(), OrderLots(), ukoil_bid, input_slip, clrFireBrick);
         } else if(StringCompare(order_comm, "x3")){
            OrderClose(OrderTicket(), OrderLots(), usoil_ask, input_slip, clrFireBrick);
         }else if(StringCompare(order_comm, "x4")){
            OrderClose(OrderTicket(), OrderLots(), usoil_bid, input_slip, clrFireBrick);
         }
      }
   }
};

void handleTakeProfit(){
   int orders_count = OrdersTotal();
   double usoil_ask = MarketInfo(input_sa_1, MODE_ASK);
   double usoil_bid = MarketInfo(input_sa_1, MODE_BID);
   double ukoil_ask = MarketInfo(input_sa_2, MODE_ASK);
   double ukoil_bid = MarketInfo(input_sa_2, MODE_BID);
   double usoil_tp_price = input_take_profit * usoil_point;
   double ukoil_tp_price = input_take_profit * ukoil_point;
   double usoil_sl_price = input_stop_loss * usoil_point;
   double ukoil_sl_price = input_stop_loss * ukoil_point;
   
   PrintFormat("handleTakeProfit::orders_count= %d, us_ask= .5f%, us_bid= %.5f, uk_ask= %.5f, uk_bid= %.5f, us_tp= %.5f, uk_tp= .5f", 
            orders_count, usoil_ask, usoil_bid, ukoil_ask, ukoil_bid, usoil_tp_price, ukoil_tp_price);
   
   for(int order_index = 0; order_index < orders_count; order_index ++) {
      if (OrderSelect(order_index, SELECT_BY_POS, MODE_TRADES) == true) {
         
         string order_comment = OrderComment();
         double order_price = OrderOpenPrice();
         int    order_ticket = OrderTicket();
         double order_lots   = OrderLots();
         
         PrintFormat("handleTakeProfit:info::comment= %s, price= %.5f, ticket= %d, lots= %.3f, open_time= %s", 
                  order_comment, order_price, order_ticket, order_lots, 
                  TimeToString(OrderOpenTime(), TIME_DATE|TIME_SECONDS));
         
         if(StringCompare(order_comment, "x1") == 0) {
           if (ukoil_ask >= (ukoil_tp_price + order_price)){
             PrintFormat("handleTakeProfit::tp close::x1");
             OrderClose(order_ticket, order_lots, ukoil_ask, input_slip, clrSaddleBrown);
           } else if (ukoil_ask <= (order_price - ukoil_sl_price)) {
             PrintFormat("handleTakeProfit::sl close::x1");
             OrderClose(order_ticket, order_lots, ukoil_ask, input_slip, clrSaddleBrown);
           }          
         } else if (StringCompare(order_comment, "x2") == 0) {
           if (ukoil_bid <= (order_price - ukoil_tp_price)){
             PrintFormat("handleTakeProfit::tp close::x2");
             OrderClose(order_ticket, order_lots, ukoil_bid, input_slip, clrSaddleBrown);
           } else if (ukoil_bid > (order_price + ukoil_sl_price)){
             PrintFormat("handleTakeProfit::sl close::x2");
             OrderClose(order_ticket, order_lots, ukoil_bid, input_slip, clrSaddleBrown);
           }
         } else if (StringCompare(order_comment, "x3") == 0) {
           if (usoil_ask >= (usoil_tp_price + order_price)){
             PrintFormat("handleTakeProfit::tp close::x3");
             OrderClose(order_ticket, order_lots, usoil_ask, input_slip, clrSaddleBrown);
           } else if (usoil_ask <= (order_price - usoil_sl_price)){
             PrintFormat("handleTakeProfit::sl close::x3");
             OrderClose(order_ticket, order_lots, usoil_ask, input_slip, clrSaddleBrown);  
           }  
         } else if (StringCompare(order_comment, "x4") == 0 ) {
           if (usoil_bid <= (order_price - usoil_tp_price)){
             PrintFormat("handleTakeProfit::tp close::x4");
             OrderClose(order_ticket, order_lots, usoil_bid, input_slip, clrSaddleBrown);
           } else if (usoil_bid > (order_price + usoil_sl_price)){
             PrintFormat("handleTakeProfit::sl close::x4");
             OrderClose(order_ticket, order_lots, usoil_bid, input_slip, clrSaddleBrown);
           }
         }
      } else {
         PrintFormat("handleTakeProfit::get order info %d false, skip it==============", order_index);
      }  
   }
}

//转译记录
string getRecordStr(string current_symbol, double diff, double p_open, double p_close, double p_hight, double p_low)
 {
   string record = "";
   StringAdd(record, current_symbol);
   StringAdd(record, "|");
   StringAdd(record, DoubleToStr(MarketInfo(current_symbol, MODE_BID), 5));
   StringAdd(record, "|");
   StringAdd(record, DoubleToStr(MarketInfo(current_symbol, MODE_ASK), 5));
   StringAdd(record, "|");
   StringAdd(record, DoubleToStr(MarketInfo(current_symbol, MODE_POINT), 5));
   StringAdd(record, "|");
   StringAdd(record, DoubleToStr(p_open, 5));
   StringAdd(record, "|");
   StringAdd(record, DoubleToStr(p_close, 5));
   StringAdd(record, "|");
   StringAdd(record, DoubleToStr(p_hight, 5));
   StringAdd(record, "|");
   StringAdd(record, DoubleToStr(p_low, 5));
   StringAdd(record, "|");
   StringAdd(record, DoubleToStr(diff, 5));
   StringAdd(record, "|");

   StringAdd(record, TimeToStr(TimeLocal(), TIME_DATE|TIME_SECONDS));
   StringAdd(record, "\n");
   //交易品种|买入价|卖出价|报价日期
   PrintFormat("=============" + record + "==============");
   return(record);
 };
 
 bool isUSTradeTime()
 {
   datetime us_time_begin_1 = D'00:00:00';
   datetime us_time_end_1   = D'03:59:59';
   
   datetime us_time_begin_2 = D'21:30:00';
   datetime us_time_end_2 = D'23:59:59';
   
   datetime local_time = TimeLocal();
   
   if((local_time > us_time_begin_1 && local_time < us_time_end_1) || 
     (local_time > us_time_begin_2 && local_time < us_time_end_2)){
     return(true);
   } else {
      return(false);
   }
 };
 
 bool isUETradeTime(){
   datetime ue_time_begin = D'14:30:00';
   datetime ue_time_end   = D'21:29:59';
   
   datetime local_time = TimeLocal();
   
   if (local_time < ue_time_end && local_time > ue_time_begin) {
      return(true);
   } else {
      return(false);
   }
 };
 