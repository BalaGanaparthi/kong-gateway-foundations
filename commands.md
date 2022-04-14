# 01 - Kong Gateway Installation

## Task: Obtain Kong docker compose file and certificates
./setup-docker.sh
git clone https://github.com/gigaprimatus/kong-gateway-operations.git
cd kong-gateway-operations/installation
tree

## Task: Move SSL certificates 
cp -R ssl-certs /srv/shared

## Task: Instantiate log files and deploy Kong
mkdir -p /srv/shared/logs
touch $(grep '/srv/shared/logs/' docker-compose.yaml|awk '{print $2}'|xargs)
chmod a+w /srv/shared/logs/*
docker-compose up -d

## Training Lab Environment
env | grep KONG_ | grep -v SERVICE | sort

## Task: Verify Admin API
http --headers GET kongcluster:8001
### curl -IX GET kongcluster:8001

## Task: Verify Kong Manager 
echo $KONG_MANAGER_URI

## Task: Task: Apply and review the licence
http –headers POST kongcluster:8001/licenses \ 
  payload=@/etc/kong/license.json \ 
  | grep HTTP

### curl -isX POST kongcluster:8001/licenses \
      -F payload=@/etc/kong/license.json \
      | grep HTTP

http GET kongcluster:8001/license/report
### curl -sX GET kongcluster:8001/license/report | jq

## Task: Recreate/Restart the CP to enable EE features

docker-compose stop kong-cp
docker-compose rm -f kong-cp
docker-compose up -d kong-cp

## Task: Enable the Developer Portal:

http --form PATCH kongcluster:8001/workspaces/default \
  config.portal=true

### curl -sX PATCH kongcluster:8001/workspaces/default \
      -d "config.portal=true" \
      | jq

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
                  }' \
      | jq            

## Task: Task: Approve the Developer
http PATCH "$KONG_ADMIN_API_URI/default/developers/myemail@example.com" <<< '{"status": 0}'

### curl -sX PATCH "$KONG_ADMIN_API_URI/default/developers/myemail@example.com" \
      -H 'Content-Type: application/json' \
      -d '{"status": 0}' \
      | jq

## Task: Add an API Spec to test
http --form POST kongcluster:8001/files \
  "path=specs/jokes.one.oas.yaml" \
  "contents=@jokes1OAS.yaml"

### curl -sX POST kongcluster:8001/files \
      -F "path=specs/jokes.one.oas.yaml" \
      -F "contents=@jokes1OAS.yaml" \
      | jq

## Using decK

## Task: Configure decK and Create a sample Service/Route
cd ~/kong-gateway-operations/installation
sed -i "s|KONG_ADMIN_API_URI|$KONG_ADMIN_API_URI|g" deck/deck.yaml
cp deck/deck.yaml ~/.deck.yaml

http POST kongcluster:8001/services \
  name=mockbin \
  url=http://mockbin:8080/request

### curl -sX POST kongcluster:8001/services \
       -d "name=mockbin" \
       -d "url=https://mockbin/request" \
       | jq

http POST kongcluster:8001/services/mockbin/routes \
  name=mockbin \
  paths:='["/mockbin"]'

### curl -sX POST kongcluster:8001/services/mockbin/routes \
      -d "name=mockbin" \
      -d "paths=/mockbin" \
      | jq


## Task: Save/Load Kong configuration using decK

deck dump \
  --output-file gwopslabdump.yaml \
  --workspace default

deck diff --state gwopslabdump.yaml
deck reset
deck diff --state gwopslabdump.yaml

## Task: Sync updates and view config in Kong Manager
deck diff \
  --state deck/sampledump.yaml \
  --workspace default

deck sync \
  --state deck/sampledump.yaml \
  --workspace default

## Task: Restore Kong configuration using decK
deck sync \
  --state deck/gwopslabdump.yaml \
  --workspace default

Created service mockbin is consumable here:
http GET kongcluster:8000/mockbin
### curl -iX GET kongcluster:8000/mockbin
http --verify no GET https://kongcluster:8443/mockbin
### curl -k -iX GET https://kongcluster:8443/mockbin

## Kong Upgrade Lab
cd ~/kong-gateway-operations/installation
docker-compose down

## Task: Create a dedicated docker network and a database container
docker network create kong-edu-net
docker run -d --name kong-ee-database --network kong-edu-net \
  -p 5432:5432 \
  -e "POSTGRES_USER=kong" \
  -e "POSTGRES_DB=kong-edu" \
  -e "POSTGRES_PASSWORD=kong" \
  postgres:13.1

## Task: Bootstrap the Database for Kong 2.5.1.2
export KONG_LICENSE_DATA=`cat "/etc/kong/license.json"` 
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
  name=mockbin \
  url=http://mockbin:8080/request

### curl -sX POST kongcluster:8001/services \
       -d "name=mockbin" \
       -d "url=https://mockbin/request" \
       | jq

http -f POST kongcluster:8001/services/mockbin/routes \
  name=mockbin \
  paths=/mockbin

### curl -sX POST kongcluster:8001/services/mockbin/routes \
      -d "name=mockbin" \
      -d "paths=/mockbin" \
      | jq

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

## Task: Start the new 2.6 container:
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
http --headers GET kongcluster:8000/mockbin
### curl -IX GET kongcluster:8000/mockbin

## Task: Clean up Lab

docker rm -f $(docker ps -a -q) > /dev/null 2>&1
docker volume rm $(docker volume ls -q) > /dev/null 2>&1
docker network rm -f kong-edu-net > /dev/null 2>&1

## Task: Upgrade Using Docker Compose
export KONG_LICENSE_DATA=`cat "/etc/kong/license.json"`
export KONG_VERSION="2.5.1.2-alpine"
docker-compose -f kongupgdemo.yaml up -d

http GET kongcluster:8001 \
 | jq '.hostname + " " + .version'

### curl -sX GET kongcluster:8001 \
      | jq '.hostname + " " + .version'

http POST kongcluster:8001/services \
  name=mockbin \
  url=http://mockbin:8080/request

### curl -sX POST kongcluster:8001/services \
       -d "name=mockbin" \
       -d "url=https://mockbin/request" \
       | jq

http POST kongcluster:8001/services/mockbin/routes \
  name=mockbin \
  paths:='["/mockbin"]'

### curl -sX POST kongcluster:8001/services/mockbin/routes \
      -d "name=mockbin" \
      -d "paths=/mockbin" \
      | jq



export KONG_VERSION="2.6.0.1-alpine"
docker-compose -f kongupgdemo.yaml up -d

http --headers GET kongcluster:8000/mockbin
### curl -IX GET kongcluster:8000/mockbin

docker-compose -f kongupgdemo.yaml down -v


# 02 - Securing Kong Gatway

## Lab: Securing Kong Gateway
cd
git clone https://github.com/gigaprimatus/kong-gateway-operations.git
source kong-gatway-operations/installation/scram.sh

## Task: Create New Role my_role and add Permissions
http POST kongcluster:8001/rbac/roles name=my_role
### curl -sX POST kongcluster:8001/rbac/roles -d name=my_role | jq

http POST kongcluster:8001/rbac/roles/my_role/endpoints/ \
  	endpoint=* \
  	workspace=default \
  	actions=*

### curl -sX POST kongcluster:8001/rbac/roles/my_role/endpoints/ \
  	  -d endpoint=* \
  	  -d workspace=default \
  	  -d actions=* \
      | jq  

## Task: Create an RBAC user called 'my-super-admin'
http post kongcluster:8001/rbac/users name=my-super-admin user_token="my_token"
### curl -sX POST kongcluster:8001/rbac/users \
      -d name=my-super-admin \
      -d user_token="my_token" \
      | jq

## Task: Assign role created earlier and Verify user 
http POST kongcluster:8001/rbac/users/my-super-admin/roles roles='my_role'
### curl -sX POST kongcluster:8001/rbac/users/my-super-admin/roles -d roles='my_role' | jq

http GET kongcluster:8001/rbac/users/my-super-admin/roles
### curl -sX GET kongcluster:8001/rbac/users/my-super-admin/roles | jq

## Task: Assign super-admin Role to my-super-admin
http POST kongcluster:8001/rbac/users/my-super-admin/roles roles='super-admin'
### curl -sX POST kongcluster:8001/rbac/users/my-super-admin/roles -d roles='super-admin' | jq

## Task: Verify my-super-admin Role
http GET kongcluster:8001/rbac/users/my-super-admin/roles
### curl -sX GET kongcluster:8001/rbac/users/my-super-admin/roles | jq

## Task: Automatically Assign Roles to RBAC user
http POST kongcluster:8001/rbac/users \
  name=super-admin \
  user_token="super-admin"

### curl -sX POST kongcluster:8001/rbac/users \
      -d name=super-admin \
      -d user_token="super-admin" \
      | jq

http GET kongcluster:8001/rbac/users/super-admin/roles
### curl -sX GET kongcluster:8001/rbac/users/super-admin/roles | jq

## Task: Enable RBAC, reducing default cookie_lifetime
cd ~/kong-gateway-operations/installation
sed -i 's|#KONG_ENFORCE_RBAC|KONG_ENFORCE_RBAC|g' docker-compose.yaml
sed -i 's|#KONG_ADMIN_GUI_AUTH|KONG_ADMIN_GUI_AUTH|g' docker-compose.yaml
sed -i 's|#KONG_ADMIN_GUI_SESSION_CONF|KONG_ADMIN_GUI_SESSION_CONF|g' docker-compose.yaml
sed -i 's|:36000|:60|g' docker-compose.yaml
docker-compose stop kong-cp; docker-compose rm -f kong-cp; docker-compose up -d kong-cp

## Task: Revert cookie_lifetime to default value
sed -i 's|:60|:36000|g' docker-compose.yaml
docker-compose stop kong-cp; docker-compose rm -f kong-cp; docker-compose up -d kong-cp


## Task: Verify Authentication with Admin API
http --headers GET kongcluster:8001/services
### curl -sX GET kongcluster:8001/services
http --headers GET kongcluster:8001/services Kong-Admin-Token:my_token
### curl -sX GET kongcluster:8001/services -H Kong-Admin-Token:my_token | jq

## Task: Create WorkspaceA & WorkspaceB

http POST kongcluster:8001/workspaces name=WorkspaceA Kong-Admin-Token:my_token
### curl -sX POST kongcluster:8001/workspaces \
      -d name=WorkspaceA \
      -H Kong-Admin-Token:my_token \
      | jq

http POST kongcluster:8001/workspaces name=WorkspaceB Kong-Admin-Token:my_token
### curl -sX POST kongcluster:8001/workspaces \
      -d name=WorkspaceB \
      -H Kong-Admin-Token:my_token \
      | jq

http GET kongcluster:8001/workspaces Kong-Admin-Token:my_token | jq '.data[].name'
### curl -sX GET kongcluster:8001/workspaces \
      -H Kong-Admin-Token:my_token \
      | jq '.data[].name'

## Task: Create AdminA & AdminB

http POST kongcluster:8001/WorkspaceA/rbac/users \
  name=AdminA \
  user_token=AdminA_token \
  Kong-Admin-Token:super-admin

### curl -sX POST kongcluster:8001/WorkspaceA/rbac/users \
      -d name=AdminA \
      -d user_token=AdminA_token \
      -H Kong-Admin-Token:super-admin \
      | jq

http POST kongcluster:8001/WorkspaceB/rbac/users \
  name=AdminB \
  user_token=AdminB_token \
  Kong-Admin-Token:super-admin

### curl -sX POST kongcluster:8001/WorkspaceB/rbac/users \
      -d name=AdminB \
      -d user_token=AdminB_token \
      -H Kong-Admin-Token:super-admin \
      | jq

## Task: Verify AdminA & AdminB

http GET kongcluster:8001/WorkspaceA/rbac/users Kong-Admin-Token:super-admin
### curl -sX GET kongcluster:8001/WorkspaceA/rbac/users \
      -H Kong-Admin-Token:super-admin \
      | jq

http GET kongcluster:8001/WorkspaceB/rbac/users Kong-Admin-Token:super-admin
### curl -sX GET kongcluster:8001/WorkspaceB/rbac/users \
      -H Kong-Admin-Token:super-admin \
      | jq

## Task: Create an admin role & permissions for WorkspaceA

http POST kongcluster:8001/WorkspaceA/rbac/roles \
  name=admin \
  Kong-Admin-Token:super-admin

### curl -sX POST kongcluster:8001/WorkspaceA/rbac/roles \
      -d name=admin \
      -H Kong-Admin-Token:super-admin \
      | jq

http POST kongcluster:8001/WorkspaceA/rbac/roles/admin/endpoints/ \
  endpoint=* \
  workspace=WorkspaceA \
  actions=* \
  Kong-Admin-Token:super-admin

### curl -sX POST kongcluster:8001/WorkspaceA/rbac/roles/admin/endpoints/ \
      -d endpoint=* \
      -d workspace=WorkspaceA \
      -d actions=* \
      -H Kong-Admin-Token:super-admin \
      | jq

## Task: Create an admin role & permissions for WorkspaceB

http POST kongcluster:8001/WorkspaceB/rbac/roles \
  name=admin \
  Kong-Admin-Token:super-admin

### curl -sX POST kongcluster:8001/WorkspaceB/rbac/roles \
      -d name=admin \
      -H Kong-Admin-Token:super-admin \
      | jq

http POST kongcluster:8001/WorkspaceB/rbac/roles/admin/endpoints/ \
  endpoint=* \
  workspace=WorkspaceB \
  actions=* \
  Kong-Admin-Token:super-admin

### curl -sX POST kongcluster:8001/WorkspaceB/rbac/roles/admin/endpoints/ \
  	  -d endpoint=* \
  	  -d workspace=WorkspaceB \
  	  -d actions=* \
  	  -H Kong-Admin-Token:super-admin \
      | jq

## Task: Assign admin role to admin user in each workspace

http POST kongcluster:8001/WorkspaceA/rbac/users/AdminA/roles/ \
  roles=admin \
  Kong-Admin-Token:super-admin

### curl -sX POST kongcluster:8001/WorkspaceA/rbac/users/AdminA/roles/ \
      -d roles=admin \
      -H Kong-Admin-Token:super-admin \
      | jq

http POST kongcluster:8001/WorkspaceB/rbac/users/AdminB/roles/ \
  roles=admin \
  Kong-Admin-Token:super-admin

### curl -sX POST kongcluster:8001/WorkspaceB/rbac/users/AdminB/roles/ \
      -d roles=admin \
      -H Kong-Admin-Token:super-admin \
      | jq

## Verify AdminA/AdminB access to corresponding Workspaces
http GET kongcluster:8001/WorkspaceA/rbac/users Kong-Admin-Token:AdminA_token
### curl -sX GET kongcluster:8001/WorkspaceA/rbac/users \
      -H Kong-Admin-Token:AdminA_token \
      | jq

http GET kongcluster:8001/WorkspaceA/rbac/users Kong-Admin-Token:AdminB_token
### curl -sX GET kongcluster:8001/WorkspaceA/rbac/users \
      -H Kong-Admin-Token:AdminB_token \
      | jq

http GET kongcluster:8001/WorkspaceB/rbac/users Kong-Admin-Token:AdminB_token
### curl -sX GET kongcluster:8001/WorkspaceB/rbac/users \
      -H Kong-Admin-Token:AdminB_token \
      | jq

http GET kongcluster:8001/WorkspaceB/rbac/users Kong-Admin-Token:AdminA_token
### curl -sX GET kongcluster:8001/WorkspaceB/rbac/users \
      -H Kong-Admin-Token:AdminA_token \
      | jq

## Task: Deploy a service to WorkspaceA with correct Admin
http POST kongcluster:8001/WorkspaceA/services \
  name=mockbin_service \
  url='http://mockbin:8080' \
  Kong-Admin-Token:AdminA_token

### curl -sX POST kongcluster:8001/WorkspaceA/services \
  -d name=mockbin_service \
  -d url='http://mockbin:8080' \
  -H Kong-Admin-Token:AdminA_token \
  | jq

http POST kongcluster:8001/WorkspaceA/services/mockbin_service/routes \
  name=mocking \
  hosts:='["myhost.me"]' \
  paths:='["/mocker"]' \
  Kong-Admin-Token:AdminA_token

### curl -sX POST kongcluster:8001/WorkspaceA/services/mockbin_service/routes \
      -d name=mocking \
      -d hosts="myhost.me" \
      -d paths="/mocker" \
      -H Kong-Admin-Token:AdminA_token \
      | jq


http POST kongcluster:8001/WorkspaceA/services/mockbin_service/routes \
  name=mocking \
  hosts:='["myhost.me"]' \
  paths:='["/mocker"]' \
  Kong-Admin-Token:AdminA_token

### curl -sX POST kongcluster:8001/WorkspaceA/services/mockbin_service/routes \
      -d name=mocking \
      -d hosts="myhost.me" \
      -d paths="/mocker" \
      -H Kong-Admin-Token:AdminA_token \
      | jq

## Task: Verify service in WorkspaceA
http --header GET kongcluster:8000/mocker host:myhost.me | grep HTTP
### curl -sIX GET kongcluster:8000/mocker -H host:myhost.me | grep HTTP

## Task: Add TeamA_engineer & TeamB_engineer to the workspace teams 
http POST kongcluster:8001/WorkspaceA/rbac/users \
  name=TeamA_engineer \
  user_token=teama_engineer_user_token \
  Kong-Admin-Token:AdminB_token

### curl -sX POST kongcluster:8001/WorkspaceA/rbac/users \
     -d name=TeamA_engineer \
     -d user_token=teama_engineer_user_token \
     -H Kong-Admin-Token:AdminB_token \
    | jq

http POST kongcluster:8001/WorkspaceA/rbac/users \
  name=TeamA_engineer \
  user_token=teama_engineer_user_token \
  Kong-Admin-Token:AdminA_token

### curl -sX POST kongcluster:8001/WorkspaceA/rbac/users \
     -d name=TeamA_engineer \
     -d user_token=teama_engineer_user_token \
     -H Kong-Admin-Token:AdminA_token \
     | jq

http POST kongcluster:8001/WorkspaceB/rbac/users \
  name=TeamB_engineer \
  user_token=teamb_engineer_user_token \
  Kong-Admin-Token:AdminB_token

### curl -sX POST kongcluster:8001/WorkspaceB/rbac/users \
     -d name=TeamB_engineer \
     -d user_token=teamb_engineer_user_token \
     -H Kong-Admin-Token:AdminB_token \
     | jq

## Task: Create read-only roles and permissions for 'Team_engineer'
http POST kongcluster:8001/WorkspaceA/rbac/roles \
  name=engineer-role \
  Kong-Admin-Token:super-admin

### curl -sX POST kongcluster:8001/WorkspaceA/rbac/roles \
      -d name=engineer-role \
      -H Kong-Admin-Token:super-admin \
      | jq

http POST kongcluster:8001/WorkspaceA/rbac/roles/engineer-role/endpoints/ \
  	endpoint=* \
  	workspace=WorkspaceA \
  	actions="read" \
  	Kong-Admin-Token:AdminA_token

### curl -sX POST kongcluster:8001/WorkspaceA/rbac/roles/engineer-role/endpoints/ \
  	  -d endpoint=* \
  	  -d workspace=WorkspaceA \
  	  -d actions="read" \
  	  -H Kong-Admin-Token:AdminA_token \
      | jq

http POST kongcluster:8001/WorkspaceB/rbac/roles \
  name=engineer-role \
  Kong-Admin-Token:super-admin

### curl -sX POST kongcluster:8001/WorkspaceB/rbac/roles \
      -d name=engineer-role \
      -H Kong-Admin-Token:super-admin \
      | jq

http POST kongcluster:8001/WorkspaceB/rbac/roles/engineer-role/endpoints/ \
  endpoint=* \
  workspace=WorkspaceB \
  actions="read" \
  Kong-Admin-Token:AdminB_token

### curl -sX POST kongcluster:8001/WorkspaceB/rbac/roles/engineer-role/endpoints/ \
  	  -d endpoint=* \
  	  -d workspace=WorkspaceB \
  	  -d actions="read" \
  	  -H Kong-Admin-Token:AdminB_token \
      | jq


## Task: Assign roles and permissions for 'Team_engineer'
http POST kongcluster:8001/WorkspaceA/rbac/users/TeamA_engineer/roles \
  roles=engineer-role \
  Kong-Admin-Token:AdminA_token

### curl -sX POST kongcluster:8001/WorkspaceA/rbac/users/TeamA_engineer/roles \
      -d roles=engineer-role \
      -H Kong-Admin-Token:AdminA_token \
      | jq

http POST kongcluster:8001/WorkspaceB/rbac/users/TeamB_engineer/roles \
  roles=engineer-role \
  Kong-Admin-Token:AdminB_token

### curl -sX POST kongcluster:8001/WorkspaceB/rbac/users/TeamB_engineer/roles \
      -d roles=engineer-role \
      -H Kong-Admin-Token:AdminB_token \
      | jq

## Verifying Teams Access

http GET kongcluster:8001/WorkspaceA/consumers \
  Kong-Admin-Token:teama_engineer_user_token

### curl -sX GET kongcluster:8001/WorkspaceA/consumers \
      -H Kong-Admin-Token:teama_engineer_user_token \
      | jq 

http POST kongcluster:8001/WorkspaceA/consumers \
  username=Jane \
  Kong-Admin-Token:teama_engineer_user_token

### curl -sX POST kongcluster:8001/WorkspaceA/consumers \
      -d username=Jane \
      -H Kong-Admin-Token:teama_engineer_user_token \
      | jq

http GET kongcluster:8001/WorkspaceB/consumers \
  Kong-Admin-Token:teama_engineer_user_token

### curl -sX GET kongcluster:8001/WorkspaceB/consumers \
      -H Kong-Admin-Token:teama_engineer_user_token \
      | jq

http GET kongcluster:8001/WorkspaceB/consumers \
  Kong-Admin-Token:teamb_engineer_user_token

### curl -sX GET kongcluster:8001/WorkspaceB/consumers \
      -H Kong-Admin-Token:teamb_engineer_user_token \
      | jq 

http POST kongcluster:8001/WorkspaceA/consumers \
  username=Jane \
  Kong-Admin-Token:teama_engineer_user_token

### curl -sX POST kongcluster:8001/WorkspaceB/consumers \
      -d username=Jane \
      -H Kong-Admin-Token:teamb_engineer_user_token \
      | jq

http GET kongcluster:8001/WorkspaceB/consumers \
  Kong-Admin-Token:teama_engineer_user_token

### curl -sX GET kongcluster:8001/WorkspaceA/consumers \
      -H Kong-Admin-Token:teamb_engineer_user_token \
      | jq

## Task: Disable RBAC
sed -i 's|KONG_ENFORCE_RBAC|#KONG_ENFORCE_RBAC|g' docker-compose.yaml
sed -i 's|KONG_ADMIN_GUI_AUTH|#KONG_ADMIN_GUI_AUTH|g' docker-compose.yaml
sed -i 's|KONG_ADMIN_GUI_SESSION_CONF|#KONG_ADMIN_GUI_SESSION_CONF|g' docker-compose.yaml
docker-compose stop kong-cp; docker-compose rm -f kong-cp; docker-compose up -d kong-cp

## Securing the Admin API

## Network Layer Access Restrictions
cat docker-compose.yaml | grep -i admin_listen

## Task: Bring up Kong listening on localhost
cd ~/kong-gateway-operations/installation
docker-compose down -v
docker-compose -f kongsecadmin.yaml up -d
cat kongsecadmin.yaml

## Task: Review Created Service/Route for Admin API
cat loopback.yaml

## Task: Test  Service/Route for Admin API
http GET kongcluster:8001/services
### curl -sX GET kongcluster:8001/services
http GET kongcluster:8000/admin-api/services apikey:secret
### curl -sX GET kongcluster:8000/admin-api/services \
      -H apikey:secret \
      | jq


# 03 - Securing Services on Kong

## Lab: Securing Services on Kong
cd
source scram.sh

cd
git clone https://github.com/kong-education/kong-gateway-operations.git
source ~/kong-gateway-operations/installation/scram.sh

## Task: Create a service with a route

http POST kongcluster:8001/services \
  name=mockbin_service \
  url='http://mockbin:8080'

### curl -sX POST kongcluster:8001/services \
      -d name=mockbin_service \
      -d url='http://mockbin:8080' \
      | jq 

http -f POST kongcluster:8001/services/mockbin_service/routes \
  name=mocking \
  paths='/mock'

curl -sX POST kongcluster:8001/services/mockbin_service/routes \
  -d name=mocking \
  -d paths='/mock' \
  | jq

## Task: Configure Rate Limiting and key-auth Plugins

http -f POST kongcluster:8001/services/mockbin_service/plugins \
  name=rate-limiting \
  config.minute=5 \
  config.policy=local

### curl -sX POST kongcluster:8001/services/mockbin_service/plugins \
      -d name=rate-limiting \
      -d config.minute=5 \
      -d config.policy=local \
      | jq

http POST kongcluster:8001/services/mockbin_service/plugins name=key-auth
### curl -sX POST kongcluster:8001/services/mockbin_service/plugins \
      -d name=key-auth \
      | jq

## Task: Create consumer and assign credentials
http POST kongcluster:8001/consumers username=Jane
### curl -sX POST kongcluster:8001/consumers -d username=Jane | jq
http POST kongcluster:8001/consumers/Jane/key-auth key=JanePassword
### curl -sX POST kongcluster:8001/consumers/Jane/key-auth \
      -d key=JanePassword \
      | jq

## Task: Create Some Traffic for User

(for ((i=1;i<=20;i++))
    do
    sleep 1
    http GET kongcluster:8000/mock/request?apikey=JanePassword
  done)

### (for ((i=1;i<=20;i++))
      do
        sleep 1
        curl -isX GET kongcluster:8000/mock/request?apikey=JanePassword
      done)

## Task: Create mocking service and route
http DELETE kongcluster:8001/services/mockbin_service/routes/mocking
### curl -X DELETE kongcluster:8001/services/mockbin_service/routes/mocking
http DELETE kongcluster:8001/services/mockbin_service
### curl -X DELETE kongcluster:8001/services/mockbin_service

http POST kongcluster:8001/services \
  name=mockbin_service \
  url='http://mockbin:8080'

### curl -sX POST kongcluster:8001/services \
    -d name=mockbin_service \
    -d url='http://mockbin:8080' \
    | jq

http -f POST kongcluster:8001/services/mockbin_service/routes \
    name=mocking \
    paths='/mock'

### curl -sX POST kongcluster:8001/services/mockbin_service/routes \
      -d name=mocking \
      -d paths='/mock' \
      | jq

## Task: Enable JWT Plugin for a Service
http POST kongcluster:8001/services/mockbin_service/plugins name=jwt

### curl -sX POST kongcluster:8001/services/mockbin_service/plugins \
      -d name=jwt \
      | jq

## Task: Create a consumer and assign JWT credentials
http DELETE kongcluster:8001/consumers/Jane
### curl -iX DELETE kongcluster:8001/consumers/Jane

http POST kongcluster:8001/consumers username=Jane
### curl -sX POST kongcluster:8001/consumers \
      -d username=Jane \
      | jq

http POST kongcluster:8001/consumers/Jane/jwt
### curl -sX POST kongcluster:8001/consumers/Jane/jwt | jq

## Task: Get JWT key/secret for consumer
KEY=$(http GET kongcluster:8001/consumers/Jane/jwt | jq '.data[0].key')
echo '{"iss":'"$KEY"'}'
SECRET=$(http GET kongcluster:8001/consumers/Jane/jwt | jq '.data[0].secret'|xargs)
echo $SECRET
TOKEN=$(jwt -e -s $SECRET --jwt '{"iss":'"$KEY"'}')
echo $TOKEN

## Task: Consume the service with JWT credentials
http --headers GET kongcluster:8000/mock/request
### curl -IX GET kongcluster:8000/mock/request
http --headers GET kongcluster:8000/mock/request Authorization:"Bearer $TOKEN"
### curl -isX GET kongcluster:8000/mock/request -H Authorization:"Bearer $TOKEN"

## Task: Create a self-signed certificate 
cd ~/kong-gateway-operations/securing-services
./create-certificate.sh

## Kong Validating Client/Server Certificates
openssl crl2pkcs7 -nocrl -certfile ~/.certificates/client.crt \
| openssl pkcs7 -print_certs -noout

## Task: Upload self-signed CA certificate to Kong
CA_CERT_ID=$(http -f kongcluster:8001/ca_certificates \
  cert@/home/labuser/.certificates/ca.cert.pem tags=ownCA \
  | jq -r '.id')

### CA_CERT_ID=$(curl -sX POST kongcluster:8001/ca_certificates \
      -F cert=@/home/labuser/.certificates/ca.cert.pem \
      -F tags=ownCA \
      | jq -r '.id') 

echo $CA_CERT_ID

## Task: Set up public and a private services & routes

http POST kongcluster:8001/services \
  name=public-service \
  url=http://mockbin:8080/request

### curl -sX POST kongcluster:8001/services \
      -d name=public-service \
      -d url=http://mockbin:8080/request \
      | jq

http -f POST kongcluster:8001/services/public-service/routes \
  name=public-route \
  paths=/public

### curl -sX POST kongcluster:8001/services/public-service/routes \
      -d name=public-route \
      -d paths=/public \
      | jq

http POST kongcluster:8001/services \
  name=confidential-service \
  url=http://mockbin:8080/agent

### curl -sX POST kongcluster:8001/services \
      -d name=confidential-service \
      -d url=http://mockbin:8080/agent \
      | jq
    
http -f POST kongcluster:8001/services/confidential-service/routes \
  name=confidential-route \
  paths=/confidential

### curl -sX POST kongcluster:8001/services/confidential-service/routes \
      -d name=confidential-route \
      -d paths=/confidential \
      | jq

## Task: Verify traffic is being proxied
http --verify=no GET https://kongcluster:8443/public
### curl -ikX GET https://kongcluster:8443/public
http --verify=no GET https://kongcluster:8443/confidential
### curl -ikX GET https://kongcluster:8443/confidential

## Task: Create a consumer
http POST kongcluster:8001/consumers username=demo@example.com
### curl POST kongcluster:8001/consumers -d username=demo@example.com | jq

## Task: Implement the mTLS plugin to Kong

http -f POST kongcluster:8001/services/confidential-service/plugins \
  name=mtls-auth \
  config.ca_certificates=$CA_CERT_ID \
  config.revocation_check_mode='SKIP'

### curl -sX POST kongcluster:8001/services/confidential-service/plugins \
      -d name=mtls-auth \
      -d config.ca_certificates=$CA_CERT_ID \
      -d config.revocation_check_mode='SKIP' \
      | jq


## Task: Verify access for private service without a certificate
http --verify=no https://kongcluster:8443/confidential
### curl -ikX GET https://kongcluster:8443/confidential

## Task: Verify access for private service with a certificate 

http --verify=no \
     --cert=/home/labuser/.certificates/client.crt \
     --cert-key=/home/labuser/.certificates/client.key \
     https://kongcluster:8443/confidential

### curl -ikX GET \
      --key /home/labuser/.certificates/client.key \
      --cert /home/labuser/.certificates/client.crt \
      https://kongcluster:8443/confidential


## Task: Verify public route is unaffected
http --verify=no GET https://kongcluster:8443/public
### curl -ikX GET https://kongcluster:8443/public

## Task: Configure and Test Rate Limiting
http -f POST kongcluster:8001/consumers/demo@example.com/plugins \
   name=rate-limiting \
   config.minute=5

### curl -sX POST kongcluster:8001/consumers/demo@example.com/plugins \
      -d name=rate-limiting \
      -d config.minute=5 \
      | jq

(for ((i=1;i<=10;i++))
   do
     http -h --verify=no --cert=/home/labuser/.certificates/client.crt \
        --cert-key=/home/labuser/.certificates/client.key \
        https://kongcluster:8443/confidential \
        | head -1
  done)

### (for ((i=1;i<=10;i++))
     do
       curl -k -isX GET \
         --key /home/labuser/.certificates/client.key \
         --cert /home/labuser/.certificates/client.crt \
         https://kongcluster:8443/confidential \
         | head -1
     done)


# 04 - OIDC Plugin
cd
source scram.sh

cd
git clone https://github.com/gigaprimatus/kong-gateway-operations.git
source ~/kong-gateway-operations/installation/scram.sh

## Task: Deploy Keycloak
cd ~/kong-gateway-operations/installation
sed -i 's|\#\^|\ \ |g' docker-compose.yaml
docker-compose up -d
cd ~/kong-gateway-operations/oidc
cat kong_realm_template.json | jq '.users[].username'

## Task: Add a Service to use with OIDC

http POST kongcluster:8001/services \
    name=my-oidc-service \
    url=http://mockbin:8080/request

### curl -sX POST kongcluster:8001/services \
      -d name=my-oidc-service \
      -d url=http://mockbin:8080/request \
      | jq


http -f POST kongcluster:8001/services/my-oidc-service/routes \
  name=my-oidc-route \
  paths=/oidc

### curl -sX POST kongcluster:8001/services/my-oidc-service/routes \
      -d name=my-oidc-route \
      -d paths=/oidc \
      | jq

## Task: Confirm Service Functionality
http GET kongcluster:8000/oidc
### curl -isX GET kongcluster:8000/oidc

## Task: Add OpenID Connect Plugin

http -f POST kongcluster:8001/routes/my-oidc-route/plugins \
  name=openid-connect \
  config.issuer=$KEYCLOAK_CONFIG_ISSUER \
  config.client_id=kong \
  config.client_secret=$CLIENT_SECRET \
  config.redirect_uri=$KEYCLOAK_REDIRECT_URI/oidc \
  config.response_mode=form_post \
  config.ssl_verify=false

### curl -sX POST kongcluster:8001/routes/my-oidc-route/plugins \
      -d name=openid-connect \
      -d config.issuer=$KEYCLOAK_CONFIG_ISSUER \
      -d config.client_id=kong \
      -d config.client_secret=$CLIENT_SECRET \
      -d config.redirect_uri=$KEYCLOAK_REDIRECT_URI/oidc \
      -d config.response_mode=form_post \
      -d config.ssl_verify=false \
      | jq

## Task: Verify Protected Service
http GET kongcluster:8000/oidc
### curl -iX GET kongcluster:8000/oidc
http GET kongcluster:8000/oidc -a user:password
### curl -iX GET kongcluster:8000/oidc -u user:password

## Task: View Kong Discovery Information from IDP
http GET kongcluster:8001/openid-connect/issuers
### curl -sX GET kongcluster:8001/openid-connect/issuers | jq
http -b GET kongcluster:8001/openid-connect/issuers | jq -r .data[].issuer
### curl -sX GET kongcluster:8001/openid-connect/issuers | jq -r .data[].issuer

## Task: Confirm Keycloak is configured for Password Grant

OIDC_PLUGIN_ID=$(http GET kongcluster:8001/routes/my-oidc-route/plugins/ \
              | jq -r '.data[] | select(.name == "openid-connect") | .id')

### OIDC_PLUGIN_ID=$(curl -sX GET kongcluster:8001/routes/my-oidc-route/plugins/ \
                  | jq -r '.data[] | select(.name == "openid-connect") | .id')

http -b GET kongcluster:8001/plugins/$OIDC_PLUGIN_ID | jq .config.auth_methods
### curl -sX GET kongcluster:8001/plugins/$OIDC_PLUGIN_ID | jq .config.auth_methods
http -b GET kongcluster:8001/plugins/$OIDC_PLUGIN_ID | jq .config.password_param_type
### curl -sX GET kongcluster:8001/plugins/$OIDC_PLUGIN_ID | jq .config.password_param_type

## Task: Provide credentials to Kong and retrieve Access Token
http GET kongcluster:8000/oidc -a employee:test
### curl -iX GET kongcluster:8000/oidc -u employee:test

BEARER_TOKEN=$(http kongcluster:8000/oidc -a employee:test | jq -r '.headers.authorization' | cut -c 7-)
### BEARER_TOKEN=$(curl -sX GET kongcluster:8000/oidc -u employee:test | jq -r '.headers.authorization' | cut -c 7-)
jwt -d $BEARER_TOKEN | jq


## Task: Get an Access Token from Keycloak for User

BEARER_TOKEN=$(http -f POST $KEYCLOAK_URI/auth/realms/kong/protocol/openid-connect/token \
                 grant_type=password \
                 client_id=kong \
                 client_secret=$CLIENT_SECRET \
                 username=employee \
                 password=test \
                 | jq -r .access_token)

### BEARER_TOKEN=$(curl -sX POST $KEYCLOAK_URI/auth/realms/kong/protocol/openid-connect/token \
                    -d grant_type=password \
                    -d client_id=kong \
                    -d client_secret=$CLIENT_SECRET \
                    -d username=employee \
                    -d password=test \
                    | jq -r .access_token)

http GET kongcluster:8000/oidc authorization:"Bearer $BEARER_TOKEN"
### curl -iX GET kongcluster:8000/oidc -H authorization:"Bearer $BEARER_TOKEN"


## Task: Configure a consumer & modify OIDC plugin to require preferred_username
http PUT kongcluster:8001/consumers/employee
### curl -sX PUT kongcluster:8001/consumers/employee | jq

OIDC_PLUGIN_ID=$(http GET kongcluster:8001/routes/my-oidc-route/plugins/ \
              | jq -r '.data[] | select(.name == "openid-connect") | .id')

### OIDC_PLUGIN_ID=$(curl -sX GET kongcluster:8001/routes/my-oidc-route/plugins/ \
                  | jq -r '.data[] | select(.name == "openid-connect") | .id')

http -f PATCH kongcluster:8001/plugins/$OIDC_PLUGIN_ID \
  config.consumer_claim=preferred_username

### curl -sX PATCH kongcluster:8001/plugins/$OIDC_PLUGIN_ID \
      -d config.consumer_claim=preferred_username \
      | jq

## Task: Verify authorization works for a user mapped to a Kong consumer
http GET kongcluster:8000/oidc -a employee:test
### curl -isX GET kongcluster:8000/oidc -u employee:test

## Task: Verify authorization is forbidden for a user not mapped to a consumer
http GET kongcluster:8000/oidc -a partner:test
### curl -isX GET kongcluster:8000/oidc -u partner:test

## Task: Add & Verify Rate Limiting

http -f POST kongcluster:8001/consumers/employee/plugins \
  name=rate-limiting \
  config.minute=3 \
  config.policy=local

### curl -sX POST kongcluster:8001/consumers/employee/plugins \
      -d name=rate-limiting \
      -d config.minute=3 \
      -d config.policy=local \
      | jq

for ((i=1;i<=5;i++)); do http GET kongcluster:8000/oidc -a employee:test; done
### for ((i=1;i<=5;i++)); do curl -X GET kongcluster:8000/oidc -u employee:test; done

## Task: Cleanup
http -f PATCH kongcluster:8001/plugins/$OIDC_PLUGIN_ID \
  config.consumer_claim= \
  | jq . | grep consumer_claim

### curl -sX PATCH kongcluster:8001/plugins/$OIDC_PLUGIN_ID \
      -d config.consumer_claim= \
      | jq . | grep consumer_claim

RATE_PLUGIN_ID=$(http GET kongcluster:8001/consumers/employee/plugins/ \
                   | jq -r '.data[] | select(.name == "rate-limiting") | .id') 

### RATE_PLUGIN_ID=$(curl -sX GET kongcluster:8001/consumers/employee/plugins/ \
                       | jq -r '.data[] | select(.name == "rate-limiting") | .id') 

http DELETE kongcluster:8001/plugins/$RATE_PLUGIN_ID
### curl -iX DELETE kongcluster:8001/plugins/$RATE_PLUGIN_ID

## Task: Modify the OIDC plugin to search for user roles in a claim

OIDC_PLUGIN_ID=$(http GET kongcluster:8001/routes/my-oidc-route/plugins/ \
  | jq -r '.data[] | select(.name == "openid-connect") | .id')

### OIDC_PLUGIN_ID=$(curl -sX GET kongcluster:8001/routes/my-oidc-route/plugins/ \
      | jq -r '.data[] | select(.name == "openid-connect") | .id')

http -f PATCH kongcluster:8001/plugins/$OIDC_PLUGIN_ID \
  config.consumer_claim= \
  config.authenticated_groups_claim=realm_access \
  config.authenticated_groups_claim=roles \
  | jq -r '.config.authenticated_groups_claim'

### curl -sX PATCH kongcluster:8001/plugins/$OIDC_PLUGIN_ID \
      -d config.consumer_claim= \
      -d config.authenticated_groups_claim=realm_access \
      -d config.authenticated_groups_claim=roles \
      | jq -r '.config.authenticated_groups_claim'

## Task: Configure the ACL plugin and whitelist access to users with the admins role

http -f POST kongcluster:8001/routes/my-oidc-route/plugins \
  name=acl \
  config.whitelist=admins

### curl -isX POST kongcluster:8001/routes/my-oidc-route/plugins \
      -d name=acl \
      -d config.whitelist=admins \
      | jq

http GET kongcluster:8000/oidc -a employee:test
### curl -isX GET kongcluster:8000/oidc -u employee:test


## Task: Modify the ACL plugin to require users being members of the role demo-service to access the service

ACL_PLUGIN_ID=$(http GET kongcluster:8001/routes/my-oidc-route/plugins \
                  | jq -r '.data[] | select(.name == "acl") | .id')

### ACL_PLUGIN_ID=$(curl -sX GET kongcluster:8001/routes/my-oidc-route/plugins \
                      | jq -r '.data[] | select(.name == "acl") | .id')

http -f PATCH kongcluster:8001/routes/my-oidc-route/plugins/$ACL_PLUGIN_ID \
  config.whitelist=demo-service

### curl -sX PATCH kongcluster:8001/routes/my-oidc-route/plugins/$ACL_PLUGIN_ID \
      -d config.whitelist=demo-service \
      | jq

http GET kongcluster:8000/oidc -a employee:test
### curl -sX GET kongcluster:8000/oidc -u employee:test


## Task: Cleanup
http DELETE kongcluster:8001/routes/my-oidc-route/plugins/$ACL_PLUGIN_ID
### curl -iX DELETE kongcluster:8001/routes/my-oidc-route/plugins/$ACL_PLUGIN_ID


## Task: Modify & verify the plugin to require a scope of admins

OIDC_PLUGIN_ID=$(http GET kongcluster:8001/routes/my-oidc-route/plugins/ \
                   | jq -r '.data[] | select(.name == "openid-connect") | .id')

### OIDC_PLUGIN_ID=$(curl -sX GET kongcluster:8001/routes/my-oidc-route/plugins/ \
                       | jq -r '.data[] | select(.name == "openid-connect") | .id')

http -f PATCH kongcluster:8001/plugins/$OIDC_PLUGIN_ID \
  config.consumer_claim=preferred_username \
  config.consumer_optional=true

#### curl -sX PATCH kongcluster:8001/plugins/$OIDC_PLUGIN_ID \
       -d config.consumer_claim=preferred_username \
       -d config.consumer_optional=true \
       | jq

## Task: Configure Rate Limiting Plugins

http -f POST kongcluster:8001/routes/my-oidc-route/plugins \
  name=rate-limiting \
  config.minute=5 \
  config.policy=local

### curl -sX POST kongcluster:8001/routes/my-oidc-route/plugins \
      -d name=rate-limiting \
      -d config.minute=5 \
      -d config.policy=local \
      | jq

http -f POST kongcluster:8001/consumers/employee/plugins \
  name=rate-limiting \
  config.minute=1000 \
  config.policy=local

### curl -sX POST kongcluster:8001/consumers/employee/plugins \
      -d name=rate-limiting \
      -d config.minute=1000 \
      -d config.policy=local \
      | jq
  
## Task: Verify Rate Limits

for ((i=1;i<=6;i++)); do http GET kongcluster:8000/oidc -a partner:test; done
### for ((i=1;i<=6;i++)); do curl -iX GET kongcluster:8000/oidc -u partner:test; done
for ((i=1;i<=12;i++)); do http GET kongcluster:8000/oidc -a employee:test; done
### for ((i=1;i<=12;i++)); do curl -iX GET kongcluster:8000/oidc -u employee:test; done



# 05 - Troubleshooting

## Triage, Examine, Diagnose

http GET kongcluster:8001
### curl -sX GET kongcluster:8001 | jq
http GET kongcluster:8001/status
### curl -sX GET kongcluster:8001/status | jq
http GET kongcluster:8001/metrics
### curl -X GET kongcluster:8001/metrics

## Task: Gather :8001/ information

http GET kongcluster:8001 | jq '.' > 8001.json
### curl -sX GET kongcluster:8001 | jq '.' > 8001.json
jq -C '.' 8001.json | less -R

## Task: Gather :8001/status information

http GET kongcluster:8001/status | jq '.' > 8001-status.json
### curl -sX GET kongcluster:8001/status | jq '.' > 8001-status.json
jq -C '.' 8001-status.json | less -R

## Task: Explore Error Logs

cat /srv/shared/logs/proxy_error.log  | grep oidc | grep consumer

## Task: Use Debug Header to see used Service/Route

http POST kongcluster:8001/services name=mockbin url=http://mockbin:8080/request
### curl -sX POST kongcluster:8001/services \
      -d name=mockbin \
      -d url=http://mockbin:8080/request \
      | jq

http -f POST kongcluster:8001/services/mockbin/routes name=mockbin paths=/mockbin
### curl -sX POST kongcluster:8001/services/mockbin/routes \
      -d name=mockbin \
      -d paths=/mockbin \
      | jq

http -h GET kongcluster:8000/mockbin Kong-Debug:1
### curl -IX GET kongcluster:8000/mockbin -H Kong-Debug:1

## Task: Use Granular Tracing to Log Details

http POST kongcluster:8001/services/mockbin/plugins name=key-auth
### curl -sX POST kongcluster:8001/services/mockbin/plugins \
      -d name=key-auth \
      | jq

http POST kongcluster:8001/consumers username=Jane
### curl -sX POST kongcluster:8001/consumers \
      -d username=Jane \
      | jq

http POST kongcluster:8001/consumers/Jane/key-auth key=JanePassword
### curl -sX POST kongcluster:8001/consumers/Jane/key-auth \
      -d key=JanePassword \
      | jq

cd ~/kong-gateway-operations/installation
cat docker-compose.yaml | grep 'KONG_TRACING'

http -h GET kongcluster:8000/mockbin apikey:JanePassword X-Trace:1 | head -1
### curl -isX GET kongcluster:8000/mockbin -H apikey:JanePassword -H X-Trace:1 | head -1
http -h GET kongcluster:8000/mockbin X-Trace:1 | head -1
### curl -isX GET kongcluster:8000/mockbin -H X-Trace:1 | head -1
cat /srv/shared/logs/granular_tracing.log | less

## Task: Network troubleshooting with cURL

curl -svv --fail --trace-time https://api.github.com/repos/kong/kong | jq

curl -o /dev/null --silent --show-error --write-out '\n\nlookup: %{time_namelookup}\nconnect: %{time_connect}\nappconnect: %{time_appconnect}\npretransfer: %{time_pretransfer}\nredirect: %{time_redirect}\nstarttransfer: %{time_starttransfer}\ntotal: %{time_total}\nsize: %{size_download}\n\n' 'https://api.github.com/repos/kong/kong'

## Task: Broken Lab Scenario 1

cd ~/kong-gateway-operations/troubleshooting
deck sync --state broken-lab1.yaml

http --headers GET $KONG_PROXY_URI/mockbin/request?apikey=JanePassword | head -1
## curl -IX GET $KONG_PROXY_URI/mockbin/request?apikey=JanePassword | head -1

## Broken Lab Scenario 1: Solution 

http PATCH kongcluster:8001/services/mockbin protocol=http
### curl -sX PATCH kongcluster:8001/services/mockbin \
      -d protocol=http \
      | jq

## Task: Broken Lab Scenario 2

cd ~/kong-gateway-operations/troubleshooting
deck sync --state broken-lab2.yaml
http GET $KONG_PROXY_URI/mockbin X-with-ID:true

## Broken Lab Scenario 2: Solution 

CORL_PLUGIN_ID=$(http GET kongcluster:8001/routes/correlation/plugins/ \
              | jq -r '.data[] | select(.name == "correlation-id") | .id')

### OIDC_PLUGIN_ID=$(curl -sX GET kongcluster:8001/routes/my-oidc-route/plugins/ \
                  | jq -r '.data[] | select(.name == "openid-connect") | .id')

http -f PATCH kongcluster:8001/plugins/$CORL_PLUGIN_ID \
  config.generator=uuid

### curl -sX PATCH kongcluster:8001/plugins/$OIDC_PLUGIN_ID \
      -d config.consumer_claim=preferred_username \
      | jq

TRNS_PLUGIN_ID=$(http GET kongcluster:8001/routes/nocorrelation/plugins/ \
              | jq -r '.data[] | select(.name == "request-transformer") | .id')

### TRNS_PLUGIN_ID=$(curl -sX GET kongcluster:8001/routes/nocorrelation/plugins/ \
                  | jq -r '.data[] | select(.name == "request-transformer") | .id')

http DELETE kongcluster:8001/plugins/$TRNS_PLUGIN_ID
### curl -sX DELETE kongcluster:8001/plugins/$TRNS_PLUGIN_ID



# 06 - Kong Vitals

## Task: Configure Service/Route/Consumer/Plugins

http POST kongcluster:8001/services \
  name=mockbin \
  url=http://mockbin:8080/request

### curl -sX POST kongcluster:8001/services \
       -d "name=mockbin" \
       -d "url=http://mockbin:8080/request" \
       | jq

http -f POST kongcluster:8001/services/mockbin/routes \
  name=mockbin \
  paths=/mockbin

### curl -sX POST kongcluster:8001/services/mockbin/routes \
      -d "name=mockbin" \
      -d "paths=/mockbin" \
      | jq
      
http -f POST kongcluster:8001/services/mockbin/plugins \
  name=rate-limiting \
  config.minute=5 \
  config.policy=local

### curl -sX POST kongcluster:8001/services/mockbin/plugins \
      -d name=rate-limiting \
      -d config.minute=5 \
      -d config.policy=local \
      | jq

http POST kongcluster:8001/services/mockbin/plugins name=key-auth
### curl -sX POST kongcluster:8001/services/mockbin/plugins \
      -d name=key-auth \
      | jq

http POST kongcluster:8001/consumers username=Jane
### curl -sX POST kongcluster:8001/consumers \
      -d username=Jane \
      | jq

http POST kongcluster:8001/consumers/Jane/key-auth key=JanePassword
### curl -sX POST kongcluster:8001/consumers/Jane/key-auth \
      -d key=JanePassword \
      | jq


## Task: Let's Create Some Traffic 

(for ((i=1;i<=20;i++))
   do
     sleep 1
     http -h GET $KONG_PROXY_URI/mockbin/request?apikey=JanePassword
   done)

### (for ((i=1;i<=20;i++))
       do
         sleep 1
         curl -IsX GET $KONG_PROXY_URI/mockbin/request?apikey=JanePassword
       done)

## Task: View Metrics

http GET kongcluster:8001/default/vitals/status_code_classes?interval=seconds | jq .meta
### curl -sX GET kongcluster:8001/default/vitals/status_code_classes?interval=seconds | jq .meta


# 07 - Advanced Plugins review

## Lab: Advanced Plugins

cd
source scram.sh

cd
git clone https://github.com/gigaprimatus/kong-gateway-operations.git
source ~/kong-gateway-operations/installation/scram.sh

## Task: Create a service with a route

http POST kongcluster:8001/services \
    name=mockbin \
    url=http://mockbin:8080/request

### curl -sX POST kongcluster:8001/services \
      -d name=mockbin \
      -d url=http://mockbin:8080/request \
      | jq

http -f POST kongcluster:8001/services/mockbin/routes \
    name=mockbin \
    paths=/mockbin

### curl -sX POST kongcluster:8001/services/mockbin/routes \
      -d name=mockbin \
      -d paths=/mockbin \
      | jq

## Task: Enable key-auth, Create consumer and assign credentials

http POST kongcluster:8001/consumers username=Jane
### curl -sX POST kongcluster:8001/consumers \
         -d username=Jane \
         | jq

http POST kongcluster:8001/plugins name=key-auth
### curl -sX POST kongcluster:8001/plugins \
         -d name=key-auth \
         | jq

http POST kongcluster:8001/consumers/Jane/key-auth key=JanePassword
### curl -sX POST kongcluster:8001/consumers/Jane/key-auth \
         -d key=JanePassword \
         | jq

## Task: Now Let's Create Some Traffic for User 'Joe'

(for ((i=1;i<=20;i++))
   do
     sleep 1
     http GET $KONG_PROXY_URI/mockbin?apikey=JanePassword
   done)

### (for ((i=1;i<=20;i++))
       do
         sleep 1
         curl -isX GET $KONG_PROXY_URI/mockbin?apikey=JanePassword
       done)

## Task: Configure Rate Limiting Advanced Plugin

http --form POST kongcluster:8001/plugins \
  name=rate-limiting-advanced \
  config.limit=10 \
  config.limit=20 \
  config.window_size=60 \
  config.window_size=90 \
  config.window_type=sliding \
  config.sync_rate=0 \
  config.strategy=redis \
  config.redis.host=redis \
  config.redis.port=6379

### curl -sX POST kongcluster:8001/plugins \
      -d name=rate-limiting-advanced \
      -d config.limit=10 \
      -d config.limit=20 \
      -d config.window_size=60 \
      -d config.window_size=90 \
      -d config.window_type=sliding \
      -d config.sync_rate=0 \
      -d config.strategy=redis \
      -d config.redis.host=redis \
      -d config.redis.port=6379 \
      | jq

## Task: Create Traffic with Advanced Rate Limiting Plugin Enabled

(for ((i=1;i<=20;i++))
   do
     sleep 1
     http GET $KONG_PROXY_URI/mockbin?apikey=JanePassword
   done)

### (for ((i=1;i<=20;i++))
       do
         sleep 1
         curl -isX GET $KONG_PROXY_URI/mockbin?apikey=JanePassword
       done)

## Task: Configure Request Transformer Advanced Plugin

http --form POST kongcluster:8001/plugins \
  name=request-transformer-advanced \
  config.add.headers=X-Kong-Test-Request-Header:MyRequestHeader \
  config.rename.headers=User-Agent:My-User-Agent

### curl -sX POST kongcluster:8001/plugins \
      -d name=request-transformer-advanced \
      -d config.add.headers=X-Kong-Test-Request-Header:MyRequestHeader \
      -d config.rename.headers=User-Agent:My-User-Agent \
      | jq

## Task: Create Request to See Request Headers

http GET $KONG_PROXY_URI/mockbin/request?apikey=JanePassword
### curl -sX GET $KONG_PROXY_URI/mockbin/request?apikey=JanePassword | jq

## Task: Configure Response Transformer Advanced Plugin

http --form POST kongcluster:8001/plugins \
  name=response-transformer-advanced \
  config.add.json=json-key-added:Test-Key \
  config.add.headers=X-Kong-Test-Response-Header:MyResponseHeader

### curl -sX POST kongcluster:8001/plugins \
    -d name=response-transformer-advanced \
    -d config.add.json=json-key-added:Test-Key \
    -d config.add.headers=X-Kong-Test-Response-Header:MyResponseHeader \
    | jq

## Task: Create Request to See Response  Headers/Body

http GET $KONG_PROXY_URI/mockbin?apikey=JanePassword
### curl -isX $KONG_PROXY_URI/mockbin?apikey=JanePassword







## Slide 43
$ http --form POST kongcluster:8001/plugins name=prometheus \
$ for ((i=1;i<=20;i++)); do sleep 1; http GET $KONG_PROXY_URI/randomyear?apikey=JoePassword; done

## Slide 44
$ http docker:8101/metrics