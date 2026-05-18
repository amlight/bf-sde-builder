#!/bin/bash

echo $(date -u +%F,%T) "Waiting tofino switchd to start on port 9999..."

while ! nc -z localhost 9999; do
  sleep 1
done

echo "Tofino started"
