# network

Two Docker bridges that stand in for a public subnet and a private subnet.

| Network | `internal` | Who joins | Default ranges |
|---|---|---|---|
| `frontend` | `false` | nodes, optional nginx load balancer | dev `10.10.0.0/24`, staging `10.20.0.0/24`, prod `10.30.0.0/24` |
| `backend` | `true` | nodes, Postgres | dev `10.10.1.0/24`, staging `10.20.1.0/24`, prod `10.30.1.0/24` |

CIDRs must be inside `10.0.0.0/8` so they stay out of Docker's default `172.17.0.0/16` bridge and the `192.168.0.0/16` range Docker Desktop often uses. The backend bridge is internal: it is not attached to the host's external interfaces and the database publishes no port.

Labels on both networks: `environment`, `managed-by=terraform`, `project`, `owner`.
