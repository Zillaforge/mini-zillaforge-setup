helm delete test-mariadb

#test-postgresql
helm delete test-postgresql

#test-redis
helm delete test-redis

#rabbitmq
helm delete rabbitmq

#pegasusiam
helm delete pegasusiam

#ldap-opsk
helm delete ldap-opsk

#systemkong
helm delete systemkong

#admin-portal
helm delete admin-portal

#user-portal
helm delete user-portal

#ingress
kubectl delete -f ./ingress/


kubectl delete serviceaccount pegasus-system-admin


#vrm
helm delete vrm

#vps
helm delete vps 

#helm delete sss

#helm delete cloudstorage