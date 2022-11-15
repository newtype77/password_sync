#!/bin/bash

#변경된지 5초 미만인 파일 찾기
#changed=`find /etc/shadow -type f -mmin -1 | wc -l` 

for i in {1..30}; do
	changed=`find /etc/shadow -type f -mmin -0.1 | wc -l`
	if [ $changed -gt 0 ]
	then
	/root/mgmt/syncuser/syncuser.sh.x 2>> /root/mgmt/syncuser/log/sync.err
	fi
    sleep 2;
done
You have new mail in /var/spool/mail/root