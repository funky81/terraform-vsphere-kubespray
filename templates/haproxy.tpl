global
	log /dev/log	local0
	log /dev/log	local1 notice
	chroot /var/lib/haproxy
	stats socket /run/haproxy/admin.sock mode 660 level admin
	stats timeout 30s
	user haproxy
	group haproxy
	daemon

	# Default SSL material locations
	ca-base /etc/ssl/certs
	crt-base /etc/ssl/private

	# Default ciphers to use on SSL-enabled listening sockets.
	# For more information, see ciphers(1SSL). This list is from:
	#  https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
	ssl-default-bind-ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS
	ssl-default-bind-options no-sslv3

defaults
	log	global
	mode	http
	option	httplog
	option	dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
#	errorfile 400 /etc/haproxy/errors/400.http
#	errorfile 403 /etc/haproxy/errors/403.http
#	errorfile 408 /etc/haproxy/errors/408.http
#	errorfile 500 /etc/haproxy/errors/500.http
#	errorfile 502 /etc/haproxy/errors/502.http
#	errorfile 503 /etc/haproxy/errors/503.http
#	errorfile 504 /etc/haproxy/errors/504.http

frontend kubernetes
	bind ${bind_ip}:6443
	option tcplog
	mode tcp
	default_backend kubernetes-master-nodes

backend kubernetes-master-nodes
	mode tcp
	balance roundrobin
	option tcp-check

listen stats # Define a listen section called "stats"
  bind :8080 # Listen on localhost:9000
  mode http
  stats enable  # Enable stats page
  #stats hide-version  # Hide HAProxy version
  stats realm Haproxy\ Statistics  # Title text for popup window
  stats uri /stats  # Stats URI
  stats auth admin:password  # Authentication credentials
