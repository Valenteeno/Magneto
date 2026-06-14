# Magneto

"Magneto" news-driven Expert Advisor family — NewsMagneto Pro and DuoPro, plus an ETH (Eth_Magneto) DuoPro variant.

> **Proprietary software** — © Teenodi Ltd. All rights reserved. Private repository; not for distribution. See [LICENSE](LICENSE).

## Eth_Magneto_DuoPro.mq5

### Inputs


*Functionality Controls*

| Input | Type | Default | Description |
|---|---|---|---|
| `goLong` | bool | `true,goShort=true,stopsTrailer=false,tpShifter=true,equityLimits=false,` |  |

*Symbol and Timeframe Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `Symbol_Source` | SymbolSource | `Native_Chart` |  |
| `Comma_Separated_Symbols` | string | `"EURUSD,USDJPY,AUDUSD,USDCHF,USDCAD,XAUUSD"` |  |
| `AutoCorrect_Symbol_List` | bool | `true` |  |
| `maxSymbolsTradedPerTimePerType` | int | `5` |  |
| `Period_Source` | PeriodSource | `Native_Chart_Period` |  |
| `Comma_Separated_Timeframes` | string | `"M1,M5,H1"` |  |

*ETH Line Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `lineRetentionDays` | int | `7` |  |
| `ETH_Hour` | int | `16` |  |
| `ETH_Minute` | int | `30` |  |
| `ETH_PriceType` | ENUM_APPLIED_PRICE | `PRICE_CLOSE` |  |

*Signal Processing Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `minimumRangeNoTouchingLine` | int | `3` |  |
| `wickToBodyFactor` | double | `2.0` |  |

*Trade Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `tpLeaderPoints` | uint | `15,slTrailerPoints=30,slFixPoints=0,tpFixPoints=250,` |  |

*Spacer Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstSpacerPoints` | uint | `50,minimumSpacerPoints=5` |  |
| `spacerMultiplier` | double | `0.9` |  |

*Lot Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstLot` | double | `0.3,maxLot=5,lotMultiplier=1.10` |  |

*TP Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstTpPoints` | uint | `100,maximumTpPoints=200` |  |
| `tpMultiplier` | double | `1.10` |  |

*Max and Min filters*

| Input | Type | Default | Description |
|---|---|---|---|
| `startTime` | datetime | `1730768400,stopTime=1730847600` |  |
| `MaxEquity` | double | `5500,MinEquity=6500` |  |
| `maxTrades` | int | `30` |  |

## NewsMagneto_DuoPro.mq5

### Inputs


*Functionality Controls*

| Input | Type | Default | Description |
|---|---|---|---|
| `entryAtNewBars` | bool | `false,goLong=true,goShort=true,stopsTrailer=false,tpShifter=true,equityLimits=false,` |  |

*Trade Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `tpLeaderPoints` | uint | `15,slTrailerPoints=30,firstEntryPoints=0,postExitEntryPoints=10,` |  |

*Spacer Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstSpacerPoints` | uint | `50,minimumSpacerPoints=5` |  |
| `spacerMultiplier` | double | `0.9` |  |

*Lot Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstLot` | double | `0.3,maxLot=5,lotMultiplier=1.10` |  |

*TP Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstTpPoints` | uint | `100,maximumTpPoints=200` |  |
| `tpMultiplier` | double | `1.10` |  |

*Max and Min filters*

| Input | Type | Default | Description |
|---|---|---|---|
| `startTime` | datetime | `1730768400,stopTime=1730847600` |  |
| `MaxEquity` | double | `5500,MinEquity=6500` |  |
| `signalTimeout` | uint | `480` |  |
| `maxTrades` | int | `30` |  |

*Bar height and body Params*

| Input | Type | Default | Description |
|---|---|---|---|
| `barBodyPoints` | uint | `40,barHeightMinPoints=50,barHeightMaxPoints=650` |  |

## NewsMagneto_Pro.mq5

### Inputs


*Functionality Controls*

| Input | Type | Default | Description |
|---|---|---|---|
| `entryAtNewBars` | bool | `false,goLong=true,goShort=true,stopsTrailer=false,tpShifter=true,equityLimits=false,` |  |

*Trade Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `tpLeaderPoints` | uint | `15,slTrailerPoints=30,firstEntryPoints=0,postExitEntryPoints=10,` |  |

*Spacer Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstSpacerPoints` | uint | `50,minimumSpacerPoints=5` |  |
| `spacerMultiplier` | double | `0.9` |  |

*Lot Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstLot` | double | `0.3,maxLot=5,lotMultiplier=1.10` |  |

*TP Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstTpPoints` | uint | `100,maximumTpPoints=200` |  |
| `tpMultiplier` | double | `1.10` |  |

*Max and Min filters*

| Input | Type | Default | Description |
|---|---|---|---|
| `startTime` | datetime | `1730768400,stopTime=1730847600` |  |
| `MaxEquity` | double | `5500,MinEquity=6500` |  |
| `signalTimeout` | uint | `480` |  |
| `maxTrades` | int | `30` |  |

*Bar height and body Params*

| Input | Type | Default | Description |
|---|---|---|---|
| `barBodyPoints` | uint | `40,barHeightMinPoints=50,barHeightMaxPoints=650` |  |

## Archive

Earlier versions / forks are preserved under [`archive/`](archive/) for reference.

## Install

1. Copy the source file(s) into your MetaTrader 5 `MQL5/` tree (`Experts/`, `Indicators/`, or `Scripts/` as appropriate).
2. In MetaEditor, open the file and compile (**F7**).
3. Attach the compiled program to a chart from the terminal Navigator.

## License

Proprietary and confidential. © Teenodi Ltd. All rights reserved. See [LICENSE](LICENSE).
