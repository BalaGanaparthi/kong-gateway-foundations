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

### curl -siX POST kongcluster:8001/licenses \
      -F payload=@/etc/kong/license.json \
      | grep HTTP

## Task: Recreate/Restart the CP to enable EE features

docker-compose stop kong-cp
docker-compose rm -f kong-cp
docker-compose up -d kong-cp

## Task: Enable the Developer Portal:
http --form PATCH kongcluster:8001/workspaces/default config.portal=true
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
      --header 'Content-Type: application/json' \
      --data-raw '{"status": 0}'

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
  name=httpbin \
  url=https://httpbin.org/anything

###  curl -X POST kongcluster:8001/services \
       -d "name=httpbin" \
       -d "url=https://httpbin.org/anything" \
       | jq

http POST kongcluster:8001/services/httpbin/routes \
  name=httpbin \
  paths:='["/httpbin"]'

### curl -X POST kongcluster:8001/services/httpbin/routes \
      -d "name=httpbin" \
      -d "paths=/httpbin" \
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

## Upgrading Kong Gateway

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

### curl -sX POST kongcluster:8001/services \
      -d "name=httpbin" \
      -d "url=https://httpbin.org/anything" \
      | jq

http POST kongcluster:8001/services/httpbin/routes \
    name=httpbin \
    paths:='["/httpbin"]'

### curl -sX POST kongcluster:8001/services/httpbin/routes \
      -d 'name=httpbin' \
      -d 'paths[]=/httpbin' \
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
http --headers GET kongcluster:8000/httpbin
### curl -IX GET kongcluster:8000/httpbin

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
  name=httpbin \
  url=https://httpbin.org/anything

### curl -X POST kongcluster:8001/services \
      -d "name=httpbin" \
      -d "url=https://httpbin.org/anything"

http POST kongcluster:8001/services/httpbin/routes \
  name=httpbin \
  paths:='["/httpbin"]'

### curl -X POST kongcluster:8001/services/httpbin/routes \
      -d "name=httpbin" \
      -d "paths[]=/httpbin"

export KONG_VERSION="2.6.0.1-alpine"
docker-compose -f kongupgdemo.yaml up -d

http --headers GET kongcluster:8000/httpbin
### curl -IX GET kongcluster:8000/httpbin

docker-compose -f kongupgdemo.yaml down -v



# 02 - Securing Kong Gatway

## Lab: Securing Kong Gateway
cd
git clone https://github.com/gigaprimatus/kong-gateway-operations.git
source kong-gatway-oprations/installation/scram.sh

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


## Task: Verify Authentication with Kong Manager
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
  name=mocking_service \
  url='http://mockbin.org' \
  Kong-Admin-Token:AdminB_token

### curl -sX POST kongcluster:8001/WorkspaceA/services \
  -d name=mocking_service \
  -d url='http://mockbin.org' \
  -H Kong-Admin-Token:AdminB_token \
  | jq

http POST kongcluster:8001/WorkspaceA/services \
  name=mocking_service \
  url='http://mockbin.org' \
  Kong-Admin-Token:AdminA_token

### curl -sX POST kongcluster:8001/WorkspaceA/services \
  -d name=mocking_service \
  -d url='http://mockbin.org' \
  -H Kong-Admin-Token:AdminA_token \
  | jq

http POST kongcluster:8001/WorkspaceA/services/mocking_service/routes \
  name=mocking \
  hosts:='["myhost.me"]' \
  paths:='["/mocker"]' \
  Kong-Admin-Token:AdminA_token

### curl -sX POST kongcluster:8001/WorkspaceA/services/mocking_service/routes \
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

## Task: Create a service with a route

http POST kongcluster:8001/services \
  name=mocking_service \
  url='http://mockbin.org'

### curl -sX POST kongcluster:8001/services \
      -d name=mocking_service \
      -d url='http://mockbin.org' \
      | jq 

http POST kongcluster:8001/services/mocking_service/routes \
  name=mocking \
  paths:='["/mock"]'

curl -sX POST kongcluster:8001/services/mocking_service/routes \
  -d name=mocking \
  -d paths='/mock' \
  | jq

## Task: Configure Rate Limiting and key-auth Plugins

http --form POST kongcluster:8001/services/mocking_service/plugins \
  name=rate-limiting \
  config.minute=5 \
  config.policy=local

### curl -sX POST kongcluster:8001/services/mocking_service/plugins \
      -d name=rate-limiting \
      -d config.minute=5 \
      -d config.policy=local \
      | jq

http POST kongcluster:8001/services/mocking_service/plugins name=key-auth
### curl -sX kongcluster:8001/services/mocking_service/plugins -d name=key-auth | jq

## Task: Create consumer and assign credentials
http POST kongcluster:8001/consumers username=Jane
### curl -sX POST kongcluster:8001/consumers -d username=Jane | jq
http POST kongcluster:8001/consumers/Jane/key-auth key=JanePassword
### curl -sX POST kongcluster:8001/consumers/Jane/key-auth -d key=JanePassword | jq

## Task: Create Some Traffic for User

( for ((i=1;i<=20;i++))
    do
    sleep 1
    http GET kongcluster:8000/mock/request?apikey=JanePassword
  done )

### ( for ((i=1;i<=20;i++))
      do
        sleep 1
        curl -isX GET kongcluster:8000/mock/request?apikey=JanePassword
      done )

## Task: Create mocking service and route
http DELETE kongcluster:8001/services/mocking_service/routes/mocking > /dev/null 2>&1
### curl -X DELETE kongcluster:8001/services/mocking_service/routes/mocking > /dev/null 2>&1
http DELETE kongcluster:8001/services/mocking_service > /dev/null 2>&1
### curl -X DELETE kongcluster:8001/services/mocking_service > /dev/null 2>&1

http POST kongcluster:8001/services \
  name=mocking_service \
  url='http://mockbin.org'

### curl -D - -o /dev/null -sX POST kongcluster:8001/services \
    -d name=mocking_service \
    -d url='http://mockbin.org'

http POST kongcluster:8001/services/mocking_service/routes \
    name=mocking \
    paths:='["/mock"]'

### curl -D - -o /dev/null -sX POST kongcluster:8001/services/mocking_service/routes \
      -d name=mocking \
      -d paths='/mock'

## Task: Enable JWT Plugin for a Service
http POST kongcluster:8001/services/mocking_service/plugins name=jwt

### curl -sX POST kongcluster:8001/services/mocking_service/plugins \
      -d name=jwt \
      | jq

## Task: Create a consumer and assign JWT credentials
http DELETE kongcluster:8001/consumers/Jane
### curl -iX DELETE kongcluster:8001/consumers/Jane
http POST kongcluster:8001/consumers username=Jane
### curl -D - -o /dev/null -sX POST kongcluster:8001/consumers -d username=Jane
http POST kongcluster:8001/consumers/Jane/jwt
### curl -D - -o /dev/null -sX POST kongcluster:8001/consumers/Jane/jwt

## Task: Get JWT key/secret for consumer
KEY=$(http GET kongcluster:8001/consumers/Jane/jwt | jq '.data[0].key')
echo '{"iss":'"$KEY"'}'
SECRET=$(http GET kongcluster:8001/consumers/Jane/jwt | jq '.data[0].secret'|xargs)
TOKEN=$(jwt -e -s $SECRET --jwt '{"iss":'"$KEY"'}')

## Task: Consume the service with JWT credentials
http --headers GET kongcluster:8000/mock/request
### curl -isX GET kongcluster:8000/mock/request
http --headers GET kongcluster:8000/mock/request Authorization:"Bearer $TOKEN"
### curl -isX GET kongcluster:8000/mock/request -H Authorization:"Bearer $TOKEN" | jq

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

## Task: Set up a public and a private service & routes


http POST kongcluster:8001/services \
  name=public-service \
  url=http://httpbin.org/anything

### curl -sX POST kongcluster:8001/services \
      -d name=public-service \
      -d url=http://httpbin.org/anything \
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
  url=https://httpbin.org/uuid

### curl -sX POST kongcluster:8001/services \
      -d name=confidential-service \
      -d url=https://httpbin.org/uuid \
      | jq
    
http -f POST kongcluster:8001/services/confidential-service/routes \
  name=confidential-route \
  paths=/confidential

### curl -sX POST kongcluster:8001/services/confidential-service/routes \
      -d name=confidential-route \
      -d paths=/confidential \
      | jq

## Task: Verify traffic is being proxied
http GET kongcluster:8000/public
## curl -isX GET kongcluster:8000/public
http GET kongcluster:8000/confidential
### curl -isX GET kongcluster:8000/confidential

## Task: Create a consumer
http POST kongcluster:8001/consumers username=demo@example.com
### curl POST kongcluster:8001/consumers -d username=demo@example.com | jq

## Task: Implement the mTLS plugin to Kong
http POST kongcluster:8001/services/confidential-service/plugins \
  name=mtls-auth \
  config:="{\"ca_certificates\": [\"$CA_CERT_ID\"],\"revocation_check_mode\": \"SKIP\"}"

### curl -sX POST kongcluster:8001/services/confidential-service/plugins \
      -d name=mtls-auth \
      -d config.ca_certificates=$CA_CERT_ID \
      -d config.revocation_check_mode='SKIP' \
      | jq

## Task: Verify access for private service without a certificate
http --verify=no https://kongcluster:8443/confidential
### curl -k -sX GET https://kongcluster:8443/confidential | jq

http --verify=no \
    --cert=/home/labuser/.certificates/client.crt \
    --cert-key=/home/labuser/.certificates/client.key \
    https://kongcluster:8443/confidential

### curl -k -sX GET \
      --key /home/labuser/.certificates/client.key \
      --cert /home/labuser/.certificates/client.crt \
      https://kongcluster:8443/confidential \
      | jq

## Task: Verify public route is unaffected
http GET kongcluster:8000/public
### curl -isX GET kongcluster:8000/public

## Task: Configure and Test Rate Limiting
http --form POST kongcluster:8001/consumers/demo@example.com/plugins \
   name=rate-limiting \
   config.minute=5

### curl -sX POST kongcluster:8001/consumers/demo@example.com/plugins \
      -d name=rate-limiting \
      -d config.minute=5 \
      | jq


( for ((i=1;i<=10;i++))
    do
      http --headers --verify=no --cert=/home/labuser/.certificates/client.crt \
         --cert-key=/home/labuser/.certificates/client.key \
         https://kongcluster:8443/confidential \
         | head -1
  done )

### ( for ((i=1;i<=10;i++))
      do
        curl -k -isX GET \
          --key /home/labuser/.certificates/client.key \
          --cert /home/labuser/.certificates/client.crt \
          https://kongcluster:8443/confidential \
          | head -1
      done )


# 04 - OIDC Plugin
cd
source scram.sh

cd
git clone https://github.com/gigaprimatus/kong-gateway-operations.git
source ~/kong-gateway-operations/installation/scram.sh

## Task: Deploy Keycloak
sed -i 's|\#\^|\ \ |g' docker-compose.yaml
docker-compose up -d
cd ~/kong-gateway-operations/oidc
cat kong_realm_template.json | jq '.users[].username'

## Task: Add a Service to use with OIDC

http POST kongcluster:8001/services \
    name=my-oidc-service \
    url=http://httpbin.org/anything

### curl -isX POST kongcluster:8001/services \
      -d name=my-oidc-service \
      -d url=http://httpbin.org/anything

http -f POST kongcluster:8001/services/my-oidc-service/routes \
  name=my-oidc-route \
  paths=/oidc

### curl -isX POST kongcluster:8001/services/my-oidc-service/routes \
      -d name=my-oidc-route \
      -d paths=/oidc

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
### curl -X GET kongcluster:8000/oidc -u user:password

## Task: View Kong Discovery Information from IDP
http GET kongcluster:8001/openid-connect/issuers
### curl -sX GET kongcluster:8001/openid-connect/issuers | jq
http -b GET kongcluster:8001/openid-connect/issuers | jq -r .data[].issuer
### curl -sX GET kongcluster:8001/openid-connect/issuers | jq -r .data[].issuer

## Task: Provide a username/password to Kong and retrieve a token
# http -b GET kongcluster:8001/plugins | jq .data[].config.auth_methods
# http -b GET kongcluster:8001/plugins | jq .data[].config.password_param_type

# http -f POST https://8080-1-ebf469fd.labs.konghq.com/auth/realms/kong/protocol/openid-connect/token \
#   grant_type=password \
#   username=employee \
#   passowrd=test \
#   client_id=kong \
#   client_secret=681d81ee-9ff0-438a-8eca-e9a4f892a96b

http GET kongcluster:8000/oidc -a employee:test
### curl -X GET kongcluster:8000/oidc -u employee:test


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
      -d config.whitelist=admins

http GET kongcluster:8000/oidc -a employee:test
### curl -isX GET kongcluster:8000/oidc -u employee:test


## Task:  Modify the ACL plugin to require users being members of the role demo-service to access the service

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

http -f PATCH kongcluster:8001/plugins/$PLUGIN_ID \
  config.consumer_claim=preferred_username \
  config.consumer_optional=true

#### curl -sX PATCH kongcluster:8001/plugins/$PLUGIN_ID \
       -d config.consumer_claim=preferred_username \
       -d config.consumer_optional=true \
       | jq

## Task: Configure Rate Limiting Plugins

http -f POST kongcluster:8001/routes/my-oidc-route/plugins \
  name=rate-limiting \
  config.minute=5 \
  config.policy=local

### curl -iX POST kongcluster:8001/routes/my-oidc-route/plugins \
      -d name=rate-limiting \
      -d config.minute=5 \
      -d config.policy=local

http -f POST kongcluster:8001/consumers/employee/plugins \
  name=rate-limiting \
  config.minute=1000 \
  config.policy=local

### curl -iX POST kongcluster:8001/consumers/employee/plugins \
      -d name=rate-limiting \
      -d config.minute=1000 \
      -d config.policy=local
  
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


## Slide 19
$ curl -o /dev/null --trace-time -ivv -L https://www.google.com
$ curl -L --output /dev/null --silent --show-error --write-out '\n\nlookup: %{time_namelookup}\nconnect: %{time_connect}\nappconnect: %{time_appconnect}\npretransfer: %{time_pretransfer}\nredirect: %{time_redirect}\nstarttransfer: %{time_starttransfer}\ntotal: %{time_total}\nsize: %{size_download}\n\n' 'https://www.google.com'

## Slide 24
$ cd ~/kong-gateway-operations/troubleshooting
$ ./create-broken-lab1.sh

## Slide 25
$ echo $KONG_PROXY_URI

# 06 - Kong Vitals

## Slide 10
$ for ((i=1;i<=20;i++)); do sleep 1; http GET $KONG_PROXY_URI/mock/request?apikey=JanePassword; done

## Slide 12
$ http kongcluster:8001/default/vitals/status_code_classes?interval=seconds  Kong-Admin-Token:super-admin | jq .meta

# 07 - Advanced Plugins review

## Slide 14
$ http POST kongcluster:8001/services name=numberfun url='http://numbersapi.com/random/year' Kong-Admin-Token:super-admin
$ http -f POST kongcluster:8001/services/numberfun/routes name=numberfun_route paths=/randomyear Kong-Admin-Token:super-admin

## Slide 15
$ http POST kongcluster:8001/consumers username=Joe Kong-Admin-Token:super-admin
$ http POST kongcluster:8001/consumers/Joe/key-auth key=JoePassword Kong-Admin-Token:super-admin
$ http POST kongcluster:8001/plugins name=key-auth Kong-Admin-Token:super-admin
$ for ((i=1;i<=20;i++)); do sleep 1; http GET kongcluster:8000/randomyear?apikey=JoePassword; done

## Slide 18
$ http --form POST kongcluster:8001/plugins name=rate-limiting-advanced config.limit=5 config.window_size=60 config.sync_rate=-1 config.strategy=redis config.redis.host=redis-hostname config.redis.port=6379 kong-admin-token:super-admin
$ for ((i=1;i<=20;i++)); do sleep 1; http GET kongcluster:8000/randomyear?apikey=JoePassword; done

## Slide 25
$ http --form POST docker:8001/plugins name=request-transformer-advanced config.add.headers[1]=h1:v1 config.add.headers[2]=h2:v1
$ http --form POST docker:8001/plugins name=request-transformer-advanced config.add.querystring[1]=q1:v1 config.add.querystring[2]=q2:v1 config.add.headers=h1:v1

## Slide 26
$ http --form POST docker:8001/plugins name=response-transformer-advanced config.remove.headers=h1,h2 config.add.headers=h3:v1
$ http --form POST docker:8001/plugins name=response-transformer-advanced config.add.json=sample_key:sample_value config.add.headers=h1:v1

## Slide 30
$ http --form POST kongcluster:8001/plugins name=response-transformer-advanced config.add.json=p1:v1 config.add.headers=X-Kong-Test-Header:Test-Value Kong-Admin-Token:super-admin
$ http GET $KONG_PROXY_URI/randomyear?apikey=JoePassword

## Slide 33
$ http --form POST kongcluster:8001/plugins name=request-transformer-advanced config.add.headers=X-Kong-Test-Request-Header:MyHeader config.rename.headers=User-Agent:My-User-Agent Kong-Admin-Token:super-admin

## Slide 35
$ http -v GET $KONG_PROXY_URI/mock/request?apikey=JoePassword

## Slide 43
$ http --form POST kongcluster:8001/plugins name=prometheus \
$ for ((i=1;i<=20;i++)); do sleep 1; http GET $KONG_PROXY_URI/randomyear?apikey=JoePassword; done

## Slide 44
$ http docker:8101/metrics