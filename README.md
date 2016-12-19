 As soo# Limpeteer
Automatically update materials for Elite Dangerous

Limpeteer is a third party app for Elite Dangerous.

It parses your journal history files and keeps track of material, data, commodity.

Materials are sorted and categorized.

Finally it compares available materials against engineer's blueprints and shows what you can craft. If materials are missing it shows you where to get them.


### Parsed journal events:

* CollectCargo,
* Died,
* EjectCargo,
* EngineerCraft,
* MarketBuy,
* MarketSell,
* MaterialCollected,
* MaterialDiscarded,
* MiningRefined,
* MissionAccepted,
* MissionCompleted,
* Synthesis

### Known issues
FD sometimes uses a funny way to encode material names. E.g. 

`'Core Dynamics Composites' = 'fedcorecomposites'`, 

`'Untypical Shield Scans' = 'shielddensityreports',` 

`'Flawed Focus Crystals' = 'uncutfocuscrystals'`

This makes it unpredictable and a list of clear names needs to be populated. There are still a couple of items missing which did not happen to be within my journal files yet. As soon as I will get those missing entries I will update the code.

### Credits
Credits to inara.cz for providing tons of data
