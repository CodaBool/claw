# local

# remote
1. docker compose up -d
2. docker exec claw bash -lc 'openclaw devices approve $(openclaw devices list | grep -m1 -oE "[0-9a-fA-F-]{36}")'
