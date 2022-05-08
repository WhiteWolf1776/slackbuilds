#/bin/bash
cd /home/ftp/pub;
./mirror-slackware-current.sh;
ARCH="x86_64" ./mirror-slackware-current.sh;
./mirror-multilib.sh;
