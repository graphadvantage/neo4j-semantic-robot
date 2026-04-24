import os
import asyncio
import numpy as np
from scipy.spatial.transform import Rotation as R, Slerp
from dotenv import load_dotenv
from neo4j import GraphDatabase
import foxglove
from foxglove.channels import SceneUpdateChannel
from foxglove.messages import (
    SceneUpdate, SceneEntity, CubePrimitive, 
    ModelPrimitive, Vector3, Color, Pose, Quaternion, Timestamp
)

load_dotenv()

# --- CONFIG ---
ROBOT_MESH_BASE = "package://franka_description/meshes/robot_ee/franka_hand_white/visual"
CUP_MESH_PATH = "file:///Users/michaelmoore/GitHub/neo4j-semantic-robot/meshes/red-coffee-cup/3d-model.obj"
ROBOT_SCALE = 1.5
FINGER_OPEN_OFFSET = 0.06
HAND_BASE_CALIB = R.from_quat([0.0, 0.707, 0.0, 0.707])  # Franka 90° Y mount offset

# STRICT LINEAR KINEMATICS
LINEAR_STEP_POS = 0.012  # Adjusted for slightly faster lift
LINEAR_STEP_ROT = 0.12   
GRASP_THRESHOLD = 0.02   # 2cm threshold for the initial "handshake"
WITHDRAWAL_THRESHOLD = 0.25  # fingers stay open until hand clears this distance from cup

NEO4J_URI = os.getenv("NEO4J_URI", "bolt://localhost:7687")
NEO4J_AUTH = (os.getenv("NEO4J_USER", "neo4j"), os.getenv("NEO4J_PASSWORD"))

async def main():
    scene_channel = SceneUpdateChannel("/scene")
    server = foxglove.start_server(host="127.0.0.1", port=8765)
    driver = GraphDatabase.driver(NEO4J_URI, auth=NEO4J_AUTH)
    print("🚀 LINEAR STICKY ENGINE: Eliminating lift-teleport via state-locking.")

    curr_h_pos = None
    curr_h_rot = None
    curr_f_prog = 0.0
    is_grasped = False
    prev_hand_state = None

    def get_xyz(p):
        if hasattr(p, "x"): return [p.x, p.y, p.z]
        return [p.get("x", 0), p.get("y", 0), p.get("z", 0)]

    try:
        while True:
            current_time = Timestamp.now()
            entities = []
            
            try:
              with driver.session() as session:
                res = session.run("""
                    MATCH (h:Hand {id: 'humanoid_hand'}), (c:Object {id: 'red_cup_target'})
                    OPTIONAL MATCH (s:Surface {id: 'countertop'})
                    OPTIONAL MATCH (f:Finger)-[:HAS_PARENT]->(h)
                    RETURN h, c, s, c.radius as radius, avg(f.finger_tip_reach) as reach
                """)
                record = res.single()
                if not record: continue
                
                hand, cup, surface = record['h'], record['c'], record['s']
                target_radius = record['radius'] or 0.05
                reach = record['reach'] or 0.185
                status = cup.get("status", "idle")
                
                # --- FETCH TARGETS ---
                h_target_pos = np.array(get_xyz(hand["location"]))
                h_target_rot = R.from_quat([hand.get("qx", 0), hand.get("qy", 0), hand.get("qz", 0), hand.get("qw", 1)])
                
                if curr_h_pos is None:
                    curr_h_pos = h_target_pos
                    curr_h_rot = h_target_rot

                # --- LINEAR POSITION ---
                pos_diff = h_target_pos - curr_h_pos
                dist_to_target = np.linalg.norm(pos_diff)
                if dist_to_target > LINEAR_STEP_POS:
                    curr_h_pos += (pos_diff / dist_to_target) * LINEAR_STEP_POS
                else:
                    curr_h_pos = h_target_pos
                
                # --- LINEAR ROTATION ---
                total_rot_diff = (curr_h_rot.inv() * h_target_rot).as_rotvec()
                angle_dist = np.linalg.norm(total_rot_diff)
                if angle_dist > LINEAR_STEP_ROT:
                    ratio = LINEAR_STEP_ROT / angle_dist
                    slerp = Slerp([0, 1], R.from_quat([curr_h_rot.as_quat(), h_target_rot.as_quat()]))
                    curr_h_rot = slerp([ratio])[0]
                else:
                    curr_h_rot = h_target_rot

                # --- HAND STATE WRITEBACK ---
                arrived = np.linalg.norm(h_target_pos - curr_h_pos) <= GRASP_THRESHOLD
                new_hand_state = 'arrived' if arrived else 'moving'
                if new_hand_state != prev_hand_state:
                    session.run("MATCH (h:Hand {id: 'humanoid_hand'}) SET h.state = $s", s=new_hand_state)
                    prev_hand_state = new_hand_state

                # --- STICKY GRASP LOGIC ---
                if status == "grasped":
                    if not is_grasped and arrived:
                        is_grasped = True
                    is_effectively_grasped = is_grasped
                else:
                    is_grasped = False
                    is_effectively_grasped = False

                # Finger progress remains linear
                if status == 'picking':
                    f_target = 1.0
                elif status == 'grasped':
                    f_target = 0.0
                else:  # idle — stay open until hand withdraws from cup
                    cup_pos = np.array(get_xyz(cup["location"]))
                    f_target = 1.0 if np.linalg.norm(curr_h_pos - cup_pos) < WITHDRAWAL_THRESHOLD else 0.0
                f_step = 0.08 
                if abs(f_target - curr_f_prog) > f_step:
                    curr_f_prog += f_step if f_target > curr_f_prog else -f_step
                else:
                    curr_f_prog = f_target

                # --- OFFSET LOGIC ---
                if is_effectively_grasped:
                    cup_world_rot = curr_h_rot * HAND_BASE_CALIB.inv()
                    offset_vec = curr_h_rot.apply(np.array([0.0, 0.0, reach]))
                    ref_pos = [curr_h_pos[0] + offset_vec[0], curr_h_pos[1] + offset_vec[1], curr_h_pos[2] + offset_vec[2]]
                else:
                    cup_world_rot = R.from_quat([cup.get("qx", 0), cup.get("qy", 0), cup.get("qz", 0), cup.get("qw", 1)])
                    ref_pos = get_xyz(cup["location"])

                # --- RENDER ---
                grip_z_offset = hand.get("grip_z_offset", 0.06)
                mesh_offset = cup_world_rot.apply(np.array([0.0, 0.0, -grip_z_offset]))
                mesh_pos = [ref_pos[0] + mesh_offset[0], ref_pos[1] + mesh_offset[1], ref_pos[2] + mesh_offset[2]]
                h_q = curr_h_rot.as_quat()
                c_q = cup_world_rot.as_quat()
                hand_entities = [ModelPrimitive(pose=Pose(position=Vector3(x=curr_h_pos[0], y=curr_h_pos[1], z=curr_h_pos[2]), orientation=Quaternion(x=h_q[0], y=h_q[1], z=h_q[2], w=h_q[3])), scale=Vector3(x=ROBOT_SCALE, y=ROBOT_SCALE, z=ROBOT_SCALE), url=f"{ROBOT_MESH_BASE}/hand.dae")]

                fing_res = session.run("MATCH (f:Finger)-[:HAS_PARENT]->(h:Hand) RETURN f.side as side, f.local_offset_x as ox, f.local_offset_z as oz, f.reference_fully_open as ref_open")
                for f in fing_res:
                    grasp_y = (target_radius if f['side'] == 'left' else -target_radius) if is_effectively_grasped else 0.0
                    y_spread = grasp_y + curr_f_prog * (f['ref_open'] - grasp_y)
                    f_local = np.array([f['ox'], y_spread, f['oz']])
                    f_world = curr_h_rot.apply(f_local)
                    f_rot = curr_h_rot if f['side'] == 'left' else curr_h_rot * R.from_euler('z', 180, degrees=True)
                    fq = f_rot.as_quat()
                    hand_entities.append(ModelPrimitive(pose=Pose(position=Vector3(x=curr_h_pos[0] + f_world[0], y=curr_h_pos[1] + f_world[1], z=curr_h_pos[2] + f_world[2]), orientation=Quaternion(x=fq[0], y=fq[1], z=fq[2], w=fq[3])), scale=Vector3(x=ROBOT_SCALE, y=ROBOT_SCALE, z=ROBOT_SCALE), url=f"{ROBOT_MESH_BASE}/finger.dae"))
                
                entities.append(SceneEntity(id="humanoid_hand", frame_id="world", timestamp=current_time, models=hand_entities))
                entities.append(SceneEntity(id="coffee_cup", frame_id="world", timestamp=current_time, 
                    models=[ModelPrimitive(pose=Pose(position=Vector3(x=mesh_pos[0], y=mesh_pos[1], z=mesh_pos[2]), orientation=Quaternion(x=c_q[0], y=c_q[1], z=c_q[2], w=c_q[3])), scale=Vector3(x=0.003, y=0.003, z=0.003), url=CUP_MESH_PATH)],
                    cubes=[CubePrimitive(size=Vector3(x=0.15, y=0.1, z=0.12), pose=Pose(position=Vector3(x=ref_pos[0], y=ref_pos[1], z=ref_pos[2]), orientation=Quaternion(x=c_q[0], y=c_q[1], z=c_q[2], w=c_q[3])), color=Color(r=0, g=1, b=0, a=0.2))]))

                if surface:
                    s_loc = get_xyz(surface["location"])
                    entities.append(SceneEntity(id="countertop", frame_id="world", timestamp=current_time, cubes=[CubePrimitive(size=Vector3(x=2.0, y=1.0, z=0.05), pose=Pose(position=Vector3(x=s_loc[0], y=s_loc[1], z=s_loc[2]), orientation=Quaternion(x=0, y=0, z=0, w=1)), color=Color(r=0.4, g=0.4, b=0.4, a=0.5))]))

              scene_channel.log(SceneUpdate(entities=entities))
            except Exception as e:
                print(f"⚠️ Frame error: {e}")
            await asyncio.sleep(0.03)
    finally:
        driver.close()

if __name__ == "__main__":
    asyncio.run(main())