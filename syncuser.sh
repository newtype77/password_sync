#!/bin/bash

# yum -y install epel-release
# yum install -y shc 
# yum install -y sshpass
# yum install -y gcc
# shc -f syncuser.sh


bastionip=`hostname -I`
aws_profile=`cat /root/.aws/config | grep profile | sed -e 's/profile//g' | sed -e 's/\[//g' | sed -e 's/\]//g'`

pass='X'

cd /root/mgmt/syncuser
rm -f ./data/*

#대상 iplist 취합 / bastion ip 제외
for profiles in $aws_profile
do
	aws ec2 describe-instances --filter "Name=tag:stage,Values=live" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[PrivateIpAddress]" --profile $profiles  | grep -v "\[" | grep -v "\]" | grep -v $bastionip | sed -e 's/^ *//g' | sed -e "s/\"//g" >> ./data/ip.list
done


#유저 리스트 획득
cat /etc/passwd | grep -A 100 ec2-user | grep -v 'ec2-user' | cut -d ":" -f1 > ./data/user.list


#대상자 shadow 정보 취합
rm -f ./data/shadow.tmp
while read users
do
	cat /etc/shadow | grep $users >> ./data/shadow.tmp
done < ./data/user.list


#변경 시작
while read ipaddress
do
	#유저 생성
	sshpass -p$pass scp -P10022 -o StrictHostKeyChecking=no ./data/user.list techadmin@$ipaddress:/tmp/
	sshpass -p$pass ssh -no StrictHostKeyChecking=no techadmin@$ipaddress -p10022 "while read users; do sudo /usr/sbin/adduser \$users -g dev; done < /tmp/user.list"

	#대상자 shadow 정보 scp
	sshpass -p$pass scp -P10022 -o StrictHostKeyChecking=no ./data/shadow.tmp  techadmin@$ipaddress:/tmp/
	
	#shadow 수정을 위한 cp 
	sshpass -p$pass ssh -no StrictHostKeyChecking=no techadmin@$ipaddress -p10022 "sudo cp /etc/shadow /tmp/shadow; sudo chmod 002 /tmp/shadow ;"
	
	#기존 유저 패스워드 정보 삭제
	sshpass -p$pass ssh -no StrictHostKeyChecking=no techadmin@$ipaddress -p10022 "while read users; do sudo sed -i "/'$users'/d" /tmp/shadow; done < /tmp/user.list"	

	#shadow 정보 업데이트, 원복
	sshpass -p$pass ssh -no StrictHostKeyChecking=no techadmin@$ipaddress -p10022 "sudo cat /tmp/shadow.tmp >> /tmp/shadow ; sudo chmod 000 /etc/shadow ; sudo cp /tmp/shadow /etc/shadow ; sudo rm -f /tmp/shadow "



	echo `date`
	echo $ipaddress

done < ./data/ip.list

rm -f ./data/* 

echo done