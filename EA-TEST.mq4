//+------------------------------------------------------------------+
//|                                         AtlanticTrading_2023.mq4 |
//|                         Copyright 2023, MetaQuotes Software Corp.|
//|                                                                  |
//+------------------------------------------------------------------+
#property description "Atlantic Trading Academy, AtlanticTrading_MOD"
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link "atlantictradingacademy@gmail.com"
#property version "1.00"
#property strict

#include <stderror.mqh>
#include <stdlib.mqh>

#import "FFC.ex4"
#import   "kernel32.dll"
string NewsCheck(int, int);
int CreateFileW(string Filename,int AccessMode,int ShareMode,int PassAsZero,int CreationMode,int FlagsAndAttributes,int AlsoPassAsZero);
int GetFileSize(int FileHandle,int PassAsZero);
int SetFilePointer(int FileHandle,int Distance,int &PassAsZero[],int FromPosition);
int ReadFile(int FileHandle,uchar &BufferPtr[],int BufferLength,int  &BytesRead[],int PassAsZero);
int CloseHandle(int FileHandle);
#import

//+------------------------------------------------------------------+
//|                      DATOS DE CLIENTES                           |
//+------------------------------------------------------------------+

datetime expDate=D'2023.04.30 23:59';//yyyy.mm.dd
int ccc = 11520763; //CUENTA DE CLIENTE
int ccc1 = 72378; //CUENTA DE CLIENTE

//+------------------------------------------------------------------+

int Slippage=3;
int    Retries=10;
bool   AutoTrade=true;

int MagicID=10101988;
extern bool   ecnBroker=false; //ES UNA CUENTA ECN?
input double LOTS=0.50;
extern int risk=0;//risk: 0 --> Para lotes fijos
input double SL=15;
input double TP=30;

input string    separate_1 = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
input string    tx01       = "Configuración del COMPRA Y VENTA";
extern bool     BUYOPEN = true;              // Turn BUY on?
extern bool     SELLOPEN = true;              // Turn SELL on?
input string    separate_2 = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";  
input string    tx02       = "Configuración de INDICADORES";
input int EMA_Period = 89; // Período de la EMA
input string    separate_3 = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";  
input string    tx03       = "Configuración del HORARIO";
input int TradingStartHour = 8; // Hora de inicio de la sesión de trading (en horas)
input int TradingEndHour = 17; // Hora de finalización de la sesión de trading (en horas)
input string    separate_4 = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";  
input string    tx04       = "Configuración del NOTICIAS";
input bool EnableNewsFilter = false; // Habilitar o deshabilitar el filtro de noticias
input string FFCIndicatorName = "FFC"; // (NO TOCAR) Nombre del indicador FFC
input int FFCBufferIndex = 0; // (NO TOCAR) Índice del búfer de datos del indicador FFC
input int MinutesBeforeNews = 20; // Tiempo de bloqueo antes de las noticias (en minutos)
input int MinutesAfterNews = 20; // Tiempo de bloqueo después de las noticias (en minutos)
input string    separate_5 = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";  
input string    tx05       = "Configuración de las Ordenes Máxima";
extern int    MaxOrders = 10; //Maxímo de Ordenes
input string    separate_6 = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";  
extern double MaxSpread = 5;
double Gd_188;

//+------------------------------------------------------------------+

union Price
   {
      uchar buffer[8];
      double close;
   };

double data[][2];

int BytesToRead;
string    datapath;
string    result;
Price     m_price;

double g_Point;
int    ticket=0;

//+------------------------------------------------------------------+
//| CODIDO DE BLOQUEO POR FECHA Y NUMERO DE CUENTA                   |
//+------------------------------------------------------------------+
int OnInit()
   {
      if(!IsDllsAllowed())
         {
           Alert("Make Sure DLL Import is Allowed");
           ExpertRemove();
           return(INIT_FAILED);
         }
      if(TimeCurrent()>expDate)
         {
           MessageBox("La versión ha caducado, por favor contactar: MIKEA.RC, ELVIS O GRE");
           ExpertRemove();
           return(INIT_FAILED);
         }/*
      if(AccountNumber() != ccc && AccountNumber() != ccc1)
         {
           MessageBox("** ESTA CUENTA NO ESTA AUTORIZADA **");
           ExpertRemove();
           return INIT_FAILED;
         }*/
//------------------------------------------------------
      {
      //---
      g_Point=Point;
      if(Digits==5 || Digits==3 || Digits==2)
       {
        g_Point *= 10;
        Slippage*=10;
      
       }
      ChartSetInteger(0,17,0,0);
      ChartSetInteger(0,0,1);
      string account_server=AccountInfoString(3);
      if(account_server=="")
       {
        account_server="default";
       }
      datapath=TerminalInfoString(3)+"\\history\\"
              +account_server+"\\"+Symbol()+"240"+".hst";
      ReadFileHst(datapath);
      //---
      return(INIT_SUCCEEDED);
      }
 }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
 {
   // Obtiene la hora actual de la PC
   datetime localTime = TimeLocal();
   int currentHour = TimeHour(localTime);

   // Verifica si la hora actual está dentro del rango de horas de trading
   if (currentHour >= TradingStartHour && currentHour <= TradingEndHour)
   {
    if (!isNewsTime())
      {
      
         double emaCurrent = EMA(EMA_Period);
         double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
         double ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   
         // Verifica si la posición actual está por encima o por debajo de la EMA
         bool aboveEMA = bid > emaCurrent;
         bool belowEMA = ask < emaCurrent;
         
         static datetime previousBar;
         if(previousBar!=Time[0])
          {
           previousBar=Time[0];
           ChartRedraw();
          }
         else
          {
           return;
          }
         
         if(iVolume(Symbol(),PERIOD_H4,0)>iVolume(Symbol(),PERIOD_H4,1))
           return;
   //**********************************
   
         if(!BytesToRead>0)
           return;
         
         int pos = -1 ;
         for(int i = 0 ; i < BytesToRead - 1 ; i++)
          {
           if(!(data[i][0]<Time[0]))
              break;
           pos = i + 1;
          }
   
   //********************************
   
         double level=NormalizeDouble(data[pos][1],Digits);
         ObjectDelete("level");
         MakeLine(level);
         
         if(data[pos][1]>Open[0])
           Comment("H4 ref. Time: ", TimeToString((datetime)data[pos][0]),"\nBUY - ", DoubleToString(data[pos][1]));
         if(data[pos][1]<Open[0])
           Comment("H4 ref. Time: ", TimeToString((datetime)data[pos][0]),"\nSELL - ", DoubleToString(data[pos][1]));
         Gd_188=(Ask-Bid)/g_Point;
         if(Gd_188>MaxSpread)
           return;
         
         if(pos>0)
          {
         
           if((CheckMarketBuyOrders() + CheckMarketSellOrders())<MaxOrders)
             {
             
             // Lógica de trading existente adaptada para incluir las condiciones de la EMA
             // Compra en tendencia alcista (por encima de la EMA)
             if (aboveEMA)
               {
             
                 if(data[pos][1]>Open[0])
                     if (BUYOPEN == true)
                       if(IsBuyPinbar())
                         {
                            CloseSell();
                            double BuySL=NormalizeDouble(Ask - SL*g_Point,Digits);
                            double BuyTP=NormalizeDouble(Ask + TP*g_Point,Digits);
                            if(AccountFreeMarginCheck(Symbol(),OP_BUY,GetLots())>0)
                           {
                              ticket=OrderSend(Symbol(),OP_BUY,GetLots(),Ask,Slippage,BuySL,BuyTP,NULL,MagicID,0,clrBlue);
                           }
                         }
               }
              // Vende en tendencia bajista (por debajo de la EMA)
              if (belowEMA)
               {
                 if(data[pos][1]<Open[0])
                     if (SELLOPEN == true)
                       if(IsSellPinbar())
                        {
                           CloseBuy();
                           double SellSL=NormalizeDouble(Bid + SL*g_Point,Digits);
                           double SellTP=NormalizeDouble(Bid - TP*g_Point,Digits);
                           if(AccountFreeMarginCheck(Symbol(),OP_SELL,GetLots())>0)
                           {
                              ticket=OrderSend(Symbol(),OP_SELL,GetLots(),Bid,Slippage,SellSL,SellTP,NULL,MagicID,0,clrRed);
                           }
                        }
               }
             }
          }
     }
  }
  f0_8(); //info panel
  return;
 }
//+------------------------------------------------------------------+
void ReadFileHst(string FileName)
 {
  int       j=0;;
  string    strFileContents;
  int       Handle;
  int       LogFileSize;
  int       movehigh[1]= {0};
  uchar     buffer[];
  int       nNumberOfBytesToRead;
  int       read[1]= {0};
  int       i;
  double    mm;
//----- -----
  strFileContents="";
  Handle=CreateFileW(FileName,(int)0x80000000,3,0,3,0,0);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
  if(Handle==-1)
    {
     Comment("");
     return;
    }
  LogFileSize=GetFileSize(Handle,0);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
  if(LogFileSize<=0)
    {
     return;
    }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
  if((LogFileSize-148)/60==BytesToRead)
    {
     return;
    }
  SetFilePointer(Handle,148,movehigh,0);
  BytesToRead=(LogFileSize-148)/60;
  ArrayResize(data,BytesToRead,0);
  nNumberOfBytesToRead=60;
  ArrayResize(buffer,60,0);
  for(i=0; i<BytesToRead; i=i+1)
     //+------------------------------------------------------------------+
     //|                                                                  |
     //+------------------------------------------------------------------+
    {
     ReadFile(Handle,buffer,nNumberOfBytesToRead,read,NULL);
     if(read[0]==nNumberOfBytesToRead)
       {
        result=StringFormat("0x%02x%02x%02x%02x%02x%02x%02x%02x",buffer[7],buffer[6],buffer[5],buffer[4],buffer[3],buffer[2],buffer[1],buffer[0]);

        m_price.buffer[0] = buffer[32];
        m_price.buffer[1] = buffer[33];
        m_price.buffer[2] = buffer[34];
        m_price.buffer[3] = buffer[35];
        m_price.buffer[4] = buffer[36];
        m_price.buffer[5] = buffer[37];
        m_price.buffer[6] = buffer[38];
        m_price.buffer[7] = buffer[39];
        mm=m_price.close;
        data[j][0] = StringToDouble(result);
        data[j][1] = mm;
        j=j+1;
        strFileContents=TimeToString(StringToTime(result),3)+" "+DoubleToString(mm,8);
       }
     else
       {
        CloseHandle(Handle);
        return;
       }
    }
  CloseHandle(Handle);
  strFileContents=DoubleToString(data[j-1][0],3)+" "+DoubleToString(data[j-1][1],8)+" "+DoubleToString(data[j-2][1],3)+" "+DoubleToString(data[j-2][1],8);
  result=strFileContents;
 }
 
//ReadFileHst <<==--------   --------

int fnGetLotDigit()
 {
  double l_LotStep=MarketInfo(Symbol(),MODE_LOTSTEP);
  if(l_LotStep == 1)
     return(0);
  if(l_LotStep == 0.1)
     return(1);
  if(l_LotStep == 0.01)
     return(2);
  if(l_LotStep == 0.001)
     return(3);
  if(l_LotStep == 0.0001)
     return(4);
  return(1);
 }
//+------------------------------------------------------------------+
int CheckBuyOrders(int magic)
 {
  int op=0;

  for(int i=OrdersTotal()-1; i>=0; i--)
    {
     int status=OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
     if(OrderMagicNumber()!=magic)
        continue;
     if(OrderSymbol()==Symbol())
       {
        if(OrderType()==OP_BUY)
          {
           op++;
           break;
          }
       }
    }
  return(op);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CheckSellOrders(int magic)
 {
  int op=0;

  for(int i=OrdersTotal()-1; i>=0; i--)
    {
     int status=OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
     if(OrderMagicNumber()!=magic)
        continue;
     if(OrderSymbol()==Symbol())
       {
        if(OrderType()==OP_SELL)
          {
           op++;
           break;
          }
       }
    }
  return(op);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CheckTotalBuyOrders(int magic)
 {
  int op=0;

  for(int i=OrdersTotal()-1; i>=0; i--)
    {
     int status=OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
     if(OrderMagicNumber()!=magic)
        continue;
     if(OrderSymbol()==Symbol())
       {
        if(OrderType()==OP_BUY)
          {
           op++;
          }
       }
    }
  return(op);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CheckTotalSellOrders(int magic)
 {
  int op=0;

  for(int i=OrdersTotal()-1; i>=0; i--)
    {
     int status=OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
     if(OrderMagicNumber()!=magic)
        continue;
     if(OrderSymbol()==Symbol())
       {
        if(OrderType()==OP_SELL)
          {
           op++;
          }
       }
    }
  return(op);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CheckMarketSellOrders()
 {
  int op=0;

  for(int i=OrdersTotal()-1; i>=0; i--)
    {
     int status=OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
     if(OrderMagicNumber()!=MagicID)
        continue;
     if(OrderSymbol()==Symbol())
       {
        if(OrderType()==OP_SELL)
          {
           op++;
          }
       }
    }
  return(op);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CheckMarketBuyOrders()
 {
  int op=0;

  for(int i=OrdersTotal()-1; i>=0; i--)
    {
     int status=OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
     if(OrderMagicNumber()!=MagicID)
        continue;
     if(OrderSymbol()==Symbol())
       {
        if(OrderType()==OP_BUY)
          {
           op++;
          }
       }
    }
  return(op);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool MainOrders(int a_cmd_0,double price_24,double price_TP,double price_SL)
 {
  color color_8=Black;
  int bClosed;
  int nAttemptsLeft=Retries;
  int cmd=0;

  if(a_cmd_0 ==OP_BUY||a_cmd_0 ==OP_BUYSTOP)
     cmd=0;
  if(a_cmd_0 ==OP_SELL||a_cmd_0 ==OP_SELLSTOP)
     cmd=1;
  if(a_cmd_0==OP_BUYLIMIT || a_cmd_0==OP_BUY)
    {
     color_8=Blue;
    }
  else
    {
     if(a_cmd_0==OP_SELLLIMIT || a_cmd_0==OP_SELL)
       {
        color_8=Red;
       }
    }

  double lots_32=NormalizeDouble(LOTS,fnGetLotDigit());

  if(lots_32==0.0)
     return(false);

  double gd_532 = MarketInfo(Symbol(), MODE_MAXLOT);
  double gd_540 = MarketInfo(Symbol(), MODE_MINLOT);

  if(lots_32 > gd_532)
     lots_32 = gd_532;
  if(lots_32 < gd_540)
     lots_32 = gd_540;

  bClosed=false;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
  while((bClosed==false) && (nAttemptsLeft>=0))
    {
     nAttemptsLeft--;
     RefreshRates();

     if(!ecnBroker)
        bClosed=OrderSend(Symbol(),a_cmd_0,lots_32,price_24,Slippage,price_SL,price_TP,NULL,MagicID,0,color_8);
     else
        bClosed=OrderSend(Symbol(),a_cmd_0,lots_32,price_24,Slippage,0,0,NULL,MagicID,0,color_8);

     if(bClosed<=0)
       {
        int nErrResult=GetLastError();

        if(a_cmd_0==0)
          {
           Print("DOPE EA Open New Buy FAILED : Error "+IntegerToString(nErrResult)+" ["+ErrorDescription(nErrResult)+".]");
           Print(IntegerToString(a_cmd_0)+" "+DoubleToString(lots_32,2)+" "+DoubleToString(price_24,Digits));
          }
        else
          {
           if(a_cmd_0==1)
             {
              Print("DOPE EA Open New Sell FAILED : Error "+IntegerToString(nErrResult)+" ["+ErrorDescription(nErrResult)+".]");
              Print(IntegerToString(a_cmd_0)+" "+DoubleToString(lots_32,2)+" "+DoubleToString(price_24,Digits));
             }
          }

        if(nErrResult == ERR_TRADE_CONTEXT_BUSY ||
           nErrResult == ERR_NO_CONNECTION)
          {
           Sleep(50);
           continue;
          }
       }

     ticket=bClosed;

     bClosed=true;

    }

  return(true);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseBuy()
 {
  bool clo;
  while(CheckMarketBuyOrders()>0)
    {
     for(int i=OrdersTotal()-1; i>=0; i--)
       {
        if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
           if(OrderSymbol()==Symbol() && OrderMagicNumber()==MagicID)
              if(OrderType()==OP_BUY)
                 clo=OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),Slippage,clrAqua);

       }
    }

 }
//+------------------------------------------------------------------+
void CloseSell()
 {
  bool clo;
  while(CheckMarketSellOrders()>0)
    {
     for(int i=OrdersTotal()-1; i>=0; i--)
       {
        if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
           if(OrderSymbol()==Symbol() && OrderMagicNumber()==MagicID)
              if(OrderType()==OP_SELL)
                 clo=OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),Slippage,clrAqua);

       }
    }
 }
//+------------------------------------------------------------------+
double GetLots()
 {
  double lot;
  double minlot=MarketInfo(Symbol(),MODE_MINLOT);
  double maxlot=MarketInfo(Symbol(),MODE_MAXLOT);
  if(risk!=0)
    {
     lot=NormalizeDouble(AccountBalance()*risk/100/10000,2);
     if(lot<minlot)
        lot=minlot;
     if(lot>maxlot)
        lot=maxlot;
    }
  else
     lot=LOTS;
  return(lot);
 }
//+------------------------------------------------------------------+
void MakeLine(double price)
 {
  string name="level";

  if(price>iOpen(Symbol(),PERIOD_M1,0))
     Comment("BUY = "+DoubleToStr(price,Digits));
  if(price<iOpen(Symbol(),PERIOD_M1,0))
     Comment("SELL= "+DoubleToStr(price,Digits));

  if(ObjectFind(name)!=-1)
    {
     ObjectMove(name,0,iTime(Symbol(),PERIOD_M1,0),price);
     return;
    }
  ObjectCreate(name,OBJ_HLINE,0,0,price);
  ObjectSet(name,OBJPROP_COLOR,clrAqua);
  ObjectSet(name,OBJPROP_STYLE,STYLE_SOLID);
  ObjectSet(name,OBJPROP_WIDTH,2);
  ObjectSet(name,OBJPROP_BACK,TRUE);
 }

//+------------------------------------------------------------------+
//| User function IsPinbar                                           |
//+------------------------------------------------------------------+
bool IsBuyPinbar()
 {
//start of declarations
  double actOp,actCl,actHi,actLo,preHi,preLo,preCl,preOp,actRange,preRange,actHigherPart,actHigherPart1;
  actOp=Open[1];
  actCl=Close[1];
  actHi=High[1];
  actLo=Low[1];
  preOp=Open[2];
  preCl=Close[2];
  preHi=High[2];
  preLo=Low[2];

  actRange=actHi-actLo;
  preRange=preHi-preLo;
  actHigherPart=actHi-actRange*0.4;//helping variable to not have too much counting in IF part
  actHigherPart1=actHi-actRange*0.4;//helping variable to not have too much counting in IF part
//end of declaratins
//start function body
  double dayRange=AveRange4();
  if((actCl>actHigherPart1&&actOp>actHigherPart)&&  //Close&Open of PB is in higher 1/3 of PB
     (actRange>dayRange*0.5)&& //PB is not too small

     (actLo+actRange*0.25<preLo)) //Nose of the PB is at least 1/3 lower than previous bar
    {

     if(Low[ArrayMinimum(Low,3,3)]>Low[1])
        return (true);
    }
  return(false);

 }

//+------------------------------------------------------------------+
bool IsSellPinbar()
 {
//start of declarations
  double actOp,actCl,actHi,actLo,preHi,preLo,preCl,preOp,actRange,preRange,actLowerPart, actLowerPart1;
  actOp=Open[1];
  actCl=Close[1];
  actHi=High[1];
  actLo=Low[1];
  preOp=Open[2];
  preCl=Close[2];
  preHi=High[2];
  preLo=Low[2];
//SetProxy(preHi,preLo,preOp,preCl);//Check proxy
  actRange=actHi-actLo;
  preRange=preHi-preLo;
  actLowerPart=actLo+actRange*0.4;//helping variable to not have too much counting in IF part
  actLowerPart1=actLo+actRange*0.4;//helping variable to not have too much counting in IF part
//end of declaratins

//start function body

  double dayRange=AveRange4();
  if((actCl<actLowerPart1&&actOp<actLowerPart)&&  //Close&Open of PB is in higher 1/3 of PB
     (actRange>dayRange*0.5)&& //PB is not too small

     (actHi-actRange*0.25>preHi)) //Nose of the PB is at least 1/3 lower than previous bar

    {
     if(High[ArrayMaximum(High,3,3)]<High[1])
        return (true);
    }
  return false;
 }
    
//+------------------------------------------------------------------+
//| User function AveRange4                                          |
//+------------------------------------------------------------------+
double AveRange4()
 {
  double sum=0;
  double rangeSerie[4];

  int i=0;
  int ind=1;
  int startYear=1995;


  while(i<4)
    {
     if(TimeDayOfWeek(Time[ind])!=0)
       {
        sum+=High[ind]-Low[ind];//make summation
        i++;
       }
     ind++;
     //i++;
    } 
  return (sum/4.0);//make average, don't count min and max, this is why I divide by 4 and not by 6
 }


//+------------------------------------------------------------------+
//| Función para verificar si hay noticias en el tiempo especificado |
//+------------------------------------------------------------------+
bool isNewsTime()
{
    if (EnableNewsFilter)
    {
        datetime currentTime = TimeLocal();
        //Print("Hora actual: ", currentTime);

        for (int i = 0; i < Bars; i++)
        {
            double newsValue = iCustom(Symbol(), PERIOD_M1, FFCIndicatorName, FFCBufferIndex, i);

            if (newsValue != 0.0) // Solo comprueba eventos de impacto medio y alto
            {
                datetime eventTime = Time[i];
                //Print("Hora del evento: ", eventTime);

                // Verifica si el evento está dentro del rango de tiempo especificado
                if (eventTime >= currentTime - (MinutesBeforeNews * 60) && eventTime <= currentTime + (MinutesAfterNews * 60))
                {
                    Print("Dentro del rango de tiempo de noticias");
                    return true;
                }
            }
        }
    }

    return false;
}



//+------------------------------------------------------------------+
//| Función del Indicador Media Móvil Exponencial                    |
//+------------------------------------------------------------------+

double EMA(int period, int shift = 0)
{
    string symbol = _Symbol;
    int timeframe = _Period;
    string indicatorName = "EMA";
    double emaValue = iMA(symbol, timeframe, period, 0, MODE_EMA, PRICE_CLOSE, shift);
    return emaValue;
}




//+------------------------------------------------------------------+
//| INFORMACION DEL PANEL                    |
//+------------------------------------------------------------------+

void f0_8() {
double lot=GetLots();
ObjectCreate("klc19", OBJ_LABEL, 0, 0, 0);
ObjectSetText("klc19", "ATLANTIC TRADING ACADEMY", 12, "Arial", Green);
ObjectSet("klc19", OBJPROP_CORNER, 1);
ObjectSet("klc19", OBJPROP_XDISTANCE, 10);
ObjectSet("klc19", OBJPROP_YDISTANCE, 40);

ObjectCreate("klc191", OBJ_LABEL, 0, 0, 0);
ObjectSetText("klc191", "Version: 1.00 - 2023", 10, "Arial", Green);
ObjectSet("klc191", OBJPROP_CORNER, 1);
ObjectSet("klc191", OBJPROP_XDISTANCE, 10);
ObjectSet("klc191", OBJPROP_YDISTANCE, 65);

ObjectCreate("klc20", OBJ_LABEL, 0, 0, 0);
ObjectSetText("klc20", "Risk :: "+DoubleToString(risk,0), 10, "Arial", Green);
ObjectSet("klc20", OBJPROP_CORNER, 1);
ObjectSet("klc20", OBJPROP_XDISTANCE, 10);
ObjectSet("klc20", OBJPROP_YDISTANCE, 105);

ObjectCreate("klc21", OBJ_LABEL, 0, 0, 0);
ObjectSetText("klc21","Lots :: " + DoubleToStr(lot, 2)+" Free Mrg  :: "+ DoubleToStr(AccountFreeMargin(),2), 10, "Arial", Green);
ObjectSet("klc21", OBJPROP_CORNER, 1);
ObjectSet("klc21", OBJPROP_XDISTANCE, 10);
ObjectSet("klc21", OBJPROP_YDISTANCE, 125);

ObjectCreate("klc22", OBJ_LABEL, 0, 0, 0);
ObjectSetText("klc22", "Balance :: " + DoubleToStr(AccountBalance(), 2), 10, "Arial", Green);
ObjectSet("klc22", OBJPROP_CORNER, 1);
ObjectSet("klc22", OBJPROP_XDISTANCE, 10);
ObjectSet("klc22", OBJPROP_YDISTANCE, 145);

ObjectCreate("klc23", OBJ_LABEL, 0, 0, 0);
ObjectSetText("klc23", "Equity :: " + DoubleToStr(AccountEquity(), 2), 10, "Arial", Green);
ObjectSet("klc23", OBJPROP_CORNER, 1);
ObjectSet("klc23", OBJPROP_XDISTANCE, 10);
ObjectSet("klc23", OBJPROP_YDISTANCE, 165);

ObjectCreate("klc24", OBJ_LABEL, 0, 0, 0);
ObjectSetText("klc24", "Running P/L :: " + DoubleToStr(AccountProfit(), 2), 10, "Arial", Green);
ObjectSet("klc24", OBJPROP_CORNER, 1);
ObjectSet("klc24", OBJPROP_XDISTANCE, 10);
ObjectSet("klc24", OBJPROP_YDISTANCE, 185);

ObjectCreate("klc27", OBJ_LABEL, 0, 0, 0);
ObjectSetText("klc27", "OrdersTotal :: " + (string)OrdersTotal(), 10, "Arial", Green);
ObjectSet("klc27", OBJPROP_CORNER, 1);
ObjectSet("klc27", OBJPROP_XDISTANCE, 10);
ObjectSet("klc27", OBJPROP_YDISTANCE, 205);

ObjectCreate("klc30", OBJ_LABEL, 0, 0, 0);
ObjectSetText("klc30", "TP :: " + (string)TP+" SL :: "+ (string)SL, 10, "Arial", Green);
ObjectSet("klc30", OBJPROP_CORNER, 1);
ObjectSet("klc30", OBJPROP_XDISTANCE, 10);
ObjectSet("klc30", OBJPROP_YDISTANCE, 225);
/*
color col=clrDimGray; if(trend>0) col=clrRoyalBlue; if(trend<0) col=clrRed;
ObjectSetText("klc13", "trd: "+trend, 10, "Tahoma", col);  
ObjectSet("klc13", OBJPROP_CORNER, 1);
ObjectSet("klc13", OBJPROP_XDISTANCE, 10);
ObjectSet("klc13", OBJPROP_YDISTANCE, 220);
*/
ObjectCreate("klc01", OBJ_LABEL, 0, 0, 0);
color col1=clrDimGray; //if(trend>0) col=clrRoyalBlue; if(trend<0) col=clrRed;
ObjectSetText("klc01", //"Pending exec: "+ Gi_196+" Modif exec: "+Gi_200+ 
               "Spread: "+ DoubleToString(Gd_188, 1), 10, "Tahoma", col1);   
ObjectSet("klc01", OBJPROP_CORNER, 1);
ObjectSet("klc01", OBJPROP_XDISTANCE, 10);
ObjectSet("klc01", OBJPROP_YDISTANCE, 265);

ObjectCreate("klc58", OBJ_LABEL, 0, 0, 0);
ObjectSetText("klc58", "HORA DEL BROCKER: "+(string)TimeCurrent(), 8, "Arial", Red);
ObjectSet("klc58", OBJPROP_CORNER, 1);
ObjectSet("klc58", OBJPROP_XDISTANCE, 10);
ObjectSet("klc58", OBJPROP_YDISTANCE, 325);

ObjectCreate("klc59", OBJ_LABEL, 0, 0, 0);
ObjectSetText("klc59", "HORA DE LA PC: "+(string)TimeLocal(), 8, "Arial", Red);
ObjectSet("klc59", OBJPROP_CORNER, 1);
ObjectSet("klc59", OBJPROP_XDISTANCE, 10);
ObjectSet("klc59", OBJPROP_YDISTANCE, 345);

ObjectCreate("klc60", OBJ_LABEL, 0, 0, 0);
ObjectSetText("klc60", "EXP DEL EA: "+(string)expDate, 8, "Arial", Green);
ObjectSet("klc60", OBJPROP_CORNER, 1);
ObjectSet("klc60", OBJPROP_XDISTANCE, 10);
ObjectSet("klc60", OBJPROP_YDISTANCE, 370);

}
//+------------------------------------------------------------------+
