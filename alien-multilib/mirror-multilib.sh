#/bin/bash
cd /home/ftp/pub/Linux/Slackware/Multilib
lftp -c 'open http://slackware.com/~alien/multilib/ ; mirror -c -e current'
