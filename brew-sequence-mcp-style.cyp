CALL apoc.periodic.iterate(
  'UNWIND [

    // 0: rotate to side-grasp baseline
    {hqx:0,     hqy:0.707, hqz:0,     hqw:0.707},
    {sleep: 1200},

    // 1: stage to cup
    {hx:1.07,   hy:-0.5,   hz:0.911,  cstatus:"picking"},
    {sleep: 1200},

    // 2: strike cup
    {hx:1.235,  hy:-0.5,   hz:0.911},
    {sleep: 1200},

    // 3: lock
    {cstatus:"grasped"},
    {sleep: 1200},

    // 4: lift
    {hx:1.235,  hy:-0.5,   hz:1.2,    cx:1.42,   cy:-0.5,    cz:1.2},
    {sleep: 1200},

    // 5: transit to sink
    {hx:1.25,   hy:-0.105, hz:1.2,    cx:1.435,  cy:-0.105,  cz:1.2},
    {sleep: 1200},

    // 6: invert to drain
    {hqx:0.707, hqy:0,     hqz:0.707, hqw:0,     cqx:0.707,  cqy:0,  cqz:0.707, cqw:0, cup_level:"empty"},
    {sleep: 1200},

    // 7: restore upright
    {hqx:0,     hqy:0.707, hqz:0,     hqw:0.707, cqx:0,      cqy:0,  cqz:0,     cqw:1},
    {sleep: 1200},

    // 8: transit to spout
    {hx:1.63,   hy:-0.8355,hz:0.986,  cx:1.815,  cy:-0.8355, cz:0.986},
    {sleep: 1200},

    // 9: brew dwell
    {cup_level:"full", brew:true},
    {sleep: 1200},

    // 10: retreat from spout
    {hx:1.3,    hy:-0.8355,hz:0.986,  cx:1.485,  cy:-0.8355, cz:0.986},
    {sleep: 1200},

    // 11: lift from spout
    {hx:1.3,    hy:-0.8355,hz:1.2,    cx:1.485,  cy:-0.8355, cz:1.2},
    {sleep: 1200},

    // 12: transit to cup home
    {hx:1.235,  hy:-0.5,   hz:1.2,    cx:1.42,   cy:-0.5,    cz:1.2},
    {sleep: 1200},

    // 13: lower to counter
    {hx:1.235,  hy:-0.5,   hz:0.911,  cx:1.42,   cy:-0.5,    cz:0.911},
    {sleep: 1200},

    // 14: release
    {cstatus:"idle", cqx:0, cqy:0, cqz:0, cqw:1, cx:1.42,   cy:-0.5,    cz:0.911},
    {sleep: 1200},

    // 15: withdraw
    {hx:0.735,  hy:-0.5,   hz:0.911},
    {sleep: 1200},

    // 16: return home
    {hx:0.5,    hy:0,      hz:1.25,   hqx:0,     hqy:1.0,    hqz:0,  hqw:0},
    {sleep: 1200}

  ] AS step RETURN step',
  'MATCH (h:Hand {id: "humanoid_hand"})
   OPTIONAL MATCH (c:Object {id: "red_cup_target"})
   FOREACH (_ IN CASE WHEN step.hx        IS NOT NULL THEN [1] ELSE [] END |
     SET h.location = point({x: step.hx, y: step.hy, z: step.hz, crs: "cartesian-3d"}))
   FOREACH (_ IN CASE WHEN step.hqx       IS NOT NULL THEN [1] ELSE [] END |
     SET h.qx = step.hqx, h.qy = step.hqy, h.qz = step.hqz, h.qw = step.hqw)
   FOREACH (_ IN CASE WHEN step.cx        IS NOT NULL THEN [1] ELSE [] END |
     SET c.location = point({x: step.cx, y: step.cy, z: step.cz, crs: "cartesian-3d"}))
   FOREACH (_ IN CASE WHEN step.cqx       IS NOT NULL THEN [1] ELSE [] END |
     SET c.qx = step.cqx, c.qy = step.cqy, c.qz = step.cqz, c.qw = step.cqw)
   FOREACH (_ IN CASE WHEN step.cstatus   IS NOT NULL THEN [1] ELSE [] END |
     SET c.status = step.cstatus)
   FOREACH (_ IN CASE WHEN step.cup_level IS NOT NULL THEN [1] ELSE [] END |
     SET c.coffee_cup_level = step.cup_level)
   FOREACH (_ IN CASE WHEN step.brew      IS NOT NULL THEN [1] ELSE [] END |
     SET c.last_fresh_brew = datetime())
   WITH step CALL apoc.util.sleep(coalesce(step.sleep, 0))',
  {batchSize: 1, iterateList: true}
)
YIELD batches, total RETURN batches, total
