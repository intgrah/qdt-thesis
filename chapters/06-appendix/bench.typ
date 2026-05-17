= Synthetic benchmark data <ch:appendix-bench>

This appendix records the per-cycle rebuild times underlying #ref(<sec:incremental-eval>, supplement: none). Each cell is the elapsed milliseconds reported by qdt's `OK (Nms)` line for one edit cycle. Cold rows are the median of five fresh-process invocations; edit rows give eight consecutive flip-flopped cycles under a single watch-mode process.

== Triangle <sec:appendix-bench-triangle>

#figure(
  table(
    columns: (auto, auto, auto, auto, auto, auto, auto, auto, auto, auto),
    align: (left, right, right, right, right, right, right, right, right, right),
    table.header([*N* / *Edit*], [*Cold*], [*1*], [*2*], [*3*], [*4*], [*5*], [*6*], [*7*], [*8*]),
    [25 / leaf body], [23], [6], [6], [8], [7], [5], [6], [6], [5],
    [25 / append/delete], [18], [9], [7], [7], [6], [7], [8], [7], [7],
    [25 / root cascade], [19], [20], [24], [24], [22], [22], [22], [24], [23],
    [50 / leaf body], [84], [15], [16], [16], [17], [18], [18], [15], [16],
    [50 / append/delete], [92], [20], [21], [20], [19], [21], [21], [19], [20],
    [50 / root cascade], [79], [96], [91], [91], [93], [90], [92], [90], [99],
    [100 / leaf body], [416], [65], [64], [56], [73], [57], [73], [63], [74],
    [100 / append/delete], [456], [85], [71], [78], [70], [76], [94], [74], [70],
    [100 / root cascade], [427], [449], [457], [494], [450], [438], [445], [419], [459],
    [200 / leaf body], [1718], [203], [188], [196], [194], [191], [205], [187], [199],
    [200 / append/delete], [1734], [248], [243], [251], [240], [246], [253], [241], [249],
    [200 / root cascade], [1775], [1801], [1789], [1763], [1812], [1779], [1791], [1768], [1808],
    [400 / leaf body], [6927], [548], [540], [537], [551], [539], [545], [532], [549],
    [400 / append/delete], [6982], [739], [731], [728], [742], [725], [734], [736], [728],
    [400 / root cascade], [7011], [7204], [7152], [7187], [7163], [7195], [7128], [7176], [7148],
  ),
  caption: [Triangle: per-edit rebuild times (ms). Cold is median of five fresh-process runs; edits are eight consecutive cycles under one watch-mode process.],
) <fig:appendix-triangle>

== Chain <sec:appendix-bench-chain>

#figure(
  table(
    columns: (auto, auto, auto, auto, auto, auto, auto, auto, auto, auto),
    align: (left, right, right, right, right, right, right, right, right, right),
    table.header([*N* / *Edit*], [*Cold*], [*1*], [*2*], [*3*], [*4*], [*5*], [*6*], [*7*], [*8*]),
    [25 / leaf body], [5], [7], [6], [5], [5], [6], [5], [7], [5],
    [25 / append/delete], [7], [7], [6], [7], [5], [6], [5], [6], [6],
    [25 / root cascade], [5], [5], [5], [5], [6], [7], [6], [6], [7],
    [50 / leaf body], [9], [9], [6], [10], [7], [7], [10], [8], [8],
    [50 / append/delete], [12], [8], [9], [11], [15], [15], [15], [15], [11],
    [50 / root cascade], [9], [8], [7], [8], [7], [7], [8], [7], [10],
    [100 / leaf body], [15], [27], [27], [26], [27], [26], [33], [36], [29],
    [100 / append/delete], [18], [28], [29], [28], [29], [29], [28], [30], [29],
    [100 / root cascade], [15], [27], [27], [29], [29], [29], [27], [29], [26],
    [200 / leaf body], [33], [55], [54], [54], [55], [53], [56], [57], [55],
    [200 / append/delete], [38], [60], [59], [58], [62], [58], [61], [59], [60],
    [200 / root cascade], [33], [55], [54], [54], [56], [55], [53], [54], [55],
    [400 / leaf body], [69], [112], [108], [110], [112], [109], [111], [107], [113],
    [400 / append/delete], [76], [121], [118], [122], [117], [120], [119], [121], [118],
    [400 / root cascade], [69], [112], [110], [109], [111], [110], [113], [112], [108],
  ),
  caption: [Chain: per-edit rebuild times (ms). Cold dominated by parsing; cache verification overhead exceeds elaboration work for $N >= 100$.],
) <fig:appendix-chain>
