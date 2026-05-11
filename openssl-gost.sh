#!/bin/bash
read -p "Ты включил ssh на ISP? [y/N]" -n 1 -r

if [[ $REPLY =~ ^[Yy]$ ]]
then

	apt-get install -y openssl-gost-engine
	apt-get install sshpass -y

	control openssl-gost enabled
	
	openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:TCB -out ca.key
	openssl req -new -x509 -md_gost12_256 -days 30 -key ca.key -out ca.cer
	openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:A -out web.au-team.irpo.key
	openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:A -out docker.au-team.irpo.key
	openssl req -new  -md_gost12_256 -key web.au-team.irpo.key -out web.au-team.irpo.csr -subj "/C=RU/O=au-team.irpo/CN=docker.au-team.irpo"
	openssl req -new  -md_gost12_256 -key docker.au-team.irpo.key -out docker.au-team.irpo.csr -subj "/C=RU/O=au-team.irpo/CN=docker.au-team.irpo"
	openssl x509 -req -in web.au-team.irpo.csr -CA ca.cer -CAkey ca.key -CAcreateserial -out web.au-team.irpo.cer -days 30
	openssl x509 -req -in docker.au-team.irpo.csr -CA ca.cer -CAkey ca.key -CAcreateserial -out docker.au-team.irpo.cer -days 30

	scp web.au-team.irpo.key root@172.16.1.1:~/
	scp web.au-team.irpo.cer root@172.16.1.1:~/
	scp docker.au-team.irpo.key root@172.16.1.1:~/
	scp docker.au-team.irpo.cer root@172.16.1.1:~/

	sshpass -p "P@ssw0rd" ssh -o StrictHostKeyChecking=no root@172.16.1.1 \
	'
	mkdir /etc/nginx/ssl
	cp *au-team.irpo* /etc/nginx/ssl
	cat << EOF > /etc/nginx/sites-available/default
	server {
    listen 443 ssl;
    server_name web.au-team.irpo;
    ssl_certificate /etc/nginx/ssl/web.au-team.irpo.cer;
    ssl_certificate_key /etc/nginx/ssl/web.au-team.irpo.key;
    ssl_ciphers GOST2012-GOST8912-GOST8912:HIGH:MEDIUM;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://172.16.1.2:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        auth_basic "Restricted area";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}

server {
    listen 443 ssl;
    server_name docker.au-team.irpo;
    ssl_certificate /etc/nginx/ssl/docker.au-team.irpo.cer;
    ssl_certificate_key /etc/nginx/ssl/docker.au-team.irpo.key;
    ssl_ciphers GOST2012-GOST8912-GOST8912:HIGH:MEDIUM;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://172.16.2.2:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
	EOF
	systemctl restart nginx
	'

fi
