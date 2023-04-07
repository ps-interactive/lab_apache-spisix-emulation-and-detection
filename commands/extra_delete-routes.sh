#!/usr/bin/bash

# clear existing routes
curl -s -X 'POST' http://172.31.24.111/apisix/batch-requests -o- \
 -H 'Host: 127.0.0.1:9080' \
 -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
 -H 'Accept: */*' \
 -H 'Accept-Encoding: utf8' \
 -H 'Content-Type: application/json' \
 -H 'Connection: close' \
--data "$(echo -n "{
 \"headers\": {
  \"X-Real-IP\": \"127.0.0.1\",
  \"X-API-KEY\": \"edd1c9f034335f136f87ad84b625c8f1\",
  \"Content-Type\": \"application/json\"
 },
 \"timeout\": 1500,
 \"pipeline\": [{
  \"path\": \"/apisix/admin/routes/index\",
  \"method\": \"DELETE\"
 }]
}")"|jq
