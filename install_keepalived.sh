#!/bin/bash
##sudo apt-get update
##sudo apt-get install build-essential libssl-dev
product=keepalived-2.0.7
echo "Step 1. download binary"
echo "we will download $product. For the latest version please check into http://www.keepalived.org/software"
wget http://www.keepalived.org/software/${product}.tar.gz
tar -zxf ${product}.tar.gz
cd $product

echo -e "\n Step 2. compile and install"
./configure
make
sudo make install

echo -e "\n Step 3. Setting up Upstart Script for Keepalived"

conffile=test.conf
echo "description \"load-balancing and high-availability service\"" > /etc/init/${conffile}
echo "start on runlevel [2345]" >> /etc/init/${conffile}
echo "stop on runlevel [!2345]" >> /etc/init/${conffile}
echo "respwan" >> /etc/init/${conffile}
echo "exec /usr/local/sbin/keepalived --dont-fork" >> /etc/init/${conffile}

echo -e "\n Step 4. Setup Keepalived Configuration:"
#mkdir -p /etc/keepalived
echo "ip virtual:"
read ipv
echo "ip source:"
read ips
echo "ip peer:"
read ipr
cat << EOF > /etc/keepalived/keepalived.conf
vrrp_script haproxy-check {
    script "killall -0 haproxy"
    interval 2
    weight 20
}
 
vrrp_instance haproxy-vip {
    state BACKUP
    priority 101
    interface eth0
    virtual_router_id 47
    advert_int 3
 
    unicast_src_ip $ips 
    unicast_peer {
        $ipr 
    }
 
    virtual_ipaddress {
        $ipv 
    }
 
    track_script {
        haproxy-check weight 20
    }
}
EOF
systemctl start keepalived
