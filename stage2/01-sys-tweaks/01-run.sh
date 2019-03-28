#!/bin/bash -e

install -m 755 files/resize2fs_once	"${ROOTFS_DIR}/etc/init.d/"

install -d				"${ROOTFS_DIR}/etc/systemd/system/rc-local.service.d"
install -m 644 files/ttyoutput.conf	"${ROOTFS_DIR}/etc/systemd/system/rc-local.service.d/"

install -m 644 files/50raspi		"${ROOTFS_DIR}/etc/apt/apt.conf.d/"

install -m 644 files/console-setup   	"${ROOTFS_DIR}/etc/default/"

install -m 755 files/rc.local		"${ROOTFS_DIR}/etc/"

on_chroot << EOF
systemctl disable hwclock.sh
systemctl disable nfs-common
systemctl disable rpcbind
systemctl enable ssh
systemctl enable regenerate_ssh_host_keys
EOF

if [ "${USE_QEMU}" = "1" ]; then
	echo "enter QEMU mode"
	install -m 644 files/90-qemu.rules "${ROOTFS_DIR}/etc/udev/rules.d/"
	on_chroot << EOF
systemctl disable resize2fs_once
EOF
	echo "leaving QEMU mode"
else
	on_chroot << EOF
systemctl enable resize2fs_once
EOF
fi

on_chroot <<EOF
for GRP in input spi i2c gpio; do
	groupadd -f -r "\$GRP"
done
for GRP in adm dialout cdrom audio users sudo video games plugdev input gpio spi i2c netdev; do
  adduser $FIRST_USER_NAME \$GRP
done
EOF

on_chroot << EOF
setupcon --force --save-only -v
EOF

on_chroot << EOF
usermod --pass='*' root
EOF

# now install everything for solarSENSE

cp -rf files/solarSENSE/ "${ROOTFS_DIR}/home/pi/"
chmod 755 "${ROOTFS_DIR}/home/pi/solarSENSE"

on_chroot << EOF
apt-get update -y
apt-get upgrade -y
apt-get install -y vim hostapd dnsmasq nginx python3 python3-dev python3-pip build-essential mongodb-server git bluetooth bluez mosquitto mosquitto-clients
pip3 install flask uwsgi flask_wtf pymongo flask_jsonpify flask-cors paho-mqtt colorama unidecode btlewrap sdnotify miflora configparser
python3 -m pip install pymongo==3.4.0
git clone https://github.com/ThomDietrich/miflora-mqtt-daemon.git /opt/miflora-mqtt-daemon
cd /home/pi/solarSENSE
git fetch
git pull
ex -s -c '19i|/home/pi/solarSENSE/setup hotspot webserver databases sensors' -c x /etc/rc.local
ex -s -c '19i|reboot' -c x /etc/rc.local
ex -s -c '19i|sed "19,21d" /etc/rc.local -i' -c x /etc/rc.local
ex -s -c '19i|/home/pi/solarSENSE/setup mongo' -c x /etc/rc.local
EOF

rm -f "${ROOTFS_DIR}/etc/ssh/"ssh_host_*_key*
