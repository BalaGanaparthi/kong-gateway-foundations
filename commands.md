
> tmux set mouse off

# 02 - Kong Gateway Installation
./setup-docker.sh
git clone https://github.com/johnfitzpatrick/kong-gateway-operations.git
cd kong-gateway-operations/installation
tree

sudo cp -R ssl-certs /srv/shared
docker-compose up -d

echo $KONG_ADMIN_API_URI
http --headers GET $KONG_ADMIN_API_URI

echo $KONG_MANAGER_URI
cat << EOF >> license.json
{"license":{"version":1,"signature":"06497d9d0a20ed9cdae9c213fad12760820887ab3dfd66fdc97c417264a7853e2b2fb20dcb239c9edbc0df03edfae6c70003bfc5ecce8b6911e0c24d022a8204","payload":{"customer":"John Fitzpatrick","license_creation_date":"2021-8-9","product_subscription":"Kong Enterprise Subscription","support_plan":"Platinum","admin_seats":"1","dataplanes":"10","license_expiration_date":"2022-08-09","license_key":"0011K000022IA3HQAW_a1V1K0000084AfPUAU"}}}
EOF
http POST "$KONG_ADMIN_API_URI/licenses" payload=@./license.json
docker-compose stop kong-cp; docker-compose rm -f kong-cp; docker-compose up -d kong-cp

sed -ie "s|KONG_ADMIN_API_URI|$KONG_ADMIN_API_URI|g" deck/deck.yaml
deck diff --config deck/deck.yaml -s deck/default-entities.yaml --workspace default
deck sync --config deck/deck.yaml -s deck/default-entities.yaml --workspace default

curl --cacert /srv/shared/ssl-certs/rootCA.pem -X POST "$KONG_PORTAL_API_URI/default/register" \
-H 'Content-Type: application/json' \
-D 'Kong-Admin-Token: password' \
--data-raw '{"email":"myemail@example.com",
 "password":"password",
 "meta":"{\"full_name\":\"Dev E. Loper\"}"
}'

curl --cacert /srv/shared/ssl-certs/rootCA.pem -X PATCH "$KONG_ADMIN_API_URI/default/developers/myemail@example.com" \
--header 'Content-Type: application/json' \
--header 'Kong-Admin-Token: password' \
--data-raw '{"status": 0}'



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
