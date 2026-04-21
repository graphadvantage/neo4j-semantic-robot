// 1. Clear existing nodes to prevent point/float conflicts
MATCH (n) DETACH DELETE n;

// 2. Create the Room and Surface
CREATE (rm:Room {id: 'rm_001', label: 'Kitchen'})
CREATE (surf:Surface {
    id: 'counter_01', 
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

// 4. Create the Humanoid Hand (The Actor)
CREATE (hand:Actor {
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


MERGE (a:Actor {id: 'humanoid_hand'}) SET a.status = 'idle'
MERGE (o:Object {id: 'red_cup_target'}) SET o.status = 'idle'