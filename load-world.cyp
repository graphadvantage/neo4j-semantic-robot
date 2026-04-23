// 1. Clear existing nodes to prevent point/float conflicts
MATCH (n) DETACH DELETE n;

// 2. Create the Room and Surface
CREATE (rm:Room {id: 'rm_001', label: 'Kitchen'})
CREATE (surf:Surface {
    id: 'countertop', 
    label: 'Countertop',
    location: point({x: 1.0, y: -0.5, z: 0.725, crs: 'cartesian-3d'})
    })
CREATE (rm)-[:HAS_SURFACE]->(surf);

// 3. Create the Red Cup with a Cartesian 3D Point
CREATE (cup:Object {
    id: 'red_cup_target',
    label: 'Red Cup', 
    color: 'Red',
    location: point({x: 1.42, y: -0.55, z: 0.75, crs: 'cartesian-3d'}),
    home: point({x: 1.42, y: -0.55, z: 0.75, crs: 'cartesian-3d'})
});

// 4. Create the Humanoid Hand (The Hand)
CREATE (hand:Hand {
    id: 'humanoid_hand',
    label: 'Right Hand',
    location: point({x: 0.5, y: -0.55, z: 0.90, crs: 'cartesian-3d'}),
    home: point({x: 0.5, y: -0.55, z: 0.90, crs: 'cartesian-3d'})
});

// 5. Establish Spatial Relationships
MATCH (cup:Object), (surf:Surface)
CREATE (cup)-[:IS_ON]->(surf);

//6. Make the cup physical
MATCH (o:Object {id: 'red_cup_target'})
SET o.radius = 0.05,  // 5cm radius (10cm total width)
    o.height = 0.2;


MERGE (a:Hand {id: 'humanoid_hand'}) SET a.status = 'idle';
MERGE (o:Object {id: 'red_cup_target'}) SET o.status = 'idle';


// 1. Update the Hand (Humanoid Hand)
MATCH (a:Hand {id: 'humanoid_hand'})
SET a.qx = 0.0, a.qy = 0.707, a.qz = 0.0, a.qw = 0.707, // 90-degree rotation for Franka
    a.scale = 1.5,
    a.p_type = 'box',
    a.p_x = 0.1, a.p_y = 0.1, a.p_z = 0.1; // Representative bounding box for the wrist

// 2. Update the Object (Red Coffee Cup)
MATCH (o:Object {id: 'red_cup_target'})
SET o.qx = 0.0, o.qy = 0.0, o.qz = 0.0, o.qw = 1.0,
    o.scale = 0.003,
    o.p_type = 'box',
    o.p_x = 0.15, // Total length including handle
    o.p_y = 0.1,  // Diameter of the cup body
    o.p_z = 0.12; // Total height

// 3. Update the Surface (Countertop)
MATCH (s:Surface {id: 'countertop'})
SET s.qx = 0.0, s.qy = 0.0, s.qz = 0.0, s.qw = 1.0,
    s.scale = 1.0,
    s.p_type = 'box',
    s.p_x = 2.0, s.p_y = 1.0, s.p_z = 0.05;           // Dimensions from your script



    // 1. Hand: Vertical offset from the target point to the actual grip height
MATCH (a:Hand {id: 'humanoid_hand'})
SET a.grip_z_offset = 0.06;

// 2. Cup: Half-height offset to position the bounding box correctly
MATCH (o:Object {id: 'red_cup_target'})
SET o.origin_z_offset = 0.06; // Assuming p_z is 0.12, half is 0.06


// 1. Setup/Update the Hand (The Hand)
MERGE (a:Hand {id: 'humanoid_hand'})
SET a.name = 'Franka Emika Hand',
    a.status = 'idle',
    // Home position: Table center, 10cm above surface
    a.location = point({x: 0.5, y: -0.55, z: 0.85, crs: 'cartesian-3d'}),
    a.home = point({x: 0.5, y: -0.55, z: 0.85, crs: 'cartesian-3d'}),
    // Calibration: Wrist pitch of 90 degrees
    a.qx = 0.0, a.qy = 0.707, a.qz = 0.0, a.qw = 0.707,
    a.scale = 1.5,
    a.grip_z_offset = 0.06;

// 2. Create/Update Left Finger
MERGE (fL:Finger {id: 'hand_finger_left'})
SET fL.name = 'Left Finger',
    fL.side = 'left',
    // Local offset relative to Hand center (Closed state: Y=0)
    fL.local_offset_x = -0.0875,
    fL.local_offset_y = 0.0,
    fL.local_offset_z = 0.0,
    fL.qx = 0.0, fL.qy = 0.0, fL.qz = 0.0, fL.qw = 1.0,
    fL.scale = 1.5;

// 3. Create/Update Right Finger
MERGE (fR:Finger {id: 'hand_finger_right'})
SET fR.name = 'Right Finger',
    fR.side = 'right',
    // Local offset relative to Hand center (Closed state: Y=0)
    fR.local_offset_x = -0.0875,
    fR.local_offset_y = 0.0,
    fR.local_offset_z = 0.0,
    fR.qx = 0.0, fR.qy = 0.0, fR.qz = 0.0, fR.qw = 1.0,
    fR.scale = 1.5;

// 4. Build Kinematic Relationship
MATCH (a:Hand {id: 'humanoid_hand'})
MATCH (fL:Finger {id: 'hand_finger_left'})
MATCH (fR:Finger {id: 'hand_finger_right'})
MERGE (fL)-[:HAS_PARENT]->(a)
MERGE (fR)-[:HAS_PARENT]->(a);

// 5. Ensure Environment Source of Truth (Countertop)
MERGE (s:Surface {id: 'countertop'})
SET s.location = point({x: 0.5, y: -0.5, z: 0.75, crs: 'cartesian-3d'}),
    s.p_x = 2.0, s.p_y = 1.0, s.p_z = 0.05,
    s.qx = 0.0, s.qy = 0.0, s.qz = 0.0, s.qw = 1.0;


MATCH (s:Surface {id: 'countertop'})
SET s.location = point({x: 1.0, y: -0.5, z: 0.75, crs: 'cartesian-3d'})

MATCH (c:Object {id: 'red_cup_target'})
SET c.location = point({x: 0.7, y: -0.5, z: 0.835, crs: 'cartesian-3d'}),
    c.home = point({x: 0.7, y: -0.5, z: 0.835, crs: 'cartesian-3d'}),
    c.origin_z_offset = 0.06; // Half-height of the cup

MATCH (c:Object {id: 'red_cup_target'})
SET c.location = point({x: 1.42, y: -0.55, z: 0.835, crs: 'cartesian-3d'}),
    c.home = point({x: 1.42, y: -0.55, z: 0.835, crs: 'cartesian-3d'});


// Sync Hand
MATCH (h:Hand {id: 'humanoid_hand'})
SET h.location = point({x: h.location.x, y: -0.5, z: h.location.z, crs: 'cartesian-3d'}),
    h.home = point({x: h.home.x, y: -0.5, z: h.home.z, crs: 'cartesian-3d'});

// Sync Fingers
MATCH (f:Finger)-[:HAS_PARENT]->(:Hand {id: 'humanoid_hand'})
SET f.local_offset_y = 0.0; // Ensure they start closed at the center line

// Sync Cup
MATCH (c:Object {id: 'red_cup_target'})
SET c.location = point({x: c.location.x, y: -0.5, z: c.location.z, crs: 'cartesian-3d'}),
    c.home = point({x: c.home.x, y: -0.5, z: c.home.z, crs: 'cartesian-3d'});

MATCH (h:Hand {id: 'humanoid_hand'})
SET h.qx = 0.0, h.qy = 0.707, h.qz = 0.0, h.qw = 0.707;


MATCH (h:Hand {id: 'humanoid_hand'})
SET h.location = point({x: 0.0, y: 0.0, z: 1.2}),
    h.qx = 0.0, h.qy = 1.0, h.qz = 0.0, h.qw = 0.0;

MATCH (f:Finger)-[:HAS_PARENT]->(h:Hand {id: 'humanoid_hand'})
SET f.local_offset_x = 0.0,
    f.local_offset_y = 0.0,
    f.local_offset_z = -0.165;



//Home reset
MATCH (h:Hand {id: 'humanoid_hand'})
SET
h.state = "idle",
h.home = point({x: 0.0, y: 0.0, z: 1.2}),
h.location = point({x: 0.0, y: 0.0, z: 1.2}),
h.qx = 0.0, h.qy = 1.0, h.qz = 0.0, h.qw = 0.0;


MATCH (f:Finger)-[:HAS_PARENT]->(h:Hand {id: 'humanoid_hand'})
SET f.finger_tip_reach = 0.185,
    f.status = 'open'
RETURN f.id, f.finger_tip_reach;