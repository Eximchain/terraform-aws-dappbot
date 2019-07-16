# terraform-aws-dappbot
Terraform infrastructure to run DappBot

## Deployment
Before `terraform apply`ing this module, the `dappsmith-builder` image needs to have been built into an [Amazon ECR](https://aws.amazon.com/ecr/) repository.    The image probably already exists, but if you need to build it yourself, scroll down for Packer Build instructions.

### Terraform Apply

Before trying to run `terraform apply`, you need to:

- (1) Run `export GITHUB_TOKEN=XXX`, otherwise you'll run into github oauth issues.
- (2) Make sure you have a `terraform.tfvars` file which includes the below values:
  - **`npm_email`** & **`npm_pass`**: These should be set to the exim-service-account details, which can be found in 1pass.  The email is `robot@eximchain.com`.
  - **`codebuild_image`**: This should correspond to the built image, using the syntax `[repository-name]:tag` (e.g. `eximchain/dappsmith-builder:0.4`).  If you haven't made any changes to the Packer config, you can just check on the Console to see that the image is there.
  - **`subdomain`**: This subdomain is used on a variety of names, so you need to ensure that new resources won't collide with existing ones.  Set it to something unique and informative.
  - **`existing_cert_domain`** & **`create_wildcard_cert`**: Unless you're trying to build onto a brand new root domain, you probably want to use one which we already have provisioned and certified.  Provisioning a certificate for the new domain can take 30 minutes, so you generally only want to do this if you know you need to.  You probably want to set `existing_...` to `"eximchain-dev.com"` and `create_...` to `false`.
  - **`dapphub_subdomain`** & **`dappbot_manager_subdomain`**: If you're reusing an existing domain, you need to change these two subdomains from their default values in order to prevent a collision.


### Packer Build
If you need to build the image yourself, first make sure that you set the following NPM auth variables in your terminal (e.g. `export NPM_EMAIL=test@example.com`):
- `NPM_EMAIL`: Email for an account with read access to the `@eximchain/dappsmith` NPM package.
- `NPM_USER`: Username of above account, which is distinct from the email.
- `NPM_PASS`: Pass of above account.  Make sure to escape any special characters, echo the value to be certain it's what you need it to be.

You can find these value under the "NPM service account" in the Eximchain 1Password.  Also double-check that the `aws_account_id`, `aws_region`, `repository`, and `image_tag` variables are all set to appropriate values within the `variables` key of `packer/dappsmith-builder.json`.  Once that is complete, you can build:

```sh
$ cd packer
$ packer build dappsmith-builder.json
$ cd ../terraform
$ ... double check everything from section above ...
$ terraform apply
```


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

By default the `--num-dapps` argument applies to all tiers. You can use an additional optional argument to override `--num-dapps` for a specific tier. For example, to allow `5` standard, `2` professional, and `0` enterprise dapps you could use the following command instead:

```sh
python3 test-auth.py --username $EMAIL create --user-pool-id $USER_POOL_ID --num-dapps $NUM_DAPPS --standard-limit 5 --professional-limit 2 --enterprise-limit 0
```

Note that `--num-dapps` must be specified even if all tiers have overrides specified.

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
