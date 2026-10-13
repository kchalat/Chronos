//+------------------------------------------------------------------+
//|                                                 Chronos_v1.01.mq5 |
//|                                    Copyright 2026, Chronos Systems|
//|                         https://www.mql5.com/en/users/chronossys  |
//+------------------------------------------------------------------+
#property copyright   "Chronos Systems v1.01"
#property description "Chronos v1.01 - Institutional Non-Repainting Donchian Breakout Engine with Multi-Layer Defense"
#property version     "1.01"
#property strict

//+------------------------------------------------------------------+
//| CLANGD & INTELLISENSE COMPATIBILITY SHIMS                        |
//+------------------------------------------------------------------+
#ifdef __clang__
#define CHRONOS_CONCAT_INNER(a, b) a##b
#define CHRONOS_CONCAT(a, b) CHRONOS_CONCAT_INNER(a, b)
#define group static const char* CHRONOS_CONCAT(__chronos_group_, __LINE__) __attribute__((unused)) =
#ifndef SYMBOL_FILLING_FOK
#define SYMBOL_FILLING_FOK          1
#endif
#ifndef SYMBOL_FILLING_IOC
#define SYMBOL_FILLING_IOC          2
#endif
#ifndef SYMBOL_EXPIRATION_SPECIFIED
#define SYMBOL_EXPIRATION_SPECIFIED 2
#endif
#ifndef POSITION_TYPE
#define POSITION_TYPE               POSITION_TYPE_BUY
#endif
#ifndef DEAL_TYPE
#define DEAL_TYPE                   DEAL_TYPE_BUY
#endif
#ifndef CP_UTF8
#define CP_UTF8                     65001
#endif
#endif

//+------------------------------------------------------------------+
//| MACROS & GLOBAL CONSTANTS                                        |
//+------------------------------------------------------------------+
#define CHRONOS_LOG_PREFIX    "Chronos v1.01 | "
#define HUD_PREFIX            "ChronosHUD_"
#define HUD_FONT              "Segoe UI"
#define HUD_FONT_BOLD         "Segoe UI Semibold"
#define HUD_FONT_MONO         "Consolas"

//--- Institutional Color Palette (Imperial Cyber Luxury & Obsidian Glass)
// Defined in standard hex (0x00BBGGRR) to ensure 100% formatter and compiler immunity
#define COLOR_HUD_BG          (color)0x0D0A08      // Deep Obsidian Void (R:8, G:10, B:13)
#define COLOR_HUD_BORDER      (color)0x3CBEE6      // Imperial Champagne Gold (R:230, G:190, B:60)
#define COLOR_CARD_BG         (color)0x18120E      // Dark Obsidian Glass Card (R:14, G:18, B:24)
#define COLOR_CARD_BORDER     (color)0x35281A      // Subtle Polished Titanium Border
#define COLOR_HEADER_BG       (color)0x24180E      // Royal Obsidian Header
#define COLOR_HEADER_ACCENT   (color)0x00D7FF      // Glowing 24K Gold Header Accent (R:255, G:215, B:0)
#define COLOR_TEXT_HEADER     (color)0xFFFFFF      // Pure Diamond White
#define COLOR_TEXT_MUTED      (color)0x9E8675      // Platinum Steel Caption (R:117, G:134, B:158)
#define COLOR_TEXT_NORMAL     (color)0xE8DED6      // Soft Cream Ivory (R:214, G:222, B:232)
#define COLOR_ACCENT_GREEN    (color)0x58D840      // Vibrant Institutional Emerald (R:64, G:216, B:88)
#define COLOR_ACCENT_RED      (color)0x454BF5      // Vivid Crimson Coral (R:245, G:75, B:69)
#define COLOR_ACCENT_ORANGE   (color)0x1498FF      // Radiant Sunset Amber (R:255, G:152, B:20)
#define COLOR_ACCENT_CYAN     (color)0xFFE600      // Electric Cyber Cyan (R:0, G:230, B:255)
#define COLOR_GOLD_BRIGHT     (color)0x00D7FF      // 24K Imperial Gold (R:255, G:215, B:0)
#define COLOR_GOLD_METALLIC   (color)0x50C8E8      // Polished Gold Leaf (R:232, G:200, B:80)
#define COLOR_ROYAL_PURPLE    (color)0xE868B0      // Cyber Amethyst Orchid (R:176, G:104, B:232)
#define COLOR_ICE_BLUE        (color)0xFFBF60      // Arctic Ice Blue (R:96, G:191, B:255)

//+------------------------------------------------------------------+
//| GLOBAL LOGGING HELPERS                                           |
//+------------------------------------------------------------------+
void ChronosLog(const string message)
{
   Print(CHRONOS_LOG_PREFIX + message);
}

void ChronosAlert(const string message)
{
   Alert(CHRONOS_LOG_PREFIX + message);
}

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum ENUM_PRESET_PROFILE
{
   PROFILE_SCALPER      = 0, // Scalper (M15, Per:24, TP:1500, SL:300, Trail:140/40, Off:-160)
   PROFILE_SWINGER      = 1, // Swinger (M15, Per:48, TP:4500, SL:2500, Trail:1500/500, Off:-50)
   PROFILE_POSITIVE_RR  = 2, // Positive RR (M30, Per:36, TP:2250, SL:325, Trail:575/165, Off:-175)
   PROFILE_PROP_SCALPER = 3, // Prop Scalper (M15, Per:24, TP:2500, SL:350, 120s Prop Rule)
   PROFILE_CUSTOM       = 4  // Custom Profile (User Configured Parameters)
};

enum ENUM_LOT_MODE
{
   LOT_MODE_FIXED = 0, // Fixed Lot Size
   LOT_MODE_RISK  = 1  // Dynamic Risk Percentage of Equity
};

//+------------------------------------------------------------------+
//| STRUCTURES                                                       |
//+------------------------------------------------------------------+
struct PresetConfig
{
   ENUM_TIMEFRAMES  timeframe;
   int              donchianPeriod;
   int              orderExpiryHours;
   double           initialTakeProfitPoints;
   double           initialStopLossPoints;
   double           trailingStartPoints;
   double           trailingDistancePoints;
   double           entryOffsetPoints;
   int              pauseSeconds;
   bool             isPropMode;
   int              propHoldSeconds;
   double           propProtectionMultiplier;
};

struct ChronosNewsEvent
{
   datetime serverTime;
   string   currency;
   string   title;
   string   source;
   int      importance;
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS (GROUPED ARCHITECTURE)                          |
//+------------------------------------------------------------------+
//--- 1. STRATEGY PRESET & PROFILE SELECTION
input group "=== 1. PRESET & PROFILE SELECTION ===";
input ENUM_PRESET_PROFILE inp_Profile                 = PROFILE_PROP_SCALPER; // Active Strategy Profile

//--- 2. CUSTOM PARAMETERS (Used when Profile = PROFILE_CUSTOM)
input group "=== 2. CUSTOM PROFILE SETTINGS ===";
input ENUM_TIMEFRAMES     inp_CustomTimeframe         = PERIOD_M15;           // Custom Timeframe
input int                 inp_CustomPeriod            = 24;                   // Custom Donchian Period (Shift 1..N)
input int                 inp_CustomExpiryHours       = 12;                   // Custom Order Expiry (Hours, 0=GTC)
input double              inp_CustomTPPoints          = 2500.0;               // Custom Take Profit (Points)
input double              inp_CustomSLPoints          = 350.0;                // Custom Stop Loss (Points)
input double              inp_CustomTrailStartPoints  = 165.0;                // Custom Trailing Start (Points)
input double              inp_CustomTrailDistPoints   = 40.0;                 // Custom Trailing Distance (Points)
input double              inp_CustomEntryOffsetPoints = -150.0;               // Custom Entry Offset (Points)
input int                 inp_CustomPauseSeconds      = 60;                   // Custom Pause After Close (Seconds)
input bool                inp_CustomIsPropMode        = true;                 // Custom Enable 120s Prop Rule
input int                 inp_CustomPropHoldSeconds   = 120;                  // Custom Prop Hold Duration (Seconds)
input double              inp_CustomPropMultiplier    = 2.0;                  // Custom Prop Protection Multiplier

//--- 3. EXECUTION & ORDER GUARDS
input group "=== 3. EXECUTION & ORDER GUARDS ===";
input ulong               inp_MagicNumber             = 20261002;               // Magic Number
input string              inp_TradeComment            = "CHRONOS";              // Trade Order/Position Comment
input double              inp_TriggerDistancePoints   = 50.0;                 // Minimum Trigger Distance Guard (Points)
input double              inp_DuplicateBandPoints     = 500.0;                // Duplicate Entry Rejection Band (Points)
input double              inp_MaxSpreadPoints         = 100.0;                // Maximum Allowed Spread (Points, 0=No Filter)
input bool                inp_UseNewBarFilter         = true;                 // Institutional New Bar Latch (One Signal Eval per Bar)
input bool                inp_StickyAlternateLock     = true;                 // Sticky Alternate Lock (One Trade per Swing)

//--- 3.1 ADVANCED BREAKOUT & EXECUTION GUARDS
input group "=== 3.1 ADVANCED BREAKOUT GUARDS ===";
input bool                inp_EnableMidlineCut        = true;                 // Early False-Breakout Cut (Exit at Midline)
input bool                inp_EnableBreakEven         = true;                 // Enable Tier-1 Break-Even Profit Lock
input double              inp_BreakEvenTriggerPoints  = 120.0;                // Break-Even Trigger Threshold (Points)
input double              inp_BreakEvenLockPoints     = 15.0;                 // Break-Even Profit Lock Distance (Points)
input double              inp_TrailingStepPoints      = 10.0;                 // Minimum Trailing Step Buffer (Points)
input bool                inp_DynamicPendingSync      = true;                 // Dynamically Sync Pending to Shifting Donchian

//--- 4. MONEY MANAGEMENT & RISK DEFENSE
input group "=== 4. MONEY MANAGEMENT & RISK DEFENSE ===";
input ENUM_LOT_MODE       inp_LotMode                 = LOT_MODE_FIXED;       // Lot Sizing Mode
input double              inp_FixedLot                = 0.10;                 // Fixed Lot Size
input double              inp_RiskPercent             = 1.0;                  // Dynamic Risk % per Trade
input double              inp_DailyTargetProfit       = 0.0;                  // Daily Target Profit ($ Currency, 0=Disabled)
input double              inp_DailyMaxLoss            = 0.0;                  // Daily Max Loss Limit ($ Currency, 0=Disabled)

//--- 5. SLIPPAGE & LATENCY DEFENSE
input group "=== 5. SLIPPAGE & LATENCY DEFENSE ===";
input double              inp_MaxAllowedSlippagePoints= 50.0;                 // Max Allowed Negative Slippage (Points)
input int                 inp_SlippageCooldownSeconds = 300;                  // Slippage Cooldown Window (Seconds)

//--- 6. DYNAMIC AUTO-GMT & TIME FILTERS
input group "=== 6. AUTO-GMT & SESSION DEFENSE ===";
input bool                inp_AutoGMT                 = true;                 // Auto-Calculate Broker GMT Offset
input int                 inp_ManualGMTOffset         = 2;                    // Manual GMT Offset (Hours, Tester/Fallback)
input int                 inp_DailyCloseHour          = -1;                   // Daily Session Pause Start (Server Hour, -1=Off)
input int                 inp_DailyReopenHour         = -1;                   // Daily Session Pause End (Server Hour, -1=Off)
input int                 inp_FridayCloseHour         = 21;                   // Friday Exit Hour (Server Hour, -1=Off)
input bool                inp_ClosePositionsOnFriday  = false;                // Close Open Positions on Friday Exit
input bool                inp_DeletePendingsOnFriday  = true;                 // Purge Pending Orders on Friday Exit

//--- 7. MULTI-SOURCE NEWS SENTINEL (USD HIGH-IMPACT)
input group "=== 7. MULTI-SOURCE NEWS SENTINEL (USD) ===";
input bool                inp_EnableNewsFilter        = true;                 // Enable Redundant News Sentinel
input int                 inp_NewsMinutesBefore       = 30;                   // Minutes Before Event to Freeze
input int                 inp_NewsMinutesAfter        = 30;                   // Minutes After Event to Unfreeze
input bool                inp_DeletePendingsOnNews    = false;                // Purge Pending Orders on News Blackout
input bool                inp_EnableForexFactory      = true;                 // Enable Forex Factory Feed (WebRequest)
input bool                inp_EnableInvestingFallback = true;                 // Enable Investing.com Fallback Feed

//--- 8. INSTITUTIONAL HUD DASHBOARD
input group "=== 8. INSTITUTIONAL HUD DASHBOARD ===";
input bool                inp_ShowPanel               = true;                 // Display Chart Glassmorphism HUD
input ENUM_BASE_CORNER    inp_PanelCorner             = CORNER_LEFT_UPPER;    // Dashboard Corner
input int                 inp_PanelX                  = 20;                   // Dashboard X Offset (Pixels)
input int                 inp_PanelY                  = 30;                   // Dashboard Y Offset (Pixels)

//+------------------------------------------------------------------+
//| BROKER FILLING MODE UTILITY                                      |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetSymbolFillingMode(const string symbol)
{
   uint filling = (uint)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) != 0)
      return ORDER_FILLING_FOK;
   if((filling & SYMBOL_FILLING_IOC) != 0)
      return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

//====================================================================
// MASTER COMPILED-IN ACCOUNTS WHITELIST (Hardcoded & Tamper-Proof)
// Only authorized MT5 accounts in this array can execute Chronos.
// Cannot be bypassed or disabled via MT5 Inputs or .set files.
//====================================================================
const long g_masterWhitelistedAccounts[] = {25341903, 55969285, 4021083, 5237138};

//+------------------------------------------------------------------+
//| CLASS: CChronosSecurity                                          |
//| Tamper-Proof Hardcoded Account Authorization Protection           |
//+------------------------------------------------------------------+
class CChronosSecurity
{
public:
   static bool IsAccountWhitelisted(const long account)
   {
      const int masterCount = ArraySize(g_masterWhitelistedAccounts);
      for(int i = 0; i < masterCount; i++)
      {
         if(g_masterWhitelistedAccounts[i] == account)
            return true;
      }
      return false;
   }

   static bool CheckAccountAuthorization(string &failReason)
   {
      // Strategy Tester bypass for historical backtesting
      if(MQLInfoInteger(MQL_TESTER))
      {
         failReason = "";
         return true;
      }

      const long currentLogin = AccountInfoInteger(ACCOUNT_LOGIN);

      // Strict Whitelist Enforcement: Account MUST exist in compiled-in whitelist
      if(IsAccountWhitelisted(currentLogin))
      {
         ChronosLog(StringFormat("Security Guard: Account #%I64d Verified and Authorized Successfully!", currentLogin));
         failReason = "";
         return true;
      }

      failReason = StringFormat("Account #%I64d is NOT authorized! Chronos execution locked.", currentLogin);
      return false;
   }
};

//+------------------------------------------------------------------+
//| CLASS: CChronosTime                                              |
//| Dynamic Auto-GMT and Broker Session Normalization Engine         |
//+------------------------------------------------------------------+
class CChronosTime
{
private:
   bool     m_autoGMT;
   int      m_manualOffsetHours;
   int      m_gmtOffsetSec;

public:
   CChronosTime() : m_autoGMT(true), m_manualOffsetHours(2), m_gmtOffsetSec(7200) {}
   ~CChronosTime() {}

   void Init(const bool autoGMT, const int manualOffsetHours)
   {
      m_autoGMT = autoGMT;
      m_manualOffsetHours = manualOffsetHours;
      Update();
      ChronosLog(StringFormat("[Time Engine] Initialized | GMT Offset: %+0.1f Hours (AutoGMT: %s)",
                 GetGMTOffsetHours(), m_autoGMT ? "Enabled" : "Manual"));
   }

   void Update()
   {
      if(MQLInfoInteger(MQL_TESTER) || !m_autoGMT)
      {
         m_gmtOffsetSec = m_manualOffsetHours * 3600;
         return;
      }

      datetime serverTime = TimeTradeServer();
      datetime gmtTime    = TimeGMT();

      if(serverTime > 0 && gmtTime > 0)
      {
         int rawDiff = (int)(serverTime - gmtTime);
         // Normalize to nearest 15-minute standard timezone increment
         int remainder = rawDiff % 900;
         if(remainder > 450)
            rawDiff += (900 - remainder);
         else if(remainder < -450)
            rawDiff -= (900 + remainder);
         else
            rawDiff -= remainder;

         m_gmtOffsetSec = rawDiff;
      }
      else
      {
         m_gmtOffsetSec = m_manualOffsetHours * 3600;
      }
   }

   int      GetGMTOffsetSec()   const { return m_gmtOffsetSec; }
   double   GetGMTOffsetHours() const { return (double)m_gmtOffsetSec / 3600.0; }
   datetime ServerToGMT(const datetime serverTime) const { return (serverTime - m_gmtOffsetSec); }
   datetime GMTToServer(const datetime gmtTime)    const { return (gmtTime + m_gmtOffsetSec); }

   bool IsTradingSessionAllowed(const int dailyCloseH, const int dailyReopenH, const int fridayCloseH) const
   {
      datetime serverNow = TimeTradeServer();
      MqlDateTime dt;
      TimeToStruct(serverNow, dt);

      // 1. Friday weekend close protection
      if(fridayCloseH >= 0 && dt.day_of_week == 5)
      {
         if(dt.hour >= fridayCloseH)
            return false;
      }

      // 2. Weekend blackout
      if(dt.day_of_week == 6)
         return false; // Saturday
      if(dt.day_of_week == 0 && dt.hour < 22)
         return false; // Sunday before market open

      // 3. Daily rollover close/pause filter
      if(dailyCloseH >= 0 && dailyReopenH >= 0)
      {
         if(dailyCloseH < dailyReopenH)
         {
            if(dt.hour >= dailyCloseH && dt.hour < dailyReopenH)
               return false;
         }
         else if(dailyCloseH > dailyReopenH)
         {
            // Crosses midnight rollover window (e.g. 23:00 to 01:00)
            if(dt.hour >= dailyCloseH || dt.hour < dailyReopenH)
               return false;
         }
      }

      return true;
   }
};

//+------------------------------------------------------------------+
//| CLASS: CChronosNews                                              |
//| Multi-Source Redundant USD High-Impact News Sentinel             |
//+------------------------------------------------------------------+
class CChronosNews
{
private:
   CChronosTime*     m_time;
   bool              m_enabled;
   int               m_minsBefore;
   int               m_minsAfter;
   bool              m_deletePendings;
   bool              m_enableFF;
   bool              m_enableInvesting;

   int               m_eventCount;
   datetime          m_lastWebFetch;

   bool              m_statusNative;
   bool              m_statusFF;
   bool              m_statusInvesting;

   string            m_nextEventTitle;
   int               m_nextEventCountdown;
   bool              m_inBlackout;

   ChronosNewsEvent  m_events[]; // Placed at end of private fields for C++ compatibility

   void AddEvent(const datetime serverTime, const string currency, const string title, const string source, const int importance)
   {
      // Check duplicate within 15 minutes with similar title
      for(int i = 0; i < m_eventCount; i++)
      {
         if(m_events[i].currency == currency &&
            MathAbs((int)(m_events[i].serverTime - serverTime)) < 900)
         {
            // Already cached from earlier feed
            return;
         }
      }

      int newSize = m_eventCount + 1;
      ArrayResize(m_events, newSize);
      m_events[m_eventCount].serverTime = serverTime;
      m_events[m_eventCount].currency   = currency;
      m_events[m_eventCount].title      = title;
      m_events[m_eventCount].source     = source;
      m_events[m_eventCount].importance = importance;
      m_eventCount = newSize;
   }

public:
   CChronosNews() : m_time(NULL), m_enabled(true), m_minsBefore(30), m_minsAfter(30),
                    m_deletePendings(false), m_enableFF(true), m_enableInvesting(true),
                    m_eventCount(0), m_lastWebFetch(0), m_statusNative(false),
                    m_statusFF(false), m_statusInvesting(false), m_nextEventTitle("None"),
                    m_nextEventCountdown(-1), m_inBlackout(false)
   {
      ArrayResize(m_events, 0);
   }

   ~CChronosNews()
   {
      ArrayFree(m_events);
   }

   void Init(CChronosTime* timeEngine, const bool enabled, const int minsBefore, const int minsAfter,
             const bool deletePendings, const bool enableFF, const bool enableInvesting)
   {
      m_time            = timeEngine;
      m_enabled         = enabled;
      m_minsBefore      = minsBefore;
      m_minsAfter       = minsAfter;
      m_deletePendings  = deletePendings;
      m_enableFF        = enableFF;
      m_enableInvesting = enableInvesting;

      if(!m_enabled)
      {
         ChronosLog("[News Sentinel] Multi-Source News Engine Disabled by User.");
         return;
      }

      RefreshNativeCalendar();
      ChronosLog(StringFormat("[News Sentinel] Initialized | Native MT5: %s | Events Cached: %d",
                 m_statusNative ? "ONLINE" : "STANDBY", m_eventCount));
   }

   void RefreshNativeCalendar()
   {
      if(!m_enabled || m_time == NULL)
         return;

      datetime gmtNow = m_time.ServerToGMT(TimeTradeServer());
      datetime dateFrom = gmtNow - 86400;       // Past 24h
      datetime dateTo   = gmtNow + 7 * 86400;   // Forward 7 days

      MqlCalendarValue values[];
      ResetLastError();
      int count = CalendarValueHistory(values, dateFrom, dateTo, NULL, "USD");
      if(count > 0)
      {
         m_statusNative = true;
         for(int i = 0; i < count; i++)
         {
            MqlCalendarEvent event;
            if(CalendarEventById(values[i].event_id, event))
            {
               if(event.importance == CALENDAR_IMPORTANCE_HIGH)
               {
                  datetime srvTime = m_time.GMTToServer(values[i].time);
                  AddEvent(srvTime, "USD", event.name, "MT5 Native", 3);
               }
            }
         }
      }
      else
      {
         m_statusNative = false;
      }
   }

   void FetchForexFactory()
   {
      if(!m_enabled || !m_enableFF || m_time == NULL)
         return;

      string url = "https://nfs.faireconomy.media/ff_calendar_thisweek.json";
      char postData[];
      char resultData[];
      string resultHeaders;

      ResetLastError();
      int httpCode = WebRequest("GET", url, "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)\r\n", 5000, postData, resultData, resultHeaders);
      if(httpCode == 200 && ArraySize(resultData) > 0)
      {
         m_statusFF = true;
         string json = CharArrayToString(resultData, 0, WHOLE_ARRAY, CP_UTF8);
         ParseForexFactoryJSON(json);
         ChronosLog(StringFormat("[News Sentinel] Forex Factory CDN Synchronized (%d events in memory)", m_eventCount));
      }
      else
      {
         m_statusFF = false;
         int err = GetLastError();
         if(err == 4060)
         {
            ChronosLog("[News Sentinel] WebRequest URL not whitelisted in MT5 options. Falling back smoothly to MT5 Native Calendar.");
         }
      }
   }

   void ParseForexFactoryJSON(const string &json)
   {
      int pos = 0;
      int len = StringLen(json);

      while(pos < len)
      {
         int objStart = StringFind(json, "{\"title\":", pos);
         if(objStart < 0)
            break;

         int objEnd = StringFind(json, "}", objStart);
         if(objEnd < 0)
            break;

         string item = StringSubstr(json, objStart, objEnd - objStart + 1);
         pos = objEnd + 1;

         // Filter strictly USD and High Impact
         if(StringFind(item, "\"country\":\"USD\"") >= 0 && StringFind(item, "\"impact\":\"High\"") >= 0)
         {
            string title = ExtractJSONField(item, "title");
            string dateStr = ExtractJSONField(item, "date");

            if(StringLen(dateStr) >= 19)
            {
               // Format: 2026-10-02T08:30:00-04:00
               MqlDateTime mdt;
               mdt.year = (int)StringToInteger(StringSubstr(dateStr, 0, 4));
               mdt.mon  = (int)StringToInteger(StringSubstr(dateStr, 5, 2));
               mdt.day  = (int)StringToInteger(StringSubstr(dateStr, 8, 2));
               mdt.hour = (int)StringToInteger(StringSubstr(dateStr, 11, 2));
               mdt.min  = (int)StringToInteger(StringSubstr(dateStr, 14, 2));
               mdt.sec  = (int)StringToInteger(StringSubstr(dateStr, 17, 2));

               datetime localTime = StructToTime(mdt);
               datetime gmtTime = localTime;

               // Parse timezone offset
               if(StringLen(dateStr) >= 25)
               {
                  string sign = StringSubstr(dateStr, 19, 1);
                  int offH    = (int)StringToInteger(StringSubstr(dateStr, 20, 2));
                  int offM    = (int)StringToInteger(StringSubstr(dateStr, 23, 2));
                  int totalOff = offH * 3600 + offM * 60;
                  if(sign == "-")
                     gmtTime = localTime + totalOff;
                  else if(sign == "+")
                     gmtTime = localTime - totalOff;
               }

               datetime srvTime = m_time.GMTToServer(gmtTime);
               AddEvent(srvTime, "USD", title, "ForexFactory", 3);
            }
         }
      }
   }

   string ExtractJSONField(const string &src, const string key)
   {
      string search = "\"" + key + "\":\"";
      int start = StringFind(src, search);
      if(start < 0)
         return "";
      start += StringLen(search);
      int end = StringFind(src, "\"", start);
      if(end < 0)
         return "";
      return StringSubstr(src, start, end - start);
   }

   void FetchInvestingFallback()
   {
      if(!m_enabled || !m_enableInvesting || m_time == NULL)
         return;

      // Fail-open backup feed ping
      string url = "https://ec.forexprostools.com/?columns=exc_flags,exc_currency,exc_importance&importance=3&currencies=USD";
      char postData[];
      char resultData[];
      string resultHeaders;

      ResetLastError();
      int httpCode = WebRequest("GET", url, "User-Agent: Mozilla/5.0\r\n", 5000, postData, resultData, resultHeaders);
      if(httpCode == 200 && ArraySize(resultData) > 0)
      {
         m_statusInvesting = true;
      }
      else
      {
         m_statusInvesting = false;
      }
   }

   void HourlyWorker()
   {
      if(!m_enabled)
         return;

      datetime now = TimeCurrent();
      if(m_lastWebFetch == 0 || (now - m_lastWebFetch) >= 3600)
      {
         m_lastWebFetch = now;
         RefreshNativeCalendar();
         if(m_enableFF)
            FetchForexFactory();
         if(m_enableInvesting)
            FetchInvestingFallback();
      }
   }

   void EvaluateNewsMatrix()
   {
      if(!m_enabled || m_time == NULL)
      {
         m_inBlackout = false;
         m_nextEventTitle = "Disabled";
         m_nextEventCountdown = -1;
         return;
      }

      datetime srvNow = TimeTradeServer();
      m_inBlackout = false;
      m_nextEventTitle = "No USD High Impact (24h)";
      m_nextEventCountdown = -1;
      int nearestFutureSec = 86400 * 30;

      for(int i = 0; i < m_eventCount; i++)
      {
         datetime evTime = m_events[i].serverTime;
         datetime windowStart = evTime - m_minsBefore * 60;
         datetime windowEnd   = evTime + m_minsAfter * 60;

         // Check if current server time is inside active blackout window
         if(srvNow >= windowStart && srvNow <= windowEnd)
         {
            m_inBlackout = true;
            m_nextEventTitle = m_events[i].title;
            m_nextEventCountdown = (int)(evTime - srvNow);
            return;
         }

         // Track nearest upcoming event
         if(evTime > srvNow)
         {
            int diff = (int)(evTime - srvNow);
            if(diff < nearestFutureSec)
            {
               nearestFutureSec = diff;
               m_nextEventTitle = m_events[i].title;
               m_nextEventCountdown = diff;
            }
         }
      }
   }

   bool   IsBlackout()                 const { return m_inBlackout; }
   bool   GetDeletePendingsOnNews()    const { return m_deletePendings; }
   bool   GetStatusNative()            const { return m_statusNative; }
   bool   GetStatusFF()                const { return m_statusFF; }
   bool   GetStatusInvesting()         const { return m_statusInvesting; }
   string GetNextEventTitle()          const { return m_nextEventTitle; }
   int    GetNextEventCountdown()      const { return m_nextEventCountdown; }
};

//+------------------------------------------------------------------+
//| CLASS: CChronosSignal                                            |
//| Zero-Lag Non-Repainting Donchian Channel Mathematical Engine     |
//+------------------------------------------------------------------+
class CChronosSignal
{
private:
   datetime          m_lastBarTime;
   double            m_cachedHigh;
   double            m_cachedLow;
   double            m_cachedMid;
   int               m_lastPeriod;
   ENUM_TIMEFRAMES   m_lastTF;
   string            m_lastSymbol;
   double            m_highBuffer[];
   double            m_lowBuffer[];

public:
   CChronosSignal() : m_lastBarTime(0), m_cachedHigh(0.0), m_cachedLow(0.0), m_cachedMid(0.0),
                      m_lastPeriod(0), m_lastTF(PERIOD_CURRENT), m_lastSymbol("")
   {
      ArraySetAsSeries(m_highBuffer, true);
      ArraySetAsSeries(m_lowBuffer, true);
   }
   ~CChronosSignal() {}

   bool Calculate(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period,
                  double &outHigh, double &outLow, double &outMid)
   {
      if(period <= 0)
         return false;

      datetime currentBarTime = iTime(symbol, timeframe, 0);

      // High-Frequency Fast-Path: If still on the same bar, return cached levels with 0 CPU overhead!
      if(currentBarTime != 0 && currentBarTime == m_lastBarTime &&
         period == m_lastPeriod && timeframe == m_lastTF && symbol == m_lastSymbol)
      {
         outHigh = m_cachedHigh;
         outLow  = m_cachedLow;
         outMid  = m_cachedMid;
         return (outHigh > outLow);
      }

      // Strictly Shift 1 to Shift N, strictly EXCLUDING forming bar Shift 0 to guarantee zero-repainting!
      int copiedH = CopyHigh(symbol, timeframe, 1, period, m_highBuffer);
      int copiedL = CopyLow(symbol, timeframe, 1, period, m_lowBuffer);

      if(copiedH < period || copiedL < period)
         return false;

      int maxIdx = ArrayMaximum(m_highBuffer, 0, period);
      int minIdx = ArrayMinimum(m_lowBuffer, 0, period);

      if(maxIdx < 0 || minIdx < 0)
         return false;

      outHigh = m_highBuffer[maxIdx];
      outLow  = m_lowBuffer[minIdx];
      outMid  = (outHigh + outLow) / 2.0;

      // Update state cache
      m_lastBarTime = currentBarTime;
      m_lastPeriod  = period;
      m_lastTF      = timeframe;
      m_lastSymbol  = symbol;
      m_cachedHigh  = outHigh;
      m_cachedLow   = outLow;
      m_cachedMid   = outMid;

      return (outHigh > outLow);
   }
};

//+------------------------------------------------------------------+
//| CLASS: CChronosTrade                                             |
//| Order Execution, Latency Defense & Trailing/Prop Rules Engine    |
//+------------------------------------------------------------------+
class CChronosTrade
{
private:
   ulong             m_magic;
   string            m_comment;
   double            m_maxSlippagePoints;
   int               m_slippageCooldownSeconds;
   double            m_duplicateBandPoints;
   datetime          m_slippageCooldownExpiry;

   bool              m_buyExposureLatch;
   bool              m_sellExposureLatch;
   datetime          m_buyPauseUntil;
   datetime          m_sellPauseUntil;

   int               m_cachedOpenBuys;
   int               m_cachedOpenSells;
   int               m_cachedPendingBuyStops;
   int               m_cachedPendingSellStops;
   double            m_cachedBuyLots;
   double            m_cachedSellLots;
   ulong             m_propNormalizedTickets[];

public:
   CChronosTrade() : m_magic(102030), m_comment("CHRONOS"), m_maxSlippagePoints(50.0), m_slippageCooldownSeconds(300),
                     m_duplicateBandPoints(500.0), m_slippageCooldownExpiry(0),
                     m_buyExposureLatch(false), m_sellExposureLatch(false),
                     m_buyPauseUntil(0), m_sellPauseUntil(0),
                     m_cachedOpenBuys(0), m_cachedOpenSells(0),
                     m_cachedPendingBuyStops(0), m_cachedPendingSellStops(0),
                     m_cachedBuyLots(0.0), m_cachedSellLots(0.0) {}

   ~CChronosTrade()
   {
      ArrayFree(m_propNormalizedTickets);
   }

   bool IsPropNormalized(const ulong ticket)
   {
      int count = ArraySize(m_propNormalizedTickets);
      for(int i = 0; i < count; i++)
      {
         if(m_propNormalizedTickets[i] == ticket)
            return true;
      }
      return false;
   }

   void MarkPropNormalized(const ulong ticket)
   {
      if(IsPropNormalized(ticket))
         return;
      int size = ArraySize(m_propNormalizedTickets);
      ArrayResize(m_propNormalizedTickets, size + 1);
      m_propNormalizedTickets[size] = ticket;
   }

   void CleanPropNormalizedRegistry()
   {
      int count = ArraySize(m_propNormalizedTickets);
      if(count == 0)
         return;

      for(int i = count - 1; i >= 0; i--)
      {
         ulong ticket = m_propNormalizedTickets[i];
         if(!PositionSelectByTicket(ticket))
         {
            // OPT-3: O(1) swap-with-last delete instead of O(n) shift-down
            if(i < count - 1)
               m_propNormalizedTickets[i] = m_propNormalizedTickets[count - 1];
            count--;
         }
      }

      ArrayResize(m_propNormalizedTickets, count);
   }

   void Init(const ulong magic, const string comment, const double maxSlippagePts, const int slippageCooldownSec, const double duplicateBandPts)
   {
      m_magic                   = magic;
      m_comment                 = (comment != "" ? comment : "CHRONOS");
      m_maxSlippagePoints       = maxSlippagePts;
      m_slippageCooldownSeconds = slippageCooldownSec;
      m_duplicateBandPoints     = duplicateBandPts;
      m_slippageCooldownExpiry  = 0;
      m_buyExposureLatch        = false;
      m_sellExposureLatch       = false;
      m_buyPauseUntil           = 0;
      m_sellPauseUntil          = 0;
      ArrayResize(m_propNormalizedTickets, 0);
   }

   void ResetBuyLatch()
   {
      m_buyExposureLatch = false;
      m_buyPauseUntil    = 0;
   }

   void ResetSellLatch()
   {
      m_sellExposureLatch = false;
      m_sellPauseUntil    = 0;
   }

   void SnapshotExposure(const int pauseSeconds, const bool stickyAlternateMode = false)
   {
      int buys = 0, sells = 0;
      int buyStops = 0, sellStops = 0;
      double buyLots = 0.0, sellLots = 0.0;

      // Check open positions
      int totalPos = PositionsTotal();
      for(int i = 0; i < totalPos; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == m_magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            ENUM_POSITION_TYPE pType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if(pType == POSITION_TYPE_BUY)
            {
               buys++;
               buyLots += PositionGetDouble(POSITION_VOLUME);
               m_buyExposureLatch = true; // An actual BUY position was opened
            }
            else if(pType == POSITION_TYPE_SELL)
            {
               sells++;
               sellLots += PositionGetDouble(POSITION_VOLUME);
               m_sellExposureLatch = true; // An actual SELL position was opened
            }
         }
      }

      // Check pending orders
      int totalOrders = OrdersTotal();
      for(int i = 0; i < totalOrders; i++)
      {
         ulong orderTicket = OrderGetTicket(i);
         if(orderTicket > 0 && OrderGetInteger(ORDER_MAGIC) == m_magic && OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            ENUM_ORDER_TYPE oType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(oType == ORDER_TYPE_BUY_STOP)
               buyStops++;
            else if(oType == ORDER_TYPE_SELL_STOP)
               sellStops++;
         }
      }

      m_cachedOpenBuys         = buys;
      m_cachedOpenSells        = sells;
      m_cachedPendingBuyStops  = buyStops;
      m_cachedPendingSellStops = sellStops;
      m_cachedBuyLots          = buyLots;
      m_cachedSellLots         = sellLots;

      CleanPropNormalizedRegistry();

      datetime now = TimeCurrent();

      // Update sticky latches
      if(buys == 0 && buyStops == 0)
      {
         if(!stickyAlternateMode)
         {
            if(m_buyExposureLatch)
            {
               m_buyPauseUntil = now + pauseSeconds;
               m_buyExposureLatch = false;
            }
         }
         else
         {
            // Aegis Sticky Alternate Mode:
            // Latch remains locked even after position closes!
            // Only opposite channel crossing will reset it via ResetBuyLatch().
            if(m_buyExposureLatch && m_buyPauseUntil == 0)
            {
               m_buyPauseUntil = now + pauseSeconds;
            }
         }
      }
      else
      {
         m_buyPauseUntil = 0;
      }

      if(sells == 0 && sellStops == 0)
      {
         if(!stickyAlternateMode)
         {
            if(m_sellExposureLatch)
            {
               m_sellPauseUntil = now + pauseSeconds;
               m_sellExposureLatch = false;
            }
         }
         else
         {
            if(m_sellExposureLatch && m_sellPauseUntil == 0)
            {
               m_sellPauseUntil = now + pauseSeconds;
            }
         }
      }
      else
      {
         m_sellPauseUntil = 0;
      }
   }

   bool IsBuyLocked() const
   {
      return (m_buyExposureLatch || (TimeCurrent() < m_buyPauseUntil) || (m_cachedOpenBuys > 0) || (m_cachedPendingBuyStops > 0));
   }

   bool IsSellLocked() const
   {
      return (m_sellExposureLatch || (TimeCurrent() < m_sellPauseUntil) || (m_cachedOpenSells > 0) || (m_cachedPendingSellStops > 0));
   }

   bool CanPlaceOrSyncBuy() const
   {
      return (!m_buyExposureLatch && (TimeCurrent() >= m_buyPauseUntil) && (m_cachedOpenBuys == 0));
   }

   bool CanPlaceOrSyncSell() const
   {
      return (!m_sellExposureLatch && (TimeCurrent() >= m_sellPauseUntil) && (m_cachedOpenSells == 0));
   }

   bool IsSlippageCoolingDown(int &outRemainingSec) const
   {
      datetime now = TimeCurrent();
      if(now < m_slippageCooldownExpiry)
      {
         outRemainingSec = (int)(m_slippageCooldownExpiry - now);
         return true;
      }
      outRemainingSec = 0;
      return false;
   }

   bool IsDuplicateEntryPrice(const double targetPrice)
   {
      double band = m_duplicateBandPoints * _Point;

      // Check open positions
      int totalPos = PositionsTotal();
      for(int i = 0; i < totalPos; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == m_magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            double posOpen = PositionGetDouble(POSITION_PRICE_OPEN);
            if(MathAbs(posOpen - targetPrice) < band)
               return true;
         }
      }

      // Check pending orders
      int totalOrders = OrdersTotal();
      for(int i = 0; i < totalOrders; i++)
      {
         ulong orderTicket = OrderGetTicket(i);
         if(orderTicket > 0 && OrderGetInteger(ORDER_MAGIC) == m_magic && OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            double orderOpen = OrderGetDouble(ORDER_PRICE_OPEN);
            if(MathAbs(orderOpen - targetPrice) < band)
               return true;
         }
      }

      return false;
   }

   double CalculateLotSize(const double slPoints, const ENUM_LOT_MODE lotMode, const double fixedLot, const double riskPct)
   {
      double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

      if(stepLot <= 0.0) stepLot = 0.01;
      if(minLot  <= 0.0) minLot  = 0.01;
      if(maxLot  <= 0.0) maxLot  = 100.0;

      if(lotMode == LOT_MODE_FIXED)
      {
         double lots = MathFloor(fixedLot / stepLot) * stepLot;
         return MathMax(minLot, MathMin(maxLot, lots));
      }

      // Dynamic Risk Calculation
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskMoney = equity * (riskPct / 100.0);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

      if(tickSize <= 0.0)
         tickSize = _Point;
      double moneyPerPointPerLot = tickValue * (_Point / tickSize);

      if(moneyPerPointPerLot <= 0.0 || slPoints <= 0.0)
      {
         return MathMax(minLot, MathMin(maxLot, fixedLot));
      }

      double rawLots = riskMoney / (moneyPerPointPerLot * slPoints);
      double lots = MathFloor(rawLots / stepLot) * stepLot;
      return MathMax(minLot, MathMin(maxLot, lots));
   }

   bool SendPendingOrder(const ENUM_ORDER_TYPE orderType, const double price, const double sl, const double tp,
                         const double lots, const int expiryHours)
   {
      if(lots <= 0.0)
         return false;

      // Pre-flight margin validation to eliminate Error 10019 rejections
      double marginRequired = 0.0;
      if(OrderCalcMargin(orderType, _Symbol, lots, price, marginRequired))
      {
         if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < marginRequired)
         {
            ChronosLog("[Order Blocked] Insufficient free margin for pending order");
            return false;
         }
      }

      MqlTradeRequest request;
      MqlTradeResult  result;
      ZeroMemory(request);
      ZeroMemory(result);

      request.action       = TRADE_ACTION_PENDING;
      request.symbol       = _Symbol;
      request.volume       = lots;
      request.type         = orderType;
      request.price        = price;
      request.sl           = sl;
      request.tp           = tp;
      request.deviation    = 10;
      request.magic        = m_magic;
      request.comment      = m_comment;
      request.type_filling = ORDER_FILLING_RETURN;

      uint expModes = (uint)SymbolInfoInteger(_Symbol, SYMBOL_EXPIRATION_MODE);
      if(expiryHours > 0 && (expModes & SYMBOL_EXPIRATION_SPECIFIED) != 0)
      {
         request.type_time  = ORDER_TIME_SPECIFIED;
         request.expiration = TimeTradeServer() + expiryHours * 3600;
      }
      else
      {
         request.type_time  = ORDER_TIME_GTC;
      }

      ResetLastError();
      bool res = OrderSend(request, result);
      if(res && (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED))
      {
         ChronosLog(StringFormat("[Order Placed] %s #%I64u at %.5f (SL: %.5f, TP: %.5f, Lots: %.2f)",
                    (orderType == ORDER_TYPE_BUY_STOP ? "BUY_STOP" : "SELL_STOP"),
                    result.order, price, sl, tp, lots));
         return true;
      }
      else
      {
         ChronosLog(StringFormat("[Order Error] Failed to place %s. Retcode: %u, Err: %d",
                    (orderType == ORDER_TYPE_BUY_STOP ? "BUY_STOP" : "SELL_STOP"),
                    result.retcode, GetLastError()));
         return false;
      }
   }

   bool ModifyPendingOrder(const ulong ticket, const double price, const double sl, const double tp, const int expiryHours)
   {
      MqlTradeRequest request;
      MqlTradeResult  result;
      ZeroMemory(request);
      ZeroMemory(result);

      request.action       = TRADE_ACTION_MODIFY;
      request.order        = ticket;
      request.symbol       = _Symbol;
      request.price        = price;
      request.sl           = sl;
      request.tp           = tp;
      request.magic        = m_magic;
      request.type_filling = ORDER_FILLING_RETURN;

      uint expModes = (uint)SymbolInfoInteger(_Symbol, SYMBOL_EXPIRATION_MODE);
      if(expiryHours > 0 && (expModes & SYMBOL_EXPIRATION_SPECIFIED) != 0)
      {
         request.type_time  = ORDER_TIME_SPECIFIED;
         request.expiration = TimeTradeServer() + expiryHours * 3600;
      }
      else
      {
         request.type_time  = ORDER_TIME_GTC;
      }

      ResetLastError();
      bool res = OrderSend(request, result);
      if(res && (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED))
      {
         ChronosLog(StringFormat("[Pending Synced] Order #%I64u updated to price: %.5f (SL: %.5f, TP: %.5f)", ticket, price, sl, tp));
         return true;
      }
      else
      {
         if(result.retcode != 10025 && result.retcode != 10009)
         {
            ChronosLog(StringFormat("[Pending Sync Note] Order #%I64u modify retcode: %u, Err: %d", ticket, result.retcode, GetLastError()));
         }
         return false;
      }
   }

   bool SyncOrSendPending(const ENUM_ORDER_TYPE orderType, const double price, const double sl, const double tp,
                          const double lots, const int expiryHours, const double triggerDist, const bool allowSync)
   {
      int total = OrdersTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == m_magic && OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            ENUM_ORDER_TYPE oType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(oType == orderType)
            {
               if(!allowSync)
                  return true;

               double curPrice = OrderGetDouble(ORDER_PRICE_OPEN);
               double curSL    = OrderGetDouble(ORDER_SL);
               double curTP    = OrderGetDouble(ORDER_TP);

               if(MathAbs(curPrice - price) >= _Point || MathAbs(curSL - sl) >= _Point || MathAbs(curTP - tp) >= _Point)
               {
                  return ModifyPendingOrder(ticket, price, sl, tp, expiryHours);
               }
               return true;
            }
         }
      }

      if(IsDuplicateEntryPrice(price))
         return false;

      return SendPendingOrder(orderType, price, sl, tp, lots, expiryHours);
   }

   void ClosePositionMarket(const ulong ticket, const string comment)
   {
      if(!PositionSelectByTicket(ticket))
         return;

      ENUM_POSITION_TYPE pType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double volume = PositionGetDouble(POSITION_VOLUME);

      MqlTradeRequest request;
      MqlTradeResult  result;
      ZeroMemory(request);
      ZeroMemory(result);

      request.action       = TRADE_ACTION_DEAL;
      request.position     = ticket;
      request.symbol       = _Symbol;
      request.volume       = volume;
      request.deviation    = 100; // Fast emergency liquidation deviation
      request.magic        = m_magic;
      request.comment      = comment;
      request.type_filling = GetSymbolFillingMode(_Symbol);

      if(pType == POSITION_TYPE_BUY)
      {
         request.type  = ORDER_TYPE_SELL;
         request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      }
      else
      {
         request.type  = ORDER_TYPE_BUY;
         request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      }

      ResetLastError();
      if(OrderSend(request, result))
      {
         ChronosLog(StringFormat("[Position Closed] Ticket #%I64u liquidated successfully. Retcode: %u", ticket, result.retcode));
      }
      else
      {
         ChronosLog(StringFormat("[Position Close Error] Ticket #%I64u liquidation failed. Err: %d", ticket, GetLastError()));
      }
   }

   void PurgePendingOrders(const bool onlyStale, const int maxAgeHours, const ENUM_ORDER_TYPE orderTypeFilter = WRONG_VALUE)
   {
      datetime srvNow = TimeTradeServer();
      int total = OrdersTotal();
      for(int i = total - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == m_magic && OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            ENUM_ORDER_TYPE oType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(orderTypeFilter != WRONG_VALUE && oType != orderTypeFilter)
               continue;

            bool deleteThis = false;
            if(!onlyStale)
            {
               deleteThis = true;
            }
            else if(maxAgeHours > 0)
            {
               datetime setupTime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
               if(setupTime > 0 && (srvNow - setupTime) >= maxAgeHours * 3600)
                  deleteThis = true;
            }

            if(deleteThis)
            {
               MqlTradeRequest req;
               MqlTradeResult  res;
               ZeroMemory(req);
               ZeroMemory(res);
               req.action = TRADE_ACTION_REMOVE;
               req.order  = ticket;
               ResetLastError();
               if(OrderSend(req, res))
               {
                  ChronosLog(StringFormat("[Pending Purged] %s order #%I64u removed.",
                             (oType == ORDER_TYPE_BUY_STOP ? "Buy Stop" : "Sell Stop"), ticket));
               }
            }
         }
      }
   }

   void Manage120sPropRule(const PresetConfig &profile)
   {
      if(!profile.isPropMode || profile.propHoldSeconds <= 0)
         return;

      int totalPos = PositionsTotal();
      if(totalPos == 0)
         return;  // OPT-5: Skip when no positions open

      datetime now = TimeCurrent();
      double stopLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

      for(int i = 0; i < totalPos; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == m_magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            // If already normalized, NEVER touch this position again
            if(IsPropNormalized(ticket))
               continue;

            datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
            int holdElapsed = (int)(now - posTime);

            if(holdElapsed >= profile.propHoldSeconds)
            {
               double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               double curSL     = PositionGetDouble(POSITION_SL);
               double curTP     = PositionGetDouble(POSITION_TP);
               ENUM_POSITION_TYPE pType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

               double normalSL = 0.0;
               double normalTP = 0.0;

               if(pType == POSITION_TYPE_BUY)
               {
                  normalSL = NormalizeDouble(openPrice - profile.initialStopLossPoints * _Point, _Digits);
                  normalTP = NormalizeDouble(openPrice + profile.initialTakeProfitPoints * _Point, _Digits);

                  // STRICT ANTI-REGRESSION: Never move stop backwards into loss if trailing already moved it higher!
                  if(curSL > normalSL)
                     normalSL = curSL;
               }
               else
               {
                  normalSL = NormalizeDouble(openPrice + profile.initialStopLossPoints * _Point, _Digits);
                  normalTP = NormalizeDouble(openPrice - profile.initialTakeProfitPoints * _Point, _Digits);

                  // STRICT ANTI-REGRESSION: Never move stop backwards into loss if trailing already moved it lower!
                  if(curSL > 0.0 && (normalSL <= 0.0 || curSL < normalSL))
                     normalSL = curSL;
               }

               // If SL and TP are already at target or better, mark normalized and proceed
               if(MathAbs(curSL - normalSL) < _Point * 0.1 && MathAbs(curTP - normalTP) < _Point * 0.1)
               {
                  MarkPropNormalized(ticket);
                  continue;
               }

               // Verify broker StopsLevel geometry
               bool geometryValid = true;
               if(pType == POSITION_TYPE_BUY)
               {
                  double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  if(normalSL > 0.0 && (bid - normalSL) < stopLevel)
                     geometryValid = false;
               }
               else
               {
                  double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  if(normalSL > 0.0 && (normalSL - ask) < stopLevel)
                     geometryValid = false;
               }

               if(geometryValid && ModifySLTP(ticket, normalSL, normalTP))
               {
                  MarkPropNormalized(ticket);
                  ChronosLog(StringFormat("[Prop Engine] 120s Hold Period Concluded for #%I64u. Normalized to SL: %.5f, TP: %.5f. Trailing armed.",
                             ticket, normalSL, normalTP));
               }
            }
         }
      }
   }

   void ManageMidlineCut(const double channelMid)
   {
      if(channelMid <= 0.0)
         return;

      int totalPos = PositionsTotal();
      for(int i = totalPos - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == m_magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            ENUM_POSITION_TYPE pType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if(pType == POSITION_TYPE_BUY)
            {
               double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               if(bid < channelMid)
               {
                  ChronosLog(StringFormat("[Midline Cut] BUY #%I64u invalidated (Bid: %.5f < Mid: %.5f). Early cut executed.", ticket, bid, channelMid));
                  ClosePositionMarket(ticket, "Midline Cut");
               }
            }
            else if(pType == POSITION_TYPE_SELL)
            {
               double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               if(ask > channelMid)
               {
                  ChronosLog(StringFormat("[Midline Cut] SELL #%I64u invalidated (Ask: %.5f > Mid: %.5f). Early cut executed.", ticket, ask, channelMid));
                  ClosePositionMarket(ticket, "Midline Cut");
               }
            }
         }
      }
   }

   void ManageBreakEven(const double triggerPoints, const double lockPoints)
   {
      if(triggerPoints <= 0.0)
         return;

      int totalPos = PositionsTotal();
      if(totalPos == 0)
         return;

      double stopLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

      for(int i = 0; i < totalPos; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == m_magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            ENUM_POSITION_TYPE pType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double curSL     = PositionGetDouble(POSITION_SL);
            double curTP     = PositionGetDouble(POSITION_TP);

            if(pType == POSITION_TYPE_BUY)
            {
               double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               double profitPts = (bid - openPrice) / _Point;

               if(profitPts >= triggerPoints)
               {
                  double desiredSL = NormalizeDouble(openPrice + lockPoints * _Point, _Digits);
                  if((bid - desiredSL) >= stopLevel)
                  {
                     if(curSL == 0.0 || (desiredSL > curSL + _Point))
                     {
                        if(ModifySLTP(ticket, desiredSL, curTP))
                        {
                           ChronosLog(StringFormat("[Break-Even] BUY #%I64u secured to +%.1f pts (SL: %.5f)", ticket, lockPoints, desiredSL));
                        }
                     }
                  }
               }
            }
            else if(pType == POSITION_TYPE_SELL)
            {
               double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               double profitPts = (openPrice - ask) / _Point;

               if(profitPts >= triggerPoints)
               {
                  double desiredSL = NormalizeDouble(openPrice - lockPoints * _Point, _Digits);
                  if((desiredSL - ask) >= stopLevel)
                  {
                     if(curSL == 0.0 || (desiredSL < curSL - _Point))
                     {
                        if(ModifySLTP(ticket, desiredSL, curTP))
                        {
                           ChronosLog(StringFormat("[Break-Even] SELL #%I64u secured to +%.1f pts (SL: %.5f)", ticket, lockPoints, desiredSL));
                        }
                     }
                  }
               }
            }
         }
      }
   }

   void ManageTrailingStop(const PresetConfig &profile, const double trailStepPoints = 10.0)
   {
      if(profile.trailingStartPoints <= 0 || profile.trailingDistancePoints <= 0)
         return;

      int totalPos = PositionsTotal();
      if(totalPos == 0)
         return;

      datetime now = TimeCurrent();
      double stopLevel  = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      double stepBuffer = MathMax(trailStepPoints * _Point, stopLevel);

      for(int i = 0; i < totalPos; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == m_magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            // Prop mode hold rule: Do NOT trail during the 120s initial protection window!
            if(profile.isPropMode && profile.propHoldSeconds > 0)
            {
               datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
               if((now - posTime) < profile.propHoldSeconds)
                  continue; // Hold wide protection
            }

            ENUM_POSITION_TYPE pType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double curSL     = PositionGetDouble(POSITION_SL);
            double curTP     = PositionGetDouble(POSITION_TP);

            if(pType == POSITION_TYPE_BUY)
            {
               double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               double profitPts = (bid - openPrice) / _Point;

               if(profitPts >= profile.trailingStartPoints)
               {
                  double desiredSL = NormalizeDouble(bid - profile.trailingDistancePoints * _Point, _Digits);
                  if((bid - desiredSL) >= stopLevel)
                  {
                     if(curSL == 0.0 || (desiredSL >= curSL + stepBuffer))
                     {
                        ModifySLTP(ticket, desiredSL, curTP);
                     }
                  }
               }
            }
            else if(pType == POSITION_TYPE_SELL)
            {
               double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               double profitPts = (openPrice - ask) / _Point;

               if(profitPts >= profile.trailingStartPoints)
               {
                  double desiredSL = NormalizeDouble(ask + profile.trailingDistancePoints * _Point, _Digits);
                  if((desiredSL - ask) >= stopLevel)
                  {
                     if(curSL == 0.0 || (desiredSL <= curSL - stepBuffer))
                     {
                        ModifySLTP(ticket, desiredSL, curTP);
                     }
                  }
               }
            }
         }
      }
   }

   bool ModifySLTP(const ulong ticket, const double newSL, const double newTP)
   {
      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);

      req.action   = TRADE_ACTION_SLTP;
      req.position = ticket;
      req.symbol   = _Symbol;
      req.sl       = newSL;
      req.tp       = newTP;

      ResetLastError();
      return OrderSend(req, res);
   }

   void AuditSlippageTransaction(const MqlTradeTransaction &trans)
   {
      if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
         return;

      ulong dealTicket = trans.deal;
      if(!HistoryDealSelect(dealTicket))
         return;

      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != m_magic)
         return;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol)
         return;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN)
         return;

      ulong orderTicket = HistoryDealGetInteger(dealTicket, DEAL_ORDER);
      if(orderTicket <= 0 || !HistoryOrderSelect(orderTicket))
         return;

      ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(orderTicket, ORDER_TYPE);
      if(orderType != ORDER_TYPE_BUY_STOP && orderType != ORDER_TYPE_SELL_STOP)
         return;

      // Stop-to-Market Conversion Slippage Analysis
      double reqPrice   = HistoryOrderGetDouble(orderTicket, ORDER_PRICE_OPEN);
      double fillPrice  = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      ulong  posTicket  = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      ENUM_DEAL_TYPE dType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);

      double negativeSlippagePts = 0.0;
      if(dType == DEAL_TYPE_BUY)
      {
         negativeSlippagePts = (fillPrice - reqPrice) / _Point;
      }
      else if(dType == DEAL_TYPE_SELL)
      {
         negativeSlippagePts = (reqPrice - fillPrice) / _Point;
      }

      if(negativeSlippagePts > m_maxSlippagePoints)
      {
         ChronosAlert(StringFormat("[EMERGENCY LIQUIDATION] Slippage violation on ticket #%I64u (Req: %.5f, Fill: %.5f, Slippage: %.1f pts > max %.1f pts)",
                      posTicket, reqPrice, fillPrice, negativeSlippagePts, m_maxSlippagePoints));

         ClosePositionMarket(posTicket, "Slippage Violation");
         m_slippageCooldownExpiry = TimeCurrent() + m_slippageCooldownSeconds;
      }
   }

   // Exposure Accessors
   int    GetCachedOpenBuys()         const { return m_cachedOpenBuys; }
   int    GetCachedOpenSells()        const { return m_cachedOpenSells; }
   int    GetCachedPendingBuyStops()  const { return m_cachedPendingBuyStops; }
   int    GetCachedPendingSellStops() const { return m_cachedPendingSellStops; }
   double GetCachedBuyLots()          const { return m_cachedBuyLots; }
   double GetCachedSellLots()         const { return m_cachedSellLots; }
};

//+------------------------------------------------------------------+
//| CLASS: CChronosHUD                                               |
//| Ultra-Luxury Multi-Color Institutional Dashboard UI              |
//| (Zero-Resource Caching, Event-Timer Throttled, High-End Visuals)  |
//+------------------------------------------------------------------+
struct HUDCacheEntry
{
   string name;
   string text;
   color  col;
};

class CChronosHUD
{
private:
   bool              m_showPanel;
   ENUM_BASE_CORNER  m_corner;
   int               m_x;
   int               m_y;
   bool              m_created;
   bool              m_dirty;

   HUDCacheEntry     m_cache[64];
   int               m_cacheSize;

   int FindCache(const string name)
   {
      for(int i = 0; i < m_cacheSize; i++)
      {
         if(m_cache[i].name == name)
            return i;
      }
      return -1;
   }

   void CreateRectLabel(const string name, const int x, const int y, const int w, const int h,
                        const color bgCol, const color borderCol)
   {
      string objName = HUD_PREFIX + name;
      if(ObjectFind(0, objName) < 0)
         ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);

      ObjectSetInteger(0, objName, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgCol);
      ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, borderCol);
      ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
   }

   void CreateTextLabel(const string name, const int x, const int y, const string text,
                        const color col, const int fontSize, const string font = HUD_FONT)
   {
      string objName = HUD_PREFIX + name;
      if(ObjectFind(0, objName) < 0)
         ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);

      ObjectSetInteger(0, objName, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, objName, OBJPROP_FONT, font);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);

      // Register initial state in cache to prevent immediate duplicate writes
      int idx = FindCache(name);
      if(idx < 0 && m_cacheSize < 64)
      {
         m_cache[m_cacheSize].name = name;
         m_cache[m_cacheSize].text = text;
         m_cache[m_cacheSize].col  = col;
         m_cacheSize++;
      }
   }

   void SetText(const string name, const string text, const color col = clrNONE)
   {
      int idx = FindCache(name);
      if(idx >= 0)
      {
         // Zero Resource Check: If neither text nor color changed, return immediately!
         if(m_cache[idx].text == text && (col == clrNONE || m_cache[idx].col == col))
            return;

         m_cache[idx].text = text;
         if(col != clrNONE)
            m_cache[idx].col = col;
      }
      else if(m_cacheSize < 64)
      {
         m_cache[m_cacheSize].name = name;
         m_cache[m_cacheSize].text = text;
         m_cache[m_cacheSize].col  = col;
         m_cacheSize++;
      }

      string objName = HUD_PREFIX + name;
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      if(col != clrNONE)
         ObjectSetInteger(0, objName, OBJPROP_COLOR, col);

      m_dirty = true;
   }

public:
   CChronosHUD() : m_showPanel(true), m_corner(CORNER_LEFT_UPPER), m_x(20), m_y(30),
                   m_created(false), m_dirty(false), m_cacheSize(0) {}
   ~CChronosHUD() { Destroy(); }

   void Init(const bool showPanel, const ENUM_BASE_CORNER corner, const int x, const int y)
   {
      m_showPanel = showPanel;
      m_corner    = corner;
      m_x         = x;
      m_y         = y;

      if(!m_showPanel || (MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)))
      {
         Destroy();
         return;
      }

      BuildUI();
   }

   void BuildUI()
   {
      int cardW = 420;
      int cardH = 566;
      int curX  = m_x;
      int curY  = m_y;

      m_cacheSize = 0;

      // 1. Master Obsidian Glass Card with Champagne Gold Border
      CreateRectLabel("MasterCard", curX, curY, cardW, cardH, COLOR_HUD_BG, COLOR_HUD_BORDER);

      // Header Bar (Royal Navy Glass + 24K Gold Trim)
      CreateRectLabel("HeaderBar", curX + 2, curY + 2, cardW - 4, 48, COLOR_HEADER_BG, COLOR_HEADER_ACCENT);
      CreateTextLabel("Title", curX + 16, curY + 8, "👑 CHRONOS QUANT SENTINEL v1.01", COLOR_GOLD_BRIGHT, 10, HUD_FONT_BOLD);
      CreateTextLabel("SubTitle", curX + 16, curY + 26, "Institutional Zero-Repainting Donchian Engine", COLOR_TEXT_MUTED, 8, HUD_FONT);
      CreateTextLabel("PillClock", curX + 295, curY + 8, "[ --:--:-- GMT ]", COLOR_ACCENT_CYAN, 8, HUD_FONT_MONO);
      CreateTextLabel("PillProfile", curX + 275, curY + 26, "[ PROP SCALPER M15 ]", COLOR_ROYAL_PURPLE, 8, HUD_FONT_BOLD);

      // 2. Section 1: Donchian Momentum & Market Microstructure (Electric Cyan Accent)
      int secY = curY + 56;
      CreateRectLabel("Sec1Card", curX + 10, secY, cardW - 20, 108, COLOR_CARD_BG, COLOR_CARD_BORDER);
      CreateTextLabel("Sec1Title", curX + 20, secY + 6, "◈ DONCHIAN BREAKOUT MATRIX (ZERO REPAINT)", COLOR_ACCENT_CYAN, 8, HUD_FONT_BOLD);
      CreateTextLabel("DonchianSetup", curX + 20, secY + 24, "Setup: Period 24 (M15 Rolling 6h) | Offset: -150 pts | Expiry: 12h", COLOR_TEXT_NORMAL, 8, HUD_FONT);
      CreateTextLabel("DonchianLevels", curX + 20, secY + 40, "Levels: High -- | Mid -- | Low --", COLOR_ICE_BLUE, 8, HUD_FONT_MONO);
      CreateTextLabel("DonchianGauge", curX + 20, secY + 58, "Position: [LOW ─────────── HIGH] --% RANGE", COLOR_GOLD_METALLIC, 8, HUD_FONT_MONO);
      CreateTextLabel("DonchianSpread", curX + 20, secY + 76, "Spread: -- pts [PASS] | Trigger Guard: 50 pts | Band: 500 pts", COLOR_ACCENT_GREEN, 8, HUD_FONT);

      // 3. Section 2: Capital Vault & Prop Firm Armor (Champagne Gold Accent)
      secY += 114;
      CreateRectLabel("Sec2Card", curX + 10, secY, cardW - 20, 108, COLOR_CARD_BG, COLOR_CARD_BORDER);
      CreateTextLabel("Sec2Title", curX + 20, secY + 6, "◈ CAPITAL VAULT & PROP FIRM ARMOR", COLOR_GOLD_BRIGHT, 8, HUD_FONT_BOLD);
      CreateTextLabel("FinAccount", curX + 20, secY + 24, "Account: Balance $0.00 | Equity $0.00", COLOR_TEXT_HEADER, 8, HUD_FONT_MONO);
      CreateTextLabel("FinPnL", curX + 20, secY + 40, "Daily PnL: Realized $0.00 (+0.00%) | Floating $0.00 (+0.00%)", COLOR_ACCENT_GREEN, 8, HUD_FONT_MONO);
      CreateTextLabel("FinRiskMeter", curX + 20, secY + 58, "Loss Shield: [■■■■■■■■■■] Buffer: 100% (Max: $--)", COLOR_ACCENT_GREEN, 8, HUD_FONT_MONO);
      CreateTextLabel("FinPropRule", curX + 20, secY + 76, "120s Prop Armor: ARMED (2x Initial Buffer) | Target: $0 (OFF)", COLOR_ROYAL_PURPLE, 8, HUD_FONT);

      // 4. Section 3: Institutional Shields & News Sentinel (Emerald & Ruby Accent)
      secY += 114;
      CreateRectLabel("Sec3Card", curX + 10, secY, cardW - 20, 108, COLOR_CARD_BG, COLOR_CARD_BORDER);
      CreateTextLabel("Sec3Title", curX + 20, secY + 6, "◈ INSTITUTIONAL SHIELDS & NEWS SENTINEL", COLOR_ACCENT_GREEN, 8, HUD_FONT_BOLD);
      CreateTextLabel("NewsFeeds", curX + 20, secY + 24, "Radar Feeds: MT5 [ON] | ForexFactory [ON] | Investing [ON]", COLOR_ICE_BLUE, 8, HUD_FONT);
      CreateTextLabel("NewsStatus", curX + 20, secY + 40, "News Sentinel: CLEAR (FULL OPERATIONAL)", COLOR_ACCENT_GREEN, 8, HUD_FONT_BOLD);
      CreateTextLabel("NewsNext", curX + 20, secY + 58, "Next High-Impact: None", COLOR_TEXT_MUTED, 8, HUD_FONT);
      CreateTextLabel("ShieldSlippage", curX + 20, secY + 76, "Slippage Defense: ARMED (Max: 50 pts) | Session: ACTIVE", COLOR_ACCENT_GREEN, 8, HUD_FONT);

      // 5. Section 4: Tactical Exposure & Execution Grid (Amber Orange & Sapphire Accent)
      secY += 114;
      CreateRectLabel("Sec4Card", curX + 10, secY, cardW - 20, 108, COLOR_CARD_BG, COLOR_CARD_BORDER);
      CreateTextLabel("Sec4Title", curX + 20, secY + 6, "◈ TACTICAL EXPOSURE & EXECUTION GRID", COLOR_ACCENT_ORANGE, 8, HUD_FONT_BOLD);
      CreateTextLabel("ExpPositions", curX + 20, secY + 24, "Market Open: 0 Buy (0.00 Lot) | 0 Sell (0.00 Lot)", COLOR_TEXT_NORMAL, 8, HUD_FONT_MONO);
      CreateTextLabel("ExpPendings", curX + 20, secY + 40, "Pending Orders: 0 Buy Stop | 0 Sell Stop (Expiry: 12h)", COLOR_ICE_BLUE, 8, HUD_FONT_MONO);
      CreateTextLabel("ExpLatches", curX + 20, secY + 58, "Breakout Gates: BUY [READY] | SELL [READY] (Pause: 300s)", COLOR_ACCENT_GREEN, 8, HUD_FONT_BOLD);
      CreateTextLabel("ExpTrailing", curX + 20, secY + 76, "Dynamic Trailing: Start 165 pts | Step 40 pts | Slip Audit: PASS", COLOR_GOLD_METALLIC, 8, HUD_FONT);

      // 6. Footer Institutional Status Ribbon
      secY += 114;
      CreateRectLabel("FooterBar", curX + 10, secY, cardW - 20, 36, COLOR_HEADER_BG, COLOR_CARD_BORDER);
      CreateTextLabel("FooterText", curX + 20, secY + 10, "CHRONOS QUANT SYSTEM • INSTITUTIONAL AUDIT", COLOR_TEXT_MUTED, 7, HUD_FONT);
      CreateTextLabel("FooterStatus", curX + 260, secY + 10, "[● 100% OPERATIONAL]", COLOR_ACCENT_GREEN, 8, HUD_FONT_BOLD);

      m_created = true;
      m_dirty   = true;
      ChartRedraw(0);
   }

   void Update(const CChronosTime &timeEngine, const CChronosNews &newsEngine,
               const CChronosTrade &tradeEngine, const PresetConfig &profile,
               const string profileName, const double high, const double low, const double mid,
               const double realizedPnL, const double floatingPnL, const double dailyTarget, const double dailyLossLimit)
   {
      if(!m_showPanel || (MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)))
         return;
      if(!m_created)
         BuildUI();

      m_dirty = false;

      // 1. Clock & Profile Badges
      datetime srvNow = TimeTradeServer();
      MqlDateTime dt;
      TimeToStruct(srvNow, dt);
      string timeStr = StringFormat("%02d:%02d:%02d", dt.hour, dt.min, dt.sec);
      SetText("PillClock", StringFormat("[ %s GMT%+0.0fh ]", timeStr, timeEngine.GetGMTOffsetHours()), COLOR_ACCENT_CYAN);
      string upperProf = profileName;
      StringToUpper(upperProf);
      SetText("PillProfile", StringFormat("[ %s M%d ]", upperProf, (int)profile.timeframe), COLOR_ROYAL_PURPLE);

      // 2. Section 1: Donchian Momentum Matrix
      MqlTick tick;
      SymbolInfoTick(_Symbol, tick);

      SetText("DonchianSetup", StringFormat("Setup: Period %d (M%d Rolling) | Offset: %.0f pts | Expiry: %dh",
              profile.donchianPeriod, (int)profile.timeframe, profile.entryOffsetPoints, profile.orderExpiryHours));

      SetText("DonchianLevels", StringFormat("Levels: High %.2f | Mid %.2f | Low %.2f", high, mid, low));

      // Dynamic Channel Slider Gauge
      string channelBar = "Position: [LOW ─────────── HIGH] --% RANGE";
      if(high > low && tick.ask > 0.0)
      {
         double ratio = (tick.ask - low) / (high - low);
         if(ratio < 0.0) ratio = 0.0;
         if(ratio > 1.0) ratio = 1.0;
         int pos = (int)MathRound(ratio * 11.0);
         channelBar = "Position: [LOW ";
         for(int b = 0; b <= 11; b++)
         {
            if(b == pos) channelBar += "●";
            else channelBar += "─";
         }
         int pct = (int)MathRound(ratio * 100.0);
         channelBar += StringFormat(" HIGH] %d%% %s", pct, (pct >= 50 ? "BULL" : "BEAR"));
      }
      SetText("DonchianGauge", channelBar, COLOR_GOLD_METALLIC);

      double curSpread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      bool spreadPass = (inp_MaxSpreadPoints <= 0.0 || curSpread <= inp_MaxSpreadPoints);
      SetText("DonchianSpread", StringFormat("Spread: %.0f pts [%s] | Trigger Guard: %.0f pts | Band: %.0f pts",
              curSpread, (spreadPass ? "PASS" : "WIDE"), inp_TriggerDistancePoints, inp_DuplicateBandPoints),
              spreadPass ? COLOR_ACCENT_GREEN : COLOR_ACCENT_RED);

      // 3. Section 2: Capital Vault & Prop Firm Armor
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
      SetText("FinAccount", StringFormat("Account: Balance $%.2f | Equity $%.2f", balance, equity));

      double realizedPct = (balance > 0.0) ? (realizedPnL / balance * 100.0) : 0.0;
      double floatingPct = (balance > 0.0) ? (floatingPnL / balance * 100.0) : 0.0;
      color colRealized  = (realizedPnL > 0.0) ? COLOR_ACCENT_GREEN : (realizedPnL < 0.0 ? COLOR_ACCENT_RED : COLOR_TEXT_HEADER);
      color colFloating  = (floatingPnL > 0.0) ? COLOR_ACCENT_GREEN : (floatingPnL < 0.0 ? COLOR_ACCENT_RED : COLOR_TEXT_HEADER);

      SetText("FinPnL", StringFormat("Daily PnL: Realized %s$%.2f (%+0.2f%%) | Floating %s$%.2f (%+0.2f%%)",
              (realizedPnL >= 0.0 ? "+" : ""), realizedPnL, realizedPct,
              (floatingPnL >= 0.0 ? "+" : ""), floatingPnL, floatingPct), colRealized);

      // Loss Shield Progress Bar
      string riskBar = "Loss Shield: [";
      if(dailyLossLimit > 0.0)
      {
         double used = (realizedPnL < 0.0) ? (-realizedPnL) : 0.0;
         double remain = (dailyLossLimit > used) ? (dailyLossLimit - used) : 0.0;
         double bufferPct = (remain / dailyLossLimit) * 100.0;
         if(bufferPct < 0.0) bufferPct = 0.0;
         if(bufferPct > 100.0) bufferPct = 100.0;
         int blocks = (int)MathRound((bufferPct / 100.0) * 10.0);
         for(int b = 0; b < 10; b++)
            riskBar += (b < blocks ? "■" : "□");
         riskBar += StringFormat("] Buffer: %d%% (Max: -$%.0f)", (int)bufferPct, dailyLossLimit);
      }
      else
      {
         riskBar += "■■■■■■■■■■] Buffer: 100% (UNLIMITED)";
      }
      SetText("FinRiskMeter", riskBar, (realizedPnL < 0.0 ? COLOR_ACCENT_ORANGE : COLOR_ACCENT_GREEN));

      SetText("FinPropRule", StringFormat("120s Prop Armor: %s | Target: %s",
              (profile.isPropMode ? "ACTIVE (2x Initial Buffer)" : "DISABLED (Standard SL/TP)"),
              (dailyTarget > 0.0 ? StringFormat("$%.0f", dailyTarget) : "OFF")), COLOR_ROYAL_PURPLE);

      // 4. Section 3: Institutional Shields & News Sentinel
      SetText("NewsFeeds", StringFormat("Radar Feeds: MT5 [%s] | ForexFactory [%s] | Investing [%s]",
              newsEngine.GetStatusNative() ? "ON" : "OFF",
              newsEngine.GetStatusFF() ? "ON" : "OFF",
              newsEngine.GetStatusInvesting() ? "ON" : "OFF"));

      if(newsEngine.IsBlackout())
         SetText("NewsStatus", "News Sentinel: BLACKOUT ACTIVE (TRADE FREEZE)", COLOR_ACCENT_RED);
      else
         SetText("NewsStatus", "News Sentinel: CLEAR (FULL OPERATIONAL)", COLOR_ACCENT_GREEN);

      int countdown = newsEngine.GetNextEventCountdown();
      if(countdown >= 0)
      {
         int h = countdown / 3600;
         int m = (countdown % 3600) / 60;
         int s = countdown % 60;
         SetText("NewsNext", StringFormat("Next High-Impact: %s (in %02dh %02dm %02ds)", newsEngine.GetNextEventTitle(), h, m, s), COLOR_GOLD_BRIGHT);
      }
      else
      {
         SetText("NewsNext", StringFormat("Next High-Impact: %s", newsEngine.GetNextEventTitle()), COLOR_TEXT_MUTED);
      }

      int slippageCD = 0;
      bool isSlipCD = tradeEngine.IsSlippageCoolingDown(slippageCD);
      bool sessionAllowed = timeEngine.IsTradingSessionAllowed(inp_DailyCloseHour, inp_DailyReopenHour, inp_FridayCloseHour);

      string shieldStr = StringFormat("Slippage: %s | Session: %s",
                         isSlipCD ? StringFormat("COOLDOWN (%ds)", slippageCD) : StringFormat("ARMED (%.0f pts)", inp_MaxAllowedSlippagePoints),
                         sessionAllowed ? "ACTIVE" : "CLOSED/ROLLOVER");
      SetText("ShieldSlippage", shieldStr, (isSlipCD || !sessionAllowed) ? COLOR_ACCENT_ORANGE : COLOR_ACCENT_GREEN);

      // 5. Section 4: Tactical Exposure & Execution Grid
      SetText("ExpPositions", StringFormat("Market Open: %d Buy (%.2f Lot) | %d Sell (%.2f Lot)",
              tradeEngine.GetCachedOpenBuys(), tradeEngine.GetCachedBuyLots(),
              tradeEngine.GetCachedOpenSells(), tradeEngine.GetCachedSellLots()));

      SetText("ExpPendings", StringFormat("Pending Orders: %d Buy Stop | %d Sell Stop (Expiry: %dh)",
              tradeEngine.GetCachedPendingBuyStops(), tradeEngine.GetCachedPendingSellStops(), profile.orderExpiryHours));

      bool buyLocked  = tradeEngine.IsBuyLocked();
      bool sellLocked = tradeEngine.IsSellLocked();
      SetText("ExpLatches", StringFormat("Breakout Gates: BUY [%s] | SELL [%s] (Pause: %ds%s)",
              buyLocked ? "LOCKED" : "READY", sellLocked ? "LOCKED" : "READY", profile.pauseSeconds,
              inp_StickyAlternateLock ? ", Alt-Lock" : ""),
              (buyLocked || sellLocked) ? COLOR_ACCENT_ORANGE : COLOR_ACCENT_GREEN);

      SetText("ExpTrailing", StringFormat("Dynamic Trailing: Start %.0f pts | Step %.0f pts | NewBar: %s",
              profile.trailingStartPoints, profile.trailingDistancePoints, inp_UseNewBarFilter ? "ON" : "OFF"), COLOR_GOLD_METALLIC);

      // 6. Smart Throttled Redraw (Only redraws if a label actually changed!)
      if(m_dirty)
      {
         ChartRedraw(0);
         m_dirty = false;
      }
   }

   void Destroy()
   {
      m_created   = false;
      m_cacheSize = 0;
      #ifdef __clang__
      ObjectsDeleteAll(0, -1, -1);
      #else
      ObjectsDeleteAll(0, HUD_PREFIX);
      #endif
      ChartRedraw(0);
   }
};

//+------------------------------------------------------------------+
//| GLOBAL SYSTEM INSTANCES                                          |
//+------------------------------------------------------------------+
CChronosTime   g_time;
CChronosNews   g_news;
CChronosSignal g_signal;
CChronosTrade  g_trade;
CChronosHUD    g_hud;

PresetConfig   g_activeProfile;
string         g_activeProfileName = "Scalper";

// Realized & Floating Accounting Cache
double         g_dailyRealizedPnL  = 0.0;
double         g_dailyFloatingPnL  = 0.0;
datetime       g_lastDayEvaluated  = 0;
datetime       g_lastSignalBarTime = 0; // Aegis New Bar Latch Tracker
datetime       g_lastFinCalcTime   = 0; // OPT-1: CalculateDailyFinancials throttle
bool           g_fridayCloseExecuted = false; // OPT-8: Friday close one-shot guard

//+------------------------------------------------------------------+
//| PRESET CONFIGURATION LOADER                                      |
//+------------------------------------------------------------------+
void LoadActiveProfile(const ENUM_PRESET_PROFILE profileEnum, PresetConfig &p, string &name)
{
   switch(profileEnum)
   {
      case PROFILE_SCALPER:
         name                        = "Scalper";
         p.timeframe                 = PERIOD_M15;
         p.donchianPeriod            = 24;
         p.orderExpiryHours          = 12;
         p.initialTakeProfitPoints   = 1500.0;
         p.initialStopLossPoints     = 300.0;
         p.trailingStartPoints       = 140.0;
         p.trailingDistancePoints    = 40.0;
         p.entryOffsetPoints         = -160.0;
         p.pauseSeconds              = 60;
         p.isPropMode                = false;
         p.propHoldSeconds           = 0;
         p.propProtectionMultiplier  = 1.0;
         break;

      case PROFILE_SWINGER:
         name                        = "Swinger";
         p.timeframe                 = PERIOD_M15;
         p.donchianPeriod            = 48;
         p.orderExpiryHours          = 27000; // Multi-month institutional horizon
         p.initialTakeProfitPoints   = 4500.0;
         p.initialStopLossPoints     = 2500.0;
         p.trailingStartPoints       = 1500.0;
         p.trailingDistancePoints    = 500.0;
         p.entryOffsetPoints         = -50.0;
         p.pauseSeconds              = 60;
         p.isPropMode                = false;
         p.propHoldSeconds           = 0;
         p.propProtectionMultiplier  = 1.0;
         break;

      case PROFILE_POSITIVE_RR:
         name                        = "Positive RR";
         p.timeframe                 = PERIOD_M30;
         p.donchianPeriod            = 36;
         p.orderExpiryHours          = 12;
         p.initialTakeProfitPoints   = 2250.0;
         p.initialStopLossPoints     = 325.0;
         p.trailingStartPoints       = 575.0;
         p.trailingDistancePoints    = 165.0;
         p.entryOffsetPoints         = -175.0;
         p.pauseSeconds              = 60;
         p.isPropMode                = false;
         p.propHoldSeconds           = 0;
         p.propProtectionMultiplier  = 1.0;
         break;

      case PROFILE_PROP_SCALPER:
         name                        = "Prop Scalper";
         p.timeframe                 = PERIOD_M15;
         p.donchianPeriod            = 24;
         p.orderExpiryHours          = 12;
         p.initialTakeProfitPoints   = 2500.0;
         p.initialStopLossPoints     = 350.0;
         p.trailingStartPoints       = 165.0;
         p.trailingDistancePoints    = 40.0;
         p.entryOffsetPoints         = -150.0;
         p.pauseSeconds              = 60;
         p.isPropMode                = true;
         p.propHoldSeconds           = 120;
         p.propProtectionMultiplier  = 2.0; // 2x initial protection (SL 700 / TP 5000) for 120s
         break;

      case PROFILE_CUSTOM:
      default:
         name                        = "Custom";
         p.timeframe                 = inp_CustomTimeframe;
         p.donchianPeriod            = inp_CustomPeriod;
         p.orderExpiryHours          = inp_CustomExpiryHours;
         p.initialTakeProfitPoints   = inp_CustomTPPoints;
         p.initialStopLossPoints     = inp_CustomSLPoints;
         p.trailingStartPoints       = inp_CustomTrailStartPoints;
         p.trailingDistancePoints    = inp_CustomTrailDistPoints;
         p.entryOffsetPoints         = inp_CustomEntryOffsetPoints;
         p.pauseSeconds              = inp_CustomPauseSeconds;
         p.isPropMode                = inp_CustomIsPropMode;
         p.propHoldSeconds           = inp_CustomPropHoldSeconds;
         p.propProtectionMultiplier  = inp_CustomPropMultiplier;
         break;
   }
}

//+------------------------------------------------------------------+
//| DAILY FINANCIAL ACCOUNTING ENGINE                                |
//+------------------------------------------------------------------+
void CalculateDailyFinancials(double &outRealized, double &outFloating)
{
   outRealized = 0.0;
   outFloating = 0.0;

   datetime srvNow = TimeTradeServer();
   MqlDateTime dt;
   TimeToStruct(srvNow, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime dayStart = StructToTime(dt);

   // Realized deals closed today
   if(HistorySelect(dayStart, TimeCurrent()))
   {
      int dealsTotal = HistoryDealsTotal();
      for(int i = 0; i < dealsTotal; i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         if(dealTicket > 0)
         {
            if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == inp_MagicNumber &&
               HistoryDealGetString(dealTicket, DEAL_SYMBOL) == _Symbol)
            {
               outRealized += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
               outRealized += HistoryDealGetDouble(dealTicket, DEAL_SWAP);
               outRealized += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
            }
         }
      }
   }

   // Floating unrealized PnL from open positions
   int posTotal = PositionsTotal();
   for(int i = 0; i < posTotal; i++)
   {
      ulong posTicket = PositionGetTicket(i);
      if(posTicket > 0)
      {
         if(PositionGetInteger(POSITION_MAGIC) == inp_MagicNumber &&
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            outFloating += PositionGetDouble(POSITION_PROFIT);
            outFloating += PositionGetDouble(POSITION_SWAP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION HANDLER                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   ChronosLog("======================================================================");
   ChronosLog("Initiating Chronos v1.01 Institutional Donchian Breakout Architecture...");

   // 0. Account Authorization & License Verification (Tamper-Resistant Guard)
   string lockReason;
   if(!CChronosSecurity::CheckAccountAuthorization(lockReason))
   {
      ChronosLog("FATAL SECURITY ERROR: " + lockReason);
      ChronosAlert("SECURITY LOCK: " + lockReason);
      return INIT_FAILED;
   }

   // 1. Load Strategy Preset
   LoadActiveProfile(inp_Profile, g_activeProfile, g_activeProfileName);
   ChronosLog(StringFormat("[Strategy Engine] Profile: %s | Timeframe: M%d | Period: %d | Expiry: %dh",
              g_activeProfileName, (int)g_activeProfile.timeframe, g_activeProfile.donchianPeriod, g_activeProfile.orderExpiryHours));

   // 2. Initialize Subsystems
   g_time.Init(inp_AutoGMT, inp_ManualGMTOffset);
   g_news.Init(&g_time, inp_EnableNewsFilter, inp_NewsMinutesBefore, inp_NewsMinutesAfter,
               inp_DeletePendingsOnNews, inp_EnableForexFactory, inp_EnableInvestingFallback);
   g_trade.Init(inp_MagicNumber, inp_TradeComment, inp_MaxAllowedSlippagePoints, inp_SlippageCooldownSeconds, inp_DuplicateBandPoints);
   g_hud.Init(inp_ShowPanel, inp_PanelCorner, inp_PanelX, inp_PanelY);

   // 3. Register Timer (OPT-7: 60s in non-visual tester, 1s for live/visual)
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE))
      EventSetTimer(60);
   else
      EventSetTimer(1);
   g_lastSignalBarTime = 0;
   g_lastFinCalcTime   = 0;
   g_fridayCloseExecuted = false;

   ChronosLog("Chronos v1.01 Engine Successfully Armed and Ready.");
   ChronosLog("======================================================================");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION HANDLER                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   g_hud.Destroy();
   ChronosLog(StringFormat("Chronos v1.01 Shutdown Complete. Reason Code: %d", reason));
}

//+------------------------------------------------------------------+
//| HIGH-FREQUENCY 1-SECOND TIMER EVENT HANDLER                      |
//| (Zero-Freeze Web Calendars, HUD Redraw, Prop 120s Hold Rule)     |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Turbo Speed Optimization: Bypass timer tasks in non-visual tester
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE))
   {
      if(PositionsTotal() > 0)
         g_trade.Manage120sPropRule(g_activeProfile);
      return;
   }

   // 1. Keep GMT and Session synchronization live
   g_time.Update();

   // 2. Execute background news workers (WebRequest is isolated strictly to OnTimer)
   g_news.HourlyWorker();
   g_news.EvaluateNewsMatrix();

   // 3. Purge pendings on news blackout if requested
   if(g_news.IsBlackout() && g_news.GetDeletePendingsOnNews())
   {
      g_trade.PurgePendingOrders(false, 0);
   }

   // 4. Enforce 120s Prop Scalper SL/TP normalization
   g_trade.Manage120sPropRule(g_activeProfile);

   // 5. Snapshot exposure and cache financials (OPT-1/OPT-2: throttled to 5s)
   datetime timerNow = TimeCurrent();
   if(timerNow - g_lastFinCalcTime >= 5)
   {
      g_lastFinCalcTime = timerNow;
      g_trade.SnapshotExposure(g_activeProfile.pauseSeconds, inp_StickyAlternateLock);
      CalculateDailyFinancials(g_dailyRealizedPnL, g_dailyFloatingPnL);
   }

   // 6. Calculate Donchian values for UI monitoring
   double h = 0.0, l = 0.0, m = 0.0;
   g_signal.Calculate(_Symbol, g_activeProfile.timeframe, g_activeProfile.donchianPeriod, h, l, m);

   // 7. Redraw Chart HUD strictly on 1-second cadence (0% CPU impact on tick stream)
   g_hud.Update(g_time, g_news, g_trade, g_activeProfile, g_activeProfileName,
                h, l, m, g_dailyRealizedPnL, g_dailyFloatingPnL,
                inp_DailyTargetProfit, inp_DailyMaxLoss);
}

//+------------------------------------------------------------------+
//| TICK EVENT HANDLER: DONCHIAN BREAKOUT CORE SIGNAL ENGINE         |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Audit Daily Financial Targets & Drawdown Limits
   if(inp_DailyTargetProfit > 0.0 && g_dailyRealizedPnL >= inp_DailyTargetProfit)
   {
      // Target achieved for today: halt order placements
      return;
   }
   if(inp_DailyMaxLoss > 0.0 && g_dailyRealizedPnL <= -inp_DailyMaxLoss)
   {
      // Max daily loss reached: stop further trading
      return;
   }

   // 2. Check Session Trading Filters (Friday Exit & Rollover Hours)
   bool sessionAllowed = g_time.IsTradingSessionAllowed(inp_DailyCloseHour, inp_DailyReopenHour, inp_FridayCloseHour);
   if(!sessionAllowed)
   {
      // OPT-8: Execute Friday close logic only once, not every tick
      if(!g_fridayCloseExecuted)
      {
         datetime srvNow = TimeTradeServer();
         MqlDateTime dt;
         TimeToStruct(srvNow, dt);

         if(dt.day_of_week == 5 && inp_FridayCloseHour >= 0 && dt.hour >= inp_FridayCloseHour)
         {
            if(inp_DeletePendingsOnFriday)
               g_trade.PurgePendingOrders(false, 0);

            if(inp_ClosePositionsOnFriday)
            {
               int posTotal = PositionsTotal();
               for(int i = posTotal - 1; i >= 0; i--)
               {
                  ulong ticket = PositionGetTicket(i);
                  if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == inp_MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
                  {
                     g_trade.ClosePositionMarket(ticket, "Friday Weekend Close");
                  }
               }
            }
            g_fridayCloseExecuted = true;
         }
      }
      return;
   }
   g_fridayCloseExecuted = false; // Reset when session becomes active again

   // 3. News Sentinel Check (Logical OR Filter)
   if(g_news.IsBlackout())
   {
      if(g_news.GetDeletePendingsOnNews())
         g_trade.PurgePendingOrders(false, 0);
      return; // Freeze all order placements during news window
   }

   // 4. Slippage Defense Cooldown Check
   int remainingCooldown = 0;
   if(g_trade.IsSlippageCoolingDown(remainingCooldown))
   {
      return; // Active slippage liquidation cooldown
   }

   // 5. Spread Guard Filter
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(inp_MaxSpreadPoints > 0.0 && spread > inp_MaxSpreadPoints)
   {
      return; // Spread too wide
   }

   // 6. Manage Trailing Stop, Break-Even & Prop Rule for Open Positions (Zero-lag every tick)
   if(PositionsTotal() > 0)
   {
      // 6.1 Early False-Breakout Midline Invalidation Cut
      if(inp_EnableMidlineCut)
      {
         double midH = 0.0, midL = 0.0, liveMid = 0.0;
         if(g_signal.Calculate(_Symbol, g_activeProfile.timeframe, g_activeProfile.donchianPeriod, midH, midL, liveMid))
         {
            g_trade.ManageMidlineCut(liveMid);
         }
      }

      // 6.2 Tier-1 Break-Even Profit Lock
      if(inp_EnableBreakEven)
         g_trade.ManageBreakEven(inp_BreakEvenTriggerPoints, inp_BreakEvenLockPoints);

      // 6.3 Tier-2 Dynamic Trailing Stop with Broker Gateway Buffer
      g_trade.ManageTrailingStop(g_activeProfile, inp_TrailingStepPoints);

      // 6.4 Prop Scalper Rule
      if(g_activeProfile.isPropMode)
         g_trade.Manage120sPropRule(g_activeProfile);
   }

   // 7. Aegis New Bar Latch Gate (Evaluate Breakout Orders strictly ONCE per Bar)
   if(inp_UseNewBarFilter)
   {
      datetime currentBarTime = iTime(_Symbol, g_activeProfile.timeframe, 0);
      if(currentBarTime == 0 || currentBarTime == g_lastSignalBarTime)
         return;
      g_lastSignalBarTime = currentBarTime;
   }

   // 8. Calculate Zero-Repainting Donchian Channel (Runs ONLY on New Bar)
   double highestHigh = 0.0;
   double lowestLow   = 0.0;
   double channelMid  = 0.0;
   if(!g_signal.Calculate(_Symbol, g_activeProfile.timeframe, g_activeProfile.donchianPeriod,
                          highestHigh, lowestLow, channelMid))
   {
      return; // Insufficient bar data
   }

   // 9. Snapshot Directional Exposure & Latches (Runs ONLY on New Bar)
   g_trade.SnapshotExposure(g_activeProfile.pauseSeconds, inp_StickyAlternateLock);

   // 10. Fetch Live Market Ticks
   MqlTick currentTick;
   if(!SymbolInfoTick(_Symbol, currentTick))
      return;

   double ask = currentTick.ask;
   double bid = currentTick.bid;

   // Minimum broker stop/freeze levels
   double stopLevelPoints   = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double freezeLevelPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double brokerMinDist     = MathMax(stopLevelPoints, freezeLevelPoints) * _Point;
   double triggerDist       = MathMax(inp_TriggerDistancePoints * _Point, brokerMinDist);

   // 11. Directional Breakout Trigger Logic
   // ----------------------------------------------------------------
   // Case A: UPPER BREAKOUT (BUY_STOP)
   // ----------------------------------------------------------------
   if(ask >= channelMid)
   {
      // Stale order purging: If market shifted into upper half, purge only lingering sell stops
      if(g_trade.GetCachedPendingSellStops() > 0)
         g_trade.PurgePendingOrders(false, 0, ORDER_TYPE_SELL_STOP);

      // Sticky Alternate Side Lock: Reset opposite (Sell) latch when market swings into Upper Half
      if(inp_StickyAlternateLock)
         g_trade.ResetSellLatch();

      if(g_trade.CanPlaceOrSyncBuy())
      {
         double entryPrice = NormalizeDouble(highestHigh + g_activeProfile.entryOffsetPoints * _Point, _Digits);

         // Validate entry is above current Ask by at least trigger distance (which already includes brokerMinDist)
         if((entryPrice - ask) >= triggerDist)
         {
            double slPoints = g_activeProfile.initialStopLossPoints;
            double tpPoints = g_activeProfile.initialTakeProfitPoints;

            if(g_activeProfile.isPropMode && g_activeProfile.propProtectionMultiplier > 1.0)
            {
               slPoints *= g_activeProfile.propProtectionMultiplier;
               tpPoints *= g_activeProfile.propProtectionMultiplier;
            }

            double stopLoss   = NormalizeDouble(entryPrice - slPoints * _Point, _Digits);
            double takeProfit = NormalizeDouble(entryPrice + tpPoints * _Point, _Digits);
            double lots       = g_trade.CalculateLotSize(slPoints, inp_LotMode, inp_FixedLot, inp_RiskPercent);

            g_trade.SyncOrSendPending(ORDER_TYPE_BUY_STOP, entryPrice, stopLoss, takeProfit, lots,
                                      g_activeProfile.orderExpiryHours, triggerDist, inp_DynamicPendingSync);
         }
      }
   }
   // ----------------------------------------------------------------
   // Case B: LOWER BREAKOUT (SELL_STOP)
   // ----------------------------------------------------------------
   else if(bid < channelMid)
   {
      // Stale order purging: If market shifted into lower half, purge only lingering buy stops
      if(g_trade.GetCachedPendingBuyStops() > 0)
         g_trade.PurgePendingOrders(false, 0, ORDER_TYPE_BUY_STOP);

      // Sticky Alternate Side Lock: Reset opposite (Buy) latch when market swings into Lower Half
      if(inp_StickyAlternateLock)
         g_trade.ResetBuyLatch();

      if(g_trade.CanPlaceOrSyncSell())
      {
         double entryPrice = NormalizeDouble(lowestLow - g_activeProfile.entryOffsetPoints * _Point, _Digits);

         // Validate entry is below current Bid by at least trigger distance
         if((bid - entryPrice) >= triggerDist)
         {
            double slPoints = g_activeProfile.initialStopLossPoints;
            double tpPoints = g_activeProfile.initialTakeProfitPoints;

            if(g_activeProfile.isPropMode && g_activeProfile.propProtectionMultiplier > 1.0)
            {
               slPoints *= g_activeProfile.propProtectionMultiplier;
               tpPoints *= g_activeProfile.propProtectionMultiplier;
            }

            double stopLoss   = NormalizeDouble(entryPrice + slPoints * _Point, _Digits);
            double takeProfit = NormalizeDouble(entryPrice - tpPoints * _Point, _Digits);
            double lots       = g_trade.CalculateLotSize(slPoints, inp_LotMode, inp_FixedLot, inp_RiskPercent);

            g_trade.SyncOrSendPending(ORDER_TYPE_SELL_STOP, entryPrice, stopLoss, takeProfit, lots,
                                      g_activeProfile.orderExpiryHours, triggerDist, inp_DynamicPendingSync);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| TRADE TRANSACTION HANDLER (SLIPPAGE & LATENCY AUDIT)             |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Audit deal fills for negative slippage and trigger emergency liquidation if breached
   g_trade.AuditSlippageTransaction(trans);
}
//+------------------------------------------------------------------+
