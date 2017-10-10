#!/bin/bash

##
## Export worktimes for given users and push them to Kätkölä
##

function putti {

    username=$1
    localfile=/tmp/$username.worktime.$(date +%Y%m%d)
    remotefile=/public_html/worktime/$username.worktime.$(date +%Y%m%d)

    perl scripts/getWorkTime.pl -y $(date +%Y) -t ods -u $username -f $localfile

    sftp katkola <<EOF
    put $localfile.ods $remotefile.ods
EOF

}

putti kivilahtio
putti jraisa
putti janPasi
putti taskula
putti sundahl

