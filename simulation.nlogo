;===== Globals and Agent Variables =====
globals [
  origin-points         ; List of starting locations
  destination-points    ; List of ending locations
  total-accidents       ; Total number of accidents
  total-scooter-usage   ; Total active scooters
  average-congestion    ; Average congestion level
  total-arrival-time
  total-arrivals
  average-arrival-time
]

turtles-own [
  destination-road-x
  destination-road-y
  destination-footpath-x
  destination-footpath-y
  start-x
  start-y
  start-time
  scooter-lane?
  safety-level
  car-speed
  scooter-speed
  people-speed
  arrival-time
  helmet-wearing
  involved-in-accident?
  to-die?
]

patches-own [
  lane-type   ; "road", "scooter-lane", "intersection", "roundabout", "grass"
  occupied?   ; Whether the patch is currently occupied by an agent
]

;===== Setup =====

to setup
  clear-all                      ; Clear the simulation
  resize-world -30 30 -30 30     ; Set the world size
  setup-patches                  ; Initialize patches
  setup-people                   ; Initialize people agents
  setup-cars                     ; Initialize car agents
  setup-scooters                 ; Initialize scooter agents
  reset-ticks                     ; Reset the tick counter
  set total-accidents 0
  set total-scooter-usage 0
  set average-congestion 0
  set total-arrivals 0
  set total-arrival-time 0
end

to setup-patches
  ; Set default lane-type to grass
  ask patches [ set lane-type "grass" ]

  ; Define main horizontal roads every 7 patches
  ask patches with [ pycor mod 7 = 0 ] [
    set lane-type "road"
  ]

  ; Define main vertical roads every 7 patches
  ask patches with [ pxcor mod 7 = 0 ] [
    set lane-type "road"
  ]

  ; Define intersections at road crossings
  ask patches with [ (pxcor mod 7 = 0) and (pycor mod 7 = 0) ] [
    set lane-type "intersection"
  ]

  ; Define scooter lanes alongside main horizontal roads
  ask patches with [ pycor mod 7 = 1 ] [
    set lane-type "scooter-lane"
  ]

  ; Define scooter lanes alongside main vertical roads
  ask patches with [ pxcor mod 7 = 1 ] [
    set lane-type "scooter-lane"
  ]

  ; Define scooter intersections where horizontal and vertical scooter lanes meet
  ask patches with [ pycor mod 7 = 1 and pxcor mod 7 = 1 ] [
    set lane-type "scooter-intersection"
  ]

  ; Visualize the lanes with colors
  ask patches [
    if lane-type = "road" [ set pcolor gray ]
    if lane-type = "scooter-lane" [ set pcolor blue ]
    if lane-type = "scooter-intersection" [ set pcolor rgb 80 80 255 ]
    if lane-type = "grass" [ set pcolor brown ]
  ]

  ; Change scooter lanes to crossings if adjacent to intersections and roads
  ; Set crossings to white patch
  ask patches with [ lane-type = "scooter-lane" or lane-type = "scooter-intersection" ] [
    if any? neighbors4 with [ lane-type = "intersection" ] and any? neighbors with [ pcolor = gray ] [
      set lane-type "crossing"
      set pcolor white
    ]
  ]

  ; Assign traffic light colors to intersections
  ask patches with [lane-type = "intersection"] [
    let patch-sum (pxcor + pycor) mod 3
    if (patch-sum = 0) [ set pcolor red ]
    if (patch-sum = 1) [ set pcolor yellow ]
    if (patch-sum = 2) [ set pcolor green ]
  ]

  ; Define origin and destination points on roads
  set origin-points patches with [ pxcor = min-pxcor and lane-type = "road" ]
  set destination-points patches with [ pxcor = max-pxcor and lane-type = "road" ]
end

to setup-cars
  create-turtles number-of-cars [
    setxy random-xcor random-ycor
    ;; Ensure cars are placed on road patches
    while [ pcolor != gray ] [
      setxy random-xcor random-ycor
      setxy pxcor pycor
    ]

    ;; Assign a random road patch as destination
    let destination one-of destination-points
    set destination-road-x [pxcor] of destination
    set destination-road-y [pycor] of destination

    ask patch destination-road-x destination-road-y [
      set pcolor sky  ; Mark destination patch visually
    ]

    ;; Determine heading based on neighboring roads
    let neighboring-roads neighbors with [ lane-type = "road" or lane-type = "intersection" ]
    if any? neighboring-roads [
      ; Vertical roads: face north or south
      if any? neighboring-roads with [ pycor = [pycor] of myself + 1 or pycor = [pycor] of myself - 1 ] [
        set heading one-of [0 180]
      ]
      ; Horizontal roads: face east or west
      if any? neighboring-roads with [ pxcor = [pxcor] of myself + 1 or pxcor = [pxcor] of myself - 1 ] [
        set heading one-of [90 270]
      ]
    ]

    set shape "car"      ; Set agent shape to car
    set color blue       ; Set car color to blue

    set car-speed random-normal car-speed-slider (car-speed-slider / 4)
    if car-speed < 0 [set car-speed 0]
    if car-speed > 0.1 [set car-speed 0.1]

    set safety-level safety-level-slider
    set arrival-time 0
  ]
end

to setup-people
  create-turtles number-of-people [
    setxy random-xcor random-ycor
    ;; Ensure people are placed on scooter lanes
    while [ pcolor != blue ] [
      setxy random-xcor random-ycor
      setxy pxcor pycor
    ]

    set start-x pxcor
    set start-y pycor

    ;; Assign a random scooter lane patch as destination
    let destination patch random-xcor random-ycor
    while [[pcolor] of destination != blue ] [
      set destination patch random-xcor random-ycor
    ]

    set destination-footpath-x [pxcor] of destination
    set destination-footpath-y [pycor] of destination

    ask patch destination-footpath-x destination-footpath-y [
      set pcolor sky  ; Mark destination patch visually
    ]

    ;; Assign a road destination near the footpath
    let road-destination patch random-xcor random-ycor
    ask patch destination-footpath-x destination-footpath-y [
      ask neighbors [
        if pcolor = gray or pcolor = white [
          set road-destination patch pxcor pycor
        ]
      ]
    ]

    set destination-road-x [pxcor] of road-destination
    set destination-road-y [pycor] of road-destination

    ;; Determine heading based on neighboring scooter lanes
    let neighboring-roads neighbors with [pcolor = blue or pcolor = white]

    if any? neighboring-roads [
      ; Vertical lanes: face north or south
      if any? neighboring-roads with [pycor = [pycor] of myself + 1 or pycor = [pycor] of myself - 1] [
        ifelse pxcor < destination-footpath-x [
          set heading 180  ; Face south
        ] [
          set heading 0    ; Face north
        ]
      ]
      ; Horizontal lanes: face east or west
      if any? neighboring-roads with [pxcor = [pxcor] of myself + 1 or pxcor = [pxcor] of myself - 1] [
        ifelse pxcor > destination-footpath-x [
          set heading 270  ; Face west
        ] [
          set heading 90   ; Face east
        ]
      ]
    ]

    set shape "person"   ; Set agent shape to person
    set color black      ; Set person color to black
    set people-speed random-normal 0.02 0.01
    if people-speed < 0 [set people-speed 0]
    if people-speed > 0.5 [set people-speed 0.5]
  ]
end

to setup-scooters
  create-turtles number-of-scooters [
    ; Position the scooter on a random blue patch
    setxy random-xcor random-ycor
    while [lane-type != "scooter-lane"] [
      setxy random-xcor random-ycor
    ]
    set start-x pxcor
    set start-y pycor

    ; Assign a random scooter lane patch as destination
    let destination one-of patches with [pcolor = blue]
    while [[pcolor] of destination != blue] [
      set destination patch random-xcor random-ycor
    ]

    set destination-footpath-x [pxcor] of destination
    set destination-footpath-y [pycor] of destination

    ;; Do not alter the destination patch color
    ask patch destination-footpath-x destination-footpath-y [
      set pcolor lime
    ]

    ;; Assign a road destination near the footpath
    let road-destination patch random-xcor random-ycor
    ask patch destination-footpath-x destination-footpath-y [
      ask neighbors [
        if pcolor = gray or pcolor = white [
          set road-destination patch pxcor pycor
        ]
      ]
    ]

    set destination-road-x [pxcor] of road-destination
    set destination-road-y [pycor] of road-destination

    ;; Determine initial heading based on neighboring scooter lanes
    let neighboring-roads neighbors with [pcolor = blue]

    if any? neighboring-roads [
      ; Vertical lanes: face north or south
      if any? neighboring-roads with [pycor = [pycor] of myself + 1 or pycor = [pycor] of myself - 1] [
        set heading one-of [0 180]
      ]
      ; Horizontal lanes: face east or west
      if any? neighboring-roads with [pxcor = [pxcor] of myself + 1 or pxcor = [pxcor] of myself - 1] [
        set heading one-of [90 270]
      ]
    ]

    set shape "default"    ; Set agent shape to default (scooter)
    set color red        ; Set scooter color to green
    set scooter-lane? true ; Indicate scooter is on a scooter lane

    set safety-level safety-level-slider
    set scooter-speed scooter-speed-slider
    set helmet-wearing random-float 1 < helmet-usage-slider
    set size 2

    set scooter-speed random-normal scooter-speed-slider (scooter-speed-slider / 4)
    if scooter-speed < 0 [set scooter-speed 0]
    if scooter-speed > 0.1 [set scooter-speed 0.1]
  ]
end

;===== Go =====

to go
  ; Check the termination conditions
  if not any? turtles or ticks >= 50000 [
    stop
  ]

  move-cars           ; Move car agents
  move-people         ; Move people agents
  move-scooters       ; Move scooter agents

  update-congestion
  detect-accidents
  calculate-average-arrival-time

  change-lane         ; Possibly change lanes for scooters/cars
  change-lights       ; Update traffic light colors
  tick                ; Advance the simulation clock
end

to move-cars
  ask turtles [
    ; Ensure the turtle is a car by checking its shape
    if shape = "car" [

      let change-x 0
      let change-y 0

      ; Determine movement direction based on heading
      if heading = 0 [ set change-y 1 ]    ; North
      if heading = 90 [ set change-x 1 ]   ; East
      if heading = 180 [ set change-y -1 ] ; South
      if heading = 270 [ set change-x -1 ] ; West

      let next-patch patch-at change-x change-y
      let color-of-next-patch [pcolor] of next-patch
      let next-patch-lane-type [lane-type] of next-patch  ; Check lane-type of the next patch

      print (word "Color of next patch: " color-of-next-patch)
      ; Check for red or yellow traffic lights
      ifelse (color-of-next-patch = red) or (color-of-next-patch = yellow) [
        ; Handle red or yellow light
        print "Car stopped due to red/yellow light."
      ] [

        ; Allow movement through road, crossing, or intersection patches
        if (next-patch-lane-type = "road" or next-patch-lane-type = "crossing" or next-patch-lane-type = "intersection")[
          fd car-speed   ; Move forward on road or crossing
          print "Car moved forward."

          ; Only update heading **after** moving forward
          ; Update heading towards destination only if car has moved
          if lane-type = "intersection"[
            ifelse abs(pxcor - destination-road-x) > abs(pycor - destination-road-y) [
              if pxcor < destination-road-x [ set heading 90 ]    ; East
              if pxcor > destination-road-x [ set heading 270 ]   ; West
            ] [
              if pycor < destination-road-y [ set heading 0 ]     ; North
              if pycor > destination-road-y [ set heading 180 ]   ; South
            ]
            print (word "Car updated heading to " heading)
          ]
          ; Remove car upon reaching destination
          if pxcor = destination-road-x and pycor = destination-road-y [
            ;; Calculate arrival time
            set arrival-time ticks - start-time
            ;; Update total arrival time and arrivals count
            set total-arrival-time total-arrival-time + arrival-time
            set total-arrivals total-arrivals + 1
            die
            print "Car has reached its destination and is removed."
          ]
        ]
      ]
    ]
  ]
end

to move-people
  ask turtles [
    ; Ensure the turtle is a person by checking its shape
    if shape = "person" [

      let change-x 0
      let change-y 0

      ; Determine movement direction based on heading
      if heading = 0 [ set change-y 1 ]    ; North
      if heading = 90 [ set change-x 1 ]   ; East
      if heading = 180 [ set change-y -1 ] ; South
      if heading = 270 [ set change-x -1 ] ; West

      let color-of-next-patch [pcolor] of patch-at change-x change-y

      ifelse (color-of-next-patch = white) [
        let nearby-cars turtles with [shape = "car" and distance myself < 3]

        ifelse any? nearby-cars [
          ;; Stop if cars are nearby
        ] [
          ;; Move forward if no cars are nearby
          fd people-speed
        ]
      ] [
        ;; Move forward if the patch is not a crosswalk
        fd people-speed
      ]

      ; Update heading towards destination footpath if on scooter-intersection
      if pcolor = rgb 80 80 255 [
        ifelse abs(pxcor - destination-footpath-x) > abs(pycor - destination-footpath-y) [
          if pxcor < destination-footpath-x [ set heading 90 ]
          if pxcor > destination-footpath-x [ set heading 270 ]
        ] [
          if pycor < destination-footpath-y [ set heading 0 ]
          if pycor > destination-footpath-y [ set heading 180 ]
        ]
      ]

      ; Remove person upon reaching destination
      if pxcor = destination-footpath-x and pycor = destination-footpath-y [
        ;; Calculate arrival time
        set arrival-time ticks - start-time
        ;; Update total arrival time and arrivals count
        set total-arrival-time total-arrival-time + arrival-time
        set total-arrivals total-arrivals + 1
        die
      ]
    ]
  ]
end

to move-scooters
  ask turtles with [shape = "default"] [
    ; Check if the scooter has reached its destination

    let change-x 0
    let change-y 0

    ; Determine movement direction based on heading
    if (heading = 0)   [ set change-y  1 ] ; North
    if (heading = 90)  [ set change-x  1 ] ; East
    if (heading = 180) [ set change-y -1 ] ; South
    if (heading = 270) [ set change-x -1 ] ; West

    let next-patch patch-at change-x change-y
    let color-of-next-patch [pcolor] of next-patch

    ifelse scooter-lane? [ ;; Move in scooter lane
      ifelse (color-of-next-patch = white) [
        let nearby-cars turtles with [shape = "car" and distance myself < 3]

        ifelse any? nearby-cars [
          ;; Stop if cars are nearby
        ] [
          ;; Move forward if no cars are nearby
          fd scooter-speed
        ]
      ] [
        ;; Move forward if the patch is not a crosswalk
        fd scooter-speed
      ]

      ; Update heading towards destination footpath if on scooter-intersection
      if pcolor = rgb 80 80 255 [
        ifelse abs(pxcor - destination-footpath-x) > abs(pycor - destination-footpath-y) [
          if pxcor < destination-footpath-x [ set heading 90 ]
          if pxcor > destination-footpath-x [ set heading 270 ]
        ] [
          if pycor < destination-footpath-y [ set heading 0 ]
          if pycor > destination-footpath-y [ set heading 180 ]
        ]
      ]

    ] [ ;; Move on road
      ifelse (color-of-next-patch = red) or (color-of-next-patch = yellow) [
        ;; Handle red or yellow light (e.g., stop or prepare to stop)
      ] [
        if pcolor = green [
          fd scooter-speed  ; Move forward if light is green
        ]

        ; Update heading towards road destination
        if pcolor = green [
          ifelse abs(pxcor - destination-road-x) > abs(pycor - destination-road-y) [
            if pxcor < destination-road-x [ set heading 90 ]
            if pxcor > destination-road-x [ set heading 270 ]
          ] [
            if pycor < destination-road-y [ set heading 0 ]
            if pycor > destination-road-y [ set heading 180 ]
          ]
        ]
      ]

      ; Remove scooter upon reaching any destination
      if ((pxcor = destination-footpath-x) and (pycor = destination-footpath-y)) or
         ((pxcor = destination-road-x) and (pycor = destination-road-y)) [
        ;; Calculate arrival time
        set arrival-time ticks - start-time
        ;; Update total arrival time and arrivals count
        set total-arrival-time total-arrival-time + arrival-time
        set total-arrivals total-arrivals + 1
        die
      ]
    ]
  ]
end

to change-lights
  if ticks mod 30 = 0 [
    ;; Cycle traffic light colors
    ask patches with [pcolor = red] [
      set pcolor black
    ]
    ask patches with [pcolor = yellow] [
      set pcolor red
    ]
    ask patches with [pcolor = green] [
      set pcolor yellow
    ]
    ask patches with [pcolor = black] [
      set pcolor green
    ]
  ]
end

to change-lane
  if (ticks mod 1000) = 0 [
    ask turtles with [shape = "default"] [
      let change? false
      let new-x 0
      let new-y 0

      ifelse scooter-lane? [
        ; Attempt to change from scooter lane to road
        if random-float 1 > safety-level [
          ask patch pxcor pycor [
            ask neighbors [
              if pcolor = gray or pcolor = white [
                set new-x pxcor
                set new-y pycor
                set change? true
              ]
            ]
          ]
        ]
      ] [
        ; Attempt to change from road to scooter lane
        if random-float 1 > safety-level [
          ask patch pxcor pycor [
            ask neighbors [
              if pcolor = blue or pcolor = rgb 80 80 255 [
                set new-x pxcor
                set new-y pycor
                set change? true
              ]
            ]
          ]
        ]
      ]

      ; Execute lane change if possible
      if change? [
        setxy new-x new-y
        ifelse scooter-lane? [
          set scooter-lane? false
        ] [
          set scooter-lane? true
        ]
      ]
    ]
  ]
end

;===== Congestion Measurement Submodel =====

to update-congestion
  ;; Calculate the average number of agents per road patch
  let total-road-patches count patches with [lane-type = "road" or lane-type = "intersection" or lane-type = "crossing"]
  let agents-on-road count turtles with [
    [lane-type] of patch-here = "road" or
    [lane-type] of patch-here = "intersection" or
    [lane-type] of patch-here = "crossing"
  ]
  if total-road-patches > 0 [
    set average-congestion agents-on-road / total-road-patches
  ]
end

;===== Accident Rate Submodel =====

to detect-accidents
  ;; Reset accident status
  ask turtles [
    set involved-in-accident? false
    set to-die? false
  ]

  ;; Create a list of all turtles to iterate over pairs
  let turtle-list sort turtles

  ;; Iterate over each turtle
  while [not empty? turtle-list] [
    let turtle1 first turtle-list
    set turtle-list but-first turtle-list  ; Remove turtle1 from the list

    ;; Proceed only if turtle1 is not marked to die
    if [to-die?] of turtle1 = false [
      ;; Convert the remaining turtle-list to an agentset
      let remaining-turtles turtle-set turtle-list

      ;; Find other turtles within collision distance
      let nearby-turtles remaining-turtles with [
        distance turtle1 <= 1 and not involved-in-accident? and to-die? = false
      ]

      ;; Evaluate potential accidents with each nearby turtle
      ask nearby-turtles [
        ;; Ensure turtle1 is still alive and not marked to die
        if [to-die?] of turtle1 = false [
          ;; Calculate combined safety level
          let combined-safety-level (safety-level + [safety-level] of turtle1) / 2
          ;; Define accident probability
          let accident-probability (1 - combined-safety-level)
          ;; Adjust for agent types if desired
          if (shape = "car" and [shape] of turtle1 = "default") or
             (shape = "default" and [shape] of turtle1 = "car") [
            set accident-probability accident-probability * 1.5  ; Increase risk
          ]
          ;; Ensure probability is between 0 and 1
          if accident-probability < 0 [ set accident-probability 0 ]
          if accident-probability > 1 [ set accident-probability 1 ]
          ;; Probabilistic accident occurrence
          if random-float 1 < accident-probability [
            ;; Mark both agents as involved in an accident
            set involved-in-accident? true
            set to-die? true
            ask turtle1 [
              set involved-in-accident? true
              set to-die? true
            ]
            ;; Increment total accidents
            set total-accidents total-accidents + 1
            ;; Mark the accident location
            ;ask patch-here [ set pcolor violet ]
            ;; Exit the loop to prevent further interactions
            stop
          ]
        ]
      ]
    ]
  ]

  ;; After all interactions, remove turtles that are marked to die
  ask turtles with [to-die?] [
    die
  ]
end

;===== Arrival Time Tracking Submodel =====

to calculate-average-arrival-time
  if total-arrivals > 0 [
    set average-arrival-time total-arrival-time / total-arrivals
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
359
11
871
524
-1
-1
8.2623
1
10
1
1
1
0
1
1
1
-30
30
-30
30
0
0
1
ticks
30.0

BUTTON
183
257
249
290
NIL
setup\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
183
296
250
329
NIL
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

SLIDER
183
51
359
84
safety-level-slider
safety-level-slider
0
1
0.1
0.1
1
NIL
HORIZONTAL

SLIDER
183
93
358
126
scooter-speed-slider
scooter-speed-slider
0
0.1
0.03
0.01
1
NIL
HORIZONTAL

SLIDER
183
131
359
164
car-speed-slider
car-speed-slider
0
0.1
0.03
0.01
1
NIL
HORIZONTAL

SLIDER
0
10
180
43
people-speed-slider
people-speed-slider
0
0.05
0.01
0.01
1
NIL
HORIZONTAL

SLIDER
2
51
180
84
helmet-usage-slider
helmet-usage-slider
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
3
93
180
126
safety-awareness-slider
safety-awareness-slider
0
1
0.5
0.1
1
NIL
HORIZONTAL

SWITCH
183
11
359
44
dedicated-scooter-lane
dedicated-scooter-lane
0
1
-1000

PLOT
878
12
1208
207
Average Congestion 
ticks
average-congestion
0.0
1000.0
0.0
0.01
true
false
"" ""
PENS
"Congestion" 1.0 0 -13345367 true "" "plot average-congestion"

PLOT
878
213
1208
407
Total Accident
ticks
total-accidents
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Accident" 1.0 0 -2674135 true "" "plot total-accidents"

PLOT
1212
11
1531
206
Average Arrival Time
ticks
average-arrival-time
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -10141563 true "" "plot average-arrival-time"

SLIDER
4
131
180
164
number-of-cars
number-of-cars
0
100
12.0
1
1
NIL
HORIZONTAL

SLIDER
4
171
179
204
number-of-people
number-of-people
0
100
13.0
1
1
NIL
HORIZONTAL

SLIDER
3
212
179
245
number-of-scooters
number-of-scooters
0
100
14.0
1
1
NIL
HORIZONTAL

MONITOR
5
375
118
420
agents-on-road
count turtles with [\n    [lane-type] of patch-here = \"road\" or\n    [lane-type] of patch-here = \"intersection\" or\n    [lane-type] of patch-here = \"crossing\"\n  ]
17
1
11

MONITOR
125
375
257
420
total_road_patches
count patches with [\n    member? lane-type [\"road\" \"intersection\" \"crossing\"]\n  ]
17
1
11

MONITOR
6
427
118
472
total-arrivals
count total-arrivals
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

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
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
