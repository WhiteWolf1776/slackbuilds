#/bin/bash
cd /home/ftp/pub/Linux/Slackware/Multilib/current
upgradepkg --reinstall --install-new *.t?z
upgradepkg --install-new slackware64-compat32/*-compat32/*.t?z
