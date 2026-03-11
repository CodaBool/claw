# local
1. docker compose up -d
2. http://localhost:18789/overview
3. enter in `OPENCLAW_GATEWAY_TOKEN` and `connect`
4. approve device `docker exec claw bash -lc 'openclaw devices approve $(openclaw devices list | grep -m1 -oE "[0-9a-fA-F-]{36}")'`
5. install a secure skill using `npx clawhub install <skill>` to have openclaw build out the folder structure for you
6. run `docker exec claw bash -lc 'node install_skills.mjs'` to install the cached skills

# remote
1. docker compose up -d
2. https://claw.codabool.com/overview
3. enter in `OPENCLAW_GATEWAY_TOKEN` and `connect`
4. `ssh -i claw.pem ec2-user@2600:1f18:1248:e300:f523:4a18:df36:eca1`
5. approve device `docker exec claw bash -lc 'openclaw devices approve $(openclaw devices list | grep -m1 -oE "[0-9a-fA-F-]{36}")'`
6. install a trusted skill using `docker exec claw bash -lc 'npx clawhub install discord'` to have openclaw build out the folder structure for you
7. run `docker exec claw bash -lc 'node install_skills.mjs'` to install the cached skills


# fork?
1. create a .env from the .example.env
2. create a key pair .pem from aws
3. setup [OIDC](https://github.com/marketplace/actions/configure-aws-credentials-action-for-github-actions)
4. add vars to your repo that match the .env file
5. `git clone https://github.com/openclaw/openclaw`

# TODO
- brew installs everytime (fix `init.mjs`)
