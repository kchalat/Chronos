using System;
using cAlgo.API;
using cAlgo.API.Collections;
using cAlgo.API.Indicators;
using cAlgo.API.Internals;

namespace cAlgo.Robots
{
    [Robot(AccessRights = AccessRights.None)]
    public class Chronos : Robot
    {
        [Parameter("Volume (Lots)", Group = "Trade Settings", DefaultValue = 0.01, MinValue = 0.01, Step = 0.01)]
        public double VolumeInLots { get; set; }

        [Parameter("Stop Loss (pips)", Group = "Risk Management", DefaultValue = 20.0, MinValue = 1.0)]
        public double StopLossInPips { get; set; }

        [Parameter("Take Profit (pips)", Group = "Risk Management", DefaultValue = 30.0, MinValue = 1.0)]
        public double TakeProfitInPips { get; set; }

        [Parameter("Max Slippage (pips)", Group = "Execution", DefaultValue = 2.0, MinValue = 0.5)]
        public double SlippageInPips { get; set; }

        private const string BotLabel = "Chronos_XAUUSD";

        protected override void OnStart()
        {
            Print("==========================================");
            Print(" Chronos cBot Initialized Successfully");
            Print($" Symbol: {SymbolName} | Timeframe: {TimeFrame}");
            Print($" Volume: {VolumeInLots} Lots | SL: {StopLossInPips} pips | TP: {TakeProfitInPips} pips");
            Print("==========================================");
        }

        protected override void OnTick()
        {
            // ตรรกะการตรวจสอบราคาแบบ Real-time ทุก Tick (สำหรับ Scalping)
        }

        protected override void OnBar()
        {
            // ตรรกะการคำนวณสัญญาณเมื่อแท่งเทียนปิด (ประหยัด CPU กว่า OnTick)
        }

        protected override void OnStop()
        {
            Print("Chronos cBot has stopped.");
        }
    }
}