# 01 - Kong Gateway Installation

## Task: Obtain Kong docker compose file and certificates
./setup-docker.sh
git clone https://github.com/kong-education/kong-gateway-operations.git
cd kong-gateway-operations/installation
tree

## Task: Move SSL certificates 
sudo cp -R ssl-certs /srv/shared

## Task: Instantiate log files and deploy Kong
mkdir -p /srv/shared/logs
touch $(grep '/srv/shared/logs/' docker-compose.yaml|awk '{print $2}'|xargs)
chmod a+w /srv/shared/logs/*
docker-compose up -d

## Training Lab Environment
env | grep KONG_ | grep -v SERVICE | sort

## Task: Verify Admin API
http --headers GET kongcluster:8001
### curl -I -X GET kongcluster:8001

## Task: Verify Kong Manager 
echo $KONG_MANAGER_URI

## Task: Apply the licence & Recreate the CP
http POST "$KONG_ADMIN_API_URI/licenses" payload=@/etc/kong/license.json
### curl -X POST kongcluster:8001/licenses -F "payload=@/etc/kong/license.json"
docker-compose stop kong-cp; docker-compose rm -f kong-cp; docker-compose up -d kong-cp

## Task: Save Kong configuration using decK
sed -i "s|KONG_ADMIN_API_URI|$KONG_ADMIN_API_URI|g" deck/deck.yaml

deck --config deck/deck.yaml \
  dump --output-file deck/gwopslab.yaml \
       --workspace default

## Task: Sync updates and view config in Kong Manager

deck --config deck/deck.yaml \
  diff --state deck/sampledump.yaml \
       --workspace default

deck --config deck/deck.yaml \
  sync --state deck/sampledump.yaml \
       --workspace default

## Task: Restore Kong configuration using decK
deck sync --config deck/deck.yaml \
  --state deck/gwopslab.yaml \
  --workspace default

## Task : Create a Developer Account

http POST $KONG_PORTAL_API_URI/default/register <<< '{"email":"myemail@example.com",
                                                      "password":"password",
                                                      "meta":"{\"full_name\":\"Dev E. Loper\"}"
                                                     }'

### curl -X POST "$KONG_PORTAL_API_URI/default/register" \
      -H 'Content-Type: application/json' \
      --data-raw '{"email":"myemail@example.com",
      "password":"password",
      "meta":"{\"full_name\":\"Dev E. Loper\"}"
                  }'

## Task: Task: Approve the Developer
http PATCH "$KONG_ADMIN_API_URI/default/developers/myemail@example.com" <<< '{"status": 0}'

### curl -X PATCH "$KONG_ADMIN_API_URI/default/developers/myemail@example.com" \
      --header 'Content-Type: application/json' \
      --data-raw '{"status": 0}'

## Task: Add an API Spec to test
http --form POST kongcluster:8001/files \
  "path=specs/jokes.one.oas.yaml" \
  "contents=@jokes1OAS.yaml"

### curl -X POST kongcluster:8001/files \
      -F "path=specs/jokes.one.oas.yaml" \
      -F "contents=@jokes1OAS.yaml" 



## Task: Create a dedicated docker network and a database container
docker network create kong-edu-net
docker run -d --name kong-ee-database --network kong-edu-net \
  -p 5432:5432 \
  -e "POSTGRES_USER=kong" \
  -e "POSTGRES_DB=kong-edu" \
  -e "POSTGRES_PASSWORD=kong" \
  postgres:9.6

## Task: Bootstrap the Database for Kong 2.5.1.2
docker run --rm --network kong-edu-net \
  -e "KONG_DATABASE=postgres" \
  -e "KONG_PG_HOST=kong-ee-database" \
  -e "KONG_PG_PORT=5432" \
  -e "KONG_LICENSE_DATA=$KONG_LICENSE_DATA" \
  -e "KONG_PG_PASSWORD=kong" \
  -e "KONG_PG_USER=kong" \
  -e "KONG_PG_PASSWORD=kong" \
  -e "KONG_PASSWORD=admin" \
  -e "KONG_PG_DATABASE=kong-edu" \
  kong/kong-gateway:2.5.1.2-alpine kong migrations bootstrap

## Task: Start Kong Gateway 2.5.1.2
docker run -d --name kong-ee-edu --network kong-edu-net \
  -e "KONG_DATABASE=postgres" \
  -e "KONG_PG_HOST=kong-ee-database" \
  -e "KONG_PG_PORT=5432" \
  -e "KONG_PG_PASSWORD=kong" \
  -e "KONG_PASSWORD=admin" \
  -e "KONG_PG_DATABASE=kong-edu" \
  -e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
  -e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
  -e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
  -e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
  -e "KONG_ADMIN_LISTEN=0.0.0.0:8001" \
  -e "KONG_LICENSE_DATA=$KONG_LICENSE_DATA" \
  -e "KONG_PASSWORD=admin" \
  -e "KONG_ADMIN_GUI_URL=http://localhost:8002" \
  -p 8000-8004:8000-8004 \
  -p 8443-8445:8443-8445 \
  kong/kong-gateway:2.5.1.2-alpine

## Task: Check Version & create a simple service/route
http GET kongcluster:8001 | jq .version
### curl -sX GET kongcluster:8001 | jq .version

http POST kongcluster:8001/services \
  name=httpbin \
  url=https://httpbin.org/anything

### curl -X POST kongcluster:8001/services \
      -d "name=httpbin" \
      -d "url=https://httpbin.org/anything"

http POST kongcluster:8001/services/httpbin/routes \
    name=httpbin \
    paths:='["/httpbin"]'

### curl -X POST kongcluster:8001/services/httpbin/routes \
      -d 'name=httpbin' \
      -d 'paths[]=/httpbin'

## Task: Run the 2.6 migrations
docker run --rm --network kong-edu-net \
  -e "KONG_DATABASE=postgres" \
  -e "KONG_PG_HOST=kong-ee-database" \
  -e "KONG_PG_PORT=5432" \
  -e "KONG_PG_DATABASE=kong-edu" \
  -e "KONG_LICENSE_DATA=$KONG_LICENSE_DATA" \
  -e "KONG_PG_PASSWORD=kong" \
  -e "KONG_PASSWORD=admin" \
  kong/kong-gateway:2.6.0.1-alpine \
  kong migrations up

## Task: Complete the 2.6 migrations
docker run --rm --network kong-edu-net \
  -e "KONG_DATABASE=postgres" \
  -e "KONG_PG_HOST=kong-ee-database" \
  -e "KONG_PG_DATABASE=kong-edu" \
  -e "KONG_PG_PORT=5432" \
  -e "KONG_LICENSE_DATA=$KONG_LICENSE_DATA" \
  -e "KONG_PG_PASSWORD=kong" \
  -e "KONG_PASSWORD=admin" \
  kong/kong-gateway:2.6.0.1-alpine kong migrations finish

  docker container rm $(docker container stop kong-ee-edu)

Task: Start the new 2.6 container:

docker run -d --name kong-ee-edu --network kong-edu-net \
  -e "KONG_DATABASE=postgres" \
  -e "KONG_PG_HOST=kong-ee-database" \
  -e "KONG_PG_PORT=5432" \
  -e "KONG_PG_PASSWORD=kong" \
  -e "KONG_PG_HOST=kong-ee-database" \
  -e "KONG_PG_DATABASE=kong-edu" \
  -e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
  -e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
  -e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
  -e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
  -e "KONG_ADMIN_LISTEN=0.0.0.0:8001" \
  -e "KONG_LICENSE_DATA=$KONG_LICENSE_DATA" \
  -e "KONG_PASSWORD=admin" \
  -e "KONG_ADMIN_GUI_URL=http://localhost:8002" \
  -p 8000-8004:8000-8004 \
  -p 8443-8445:8443-8445 \
  kong/kong-gateway:2.6.0.1-alpine

## Task: Confirm upgrade and persistence of data
http --headers GET kongcluster:8000/httpbin
### curl -IX GET kongcluster:8000/httpbin

## Task: Upgrade Using Docker Compose
export KONG_VERSION="2.5.1.2-alpine"
docker-compose -f kongupgdemo.yaml up -d

http GET kongcluster:8001 kong-admin-token:admin | \
  jq '.hostname + " " + .version'

### curl -sX GET kongcluster:8001 -H kong-admin-token:admin | \
      jq '.hostname + " " + .version'

http POST kongcluster:8001/services \
  kong-admin-token:admin \
  name=httpbin \
  url=https://httpbin.org/anything

### curl -X POST kongcluster:8001/services \
      -H kong-admin-token:admin \
      -d "name=httpbin" \
      -d "url=https://httpbin.org/anything"

http POST kongcluster:8001/services/httpbin/routes \
  kong-admin-token:admin \
  name=httpbin \
  paths:='["/httpbin"]'

### curl -X POST kongcluster:8001/services/httpbin/routes \
      -H kong-admin-token:admin \
      -d 'name=httpbin' \
      -d 'paths[]=/httpbin'

http --headers GET kongcluster:8000/httpbin
### curl -IX GET kongcluster:8000/httpbin










# 04 - Securing Kong

```ThroughGUI
To create new roles and permissions
1. Log into Kong Manager
2. Navigate to Teams > Roles
3. Click View next to Default workspace
   You will see existing Roles
4. Click Add Role and name it my_role
5. Click Add Permission
   Notice you can have very granular CRUD permissions for any endpoint
6. Select permissions as illustrated
7. Click Add Permissions to Role
8. Click Create
```
Alternative:
http $KONG_ADMIN_API_URI/rbac/roles name=my_role
http $KONG_ADMIN_API_URI/rbac/roles/my_role/endpoints/ \
  	endpoint=* \
  	workspace=default \
  	actions=*

http post $KONG_ADMIN_API_URI/rbac/users name=my-super-admin user_token="my_token"

MY_SUPER_ADMIN_TOKEN=$2b$09$ZPKVKuPiICSaIPoABRdeOeVZCscWDrsUfyxmyUv.nQyCowW/c2s9y
MY_SUPER_ADMIN_TOKEN=$(http get $KONG_ADMIN_API_URI/rbac/users/my-super-admin | jq .user_token | xargs)
echo $MY_SUPER_ADMIN_TOKEN

http get $KONG_ADMIN_API_URI/rbac/users/my-super-admin/roles
http POST $KONG_ADMIN_API_URI/rbac/users/my-super-admin/roles roles='my_role'
http get $KONG_ADMIN_API_URI/rbac/users/my-super-admin/roles

http post $KONG_ADMIN_API_URI/rbac/users name=super-admin user_token="super-admin"
http get $KONG_ADMIN_API_URI/rbac/users/super-admin/roles

    #KONG_ENFORCE_RBAC: "on"
    #KONG_ADMIN_GUI_AUTH: "basic-auth"
    #KONG_ADMIN_GUI_SESSION_CONF: "{ \"cookie_name\": \"manager-session\", ...
docker-compose stop kong-cp; docker-compose rm -f kong-cp; docker-compose up -d kong-cp

http get $KONG_ADMIN_API_URI/services
http get $KONG_ADMIN_API_URI/services Kong-Admin-Token:my_token
http --headers get $KONG_ADMIN_API_URI/services Kong-Admin-Token:my_token

http post $KONG_ADMIN_API_URI/workspaces name=WorkspaceA Kong-Admin-Token:my_token
http post $KONG_ADMIN_API_URI/workspaces name=WorkspaceB Kong-Admin-Token:my_token
http get $KONG_ADMIN_API_URI/workspaces Kong-Admin-Token:my_token | jq '.data[].name'

http post $KONG_ADMIN_API_URI/WorkspaceA/rbac/users \
  name=AdminA \
  user_token=AdminA_token \
  Kong-Admin-Token:super-admin
http post $KONG_ADMIN_API_URI/WorkspaceB/rbac/users \
  name=AdminB \
  user_token=AdminB_token \
  Kong-Admin-Token:super-admin

http get $KONG_ADMIN_API_URI/WorkspaceA/rbac/users \
  Kong-Admin-Token:super-admin


http $KONG_ADMIN_API_URI/WorkspaceA/rbac/roles name=admin Kong-Admin-Token:super-admin
http $KONG_ADMIN_API_URI/WorkspaceA/rbac/roles/admin/endpoints/ \
  endpoint=* \
  workspace=WorkspaceA \
  actions=* \
  Kong-Admin-Token:super-admin

http $KONG_ADMIN_API_URI/WorkspaceB/rbac/roles name=admin Kong-Admin-Token:super-admin
http $KONG_ADMIN_API_URI/WorkspaceB/rbac/roles/admin/endpoints/ \
  	endpoint=* \
  	workspace=WorkspaceB \
  	actions=* \
  	Kong-Admin-Token:super-admin

http post $KONG_ADMIN_API_URI/WorkspaceA/rbac/users/AdminA/roles/ \
    roles=admin \
    Kong-Admin-Token:super-admin

http post $KONG_ADMIN_API_URI/WorkspaceB/rbac/users/AdminB/roles/ \
    roles=admin \
    Kong-Admin-Token:super-admin

http get $KONG_ADMIN_API_URI/WorkspaceA/rbac/users Kong-Admin-Token:AdminA_token
http get $KONG_ADMIN_API_URI/WorkspaceA/rbac/users Kong-Admin-Token:AdminB_token
http get $KONG_ADMIN_API_URI/WorkspaceB/rbac/users Kong-Admin-Token:AdminB_token
http get $KONG_ADMIN_API_URI/WorkspaceB/rbac/users Kong-Admin-Token:AdminA_token

http post $KONG_ADMIN_API_URI/WorkspaceA/services name=mocking name=mocking_service url='http://mockbin.org' Kong-Admin-Token:AdminB_token
http post $KONG_ADMIN_API_URI/WorkspaceA/services name=mocking name=mocking_service url='http://mockbin.org' Kong-Admin-Token:AdminA_token
http post $KONG_ADMIN_API_URI/WorkspaceA/services/mocking_service/routes name=mocking hosts:='["myhost.me"]' paths:='["/mocker"]' Kong-Admin-Token:AdminA_token


http post $KONG_ADMIN_API_URI/WorkspaceA/rbac/users name=TeamA_engineer user_token=teama_engineer_user_token Kong-Admin-Token:AdminB_token
http post $KONG_ADMIN_API_URI/WorkspaceA/rbac/users name=TeamA_engineer user_token=teama_engineer_user_token Kong-Admin-Token:AdminA_token

http $KONG_ADMIN_API_URI/WorkspaceA/rbac/roles name=engineer-role Kong-Admin-Token:super-admin
http $KONG_ADMIN_API_URI/WorkspaceA/rbac/roles/engineer-role/endpoints/ \
  	endpoint=* \
  	workspace=WorkspaceA \
  	actions="read" \
  	Kong-Admin-Token:AdminA_token
http $KONG_ADMIN_API_URI/WorkspaceB/rbac/roles name=engineer-role Kong-Admin-Token:super-admin
http $KONG_ADMIN_API_URI/WorkspaceB/rbac/roles/engineer-role/endpoints/ \
  	endpoint=* \
  	workspace=WorkspaceB \
  	actions="read" \
  	Kong-Admin-Token:AdminB_token

http post $KONG_ADMIN_API_URI/WorkspaceA/rbac/users/TeamA_engineer/roles \
    roles=engineer-role \
    Kong-Admin-Token:AdminA_token
http post $KONG_ADMIN_API_URI/WorkspaceB/rbac/users/TeamB_engineer/roles \
    roles=engineer-role \
    Kong-Admin-Token:AdminB_token

http get $KONG_ADMIN_API_URI/WorkspaceA/consumers Kong-Admin-Token:teama_engineer_user_token
http POST $KONG_ADMIN_API_URI/WorkspaceA/consumers username=Jane Kong-Admin-Token:teama_engineer_user_token
http get $KONG_ADMIN_API_URI/WorkspaceB/consumers Kong-Admin-Token:teama_engineer_user_token

# 05 - Securing Services on Kong

http --form POST $KONG_ADMIN_API_URI/.../plugins name=rate-limiting config.second=nn config.min=nn config.hour=nn … config.year=nn config.policy=cluster config.limit_by=consumer
http --form POST $KONG_ADMIN_API_URI/services/mocking_service/plugins name=rate-limiting config.hour=8192 config.policy=local
http POST $KONG_ADMIN_API_URI/services name=mocking_service url='http://mockbin.org' Kong-Admin-Token:super-admin
http POST $KONG_ADMIN_API_URI/services/mocking_service/routes name=mocking paths:='["/mock"]' Kong-Admin-Token:super-admin
http --form POST $KONG_ADMIN_API_URI/plugins name=rate-limiting config.minute=5 config.policy=local Kong-Admin-Token:super-admin
http POST $KONG_ADMIN_API_URI/plugins name=key-auth Kong-Admin-Token:super-admin
http POST $KONG_ADMIN_API_URI/consumers username=Jane Kong-Admin-Token:super-admin
http POST $KONG_ADMIN_API_URI/consumers/Jane/key-auth key=JanePassword Kong-Admin-Token:super-admin
for ((i=1;i<=20;i++)); do sleep 1; http --headers GET $KONG_PROXY_URI/mock/request?apikey=JanePassword; done
http --form POST $KONG_ADMIN_API_URI/.../plugins name=jwt \
http POST $KONG_ADMIN_API_URI/services/mocking_service/plugins name=jwt
http POST $KONG_ADMIN_API_URI/services/mocking_service/routes name=mocking paths:='["/mock"]' Kong-Admin-Token:super-admin
http $KONG_ADMIN_API_URI/services name=mocking_service url='http://mockbin.org' Kong-Admin-Token:super-admin
http POST $KONG_ADMIN_API_URI/consumers username=Jane Kong-Admin-Token:super-admin
http POST $KONG_ADMIN_API_URI/consumers/Jane/jwt Kong-Admin-Token:super-admin
http GET $KONG_ADMIN_API_URI/consumers/Jane/jwt Kong-Admin-Token:super-admin
http POST $KONG_ADMIN_API_URI/services/mocking_service/plugins name=jwt Kong-Admin-Token:super-admin
http -h GET $KONG_PROXY_URI/mock/request Authorization:'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJSaDNtR09iUFVYRUwzdDZIVjhkRm1qbHlNd2JHU1ZFRiJ9.1b5bl5VV2mG8WoCiMB7N3teYMboQFUHs-F_eBDxaorQ' | head -n 1
curl -L https://gist.githubusercontent.com/johnfitzpatrick/b918848c5dc7d76f95c1ed5730e70b32/raw/4389eb1abfd04857f3adc37b80b66dca6c402103/create_certificate.sh | bash
http -f $KONG_ADMIN_API_URI/ca_certificates cert@/home/labuser/.certificates/ca.cert.pem tags=ownCA Kong-Admin-Token:super-admin
CERT_ID=$(http -f $KONG_ADMIN_API_URI/ca_certificates Kong-Admin-Token:super-admin | jq -r '.data[].id')
http POST $KONG_ADMIN_API_URI/services name=public-service url=http://httpbin.org/anything Kong-Admin-Token:super-admin
http -f POST $KONG_ADMIN_API_URI/services/public-service/routes name=public-route paths=/public Kong-Admin-Token:super-admin
http POST $KONG_ADMIN_API_URI/services name=confidential-service url=https://httpbin.org/uuid Kong-Admin-Token:super-admin
http -f POST $KONG_ADMIN_API_URI/services/confidential-service/routes name=confidential-route paths=/confidential Kong-Admin-Token:super-admin
http get $KONG_PROXY_URI/public
http get $KONG_PROXY_URI/confidential
http POST $KONG_ADMIN_API_URI/consumers username=demo@example.com Kong-Admin-Token:super-admin
http POST $KONG_ADMIN_API_URI/services/confidential-service/plugins name=mtls-auth config:="{\"ca_certificates\": [\"$CERT_ID\"],\"revocation_check_mode\": \"SKIP\"}" Kong-Admin-Token:super-admin
http --verify=no  https://localhost:8443/confidential
http --verify=no --cert=/home/labuser/.certificates/ca.cert.pem --cert-key=/home/labuser/.certificates/client.key https://localhost:8443/confidential
http get $KONG_PROXY_URI/public


# SCRATCH AREA ONLY
