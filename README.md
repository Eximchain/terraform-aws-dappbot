# terraform-aws-abi-clerk
Terraform infrastructure to run ABI Clerk

## Deployment
Before `terraform apply`ing this module, the `abi-clerk-builder` image needs to have been built into an [Amazon ECR](https://aws.amazon.com/ecr/) repository.  

If you know this has already happened, just make sure to fillset `codebuild_image` in `terraform.tfvars` to `[repository-name]:tag` (e.g. `eximchain/abi-clerk:0.4`).

If you need to build the image yourself, first make sure that you set the following NPM auth variables:
- `NPM_EMAIL`: Email for an account with read access to the `@eximchain/dappsmith` NPM package.
- `NPM_USER`: Username of above account, which is distinct from the email.
- `NPM_PASS`: Pass of above account.  Make sure to escape any special characters, echo the value to be certain it's what you need it to be.

Before running `packer build abi-clerk-builder.json`, double-check that the `aws_account_id`, `aws_region`, `repository`, and `image_tag` variables are all set to appropriate values.

## Dev Testing

You can run test calls against the API from the sampleCalls directory.

> **First change the `DappName` in `create/read.json`, and don't commit your changes.**

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