# terraform-aws-abi-clerk
Terraform infrastructure to run ABI Clerk

## Testing

You can run test calls against the API from the sampleCalls directory

### Create a user

After the Terraform configuration has been applied, use the script to create a user:

```sh
USER_POOL_ID=<User Pool ID output from Terraform configuration>
EMAIL=<An email address you have access to>
NUM_DAPPS=<The dapp limit to apply to this user>

python3 test-auth.py --username $EMAIL create --user-pool-id $USER_POOL_ID --num-dapps $NUM_DAPPS
```

### Change user password

Once you get your temporary password, browse to the `login_url` that was output by Terraform. Log in with your temporary password and set a permanent password. Once your password is set, this user can be used for testing.

### Authenticate as user

Once the user's password is fully set, run the following to authenticate:

```sh
EMAIL=<The email for your test user>
CLIENT_ID=<Client ID output from Terraform configuration>
PASSWORD=<The password for your test user>

python3 test-auth.py --username $EMAIL login --client-id $CLIENT_ID --password $PASSWORD
```

### API Test

Set the `AUTH_TOKEN` and then make calls to the API

```sh
API_TOKEN=<API Token from Authentication Step>
curl -XPOST -H "Authorization: $AUTH_TOKEN" -d @create.json https://api-test.eximchain-dev.com/test/create
curl -XPOST -H "Authorization: $AUTH_TOKEN" -d @read.json https://api-test-2.eximchain-dev.com/test/read
curl -XPOST -H "Authorization: $AUTH_TOKEN" -d @read.json https://api-test-2.eximchain-dev.com/test/delete
```

### Clean up user

You can clean up your test user with the following command:

```sh
USER_POOL_ID=<User Pool ID output from Terraform configuration>
EMAIL=<The email for your test user>
python3 test-auth.py --username $EMAIL delete --user-pool-id $USER_POOL_ID
```
