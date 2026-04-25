// ============================================================
// DIGITAL TWIN — APOC EXPORT (cypher-shell format)
// Generated from live Neo4j instance via apoc.export.cypher.all
// Run top-to-bottom in Neo4j Browser or cypher-shell to restore world state.
// ============================================================

// Temporary import constraint — allows APOC to wire relationships by internal ID
CREATE CONSTRAINT UNIQUE_IMPORT_NAME FOR (node:`UNIQUE IMPORT LABEL`) REQUIRE (node.`UNIQUE IMPORT ID`) IS UNIQUE;

// ── FINGERS ──────────────────────────────────────────────────
// Left and right Franka gripper fingers.
// local_offset_* = closed position relative to hand wrist center.
// reference_fully_open/closed = Y-axis spread limits for animation.
// finger_tip_reach = calibrated reach from wrist origin to fingertip (0.185m).
UNWIND [{_id:1, properties:{finger_tip_reach:0.185, side:"right", quat:[0, 0, 0, 1], qw:1.0, qx:0.0, reference_fully_open:-0.1, qy:0.0, qz:0.0, scale:1.5, local_offset_y:0, local_offset_x:0, reference_fully_closed:0.0, local_offset_z:0.1, name:"Right Finger", location:point({x: 0.5, y: -0.05, z: 1.2, crs: 'cartesian-3d'}), id:"hand_finger_right", status:"open"}}, {_id:7, properties:{finger_tip_reach:0.185, side:"left", quat:[0, 0, 0, 1], qw:1.0, qx:0.0, reference_fully_open:0.1, qy:0.0, qz:0.0, scale:1.5, local_offset_y:0, local_offset_x:0, reference_fully_closed:0.0, local_offset_z:0.1, name:"Left Finger", location:point({x: 0.5, y: 0.05, z: 1.2, crs: 'cartesian-3d'}), id:"hand_finger_left", status:"open"}}] AS row
CREATE (n:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row._id}) SET n += row.properties SET n:Finger;

// ── OBJECTS ───────────────────────────────────────────────────
// All graspable/interactive objects in the scene:
//   yellow_coffee_maker — spout_home and brewing_time_seconds define the brew operation.
//   kitchen-sink        — drain_home and dumping_time_seconds define the dump operation. No status field = time-gated only.
//   red_cup_target      — the coffee cup. coffee_cup_level tracks fill state. last_fresh_brew timestamps last brew.
UNWIND [{_id:2, properties:{color:"Yellow", origin_z_offset:0.06, qw:0.5, qx:-0.5, qy:0.5, p_x:1.815, mesh_correction_x:0, qz:-0.5, scale:0.015, p_z:0.724, spout_home:point({x: 1.815, y: -0.8355, z: 0.986, crs: 'cartesian-3d'}), label:"Yellow Coffee Maker", p_y:-0.8355, mesh_correction_y:0, brewing_time_seconds:5, p_type:"mesh", location:point({x: 2.05, y: -1.1, z: 1.0, crs: 'cartesian-3d'}), mesh_path:"neo4j-semantic-robot/meshes/coffee-maker/coffee-maker.obj", id:"yellow_coffee_maker", status:"idle", height:0.2}}, {_id:3, properties:{dumping_time_seconds:2, location:point({x: 1.235, y: -0.1, z: 1.0, crs: 'cartesian-3d'}), id:"kitchen-sink", label:"Kitchen Sink", drain_home:point({x: 1.435, y: -0.105, z: 1.2, crs: 'cartesian-3d'}), status:"idle"}}, {_id:4, properties:{color:"Red", last_fresh_brew:datetime('2026-04-25T18:07:06.394Z'), scale:0.003, coffee_cup_level:"full", id:"red_cup_target", radius:0.05, height:0.2, p_r:0.04, quat:[0, 0, 0, 1], origin_z_offset:0.06, qw:1.0, qx:0, qy:0, p_x:1.42, mesh_correction_x:0, qz:0, p_z:0.911, label:"Red Cup", p_y:-0.5, mesh_correction_y:0, home:point({x: 1.42, y: -0.5, z: 0.911, crs: 'cartesian-3d'}), p_type:"box", location:point({x: 1.42, y: -0.5, z: 0.911, crs: 'cartesian-3d'}), mesh_path:"neo4j-semantic-robot/meshes/red-coffee-cup/3d-model.obj", status:"idle"}}] AS row
CREATE (n:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row._id}) SET n += row.properties SET n:Object;

// ── SURFACE ───────────────────────────────────────────────────
// Kitchen countertop mesh. Positioned at z=-1.0 with -90° X rotation so the
// visual surface aligns with the calibrated counter height (0.911m world Z).
// scale:1.0 = native mesh scale (p_x/p_y/p_z are metadata only, not scale factors).
UNWIND [{_id:0, properties:{qw:0.7071, qx:-0.7071, qy:0.0, p_x:1.0, qz:0.0, scale:1.0, p_z:1.0, label:"Countertop", p_y:1.0, p_type:"mesh", location:point({x: 1.65, y: -0.35, z: -1.0, crs: 'cartesian-3d'}), mesh_path:"neo4j-semantic-robot/meshes/kitchen-counter/kitchen-counter.obj", id:"countertop"}}] AS row
CREATE (n:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row._id}) SET n += row.properties SET n:Surface;

// ── HAND ──────────────────────────────────────────────────────
// Franka Emika hand. Home position: above scene center, pointing down (qy:1.0, qw:0).
// state is managed by the renderer server — do not write directly.
// grip_z_offset = mesh origin offset from logical grip point (0.06m).
UNWIND [{_id:5, properties:{quat:[0, 0, 1, 0], qw:0, qx:0, qy:1.0, qz:0, scale:1.5, label:"Right Hand", home:point({x: 0.5, y: 0.0, z: 1.25, crs: 'cartesian-3d'}), name:"Franka Emika Hand", p_type:"box", location:point({x: 0.5, y: 0.0, z: 1.25, crs: 'cartesian-3d'}), id:"humanoid_hand", grip_z_offset:0.06, state:"arrived", status:"idle"}}] AS row
CREATE (n:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row._id}) SET n += row.properties SET n:Hand;

// ── ROOM ──────────────────────────────────────────────────────
// Top-level semantic container for the kitchen scene.
UNWIND [{_id:6, properties:{id:"rm_001", label:"Kitchen"}}] AS row
CREATE (n:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row._id}) SET n += row.properties SET n:Room;

// ── RELATIONSHIPS ─────────────────────────────────────────────

// Objects are located inside the kitchen room
UNWIND [{start: {_id:2}, end: {_id:6}, properties:{}}, {start: {_id:3}, end: {_id:6}, properties:{}}, {start: {_id:4}, end: {_id:6}, properties:{}}] AS row
MATCH (start:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.start._id})
MATCH (end:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.end._id})
CREATE (start)-[r:IN_ROOM]->(end) SET r += row.properties;

// Objects rest on the countertop surface
UNWIND [{start: {_id:2}, end: {_id:0}, properties:{}}, {start: {_id:3}, end: {_id:0}, properties:{}}, {start: {_id:4}, end: {_id:0}, properties:{}}] AS row
MATCH (start:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.start._id})
MATCH (end:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.end._id})
CREATE (start)-[r:IS_ON]->(end) SET r += row.properties;

// Room owns the countertop surface
UNWIND [{start: {_id:6}, end: {_id:0}, properties:{}}] AS row
MATCH (start:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.start._id})
MATCH (end:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.end._id})
CREATE (start)-[r:HAS_SURFACE]->(end) SET r += row.properties;

// Surface is located inside the room
UNWIND [{start: {_id:0}, end: {_id:6}, properties:{}}] AS row
MATCH (start:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.start._id})
MATCH (end:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.end._id})
CREATE (start)-[r:IN_ROOM]->(end) SET r += row.properties;

// Fingers belong to the hand (kinematic chain)
UNWIND [{start: {_id:1}, end: {_id:5}, properties:{}}, {start: {_id:7}, end: {_id:5}, properties:{}}] AS row
MATCH (start:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.start._id})
MATCH (end:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.end._id})
CREATE (start)-[r:HAS_PARENT]->(end) SET r += row.properties;

// Clean up temporary import labels used for relationship wiring
MATCH (n:`UNIQUE IMPORT LABEL`)  WITH n LIMIT 20000 REMOVE n:`UNIQUE IMPORT LABEL` REMOVE n.`UNIQUE IMPORT ID`;
DROP CONSTRAINT UNIQUE_IMPORT_NAME;
