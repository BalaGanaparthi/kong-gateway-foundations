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

http --form POST kongcluster:8001/.../plugins name=rate-limiting config.second=nn config.min=nn config.hour=nn … config.year=nn config.policy=cluster config.limit_by=consumer
http --form POST kongcluster:8001/services/mocking_service/plugins name=rate-limiting config.hour=8192 config.policy=local
http POST kongcluster:8001/services name=mocking_service url='http://mockbin.org' Kong-Admin-Token:super-admin
http POST kongcluster:8001/services/mocking_service/routes name=mocking paths:='["/mock"]' Kong-Admin-Token:super-admin
http --form POST kongcluster:8001/plugins name=rate-limiting config.minute=5 config.policy=local Kong-Admin-Token:super-admin
http POST kongcluster:8001/plugins name=key-auth Kong-Admin-Token:super-admin
http POST kongcluster:8001/consumers username=Jane Kong-Admin-Token:super-admin
http POST kongcluster:8001/consumers/Jane/key-auth key=JanePassword Kong-Admin-Token:super-admin
for ((i=1;i<=20;i++)); do sleep 1; http --headers GET $KONG_PROXY_URI/mock/request?apikey=JanePassword; done
http --form POST kongcluster:8001/.../plugins name=jwt \
http POST kongcluster:8001/services/mocking_service/plugins name=jwt
http POST kongcluster:8001/services/mocking_service/routes name=mocking paths:='["/mock"]' Kong-Admin-Token:super-admin
http kongcluster:8001/services name=mocking_service url='http://mockbin.org' Kong-Admin-Token:super-admin
http POST kongcluster:8001/consumers username=Jane Kong-Admin-Token:super-admin
http POST kongcluster:8001/consumers/Jane/jwt Kong-Admin-Token:super-admin
http GET kongcluster:8001/consumers/Jane/jwt Kong-Admin-Token:super-admin
http POST kongcluster:8001/services/mocking_service/plugins name=jwt Kong-Admin-Token:super-admin
http -h GET $KONG_PROXY_URI/mock/request Authorization:'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJSaDNtR09iUFVYRUwzdDZIVjhkRm1qbHlNd2JHU1ZFRiJ9.1b5bl5VV2mG8WoCiMB7N3teYMboQFUHs-F_eBDxaorQ' | head -n 1
curl -L https://gist.githubusercontent.com/johnfitzpatrick/b918848c5dc7d76f95c1ed5730e70b32/raw/4389eb1abfd04857f3adc37b80b66dca6c402103/create_certificate.sh | bash
http -f kongcluster:8001/ca_certificates cert@/home/labuser/.certificates/ca.cert.pem tags=ownCA Kong-Admin-Token:super-admin
CERT_ID=$(http -f kongcluster:8001/ca_certificates Kong-Admin-Token:super-admin | jq -r '.data[].id')
http POST kongcluster:8001/services name=public-service url=http://httpbin.org/anything Kong-Admin-Token:super-admin
http -f POST kongcluster:8001/services/public-service/routes name=public-route paths=/public Kong-Admin-Token:super-admin
http POST kongcluster:8001/services name=confidential-service url=https://httpbin.org/uuid Kong-Admin-Token:super-admin
http -f POST kongcluster:8001/services/confidential-service/routes name=confidential-route paths=/confidential Kong-Admin-Token:super-admin
http get $KONG_PROXY_URI/public
http get $KONG_PROXY_URI/confidential
http POST kongcluster:8001/consumers username=demo@example.com Kong-Admin-Token:super-admin
http POST kongcluster:8001/services/confidential-service/plugins name=mtls-auth config:="{\"ca_certificates\": [\"$CERT_ID\"],\"revocation_check_mode\": \"SKIP\"}" Kong-Admin-Token:super-admin
http --verify=no  https://localhost:8443/confidential
http --verify=no --cert=/home/labuser/.certificates/ca.cert.pem --cert-key=/home/labuser/.certificates/client.key https://localhost:8443/confidential
http get $KONG_PROXY_URI/public


# SCRATCH AREA ONLY
