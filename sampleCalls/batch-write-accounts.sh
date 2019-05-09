#!/bin/bash

for i in {1..250}; do
  HEX=$(printf "%#04x" $i);
  EMAIL="hacker-$HEX@dapp.bot";
  GENERATED=$(xkcdpass --numwords=3 --delimiter='-' --wordfile='eff-short' --valid-chars='[a-z]');
  PASSWORD="hacker-$GENERATED";
  echo "$EMAIL $PASSWORD" >> "accounts.txt";
done