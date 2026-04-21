import os
import time
import asyncio
from dotenv import load_dotenv
from neo4j import GraphDatabase
import foxglove
from foxglove.channels import SceneUpdateChannel, LogChannel, FrameTransformChannel
from foxglove.messages import (
    SceneUpdate, SceneEntity, CubePrimitive, 
    ModelPrimitive, Vector3, Color, Log, LogLevel, Pose, Quaternion,
    Timestamp, FrameTransform
)

# --- INITIALIZATION ---
load_dotenv() 

# --- GLOBAL CONFIGURATION ---
MODE = "LIVE"  
ROBOT_SCALE_FACTOR = 1.5
CUP_SCALE_FACTOR = 0.003
ROBOT_MESH_BASE = "package://franka_description/meshes/robot_ee/franka_hand_white/visual"
CUP_MESH_PATH = "file:///Users/michaelmoore/GitHub/neo4j-semantic-robot/meshes/red-coffee-cup/3d-model.obj"

# --- CALIBRATED OFFSETS ---
# If Claude says "Go to 0.75", the Hand actually goes to 0.81 (0.75 + 0.06)
HAND_Z_OFFSET = 0.06 
# When grasped, the cup center is adjusted relative to the hand to stay on target
CUP_GRASP_CORRECTION = -0.06 

NEO4J_URI = os.getenv("NEO4J_URI", "bolt://localhost:7687")
NEO4J_AUTH = (os.getenv("NEO4J_USER", "neo4j"), os.getenv("NEO4J_PASSWORD"))

async def main():
    scene_channel = SceneUpdateChannel("/scene")
    log_channel = LogChannel("/logs") 
    tf_channel = FrameTransformChannel("/tf") 
    server = foxglove.start_server(host="127.0.0.1", port=8765)
    
    driver = None
    if MODE == "LIVE":
        try:
            driver = GraphDatabase.driver(NEO4J_URI, auth=NEO4J_AUTH)
            print("🚀 LIVE: Active Offset Authority Enabled")
        except Exception as e:
            print(f"❌ Connection Failed: {e}")
            return

    curr_h = {"x": 0.5, "y": -0.55, "z": 0.9}
    curr_f_prog = 0.0
    status = "idle" 
    counter_pos = {"x": 1.0, "y": -0.5, "z": 0.725} 
    counter_dims = {"x": 2.0, "y": 1.0, "z": 0.05}

    try:
        while True:
            current_time = Timestamp.now()
            
            # --- 1. DATA ACQUISITION & SEMANTIC OFFSET ---
            if MODE == "LIVE":
                try:
                    with driver.session() as session:
                        res = session.run("""
                            MATCH (a:Actor {id: 'humanoid_hand'})
                            MATCH (o:Object {id: 'red_cup_target'})
                            OPTIONAL MATCH (s:Surface {id: 'countertop'})
                            RETURN a.location.x AS hx, a.location.y AS hy, a.location.z AS hz,
                                   o.location.x AS cx, o.location.y AS cy, o.location.z AS cz,
                                   o.radius AS radius, o.status AS status,
                                   s.location.x AS sx, s.location.y AS sy, s.location.z AS sz
                        """)
                        record = res.single()
                        if record:
                            status = record["status"]
                            # AUTHORITY: We add our calibrated offset to whatever Z Claude provided
                            # This prevents the hand from dropping to 0.75 (the table surface)
                            target_h = {
                                "x": record["hx"], 
                                "y": record["hy"], 
                                "z": record["hz"] + HAND_Z_OFFSET
                            }
                            
                            cup_db_pos = {"x": record["cx"], "y": record["cy"], "z": record["cz"]}
                            cup_radius = record["radius"] if record["radius"] else 0.05
                            if record["sx"] is not None:
                                counter_pos = {"x": record["sx"], "y": record["sy"], "z": record["sz"]}
                except Exception: continue

            # --- 2. HANDSHAKE ---
            target_f_prog = 1.0 if status in ["picking", "grasped"] else 0.0
            if MODE == "LIVE" and status == "picking" and curr_f_prog > 0.95:
                try:
                    with driver.session() as session:
                        session.run("MATCH (o:Object {id: 'red_cup_target'}) SET o.status = 'grasped'")
                except: pass

            # --- 3. KINEMATICS ---
            table_top_z = counter_pos["z"] + (counter_dims["z"] / 2)
            curr_h["x"] += (target_h["x"] - curr_h["x"]) * 0.1
            curr_h["y"] += (target_h["y"] - curr_h["y"]) * 0.1
            curr_h["z"] += (target_h["z"] - curr_h["z"]) * 0.1
            curr_f_prog += (target_f_prog - curr_f_prog) * 0.1

            # Full Kinematic Parenting
            if status == "grasped":
                render_cup_x = curr_h["x"] + (cup_radius * 1.75)
                render_cup_y = curr_h["y"]
                # Align cup back to the database's original intended Z (e.g. 0.75) 
                # while the hand stays at 0.81
                render_cup_z = curr_h["z"] + CUP_GRASP_CORRECTION
            else:
                # Clamp hand safety
                stop_x = cup_db_pos["x"] - (cup_radius * 1.75)
                if status == "picking" and curr_h["x"] > stop_x:
                    curr_h["x"] = stop_x
                
                render_cup_x, render_cup_y = cup_db_pos["x"], cup_db_pos["y"]
                # Cup is forced to table top visually
                render_cup_z = table_top_z

            # --- 4. RENDERING ---
            r_scale = Vector3(x=ROBOT_SCALE_FACTOR, y=ROBOT_SCALE_FACTOR, z=ROBOT_SCALE_FACTOR)
            c_scale = Vector3(x=CUP_SCALE_FACTOR, y=CUP_SCALE_FACTOR, z=CUP_SCALE_FACTOR)
            f_offset = (0.06 * ROBOT_SCALE_FACTOR) - (curr_f_prog * (0.027 * ROBOT_SCALE_FACTOR))

            scene_channel.log(SceneUpdate(entities=[
                SceneEntity(id="countertop", frame_id="world", timestamp=current_time,
                    cubes=[CubePrimitive(size=Vector3(x=2.0, y=1.0, z=0.05), color=Color(r=0.4, g=0.4, b=0.4, a=0.5),
                    pose=Pose(position=Vector3(x=counter_pos["x"], y=counter_pos["y"], z=counter_pos["z"]), orientation=Quaternion(x=0,y=0,z=0,w=1)))]),
                SceneEntity(id="coffee_cup", frame_id="world", timestamp=current_time,
                    models=[ModelPrimitive(pose=Pose(position=Vector3(x=render_cup_x, y=render_cup_y, z=render_cup_z), 
                    orientation=Quaternion(x=0, y=0, z=0, w=1)), scale=c_scale, url=CUP_MESH_PATH, color=Color(r=1, g=1, b=1, a=1))]),
                SceneEntity(id="humanoid_hand", frame_id="world", timestamp=current_time,
                    models=[
                        ModelPrimitive(pose=Pose(position=Vector3(x=curr_h["x"] - 0.1, y=curr_h["y"], z=curr_h["z"]), orientation=Quaternion(x=0, y=0.707, z=0, w=0.707)), scale=r_scale, url=f"{ROBOT_MESH_BASE}/hand.dae"),
                        ModelPrimitive(pose=Pose(position=Vector3(x=curr_h["x"], y=curr_h["y"] + f_offset, z=curr_h["z"]), orientation=Quaternion(x=0, y=0.707, z=0, w=0.707)), scale=r_scale, url=f"{ROBOT_MESH_BASE}/finger.dae"),
                        ModelPrimitive(pose=Pose(position=Vector3(x=curr_h["x"], y=curr_h["y"] - f_offset, z=curr_h["z"]), orientation=Quaternion(x=0.707, y=0, z=0.707, w=0)), scale=r_scale, url=f"{ROBOT_MESH_BASE}/finger.dae")
                    ])
            ]))
            await asyncio.sleep(0.03) 
            
    finally:
        if driver: driver.close()

if __name__ == "__main__":
    asyncio.run(main())