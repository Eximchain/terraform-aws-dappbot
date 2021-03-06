import argparse
import boto3

NUM_DAPPS_ATTR = 'custom:num_dapps'
STANDARD_LIMIT_ATTR = 'custom:standard_limit'
PROFESSIONAL_LIMIT_ATTR = 'custom:professional_limit'
ENTERPRISE_LIMIT_ATTR = 'custom:enterprise_limit'
PAYMENT_PROVIDER_ATTR = 'custom:payment_provider'
PAYMENT_STATUS_ATTR = 'custom:payment_status'
EMAIL_ATTR = 'email'
EMAIL_VERIFIED_ATTR = 'email_verified'

cognito = boto3.client('cognito-idp')

def parse_args():
    parser = argparse.ArgumentParser(description='Manage Cognito Users for auth testing')
    parser.add_argument('--username', dest='username', required=True)
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')
    parser_create = subparsers.add_parser('create', help='Create a cognito user')
    parser_create.add_argument('--user-pool-id', dest='user_pool_id', required=True)
    parser_create.add_argument('--num-dapps', dest='num_dapps', required=True)
    parser_create.add_argument('--standard-limit', dest='standard_limit', required=False)
    parser_create.add_argument('--professional-limit', dest='professional_limit', required=False)
    parser_create.add_argument('--enterprise-limit', dest='enterprise_limit', required=False)
    parser_create.add_argument('--temp-password', dest='temp_password', default=None)
    parser_delete = subparsers.add_parser('delete', help='Delete a cognito user')
    parser_delete.add_argument('--user-pool-id', dest='user_pool_id', required=True)
    parser_login = subparsers.add_parser('login', help='Login as a cognito user')
    parser_login.add_argument('--client-id', dest='client_id', required=True)
    parser_login.add_argument('--password', dest='password', required=True)
    return parser.parse_args()

def create(args):
    kwargs = {
        'UserPoolId': args.user_pool_id,
        'Username': args.username,
        'DesiredDeliveryMediums': ['EMAIL'],
        'UserAttributes': [
            {
                'Name': NUM_DAPPS_ATTR,
                'Value': args.num_dapps
            },
            {
                'Name': STANDARD_LIMIT_ATTR,
                'Value': args.standard_limit if args.standard_limit else args.num_dapps
            },
            {
                'Name': PROFESSIONAL_LIMIT_ATTR,
                'Value': args.professional_limit if args.professional_limit else args.num_dapps
            },
            {
                'Name': ENTERPRISE_LIMIT_ATTR,
                'Value': args.enterprise_limit if args.enterprise_limit else args.num_dapps
            },
            {
                'Name': PAYMENT_PROVIDER_ATTR,
                'Value': 'ADMIN'
            },
            {
                'Name': PAYMENT_STATUS_ATTR,
                'Value': 'ACTIVE'
            },
            {
                'Name': EMAIL_ATTR,
                'Value': args.username
            },
            {
                'Name': EMAIL_VERIFIED_ATTR,
                'Value': 'true'
            }
        ]
    }
    if args.temp_password:
        kwargs['TemporaryPassword'] = args.temp_password
        
    response = cognito.admin_create_user(**kwargs)
    print(f'Created user {args.username} for user pool {args.user_pool_id}. Check email for a temporary password.')

def delete(args):
    response = cognito.admin_delete_user(UserPoolId=args.user_pool_id, Username=args.username)
    print(f'Deleted user {args.username} for user pool {args.user_pool_id}.')

def login(args):
    response = cognito.initiate_auth(
        ClientId=args.client_id,
        AuthFlow='USER_PASSWORD_AUTH',
        AuthParameters={
            'USERNAME': args.username,
            'PASSWORD': args.password
        }
    )
    # TODO: Handle this in an easier way
    if 'ChallengeName' in response and response['ChallengeName'] == 'NEW_PASSWORD_REQUIRED':
        print("Password change required, use the Web UI to set your password.")
        return
    id_token = response['AuthenticationResult']['IdToken']
    print(f'AUTH_TOKEN={id_token}')

# Executes the command specified in the provided argparse namespace
def execute_command(args):
    if args.command == 'create':
        create(args)
    elif args.command == 'delete':
        delete(args)
    elif args.command == 'login':
        login(args)
    else:
        raise RuntimeError(f'Unexpected command {args.command}')

args = parse_args()
execute_command(args)