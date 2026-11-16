# Magneto

News-driven trading robots for MetaTrader 5: NewsMagneto Pro, NewsMagneto DuoPro and a multi-symbol variant that trades from a daily reference line.

> **Proprietary software.** © Teenodi Ltd. All rights reserved. The code is shared for viewing only. It is not licensed for reuse or redistribution. See [LICENSE](LICENSE).

## What it does

- **Trades around the news.** NewsMagneto Pro and DuoPro act on the bar that forms at a news release. The bar must be tall enough and have the right body size to count.
- **Spaces its entries.** A spacer function sets the distance between trades. A lot function sets how the lot size grows.
- **Exits as a group.** A take-profit function closes the whole group of trades at one shared target. A trailing stop and a take-profit shifter are optional.
- **Scales out.** Eth Magneto DuoPro runs many symbols and timeframes at once and reads a daily reference line taken at a set hour and minute.

## Eth_Magneto_DuoPro.mq5

### Inputs


*Functionality Controls*

| Input | Type | Default | Description |
|---|---|---|---|
| `goLong` | bool | `true` |  |
| `goShort` | bool | `true` |  |
| `stopsTrailer` | bool | `false` |  |
| `tpShifter` | bool | `true` |  |
| `equityLimits` | bool | `false` |  |
| `stacksAfterStopTime` | bool | `true` |  |
| `stacksAfterExpiry` | bool | `true` |  |

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
| `tpLeaderPoints` | uint | `15` |  |
| `slTrailerPoints` | uint | `30` |  |
| `slFixPoints` | uint | `0` |  |
| `tpFixPoints` | uint | `250` |  |
| `spreadFilterPoints` | uint | `10` |  |
| `failedCloseSltpPoints` | uint | `2` |  |

*Spacer Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstSpacerPoints` | uint | `50` |  |
| `minimumSpacerPoints` | uint | `5` |  |
| `spacerMultiplier` | double | `0.9` |  |

*Lot Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstLot` | double | `0.3` |  |
| `maxLot` | double | `5` |  |
| `lotMultiplier` | double | `1.10` |  |

*TP Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstTpPoints` | uint | `100` |  |
| `maximumTpPoints` | uint | `200` |  |
| `tpMultiplier` | double | `1.10` |  |

*Max and Min filters*

| Input | Type | Default | Description |
|---|---|---|---|
| `startTime` | datetime | `1730768400` |  |
| `stopTime` | datetime | `1730847600` |  |
| `MaxEquity` | double | `5500` |  |
| `MinEquity` | double | `6500` |  |
| `maxTrades` | int | `30` |  |

## NewsMagneto_DuoPro.mq5

### Inputs


*Functionality Controls*

| Input | Type | Default | Description |
|---|---|---|---|
| `entryAtNewBars` | bool | `false` |  |
| `goLong` | bool | `true` |  |
| `goShort` | bool | `true` |  |
| `stopsTrailer` | bool | `false` |  |
| `tpShifter` | bool | `true` |  |
| `equityLimits` | bool | `false` |  |
| `stacksAfterStopTime` | bool | `true` |  |
| `stacksAfterExpiry` | bool | `true` |  |
| `firstEntryCheckSkip` | bool | `true` |  |
| `calendarChecks` | bool | `false` |  |

*Trade Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `tpLeaderPoints` | uint | `15` |  |
| `slTrailerPoints` | uint | `30` |  |
| `firstEntryPoints` | uint | `0` |  |
| `postExitEntryPoints` | uint | `10` |  |
| `slFixPoints` | uint | `0` |  |
| `tpFixPoints` | uint | `250` |  |
| `spreadFilterPoints` | uint | `10` |  |
| `failedCloseSltpPoints` | uint | `2` |  |

*Spacer Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstSpacerPoints` | uint | `50` |  |
| `minimumSpacerPoints` | uint | `5` |  |
| `spacerMultiplier` | double | `0.9` |  |

*Lot Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstLot` | double | `0.3` |  |
| `maxLot` | double | `5` |  |
| `lotMultiplier` | double | `1.10` |  |

*TP Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstTpPoints` | uint | `100` |  |
| `maximumTpPoints` | uint | `200` |  |
| `tpMultiplier` | double | `1.10` |  |

*Max and Min filters*

| Input | Type | Default | Description |
|---|---|---|---|
| `startTime` | datetime | `1730768400` |  |
| `stopTime` | datetime | `1730847600` |  |
| `MaxEquity` | double | `5500` |  |
| `MinEquity` | double | `6500` |  |
| `signalTimeout` | uint | `480` |  |
| `maxTrades` | int | `30` |  |

*Bar height and body Params*

| Input | Type | Default | Description |
|---|---|---|---|
| `barBodyPoints` | uint | `40` |  |
| `barHeightMinPoints` | uint | `50` |  |
| `barHeightMaxPoints` | uint | `650` |  |

## NewsMagneto_Pro.mq5

### Inputs


*Functionality Controls*

| Input | Type | Default | Description |
|---|---|---|---|
| `entryAtNewBars` | bool | `false` |  |
| `goLong` | bool | `true` |  |
| `goShort` | bool | `true` |  |
| `stopsTrailer` | bool | `false` |  |
| `tpShifter` | bool | `true` |  |
| `equityLimits` | bool | `false` |  |
| `stacksAfterStopTime` | bool | `true` |  |
| `stacksAfterExpiry` | bool | `true` |  |
| `firstEntryCheckSkip` | bool | `true` |  |
| `calendarChecks` | bool | `false` |  |

*Trade Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `tpLeaderPoints` | uint | `15` |  |
| `slTrailerPoints` | uint | `30` |  |
| `firstEntryPoints` | uint | `0` |  |
| `postExitEntryPoints` | uint | `10` |  |
| `slFixPoints` | uint | `0` |  |
| `tpFixPoints` | uint | `250` |  |
| `spreadFilterPoints` | uint | `10` |  |
| `failedCloseSltpPoints` | uint | `2` |  |

*Spacer Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstSpacerPoints` | uint | `50` |  |
| `minimumSpacerPoints` | uint | `5` |  |
| `spacerMultiplier` | double | `0.9` |  |

*Lot Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstLot` | double | `0.3` |  |
| `maxLot` | double | `5` |  |
| `lotMultiplier` | double | `1.10` |  |

*TP Function Settings*

| Input | Type | Default | Description |
|---|---|---|---|
| `firstTpPoints` | uint | `100` |  |
| `maximumTpPoints` | uint | `200` |  |
| `tpMultiplier` | double | `1.10` |  |

*Max and Min filters*

| Input | Type | Default | Description |
|---|---|---|---|
| `startTime` | datetime | `1730768400` |  |
| `stopTime` | datetime | `1730847600` |  |
| `MaxEquity` | double | `5500` |  |
| `MinEquity` | double | `6500` |  |
| `signalTimeout` | uint | `480` |  |
| `maxTrades` | int | `30` |  |

*Bar height and body Params*

| Input | Type | Default | Description |
|---|---|---|---|
| `barBodyPoints` | uint | `40` |  |
| `barHeightMinPoints` | uint | `50` |  |
| `barHeightMaxPoints` | uint | `650` |  |

## Archive

Earlier versions / forks are preserved under [`archive/`](archive/) for reference.

## Install

1. Copy the source file(s) into your MetaTrader 5 `MQL5/` tree (`Experts/`, `Indicators/`, or `Scripts/` as appropriate).
2. In MetaEditor, open the file and compile (**F7**).
3. Attach the compiled program to a chart from the terminal Navigator.

## Risk note

Trading carries risk. This code shows how the strategy is built. It is not financial advice.

## License

Proprietary. © Teenodi Ltd. All rights reserved. The code is shared for viewing only. See [LICENSE](LICENSE).
