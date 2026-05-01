// setup-robot-user.cyp
// Creates the `robot` database user and `claude_agent` RBAC role with
// least-privilege write access for Claude Desktop via neo4j-mcp.
//
// Requirements: Neo4j Enterprise Edition (RBAC not available in Community)
// Run each statement sequentially in Neo4j Browser or cypher-shell.
// Update the password before running in any non-local environment.

// ------------------------------------------------------------
// 1. Dedicated user for Claude Desktop MCP connection
// ------------------------------------------------------------
// Set the password below and use the same value for NEO4J_PASSWORD in claude_desktop_config.json
CREATE USER robot IF NOT EXISTS
SET PASSWORD 'i_am_skynet'
SET PASSWORD CHANGE NOT REQUIRED;

// ------------------------------------------------------------
// 2. Role
// ------------------------------------------------------------
CREATE ROLE claude_agent IF NOT EXISTS;

// ------------------------------------------------------------
// 3. Read — full access to all nodes, relationships, properties
//    Agent must read all state before reasoning about any action
// ------------------------------------------------------------
GRANT MATCH {*} ON GRAPH neo4j ELEMENTS * TO claude_agent;

// ------------------------------------------------------------
// 4. Hand node — position and rotation only
//    Excluded: state (server-owned), grip_z_offset, home, id
// ------------------------------------------------------------
GRANT SET PROPERTY {location, qx, qy, qz, qw}
  ON GRAPH neo4j NODES Hand TO claude_agent;

// ------------------------------------------------------------
// 5. Target nodes (red cup) — state transition properties only
//    Excluded: id, label, radius, grip_y_offset, home,
//              mesh_path, mesh_path_empty, *_home, *_time_millis
// ------------------------------------------------------------
GRANT SET PROPERTY {location, qx, qy, qz, qw, status, coffee_cup_level, last_fresh_brew}
  ON GRAPH neo4j NODES Target TO claude_agent;

// ------------------------------------------------------------
// 6. Static nodes — deny all writes
//    Covers: coffee maker, countertop, and any future static objects
//    DENY takes precedence over GRANT — protected regardless of
//    any future Object-level grants
// ------------------------------------------------------------
DENY SET PROPERTY {*}
  ON GRAPH neo4j NODES Static TO claude_agent;

// ------------------------------------------------------------
// 7. APOC procedures required for plan execution
// ------------------------------------------------------------
GRANT EXECUTE PROCEDURE apoc.periodic.iterate ON DBMS TO claude_agent;
GRANT EXECUTE PROCEDURE apoc.util.sleep ON DBMS TO claude_agent;

// ------------------------------------------------------------
// 8. Assign role
// ------------------------------------------------------------
GRANT ROLE claude_agent TO robot;
