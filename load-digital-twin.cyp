CREATE CONSTRAINT UNIQUE_IMPORT_NAME FOR (node:`UNIQUE IMPORT LABEL`) REQUIRE (node.`UNIQUE IMPORT ID`) IS UNIQUE;
UNWIND [{_id:1, properties:{finger_tip_reach:0.1675, side:"right", quat:[0, 0, 0, 1], qw:1.0, qx:0.0, reference_fully_open:-0.1, qy:0.0, qz:0.0, scale:1.5, local_offset_y:0, local_offset_x:0, reference_fully_closed:0.0, local_offset_z:0.1, name:"Right Finger", location:point({x: 0.5, y: -0.05, z: 1.2, crs: 'cartesian-3d'}), id:"hand_finger_right", status:"closed"}}, {_id:7, properties:{finger_tip_reach:0.1675, side:"left", quat:[0, 0, 0, 1], qw:1.0, qx:0.0, reference_fully_open:0.1, qy:0.0, qz:0.0, scale:1.5, local_offset_y:0, local_offset_x:0, reference_fully_closed:0.0, local_offset_z:0.1, name:"Left Finger", location:point({x: 0.5, y: 0.05, z: 1.2, crs: 'cartesian-3d'}), id:"hand_finger_left", status:"closed"}}] AS row
CREATE (n:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row._id}) SET n += row.properties SET n:Finger;
UNWIND [{_id:2, properties:{color:"Yellow", origin_z_offset:0.06, qw:0.5, qx:-0.5, qy:0.5, p_x:1.815, mesh_correction_x:0, qz:-0.5, scale:0.015, p_z:0.724, spout_home:point({x: 1.805, y: -0.854, z: 0.986, crs: 'cartesian-3d'}), label:"Yellow Coffee Maker", p_y:-0.8355, mesh_correction_y:0, brewing_time_millis:5000, p_type:"mesh", location:point({x: 2.05, y: -1.1, z: 1.0, crs: 'cartesian-3d'}), mesh_path:"neo4j-semantic-robot/meshes/coffee-maker/coffee-maker.obj", id:"yellow_coffee_maker", status:"idle", height:0.2}}, {_id:3, properties:{dumping_time_millis:2000, location:point({x: 1.235, y: -0.1, z: 1.0, crs: 'cartesian-3d'}), id:"kitchen-sink", label:"Kitchen Sink", drain_home:point({x: 1.435, y: -0.105, z: 1.2, crs: 'cartesian-3d'}), status:"idle"}}] AS row
CREATE (n:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row._id}) SET n += row.properties SET n:Object:Static;
UNWIND [{_id:4, properties:{color:"Red", `location.Y`:-0.5, `location.Z`:0.911, last_fresh_brew:datetime('2026-05-01T02:06:43.328Z'), scale:0.003, mesh_path_empty:"neo4j-semantic-robot/meshes/red-coffee-cup-empty/3d-model.obj", coffee_cup_level:"full", grip_y_offset:0.0185, id:"red_cup_target", radius:0.05, height:0.2, p_r:0.04, quat_home:[0,0,-.707,.707], origin_z_offset:0.06, qx:0, qy:0, qz:-0.707, qw:0.707, p_x:1.42, mesh_correction_x:0,  p_z:0.911, label:"Red Cup", p_y:-0.5, mesh_correction_y:0, home:point({x: 1.42, y: -0.5, z: 0.911, crs: 'cartesian-3d'}), p_type:"box", `location.X`:1.42, location:point({x: 1.42, y: -0.5, z: 0.911, crs: 'cartesian-3d'}), mesh_path:"neo4j-semantic-robot/meshes/red-coffee-cup/3d-model.obj", status:"idle"}}] AS row
CREATE (n:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row._id}) SET n += row.properties SET n:Target:Object;
UNWIND [{_id:0, properties:{qw:0.7071, qx:-0.7071, qy:0.0, p_x:1.0, qz:0.0, scale:1.0, p_z:1.0, label:"Countertop", p_y:1.0, p_type:"mesh", location:point({x: 1.65, y: -0.35, z: -1.0, crs: 'cartesian-3d'}), mesh_path:"neo4j-semantic-robot/meshes/kitchen-counter/kitchen-counter.obj", id:"countertop"}}] AS row
CREATE (n:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row._id}) SET n += row.properties SET n:Surface;
UNWIND [{_id:5, properties:{quat:[0, 0, 1, 0], qw:0.0, `location.Y`:0, qx:0, `location.Z`:1.25, qy:1.0, qz:0, scale:1.5, label:"Right Hand", home:point({x: 0.5, y: 0.0, z: 1.25, crs: 'cartesian-3d'}), name:"Franka Emika Hand", p_type:"box", `location.X`:0.5, location:point({x: 0.5, y: 0.0, z: 1.25, crs: 'cartesian-3d'}), id:"humanoid_hand", grip_z_offset:0.06, state:"arrived", status:"idle"}}] AS row
CREATE (n:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row._id}) SET n += row.properties SET n:Hand;
UNWIND [{_id:6, properties:{id:"rm_001", label:"Kitchen"}}] AS row
CREATE (n:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row._id}) SET n += row.properties SET n:Room;
UNWIND [{start: {_id:2}, end: {_id:6}, properties:{}}, {start: {_id:3}, end: {_id:6}, properties:{}}] AS row
MATCH (start:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.start._id})
MATCH (end:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.end._id})
CREATE (start)-[r:IN_ROOM]->(end) SET r += row.properties;
UNWIND [{start: {_id:4}, end: {_id:6}, properties:{}}] AS row
MATCH (start:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.start._id})
MATCH (end:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.end._id})
CREATE (start)-[r:IN_ROOM]->(end) SET r += row.properties;
UNWIND [{start: {_id:6}, end: {_id:0}, properties:{}}] AS row
MATCH (start:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.start._id})
MATCH (end:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.end._id})
CREATE (start)-[r:HAS_SURFACE]->(end) SET r += row.properties;
UNWIND [{start: {_id:0}, end: {_id:6}, properties:{}}] AS row
MATCH (start:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.start._id})
MATCH (end:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.end._id})
CREATE (start)-[r:IN_ROOM]->(end) SET r += row.properties;
UNWIND [{start: {_id:1}, end: {_id:5}, properties:{}}, {start: {_id:7}, end: {_id:5}, properties:{}}] AS row
MATCH (start:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.start._id})
MATCH (end:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.end._id})
CREATE (start)-[r:HAS_PARENT]->(end) SET r += row.properties;
UNWIND [{start: {_id:2}, end: {_id:0}, properties:{}}, {start: {_id:3}, end: {_id:0}, properties:{}}] AS row
MATCH (start:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.start._id})
MATCH (end:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.end._id})
CREATE (start)-[r:IS_ON]->(end) SET r += row.properties;
UNWIND [{start: {_id:4}, end: {_id:0}, properties:{}}] AS row
MATCH (start:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.start._id})
MATCH (end:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.end._id})
CREATE (start)-[r:IS_ON]->(end) SET r += row.properties;
MATCH (n:`UNIQUE IMPORT LABEL`)  WITH n LIMIT 20000 REMOVE n:`UNIQUE IMPORT LABEL` REMOVE n.`UNIQUE IMPORT ID`;
DROP CONSTRAINT UNIQUE_IMPORT_NAME;
