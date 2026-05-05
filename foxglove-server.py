import os
import asyncio
import threading
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
import numpy as np
from scipy.spatial.transform import Rotation as R, Slerp
from dotenv import load_dotenv
from neo4j import GraphDatabase
import foxglove
from foxglove.websocket import Capability
from foxglove.channels import SceneUpdateChannel, FrameTransformChannel
from foxglove.messages import (
    SceneUpdate, SceneEntity, CubePrimitive,
    ModelPrimitive, Vector3, Color, Pose, Quaternion, Timestamp,
    FrameTransform
)

load_dotenv()

# --- CONFIG ---
PATH_TO_REPO = os.getenv("PATH_TO_REPO", "file:///Users/michaelmoore/GitHub/")
REPO_ROOT = PATH_TO_REPO.replace("file://", "").rstrip("/")
MESH_HTTP_PORT = 8766
DEFAULT_CUP_MESH     = PATH_TO_REPO + "neo4j-semantic-robot/meshes/red-coffee-cup/3d-model.obj"
DEFAULT_COUNTER_MESH = PATH_TO_REPO + "neo4j-semantic-robot/meshes/kitchen-counter/kitchen-counter.obj"
ROBOT_MESH_BASE = f"http://127.0.0.1:{MESH_HTTP_PORT}/franka_description/meshes/robot_ee/franka_hand_white/visual"

class _MeshHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urllib.parse.unquote(self.path.lstrip("/"))
        full = os.path.join(REPO_ROOT, path)
        try:
            with open(full, "rb") as f:
                data = f.read()
            self.send_response(200)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(data)
        except Exception:
            self.send_response(404)
            self.end_headers()
    def log_message(self, *args): pass

threading.Thread(
    target=lambda: HTTPServer(("127.0.0.1", MESH_HTTP_PORT), _MeshHandler).serve_forever(),
    daemon=True
).start()

def resolve_mesh(path, default=""):
    if not path:
        path = default
    if not path:
        return ""
    if not path.startswith(("file://", "package://")):
        path = PATH_TO_REPO + path
    if path.startswith("file://"):
        rel = os.path.relpath(path[7:], REPO_ROOT)
        return f"http://127.0.0.1:{MESH_HTTP_PORT}/{rel}"
    elif path.startswith("package://"):
        return f"http://127.0.0.1:{MESH_HTTP_PORT}/{path[10:]}"
    return path

ROBOT_SCALE = 1.5
HAND_BASE_CALIB = R.from_quat([0.0, 0.707, 0.0, 0.707])

# KINEMATICS
LINEAR_STEP_POS = 0.04
LINEAR_STEP_ROT = 0.12
GRASP_THRESHOLD = 0.02
WITHDRAWAL_THRESHOLD = 0.25

NEO4J_URI = os.getenv("NEO4J_URI", "bolt://localhost:7687")
NEO4J_AUTH = (os.getenv("NEO4J_USER", "neo4j"), os.getenv("NEO4J_PASSWORD"))

async def main():
    scene_channel = SceneUpdateChannel("/scene")
    tf_channel = FrameTransformChannel("/tf")
    server = foxglove.start_server(host="127.0.0.1", port=8765, capabilities=[Capability.Time])
    driver = GraphDatabase.driver(NEO4J_URI, auth=NEO4J_AUTH)
    print("🚀 STABLE ENGINE: Commit Ready")

    curr_h_pos, curr_h_rot = None, None
    curr_f_prog = 0.0
    is_grasped = False
    cup_local_rot = None

    def get_xyz(p):
        if hasattr(p, "x"): return [p.x, p.y, p.z]
        return [p.get("x", 0), p.get("y", 0), p.get("z", 0)]

    try:
        while True:
            current_time = Timestamp.now()
            entities = []
            
            try:
              with driver.session() as session:
                rec = session.run("""
                    MATCH (h:Hand {id: 'humanoid_hand'})
                    OPTIONAL MATCH (c:Object {id: 'red_cup_target'})
                    OPTIONAL MATCH (s:Surface {id: 'countertop'})
                    OPTIONAL MATCH (extra:Object) WHERE extra.id <> 'red_cup_target'
                    RETURN h, c, s, collect(extra) AS env_objects, c.radius AS radius
                """).single()
                if not rec: continue

                hand, cup, surface = rec['h'], rec['c'], rec['s']
                env_objects = rec['env_objects']
                target_radius = rec['radius'] or 0.05
                status = cup.get("status", "idle") if cup else "idle"

                fingers = list(session.run("""
                    MATCH (f:Finger)-[:HAS_PARENT]->(h:Hand {id: 'humanoid_hand'})
                    RETURN f.side AS side, f.local_offset_x AS ox, f.local_offset_z AS oz,
                           f.reference_fully_open AS ref_open, f.finger_tip_reach AS reach
                """))
                reach = (sum(f['reach'] for f in fingers if f['reach']) / len(fingers)) if fingers else 0.1675
                
                # --- HAND KINEMATICS ---
                h_target_pos = np.array(get_xyz(hand["location"]))
                h_target_rot = R.from_quat([hand.get("qx", 0), hand.get("qy", 0), hand.get("qz", 0), hand.get("qw", 1)])
                if curr_h_pos is None:
                    curr_h_pos, curr_h_rot = h_target_pos, h_target_rot

                pos_diff = h_target_pos - curr_h_pos
                dist = np.linalg.norm(pos_diff)
                curr_h_pos += (pos_diff / dist * LINEAR_STEP_POS) if dist > LINEAR_STEP_POS else (h_target_pos - curr_h_pos)
                
                rot_diff = (curr_h_rot.inv() * h_target_rot).as_rotvec()
                a_dist = np.linalg.norm(rot_diff)
                if a_dist > LINEAR_STEP_ROT:
                    curr_h_rot = Slerp([0, 1], R.from_quat([curr_h_rot.as_quat(), h_target_rot.as_quat()]))([LINEAR_STEP_ROT / a_dist])[0]
                else:
                    curr_h_rot = h_target_rot

                # --- GRASP STATE ---
                arrived = np.linalg.norm(h_target_pos - curr_h_pos) <= GRASP_THRESHOLD
                if status == "grasped" and not is_grasped and arrived:
                    is_grasped = True
                    cup_rot_at_grasp = R.from_quat([cup.get("qx", 0), cup.get("qy", 0), cup.get("qz", 0), cup.get("qw", 1)])
                    cup_local_rot = curr_h_rot.inv() * cup_rot_at_grasp
                if status != "grasped":
                    is_grasped = False
                    cup_local_rot = None

                # --- HAND STATE WRITEBACK ---
                session.run("MATCH (h:Hand {id: 'humanoid_hand'}) SET h.state = $s",
                            s='arrived' if arrived else 'moving')

                # --- FINGER ANIMATION ---
                if status == 'picking':
                    f_target = 1.0
                elif status == 'grasped':
                    f_target = 0.0
                else:
                    if cup:
                        cup_pos = np.array(get_xyz(cup["location"]))
                        f_target = 1.0 if np.linalg.norm(curr_h_pos - cup_pos) < WITHDRAWAL_THRESHOLD else 0.0
                    else:
                        f_target = 0.0
                f_step = 0.2
                curr_f_prog += f_step if f_target > curr_f_prog + f_step else (-f_step if f_target < curr_f_prog - f_step else f_target - curr_f_prog)

                # --- CUP RENDERING (MESH + BOUNDING BOX) ---
                if cup:
                    if is_grasped:
                        cup_world_rot = curr_h_rot * cup_local_rot
                        offset_vec = curr_h_rot.apply(np.array([0.0, 0.0, reach]))
                        grip_world = curr_h_rot.apply(np.array([0.0, cup.get("grip_y_offset", 0.0), 0.0]))
                        ref_pos = curr_h_pos + offset_vec - grip_world
                    else:
                        _qh = cup.get("quat_home") or [0.0, 0.0, -0.707, 0.707]
                        cup_world_rot = R.from_quat([cup.get("qx", _qh[0]), cup.get("qy", _qh[1]), cup.get("qz", _qh[2]), cup.get("qw", _qh[3])])
                        ref_pos = np.array(get_xyz(cup["location"]))

                    mesh_off = cup_world_rot.apply(np.array([0.0, 0.0, -hand.get("grip_z_offset", 0.06)]))
                    m_p, c_q = ref_pos + mesh_off, cup_world_rot.as_quat()
                    cup_mesh_path = cup.get("mesh_path_empty") if cup.get("coffee_cup_level") == "empty" else cup.get("mesh_path")

                    entities.append(SceneEntity(
                        id="coffee_cup",
                        frame_id="world",
                        timestamp=current_time,
                        models=[ModelPrimitive(
                            pose=Pose(position=Vector3(x=m_p[0], y=m_p[1], z=m_p[2]),
                                      orientation=Quaternion(x=c_q[0], y=c_q[1], z=c_q[2], w=c_q[3])),
                            scale=Vector3(x=0.003, y=0.003, z=0.003),
                            url=resolve_mesh(cup_mesh_path, DEFAULT_CUP_MESH)
                        )],
                        cubes=[CubePrimitive(
                            size=Vector3(x=0.15, y=0.1, z=0.12), 
                            pose=Pose(position=Vector3(x=ref_pos[0], y=ref_pos[1], z=ref_pos[2]), 
                                      orientation=Quaternion(x=c_q[0], y=c_q[1], z=c_q[2], w=c_q[3])), 
                            color=Color(r=0, g=1, b=0, a=0.2)
                        )]
                    ))

                # --- ENVIRONMENT OBJECTS ---
                for obj in env_objects:
                    o_loc = get_xyz(obj["location"])
                    o_q = [obj.get("qx", 0), obj.get("qy", 0), obj.get("qz", 0), obj.get("qw", 1)]
                    o_s = obj.get("scale", 1.0)
                    entities.append(SceneEntity(id=obj["id"], frame_id="world", timestamp=current_time,
                        models=[ModelPrimitive(pose=Pose(position=Vector3(x=o_loc[0], y=o_loc[1], z=o_loc[2]), orientation=Quaternion(x=o_q[0], y=o_q[1], z=o_q[2], w=o_q[3])), scale=Vector3(x=o_s, y=o_s, z=o_s), url=resolve_mesh(obj.get("mesh_path")))]))

                # --- COUNTERTOP ---
                if surface:
                    s_loc = get_xyz(surface["location"])
                    entities.append(SceneEntity(id="countertop", frame_id="world", timestamp=current_time, 
                        models=[ModelPrimitive(pose=Pose(position=Vector3(x=s_loc[0], y=s_loc[1], z=s_loc[2]), orientation=Quaternion(x=surface.get("qx", 0), y=surface.get("qy", 0), z=surface.get("qz", 0), w=surface.get("qw", 1))), scale=Vector3(x=surface.get("p_x", 1.0), y=surface.get("p_y", 1.0), z=surface.get("p_z", 1.0)), url=resolve_mesh(surface.get("mesh_path"), DEFAULT_COUNTER_MESH))]))

                # --- HAND RENDER ---
                h_q = curr_h_rot.as_quat()
                hand_m = [ModelPrimitive(pose=Pose(position=Vector3(x=curr_h_pos[0], y=curr_h_pos[1], z=curr_h_pos[2]), orientation=Quaternion(x=h_q[0], y=h_q[1], z=h_q[2], w=h_q[3])), scale=Vector3(x=ROBOT_SCALE, y=ROBOT_SCALE, z=ROBOT_SCALE), url=f"{ROBOT_MESH_BASE}/hand.dae")]
                
                for f in fingers:
                    grasp_y = (target_radius if f['side'] == 'left' else -target_radius) if is_grasped else 0.0
                    y_spread = grasp_y + curr_f_prog * (f['ref_open'] - grasp_y)
                    f_local = np.array([f['ox'], y_spread, f['oz']])
                    f_world = curr_h_rot.apply(f_local)
                    f_rot = curr_h_rot if f['side'] == 'left' else curr_h_rot * R.from_euler('z', 180, degrees=True)
                    fq = f_rot.as_quat()
                    hand_m.append(ModelPrimitive(pose=Pose(position=Vector3(x=curr_h_pos[0] + f_world[0], y=curr_h_pos[1] + f_world[1], z=curr_h_pos[2] + f_world[2]), orientation=Quaternion(x=fq[0], y=fq[1], z=fq[2], w=fq[3])), scale=Vector3(x=ROBOT_SCALE, y=ROBOT_SCALE, z=ROBOT_SCALE), url=f"{ROBOT_MESH_BASE}/finger.dae"))
                
                entities.append(SceneEntity(id="humanoid_hand", frame_id="world", timestamp=current_time, models=hand_m))

              server.broadcast_time(int(current_time.sec * 1e9 + current_time.nsec))
              tf_channel.log(FrameTransform(parent_frame_id="", child_frame_id="world", timestamp=current_time))
              scene_channel.log(SceneUpdate(entities=entities))
            except Exception as e:
                print(f"⚠️ Frame error: {e}")
            await asyncio.sleep(0.015)
    finally:
        driver.close()

if __name__ == "__main__":
    asyncio.run(main())