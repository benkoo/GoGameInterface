extensions [table]

breed [boardspaces boardspace]
breed [whitepieces whitepiece]
breed [blackpieces blackpiece]

;; Note that once you created certain breed of links, all links must be given a special breed.
undirected-link-breed [lineLinks lineLink]

;;These are special types of links between white and black pieces of chess.
undirected-link-breed [white-links white-link]
undirected-link-breed [black-links black-link]

;;Declare global variables
globals [mouse-clicked? isBlack? num_lines currentNumberOfLinkedPieces koX koY]

;; When using HubNet features, the startup procedure must be delcared and run the hubnet-reset instruction
;to startup
;  hubnet-reset
;end

to setup
  clear-all
  reset-ticks
  set isBlack? true
  set num_lines 19 ;; Set the chess board to have num_lines * num_lines lines
  resize-world 0 num_lines 0 num_lines
  set currentNumberOfLinkedPieces 0
  set koX -1
  set koY -1

  ;import-drawing "img/wood.jpg"

  ;;Draw the grid
  drawXYGrid

end

;; Draw XY Grid
to drawXYGrid
  ask patches [
    sprout-boardspaces 1 [
      set color white
      set shape "circle"
      set size 0
    ]
  ]

  ask turtles [
    create-lineLinks-with other turtles with [distance myself = 1] [
      set thickness 0.07
    ]
  ]
end

to go
  mouse-manager
end


to mouse-manager
  ;; A list to keep track of potential kills
  let deadChessList []

  ifelse mouse-down? [
    ;; The following code structure ensure that once mouse is clicked once, the following
    ;; activities are only executed once.
    if not mouse-clicked? [

      set mouse-clicked? true
      let mX (round mouse-xcor)
      let mY (round mouse-ycor)

      ;Black and white pieces are being created in turns.
      ;; Note that canDealHand? is a function that must use patch or turtle as its operating context, I have not figure out why, yet.
      if canDealHand? mX mY isBlack?[

          ;; Knowing that this is a legitimate move, clear the koX and koY status
          set koX -1
          set koY -1

          ;; Before placing the chess piece on board, clear the board with dying enemy chess pieces.
          set deadChessList (findEnemyPiecesForKill mX mY isBlack?)

          ;;If only one enemy chess piece is found for kill, then, mark this to be the koX and koY location.
          if 1 = length deadChessList [
            let aChess last deadChessList
            set koX [xcor] of aChess
            set koY [ycor] of aChess
          ]

          ;;After marking koX and koY location if any, then, kill all the enemy chess pieces that are eligible for removal.
          foreach deadChessList [ aChess ->
            ask aChess [
              die
            ]
          ]

          ifelse isBlack? [
            create-blackpieces 1 [
              dealOneHandofChess red
            ]
            set isBlack? false
          ][
            create-whitepieces 1 [
              dealOneHandofChess white
            ]
            set isBlack? true
          ]
      ]; if canDealHand?[]


    ]; if not mouse-clicked[]

  ] ;if mouse-clicked? [1]
  [
    set mouse-clicked? false
  ] ;if mouse-clicked? [2]
end


to showXY
  ;setxy mouse-xcor mouse-ycor
  let mX (round mouse-xcor)
  let mY (round mouse-ycor)
  ;show word mX word "," mY
  ask patch mX mY [
    set pcolor blue
    ;wait 0.1
    set pcolor black
    ask whitepieces in-radius 0 [
      set pcolor yellow
    ]
  ]
end

;;This procedure is to set up the location and links with other pieces
to dealOneHandofChess [myColor]

  ;Change the shape and size of the chess piece
  set shape "circle"
  set size 0.5

  set color myColor

  ;setxy mouse-xcor mouse-ycor
  let mX (round mouse-xcor)
  let mY (round mouse-ycor)

  setxy mX mY

  markNodeListInColor sort boardspaces blue

  ifelse (myColor = white) [
    create-white-links-with other whitepieces in-radius 1 [
      ;set color blue
      set thickness 0.2
    ]

    ask one-of whitepieces in-radius 0 [
        ;ask link-neighbors [ set color green ]
        set currentNumberOfLinkedPieces count link-neighbors
    ]

  ][
    create-black-links-with other blackpieces in-radius 1 [
      ;set color yellow
      set thickness 0.2
    ]

    ask one-of blackpieces in-radius 0 [
        ;ask link-neighbors [ set color cyan ]
        set currentNumberOfLinkedPieces count link-neighbors
    ]
  ]
end

;; This function provides the overall logical structure to determine whether one may or may not deal hand.
to-report canDealHand? [x y chess_is_black?]

  let isSurrounded? false
  let patchEmpty? true
  let hasEnemyToKill? false


  let chess_color "white"
  let friendlyCount 0
  let enemyCount 0
  let spaceCount 0

  let isLastFriendlyEmptySpot? isLastEmptySpaceOfColor? x y false

  ask patch x y [
    set spaceCount count boardspaces in-radius 1

    set friendlyCount count whitepieces in-radius 1
    set enemyCount count blackpieces in-radius 1

    if (chess_is_black?)[
      set chess_color "black"
      set friendlyCount count blackpieces in-radius 1
      set enemyCount count whitepieces in-radius 1
      set isLastFriendlyEmptySpot? isLastEmptySpaceOfColor? x y true
    ]
  ]

  if isLastFriendlyEmptySpot?[
    ;; Check if this spot has more non-occupied spaces
    if (spaceCount - (friendlyCount + enemyCount)) > 1[
      set isLastFriendlyEmptySpot? false
    ]

    let piecesToBeKilled findEnemyPiecesForKill x y chess_is_black?
    if (0 < length piecesToBeKilled ) [
      set hasEnemyToKill? true
    ]
  ]



  let okToDeal true
  set patchEmpty? (isPatchEmpty? x y)
  set okToDeal patchEmpty? and (not isLastFriendlyEmptySpot?) or hasEnemyToKill?

  ifelse not okToDeal [
    if not patchEmpty?[
      user-message word "The location " word x word ", " word y " is occupied!"
    ]

    if isLastFriendlyEmptySpot?[
      user-message word "The location is the last empty spot (chi) for the friendly " word chess_color " pieces"
    ]
  ][
    ;; if this is allowed to deal, check if this violates the ko condition
    if (koX = x) and (koY = y)[
      let piecesToBeKilled findEnemyPiecesForKill x y chess_is_black?
      if (1 = length piecesToBeKilled)[
        set okToDeal false
        user-message word "This piece place on " word x word ", " word y " is a violation of the Ko rule."
      ]
    ]
  ]

  report okToDeal
end

;; This procedure checks if the selected location is completely surrounded by Enemy or not
to-report findEnemyPiecesForKill [mX mY is_black?]

  let chessList []
  let neighboringEnemyChessList []
  let deadChessList []

  show list mX mY

  ifelse is_black? [
    set chessList whitepieces  ;; For black being placed at mX mY, search for whitepieces
  ][
    set chessList blackpieces  ;; For white being placed at mX mY, search for blackpieces
  ]

  ;;This code block will create neighboringEnemyChessList that contains the opponents' immeidately adjaceny chess pieces
  ask patch mX mY [
    ask chessList in-radius 1 [
      if not member? self neighboringEnemyChessList  [
        set neighboringEnemyChessList lput self neighboringEnemyChessList
      ]
    ]
  ]

  ;;Go through each immediately adjaceny enemy chess piece, and see if it is eligible for kill.
  foreach neighboringEnemyChessList [ enemyChess ->

    ;;Find all connected enemy pieces starting from the chosen "enemyChess"
    let connectedEnemies findNeighbors (list enemyChess)

    ;;Evaluate to know how many remaining chi that this branch of chess has
    let emptySpots findChis connectedEnemies
    let spaceCount length emptySpots ;;This is set to a large number, so that we know that it is not 1 or 0

    ;;If the only available chi (spaceCount = 1) is the empty spot to be occupied, we can start constructing a deadChessList
    if (spaceCount = 1)[
      ;; user-message (word "Is surrounded by chess with " word spaceCount " chi." )
      ;; If the surrounded ememy chess only has one chi left, then send "die" message to all of them
      foreach connectedEnemies [ aChess ->
        if not member? aChess deadChessList [
          set deadChessList lput aChess deadChessList
        ]
      ]
    ]
  ]

  report deadChessList

end

;A neighbor search function that identifies all chesspieces of same color that are connected
to-report findNeighbors [ nodeList ]
  let aList nodeList
  let initialCount 0

  while [initialCount < length aList]
  [
  set initialCount length aList
  foreach aList [ vNode ->
      ask vNode [
        ask link-neighbors [
          if not member? self aList  [
            set aList lput self aList
          ]
        ]
      ]
    ]
  ]
  report aList

end

;; Given a list of black or white pieces,
;; find all the boardspaces next to them
;; and return them in a list.
to-report findChis [ nodeList ]
  let newList []

  foreach nodeList [ vNode ->
    ask vNode[
      ask boardspaces in-radius 1 [
          if not member? self newList  [
            ;;Check if aSpace is an instance of breed boardspaces
            ifelse is-boardspace? self [
              let mX ([xcor] of self)
              let mY ([ycor] of self)
              if isPatchEmpty? mX mY[
                set newList lput self newList
              ]
            ][
              user-message (word "This is not an instance of boardspace" self)
            ]
          ]
      ]
   ]
  ]

  report newList

end

;; Given black or white choices,
;; return a boolean value indicating whether
to-report isLastEmptySpaceOfColor? [mX mY isBlackPiece?]
  let isLastEmptySpot? false

  ask patch mX mY [

    let spaceCount count boardspaces in-radius 1
    let friendlyCount count whitepieces in-radius 1
    let enemyCount count blackpieces in-radius 1

    let friendlyPieces whitepieces
    if isBlackPiece? [
      set friendlyPieces blackpieces
      set friendlyCount count blackpieces in-radius 1
      set enemyCount count whitepieces in-radius 1
    ]

    let neighbhorpieces friendlyPieces in-radius 1

    let nbs findNeighbors sort neighbhorpieces
    let availableChis findChis nbs
    markNodeListInColor availableChis cyan
    if 1 >= length availableChis[
      set isLastEmptySpot? true
    ]

    if (enemyCount >= (spaceCount - 1))[
      set isLastEmptySpot? true
    ]
  ]
  report isLastEmptySpot?
end


to-report isPatchEmpty? [mX mY]
  let emptyStatus? false

  ;;Check if anEmptySpace is an instance of breed boardspaces

    let totalCount 0
    ask patch mX mY [
      ask whitepieces in-radius 0 [
        set totalCount 1 + totalCount
      ]

      ask blackpieces in-radius 0 [
        set totalCount 1 + totalCount
      ]

      ifelse totalCount = 0 [
        set emptyStatus? true
      ][
        set emptyStatus? false
      ]
    ]

  report emptyStatus?

end


to markNodeListInColor [turtleList aColor]
  foreach turtleList [anObj ->
    ask anObj [
      set color aColor
      set shape "circle"
      set size 0.2
    ]
  ]
end

to-report numBlacks
  report count blackpieces
end

to-report numWhites
  report count whitepieces
end

to-report currentlyLinkedNodes
  report currentNumberOfLinkedPieces
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
750
551
-1
-1
26.64
1
10
1
1
1
0
0
0
1
0
19
0
19
0
0
1
ticks
30.0

BUTTON
21
99
92
132
Set Up
setup
NIL
1
T
OBSERVER
NIL
A
NIL
NIL
1

BUTTON
102
100
165
133
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
782
23
902
68
Number of Blacks
numBlacks
17
1
11

MONITOR
782
497
905
542
Number of Whites
numWhites
17
1
11

MONITOR
23
40
181
85
Currently Linked Nodes
currentlyLinkedNodes
17
1
11

@#$#@#$#@
## WHAT IS IT?

A networked Go playing program designed to demonstrate many programming concepts in NetLogo, including the HubNet infrastructure. 

## HOW IT WORKS

The Go game should allow players to use mouse cursors to play black and white pieces in turn. The black side should always go first, then white, etc... Then we will follow the rule of Go.

## HOW TO USE IT

Curently, this system requires both players to use the same computer (usually the same mouse or trackpad), to play a game. As it adds HubNet features, it will allow multiple users to play over the network. 

## THINGS TO NOTICE

This program shows you how to leverage the notion of Patches, Links, and Turtle (agent) breeds to represent the game of Go. However, by implementing the Go game using our example, you will understand many idioms commonly used in NetLogo programming langauge.

## THINGS TO TRY

The goal of this program is to serve as a basis for increasingly more flexible usage of the same code base. That means, this code can be incrementally optimized to handle other use case for Go or Black-White chess games. Moreover, it should be able to be used as a visualization tool for historical games.

## EXTENDING THE MODEL

We plan to integrate the Go Chess Playing algorithm as a part of this system. This must be integrated with some external programs, such as Python or Mathematica. Currently, we know that it is possible to integrate this NetLogo implementation in a static HTML page with JavaScript as embedded NetLogo run time. We plan to add a network module to enable the communication of two or more machines to interactively play using a Browser as the common delivery mechanism.

## NETLOGO FEATURES

NetLogo is a Spatial Temporal Programming language, that means, its agent structures are designed to enable multiple discrete agents, interacting in patch-based environments. This kind of programming features is particularly conducive to the Go game. Therefore, implementing or studying the code for implementing Go game is an ideal starting point to learn NetLogo.

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
BUTTON
19
82
99
115
dsafdsa
NIL
NIL
1
T
OBSERVER
NIL
NIL

VIEW
258
145
791
678
0
0
0
1
1
1
1
1
0
1
1
1
0
19
0
19

@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@