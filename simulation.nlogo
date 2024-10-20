;=============== Global Variables =================================================================================================================================================================================

globals [
  origin-points         ; List of starting locations for agents
  destination-points    ; List of ending locations for agents
  %-cars                ; Percentage of agents that are cars
  total-car-time        ; Cumulative time taken by all cars
  total-people-time     ; Cumulative time taken by all people
  total-scooter-time    ; Cumulative time taken by all scooters
  num-car-arrivals     ; Number of cars that have reached their destination
  num-scooter-arrivals ; Number of scooters that have reached their destination
  num-people-arrivals  ; Number of people that have reached their destination
  total-car-distance    ; Total distance traveled by all cars
  total-people-distance ; Total distance traveled by all people
  average-congestion    ; Average congestion level on roads
  total-scooter-distance ; Total distance traveled by all scooters
  car-person-accidents   ; Number of accidents between cars and people
  car-scooter-accidents  ; Number of accidents between cars and scooters
  car-car-accidents      ; Number of accidents between cars
  scooter-scooter-accidents ; Number of accidents between scooters
  scooter-person-accidents   ; Number of accidents between scooters and people
]

;=============== Turtles and Patches Variable =====================================================================================================================================================================

turtles-own [
  car-speed                ; Speed of car agents
  people-speed             ; Speed of people agents
  scooter-speed            ; Speed of scooter agents
  destination-road-x       ; X-coordinate of road destination
  destination-road-y       ; Y-coordinate of road destination
  destination-footpath-x   ; X-coordinate of footpath destination
  destination-footpath-y   ; Y-coordinate of footpath destination
  start-x                  ; Starting X-coordinate
  start-y                  ; Starting Y-coordinate
  scooter-lane?            ; Boolean indicating if scooter is in scooter lane
  safety-level             ; Safety level for scooters (affects accident probability)
  arrival-time             ; Time taken to arrive at destination
]

patches-own [
  lane-type   ; Type of lane: "road", "scooter-lane", "intersection", "roundabout", "grass"
]

;=============== Setup Procedure ==================================================================================================================================================================================

to setup
  clear-all
  set %-cars (100 - %-scooters - %-people)
  set total-car-time 0
  set total-people-time 0
  set total-scooter-time 0
  set num-car-arrivals 0
  set num-scooter-arrivals 0
  set num-people-arrivals 0
  set total-car-distance 0
  set total-people-distance 0
  set total-scooter-distance 0
  set car-person-accidents 0
  set car-scooter-accidents 0
  set scooter-person-accidents 0

  resize-world -30 30 -30 30
  set average-congestion 0
  setup-patches
  setup-people
  setup-cars
  setup-scooters
  reset-ticks
end

to setup-patches
  ; Set default lane-type
  ask patches [ set lane-type "grass" ]

  ; Define main horizontal roads every 10 patches
  ask patches with [ pycor mod 10 = 0 ] [
    set lane-type "road"
  ]

  ; Define main vertical roads every 10 patches
  ask patches with [ pxcor mod 10 = 0 ] [
    set lane-type "road"
  ]

  ; Define intersections
  ask patches with [ (pxcor mod 10 = 0) and (pycor mod 10 = 0) ] [
    set lane-type "intersection"
  ]

  ; Define scooter lanes alongside main roads
  ; For horizontal roads
  ask patches with [ pycor mod 10 = 1 ] [
    set lane-type "scooter-lane"
  ]

  ; For vertical roads
  ask patches with [ pxcor mod 10 = 1 ] [
    set lane-type "scooter-lane"
  ]

  ask patches with [ pycor mod 10 = 1 and pxcor mod 10 = 1 ] [
    set lane-type "scooter-intersection"
  ]

  ; Visualize the lanes
  ask patches [
    if lane-type = "road" [ set pcolor gray ]
    if lane-type = "scooter-lane" [ set pcolor blue ]
    if lane-type = "scooter-intersection" [ set pcolor rgb 80 80 255]
    if lane-type = "grass" [ set pcolor brown ]
  ]

  ; Adjust lane types at intersections
  ask patches with [ lane-type = "scooter-lane" or lane-type = "scooter-intersection" ] [
    if any? neighbors4 with [ lane-type = "intersection"] and any? neighbors with [ pcolor = gray ] [
      set lane-type "crossing"
    ]
  ]

  ; Set traffic light colors at intersections
  ask patches with [(pxcor mod 10 = 0) and (pycor mod 10 = 0)] [
    let patch-sum (pxcor + pycor) mod 3
    if (patch-sum = 0) [
      set pcolor red
    ]
    if (patch-sum = 1) [
      set pcolor yellow
    ]
    if (patch-sum = 2) [
      set pcolor green
    ]
  ]

  ; Finalize crossing colors
  ask patches [
    if lane-type = "crossing" [ set pcolor white ]
  ]

  ; Define origin and destination points for agents
  set origin-points patches with [ pxcor = min-pxcor and lane-type = "road" ]
  set destination-points patches with [ pxcor = max-pxcor and lane-type = "road" ]
end

to setup-cars
  ; Create cars based on percentage
  create-turtles (num-agents * %-cars / 100) [
    setxy random-xcor random-ycor
    while [ pcolor != gray ] [
      setxy random-xcor random-ycor
      setxy pxcor pycor
    ]

    ; Assign destination on a road patch
    let destination patch random-xcor random-ycor
    while [[pcolor] of destination != gray and [pcolor] of destination != white] [
      set destination patch random-xcor random-ycor
    ]

    set destination-road-x [pxcor] of destination
    set destination-road-y [pycor] of destination

    ; Determine initial heading based on neighboring roads
    let neighboring-roads neighbors with [pcolor = gray or pcolor = white]
    if any? neighboring-roads [
      ; Vertical roads: face north or south
      if any? neighboring-roads with [pycor = [pycor] of myself + 1 or pycor = [pycor] of myself - 1] [
        set heading one-of [0 180]
      ]
      ; Horizontal roads: face east or west
      if any? neighboring-roads with [pxcor = [pxcor] of myself + 1 or pxcor = [pxcor] of myself - 1] [
        set heading one-of [90 270]
      ]
    ]

    set shape "car"
    set color blue
    set car-speed abs(random-normal (car-speed-slider / 2000) 0.03)
  ]
end

to setup-people
  ; Create people based on percentage
  create-turtles (num-agents * %-people / 100) [
    setxy random-xcor random-ycor
    while [ pcolor != blue ] [
      setxy random-xcor random-ycor
      setxy pxcor pycor
    ]

    set start-x pxcor
    set start-y pycor

    ; Assign destination on a footpath patch
    let destination patch random-xcor random-ycor
    while [[pcolor] of destination != blue and [pcolor] of destination != blue] [
      set destination patch random-xcor random-ycor
    ]

    set destination-footpath-x [pxcor] of destination
    set destination-footpath-y [pycor] of destination

    ; Find nearest road to the footpath destination
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

    ; Determine initial heading based on neighboring roads
    let neighboring-roads neighbors with [pcolor = blue or pcolor = white]
    if any? neighboring-roads [
      ; Vertical roads: face north or south
      if any? neighboring-roads with [pycor = [pycor] of myself + 1 or pycor = [pycor] of myself - 1] [
        ifelse pxcor < destination-footpath-x [
          set heading 180  ; Face south
        ][
          set heading 0    ; Face north
        ]
      ]
      ; Horizontal roads: face east or west
      if any? neighboring-roads with [pxcor = [pxcor] of myself + 1 or pxcor = [pxcor] of myself - 1] [
        ifelse pxcor > destination-footpath-x [
          set heading 270  ; Face west
        ][
          set heading 90   ; Face east
        ]
      ]
    ]

    set shape "person"
    set color black
    set people-speed abs(random-normal (people-speed-slider / 2000) 0.03)
  ]
end

to setup-scooters
  ; Create scooters based on percentage
  create-turtles (num-agents * %-scooters / 100) [

    ; Position the scooter on a random blue patch (scooter lane)
    setxy random-xcor random-ycor
    while [pcolor != blue] [
      setxy random-xcor random-ycor
    ]
    set start-x pxcor
    set start-y pycor

    ; Assign destination on a scooter lane patch
    let destination one-of patches with [pcolor = blue]
    while [[pcolor] of destination != blue] [
      set destination patch random-xcor random-ycor
    ]

    set destination-footpath-x [pxcor] of destination
    set destination-footpath-y [pycor] of destination

    ; Find nearest road to the scooter lane destination
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

    ; Determine initial heading based on neighboring scooter lanes
    let neighboring-roads neighbors with [pcolor = blue]
    if any? neighboring-roads [
      ; Vertical scooter lanes: face north or south
      if any? neighboring-roads with [pycor = [pycor] of myself + 1 or pycor = [pycor] of myself - 1] [
        set heading one-of [0 180]
      ]
      ; Horizontal scooter lanes: face east or west
      if any? neighboring-roads with [pxcor = [pxcor] of myself + 1 or pxcor = [pxcor] of myself - 1] [
        set heading one-of [90 270]
      ]
    ]

    set shape "bike"
    set color green
    set scooter-lane? true
    set scooter-speed abs(random-normal (scooter-speed-slider / 2000) 0.03)
    set safety-level abs(random-normal (scooter-safety-slider / 2000) 0.03)
  ]
end

;=============== Main Simulation Loop =============================================================================================================================================================================

to go
  if (not any? turtles) or (ticks > 40000) [stop]
  move-people
  move-cars
  if change-lane-switch?[
     change-lane
  ]
  move-scooters
  change-lights
  remove-strangler
  update-congestion
  accident
  if count turtles = 0 [
    stop
  ]
  tick
end

to move-cars
  ask turtles [
    ; Identify cars by their shape
    if shape = "car" [

      let change-x 0
      let change-y 0

      ; Determine movement direction based on heading
      if heading = 0 [ set change-y 1 ]    ; North
      if heading = 90 [ set change-x 1 ]   ; East
      if heading = 180 [ set change-y -1 ] ; South
      if heading = 270 [ set change-x -1 ] ; West

      let color-of-next-patch [pcolor] of patch-at change-x change-y

      ; Stop at red or yellow traffic lights
      ifelse (color-of-next-patch = red) or (color-of-next-patch = yellow) [
        ;; Stop
      ][
        fd car-speed  ;; Move forward at normal speed
      ]

      ; Adjust heading towards destination
      if pcolor = green [
        ifelse abs(pxcor - destination-road-x) > abs(pycor - destination-road-y) [
          if pxcor < destination-road-x [ set heading 90 ]  ; East
          if pxcor > destination-road-x [ set heading 270 ] ; West
        ][
          if pycor < destination-road-y [ set heading 0 ]   ; North
          if pycor > destination-road-y [ set heading 180 ] ; South
        ]
      ]

      ; Check if car has reached its destination
      if pxcor = destination-road-x and pycor = destination-road-y [
        let dist (abs(destination-road-x - start-x) + abs(destination-road-y - start-y))
        set total-car-time (total-car-time + ticks)
        set num-car-arrivals (num-car-arrivals + 1)
        set total-car-distance (total-car-distance + dist)
        die
      ]
    ]
  ]
end

to move-people
  ask turtles [
    ; Identify people by their shape
    if shape = "person" [

      let change-x 0
      let change-y 0

      ; Determine movement direction based on heading
      if heading = 0 [ set change-y 1 ]    ; North
      if heading = 90 [ set change-x 1 ]   ; East
      if heading = 180 [ set change-y -1 ] ; South
      if heading = 270 [ set change-x -1 ] ; West

      let color-of-next-patch [pcolor] of patch-at change-x change-y

      ; Behavior at white patches (crossings)
      ifelse (color-of-next-patch = white) [
        let nearby-cars turtles with [shape = "car" and distance myself < 3]
        ifelse any? nearby-cars [
          ;; Stop if cars are nearby
        ][
          ;; Move forward if no cars are nearby
          fd people-speed
        ]
      ][
        fd people-speed  ;; Move forward if not at a crossing
      ]

      ; Adjust heading towards destination
      if pcolor = rgb 80 80 255 [
        ifelse abs(pxcor - destination-footpath-x) > abs(pycor - destination-footpath-y) [
          if pxcor < destination-footpath-x [ set heading 90 ]   ; East
          if pxcor > destination-footpath-x [ set heading 270 ]  ; West
        ][
          if pycor < destination-footpath-y [ set heading 0 ]    ; North
          if pycor > destination-footpath-y [ set heading 180 ]  ; South
        ]
      ]

      ; Check if person has reached destination
      if pxcor = destination-footpath-x and pycor = destination-footpath-y [
        let dist (abs(destination-footpath-x - start-x) + abs(destination-footpath-y - start-y))
        set total-people-time (total-people-time + ticks)
        set num-people-arrivals (num-people-arrivals + 1)
        set total-people-distance (total-people-distance + dist)
        die
      ]
    ]
  ]
end

to move-scooters
  ask turtles with [shape = "bike"] [
    ; Determine movement direction based on heading
    let change-x 0
    let change-y 0

    if (heading = 0) [ set change-y 1 ]    ; North
    if (heading = 90) [ set change-x 1 ]   ; East
    if (heading = 180) [ set change-y -1 ] ; South
    if (heading = 270) [ set change-x -1 ] ; West

    let next-patch patch-at change-x change-y
    let color-of-next-patch [pcolor] of next-patch

    ifelse scooter-lane? [ ;; Move in scooter lane
      ifelse (color-of-next-patch = white) [
        let nearby-cars turtles with [shape = "car" and distance myself < 3]
        ifelse any? nearby-cars [
          ;; Stop if cars are nearby
        ][
          ;; Move forward if no cars are nearby
          fd scooter-speed
        ]
      ][
        fd scooter-speed  ;; Move forward if not at a crossing
      ]

      ; Adjust heading towards destination
      if pcolor = rgb 80 80 255 [
        ifelse abs(pxcor - destination-footpath-x) > abs(pycor - destination-footpath-y) [
          if pxcor < destination-footpath-x [ set heading 90 ]   ; East
          if pxcor > destination-footpath-x [ set heading 270 ]  ; West
        ][
          if pycor < destination-footpath-y [ set heading 0 ]    ; North
          if pycor > destination-footpath-y [ set heading 180 ]  ; South
        ]
      ]

    ][ ;; Move in road
      ifelse (color-of-next-patch = red) or (color-of-next-patch = yellow) [
        ;; Handle red or yellow patch (e.g., stop)
      ][
        fd scooter-speed  ;; Move forward at normal speed
      ]

      ; Adjust heading towards road destination
      if pcolor = green [
        ifelse abs(pxcor - destination-road-x) > abs(pycor - destination-road-y) [
          if pxcor < destination-road-x [ set heading 90 ]   ; East
          if pxcor > destination-road-x [ set heading 270 ]  ; West
        ][
          if pycor < destination-road-y [ set heading 0 ]    ; North
          if pycor > destination-road-y [ set heading 180 ]  ; South
        ]
      ]
    ]

    ; Check if scooter has reached destination
    if ((pxcor = destination-footpath-x and pycor = destination-footpath-y) or
        (pxcor = destination-road-x and pycor = destination-road-y)) [
      let dist (abs(destination-road-x - start-x) + abs(destination-road-y - start-y))
      set total-scooter-time (total-scooter-time + ticks)
      set num-scooter-arrivals (num-scooter-arrivals + 1)
      set total-scooter-distance (total-scooter-distance + dist)
      die
    ]
  ]
end

to remove-strangler
  ask turtles [
    if [lane-type] of patch-here = "grass" [
      die
    ]
  ]
end

;=============== Submodel =========================================================================================================================================================================================

;=============== Congestion Measurement =========================================================

to update-congestion
  ;; Calculate the average number of agents per road patch
  let total-road-patches count patches with [lane-type = "road" or lane-type = "intersection" or lane-type = "crossing"]
  let agents-on-road count turtles with [
    [lane-type] of patch-here = "road" or
    [lane-type] of patch-here = "intersection" or
    [lane-type] of patch-here = "crossing"
  ]
  if total-road-patches > 0 [
    ; convert to km--> total road patch * 15 meter/patch divide by 1000 meter
    set average-congestion agents-on-road / (total-road-patches * 0.015)
  ]
end

;=============== Traffic Light Management =======================================================

to change-lights
  if ticks mod 90 = 0[
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

;=============== Lane Switching =================================================================

to change-lane
  if (ticks mod 300) = 0 [
    ask turtles with [shape = "bike"] [
      let change? false
      let new-x 0
      let new-y 0

      ifelse scooter-lane? [
        ; Attempt to move off the scooter lane to the road
        let below-patch-x [pxcor] of patch-here
        let below-patch-y [pycor - 1] of patch-here
        let left-patch-x [pxcor - 1] of patch-here
        let left-patch-y [pycor] of patch-here

        if [pcolor] of patch below-patch-x below-patch-y = gray [
          set new-x below-patch-x
          set new-y below-patch-y
          set change? true
        ]
        if [pcolor] of patch left-patch-x left-patch-y = gray [
          set new-x left-patch-x
          set new-y left-patch-y
          set change? true
        ]
      ][
        ; Attempt to move back onto the scooter lane from the road
        let above-patch-x [pxcor] of patch-here
        let above-patch-y [pycor + 1] of patch-here
        let right-patch-x [pxcor + 1] of patch-here
        let right-patch-y [pycor] of patch-here

        if [pcolor] of patch above-patch-x above-patch-y = blue [
          set new-x above-patch-x
          set new-y above-patch-y
          set change? true
        ]
        if [pcolor] of patch right-patch-x right-patch-y = blue [
          set new-x right-patch-x
          set new-y right-patch-y
          set change? true
        ]
      ]

      ; Execute lane change if possible
      if change? [
        setxy new-x new-y
        ifelse scooter-lane? [
          set scooter-lane? false
        ][
          set scooter-lane? true
        ]
      ]
    ]
  ]
end

;=============== Accident  ======================================================================

to accident
  let no-helmet-divisor 1e-3
  let helmet-divisor 1.5e-3

  ask turtles [
    ; Accidents involving cars
    if shape = "car" [
      ; Car and person collisions
      let nearby-people turtles with [shape = "person" and distance myself < 1]
      if any? nearby-people [
        if random-float 1 < accident-probability * no-helmet-divisor [
          set car-person-accidents car-person-accidents + 1
          ; Remove involved people
          ask nearby-people [ die ]
          die
        ]
      ]

      ; Car and scooter collisions
      let nearby-scooters turtles with [shape = "bike" and distance myself < 1]
      if any? nearby-scooters [
        ifelse helmet? [
          if random-float 1 < accident-probability * helmet-divisor [
            set car-scooter-accidents car-scooter-accidents + 1
            ask nearby-scooters [ die ]
            die
          ]
        ][
          if random-float 1 < accident-probability * no-helmet-divisor [
            set car-scooter-accidents car-scooter-accidents + 1
            ask nearby-scooters [ die ]
            die
          ]
        ]
      ]
    ]

    ; Car and car collisions
    let nearby-cars turtles with [shape = "car" and distance myself < 1 and self != myself]
    if any? nearby-cars [
      if random-float 1 < accident-probability * no-helmet-divisor [
        set car-car-accidents car-car-accidents + 1
        ask nearby-cars [ die ] ; Remove the other car
        die                     ; Remove current car
      ]
    ]

    ; Accidents involving scooters
    if shape = "bike" [
      ; Scooter and person collisions
      let nearby-people turtles with [shape = "person" and distance myself < 1]
      if any? nearby-people [
        ifelse helmet? [
          if random-float 1 < (accident-probability * (1 - safety-level)) * helmet-divisor [
            set scooter-person-accidents scooter-person-accidents + 1
            ask nearby-people [ die ]
            die
          ]
        ][
          if random-float 1 < (accident-probability * (1 - safety-level)) * no-helmet-divisor [
            set scooter-person-accidents scooter-person-accidents + 1
            ask nearby-people [ die ]
            die
          ]
        ]
      ]

      ; Scooter and scooter collisions
      let nearby-scooters turtles with [shape = "bike" and distance myself < 1 and self != myself]
      if any? nearby-scooters [
        ifelse helmet? [
          if random-float 1 < accident-probability * (1 - safety-level) * helmet-divisor [
            set scooter-scooter-accidents scooter-scooter-accidents + 1
            ask nearby-scooters [ die ] ; Remove the other scooter
            die                         ; Remove current scooter
          ]
        ][
          if random-float 1 < accident-probability * (1 - safety-level) * no-helmet-divisor [
            set scooter-scooter-accidents scooter-scooter-accidents + 1
            ask nearby-scooters [ die ] ; Remove the other scooter
            die                         ; Remove current scooter
          ]
        ]
      ]
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
837
638
-1
-1
10.15
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
103
400
169
433
NIL
setup
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
31
400
94
433
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
21
23
193
56
car-speed-slider
car-speed-slider
0
2
0.53
0.2
1
NIL
HORIZONTAL

SLIDER
21
67
193
100
scooter-speed-slider
scooter-speed-slider
0
1
0.46
0.1
1
NIL
HORIZONTAL

INPUTBOX
31
150
186
214
%-people
52.28
1
0
Number

INPUTBOX
31
230
186
290
%-scooters
26.51
1
0
Number

SLIDER
21
111
193
144
people-speed-slider
people-speed-slider
0
0.3
0.14
0.1
1
NIL
HORIZONTAL

SLIDER
21
308
193
341
num-agents
num-agents
10
500
380.0
50
1
NIL
HORIZONTAL

MONITOR
871
49
977
94
NIL
num-car-arrivals
17
1
11

MONITOR
872
110
980
155
avg-car-distance
total-car-distance / num-car-arrivals
3
1
11

MONITOR
871
167
956
212
avg-car-time
total-car-time / num-car-arrivals
17
1
11

MONITOR
871
222
965
267
avg-car-speed
total-car-distance / total-car-time * 2000
3
1
11

MONITOR
1001
49
1127
94
NIL
num-people-arrivals
17
1
11

MONITOR
1151
50
1282
95
NIL
num-scooter-arrivals
17
1
11

MONITOR
1002
111
1128
156
avg-people-distance
total-people-distance / num-people-arrivals
3
1
11

MONITOR
971
167
1075
212
avg-people-time
total-people-time / num-people-arrivals
3
1
11

MONITOR
972
222
1078
267
avg-people-speed
total-people-distance / total-people-time * 2000
3
1
11

MONITOR
1152
113
1284
158
avg-scooter-distance
total-scooter-distance / num-scooter-arrivals
3
1
11

MONITOR
1089
168
1199
213
avg-scooter-time
total-scooter-time / num-scooter-arrivals
17
1
11

MONITOR
1083
222
1202
267
avg-scooter-speed
total-scooter-distance / total-scooter-time * 2000
3
1
11

SLIDER
21
493
193
526
scooter-safety-slider
scooter-safety-slider
0.1
1
0.7
0.5
1
NIL
HORIZONTAL

SWITCH
26
537
188
570
change-lane-switch?
change-lane-switch?
1
1
-1000

MONITOR
873
274
1004
319
NIL
car-person-accidents
17
1
11

MONITOR
1009
275
1144
320
NIL
car-scooter-accidents
17
1
11

MONITOR
1269
275
1425
320
NIL
scooter-person-accidents
17
1
11

MONITOR
1151
275
1261
320
NIL
car-car-accidents
17
1
11

MONITOR
872
332
1021
377
NIL
scooter-scooter-accidents
17
1
11

SLIDER
19
581
191
614
accident-probability
accident-probability
0.00
0.3
0.05
0.05
1
NIL
HORIZONTAL

MONITOR
1145
332
1285
377
total-road-patches
count patches with [\n    member? lane-type [\"road\" \"intersection\" \"crossing\"]\n  ]
17
1
11

MONITOR
1294
333
1395
378
agents-on-road
count turtles with [\n    [lane-type] of patch-here = \"road\" or\n    [lane-type] of patch-here = \"intersection\" or\n    [lane-type] of patch-here = \"crossing\"\n  ]
17
1
11

PLOT
857
394
1057
544
Average Congestion
ticks
average-congestion
0.0
100.0
0.0
0.01
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot average-congestion"

SWITCH
49
452
152
485
helmet?
helmet?
0
1
-1000

PLOT
1066
395
1266
545
Total Car Accidents
Ticks
No. of cars
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -5298144 true "" "plot car-car-accidents + car-scooter-accidents"

PLOT
1274
395
1474
545
Total Scooter Accidents
No. of scooters
Ticks
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -8630108 true "" "plot scooter-scooter-accidents + scooter-person-accidents"

PLOT
856
558
1056
708
Total Pedestrian Accident
Ticks
No. of people
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -13345367 true "" "plot car-person-accidents + scooter-person-accidents"

MONITOR
1233
561
1359
606
NIL
total-car-distance
17
1
11

MONITOR
1233
613
1300
658
total-car
(num-agents * (100 - %-people - %-scooters ) / 100)
17
1
11

MONITOR
1069
561
1206
606
accident per 1k trip
((car-person-accidents + car-car-accidents + car-scooter-accidents)/(num-agents) * 1000)
3
1
11

MONITOR
1029
331
1134
376
total-accident
car-person-accidents + car-scooter-accidents + car-car-accidents + scooter-person-accidents + scooter-scooter-accidents
17
1
11

MONITOR
1070
613
1127
658
ATT
((total-car-time / num-car-arrivals) + (total-people-distance / total-people-time * 2000) + (total-scooter-distance / total-scooter-time * 2000))/(num-car-arrivals + num-people-arrivals + num-scooter-arrivals)
17
1
11

MONITOR
1309
612
1399
657
total-scooters
num-agents * (%-scooters) / 100
12
1
11

MONITOR
1406
612
1484
657
total-people
num-agents * (%-people) / 100
2
1
11

@#$#@#$#@
## WHAT IS IT?

Traffic Dynamics Simulation with Multi-Agent Interactions

This NetLogo model simulates urban traffic dynamics involving three types of agents: cars, people, and scooters. It aims to demonstrate and analyze the interactions between different transportation modes within a city environment, highlighting factors such as movement patterns, traffic light control, lane switching, accidents, and congestion levels. By modeling these elements, the simulation provides insights into how various agents navigate through roads, scooter lanes, and pedestrian paths, and how their interactions impact overall traffic flow and safety.

Key Objectives:

• Traffic Flow Analysis: Understand how different agents contribute to or alleviate congestion.
• Safety Assessment: Evaluate the frequency and impact of accidents among cars, scooters, and pedestrians.
• Infrastructure Utilization: Observe the effectiveness of dedicated lanes (e.g., scooter lanes) and traffic light systems.
• Behavioral Insights: Explore how agent behaviors, such as lane switching and compliance with traffic signals, influence the overall traffic environment.

## HOW IT WORKS

Agent-Based Rules and Interactions Driving the Simulation

The model operates based on a set of predefined rules governing the behavior of three types of agents—cars, people, and scooters—and their interactions with the environment and each other. Here’s an overview of the core mechanics:

1. Environment Setup:

• Grid Layout: The simulation world is a grid with designated areas for roads, scooter lanes, intersections, crossings, and grass (non-navigable areas).
• Lane Types:
	• Roads: Main horizontal and vertical roads where cars primarily operate.
	• Scooter Lanes: Dedicated lanes adjacent to roads for scooter movement.
	• Intersections and Crossings: Points where roads intersect, controlled by 			  traffic lights, and crossings for pedestrians.

2. Agent Initialization:

• Cars:
	• Spawn on random road patches.
	• Assigned random road destinations.
	• Move towards their destinations, obeying traffic lights and adjusting direction 	  as needed.
• People:
	• Spawn on scooter lanes (blue patches).
	• Assigned footpath destinations.
	• Navigate towards their destinations, stopping at crossings if cars are nearby.
• Scooters:
	• Spawn on scooter lanes.
	• Assigned scooter lane destinations.
	• Move within scooter lanes or switch to roads, adhering to traffic signals and 		  adjusting direction towards destinations.

3. Movement Rules:

• Directional Movement: Agents move in the direction they are heading (north, east, south, west) based on their initial assignment and proximity to destinations.
• Traffic Light Compliance:
	• Cars and Scooters: Stop at red or yellow traffic lights; proceed on 				  green.
	• People: Stop at crossings if cars are within a certain distance.
• Lane Switching:
	• Scooters: Periodically attempt to switch between scooter lanes and roads to 			  simulate dynamic lane usage.
•Destination Arrival: Upon reaching their assigned destinations, agents update statistics 		      (e.g., time taken, distance traveled) and are removed from the simulation.

4. Accident Handling:

• Collision Detection: The model checks for proximity-based collisions between cars, scooters, and people.
• Accident Probabilities: Based on factors like helmet usage and scooter safety levels, accidents are probabilistically determined.
• Consequences: Involved agents are removed from the simulation upon accidents, and relevant accident counters are incremented.

5. Congestion Measurement:

• Average Congestion: Calculated as the number of agents per kilometer of road, providing a metric to assess traffic density and congestion levels.

	6. Traffic Light Control:

• Cycle Timing: Traffic lights at intersections change colors in a fixed sequence (red → black → green → yellow → red) every 90 ticks to simulate real-world traffic signal timing.

## HOW TO USE IT

The Interface Tab in NetLogo typically includes sliders, switches, buttons, and monitors that allow users to interact with and control the simulation. Below is a description of the likely interface elements based on the provided code:

Sliders:
	•	car-speed-slider: Adjusts the average speed of car agents.
	•	people-speed-slider: Adjusts the average speed of people agents.
	•	scooter-speed-slider: Adjusts the average speed of scooter agents.
	•	scooter-safety-slider: Sets the safety level for scooters, influencing   			accident probabilities.
	•	accident-probability: Determines the base probability of accidents occurring during collisions.

Switches:
	•	change-lane-switch?: Toggles the lane-switching behavior of scooters on or off.

Buttons:
	•	setup: Initializes the simulation by setting up the environment and agents.
	•	go: Starts or resumes the simulation loop, allowing agents to move and interact according to the defined rules.
	•	stop: Halts the simulation loop.

Monitors:
	•	average-congestion: Displays the current average congestion level on roads.
	•	Accident Counters: Various monitors to display the number of different types of accidents (e.g., car-person-accidents, car-scooter-accidents, etc.).
	•	Arrival Counters: Monitors to show the number of agents that have reached their destinations (e.g., num-car-arrivals, num-people-arrivals, num-scooter-arrivals).
	•	Time and Distance Metrics: Displays cumulative time and distance metrics for each agent type.

To run the simulation, users begin by setting the desired parameters using the sliders and toggling the lane-switching switch as needed. After configuring the settings, clicking the setup button initializes the environment and agents, followed by clicking the go button to start the simulation. Users can observe the simulation’s progress through the monitors and make real-time adjustments to parameters to see how changes affect traffic flow, congestion, and accident rates. The simulation will continue until all agents have either reached their destinations or been removed due to accidents, or until a predefined tick limit is reached. Users can pause or stop the simulation at any time using the stop button to analyze the current state or modify parameters for further experimentation.

## THINGS TO NOTICE

As you run the simulation, several critical aspects emerge that offer valuable insights into urban traffic dynamics. One primary observation is the formation of congestion hotspots, particularly at major intersections or heavily trafficked roads, where the accumulation of cars, scooters, and pedestrians can significantly impact traffic flow. The distribution of different agent types across the network reveals how cars, scooters, and people utilize roads and lanes differently, highlighting the effectiveness of dedicated scooter lanes in managing two-wheeled traffic. Observing the impact of lane switching behavior, enabled or disabled via the change-lane-switch? switch, allows users to assess whether such maneuvers help alleviate congestion or inadvertently contribute to traffic density. The role of traffic light cycles is also evident, as the fixed timing of traffic signals influences the stop-and-go patterns of cars and scooters, affecting overall traffic efficiency.

 Accident dynamics become apparent through the frequency and types of collisions occurring between cars, scooters, and pedestrians, providing a measure of the model’s safety aspects. Additionally, monitoring the average-congestion metric over time offers a quantitative assessment of traffic density, enabling users to correlate parameter adjustments with changes in congestion levels. The interactions between different agent types, such as cars passing scooters or people stopping at crossings when cars are nearby, showcase the complexity of managing diverse transportation modes within a single traffic system. These observations collectively help users understand the intricate balance required to maintain smooth and safe urban traffic flow.

## THINGS TO TRY

To deepen your understanding of the simulation and its underlying dynamics, several experimental adjustments are recommended. Start by varying the percentages of different agent types using the %-cars, %-people, and %-scooters sliders to observe how changes in the composition of traffic affect congestion and accident rates. For instance, increasing the proportion of cars may lead to higher congestion and more frequent collisions, while boosting the number of scooters or pedestrians could highlight the effectiveness of dedicated lanes and pedestrian crossings. Adjusting the speeds of agents through the car-speed-slider, people-speed-slider, and scooter-speed-slider allows you to explore how faster or slower movement impacts overall traffic flow and congestion levels. Modifying the scooter-safety-slider and accident-probability slider can help you assess the influence of safety measures and accident likelihood on traffic dynamics and agent interactions. Enabling or disabling the change-lane-switch? switch provides an opportunity to evaluate the benefits and drawbacks of scooter lane switching behavior in managing traffic density.

 Additionally, experimenting with the duration of the traffic light cycle by adjusting the timing within the change-lights procedure (if accessible) can reveal how different signaling timings influence traffic efficiency and congestion at intersections. Running the simulation for extended periods beyond the default 40,000 ticks can help you observe long-term traffic patterns and congestion trends. Furthermore, introducing additional agent types, such as buses or trucks, and observing their interactions with existing agents can add complexity and realism to the simulation. These experimental adjustments encourage users to interact dynamically with the model, fostering a comprehensive understanding of urban traffic management and the factors that influence it.

## EXTENDING THE MODEL

To elevate the simulation’s complexity and realism, several enhancements can be implemented. One significant extension is the incorporation of adaptive traffic lights that adjust their timing based on real-time congestion levels or traffic density, making the traffic light control more responsive to actual traffic conditions. Introducing more sophisticated pathfinding algorithms for agents would allow cars, people, and scooters to choose optimal routes rather than random destinations, thereby simulating more realistic navigation behaviors. Adding varied road types, such as secondary roads with different speed limits or one-way streets, can diversify traffic flow and introduce additional layers of complexity to the network. Implementing pedestrian-specific crosswalks with dedicated signals can enhance the realism of pedestrian interactions with vehicular traffic, ensuring better safety dynamics. Incorporating emergency vehicles with priority access would add another dimension to traffic management, requiring the simulation to handle dynamic obstacles and priority routing. 

Environmental factors like weather conditions (e.g., rain, snow) and time-of-day cycles could be introduced to simulate their effects on agent speeds, accident probabilities, and overall traffic behavior. Expanding data collection and visualization tools within the model, such as detailed metrics and graphical displays, would provide deeper insights into traffic patterns and congestion trends. Enhancing the user interface with more interactive controls, such as additional sliders or agent selection features, would allow users to manipulate a broader range of parameters and observe their effects in real-time. Introducing multi-lane roads with lane-specific behaviors, such as overtaking and lane changing for cars, would add further realism to the traffic simulation. Additionally, integrating public transportation elements like buses with predefined routes and passenger boarding dynamics could enrich the simulation by reflecting more complex urban transportation systems. These extensions not only increase the model’s depth and applicability but also offer users a more nuanced understanding of the multifaceted nature of urban traffic management.


## CREDITS AND REFERENCES

Model Development:

Riwaz Udas
Muhammad Md Nasrein

October 2024

University of Melbourne

https://github.com/dnelfhmi/E-ScooterTrafficSim.git
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

bike
false
1
Line -7500403 false 163 183 228 184
Circle -7500403 false false 213 184 22
Circle -7500403 false false 156 187 16
Circle -16777216 false false 28 148 95
Circle -16777216 false false 24 144 102
Circle -16777216 false false 174 144 102
Circle -16777216 false false 177 148 95
Polygon -8630108 true false 75 195 90 90 98 92 97 107 192 122 207 83 215 85 202 123 211 133 225 195 165 195 164 188 214 188 202 133 94 116 82 195
Polygon -8630108 true false 208 83 164 193 171 196 217 85
Polygon -8630108 true false 165 188 91 120 90 131 164 196
Line -7500403 false 159 173 170 219
Line -7500403 false 155 172 166 172
Line -7500403 false 166 219 177 219
Polygon -16777216 true false 187 92 198 92 208 97 217 100 231 93 231 84 216 82 201 83 184 85
Polygon -7500403 true false 71 86 98 93 101 85 74 81
Rectangle -16777216 true false 75 75 75 90
Polygon -16777216 true false 70 87 70 72 78 71 78 89
Circle -7500403 false false 153 184 22
Line -7500403 false 159 206 228 205

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
<experiments>
  <experiment name="Safety" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>(not any? turtles) or (ticks &gt; 30000)</exitCondition>
    <metric>car-person-accidents</metric>
    <metric>car-scooter-accidents</metric>
    <metric>scooter-person-accidents</metric>
    <metric>scooter-scooter-accidents</metric>
    <metric>average-congestion</metric>
    <metric>(count turtles with [shape = "bike" and helmet?]) / (count turtles with [shape = "bike"])</metric>
    <metric>(total-scooter-time / num-scooter-arrivals)</metric>
    <metric>(total-car-time / num-car-arrivals)</metric>
    <enumeratedValueSet variable="accident-probability">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="helmet?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="change-lane-switch?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scooter-safety-slider">
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="0.7"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
