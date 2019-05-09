#!/bin/bash

while IFS= read -r line; do
  EMAIL=$(echo "$line" | cut -d ' ' -f1);
  PASSWORD=$(echo "$line" | cut -d ' ' -f2);
  sleep 1;
  python3 test-auth.py --username $EMAIL create --user-pool-id us-east-1_zMsnmGKj1 --num-dapps 1 --temp-password $PASSWORD
done < "accounts.txt"