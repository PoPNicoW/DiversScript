#!/bin/bash

function post_to_slack () {
  # format message as a code block ```${msg}```
  SLACK_MESSAGE="\`\`\`$1\`\`\`"
  SLACK_URL=https://hooks.slack.com/services/

  case "$2" in
    INFO)
      SLACK_ICON=':clipboard:'
      ;;
    WARNING)
      SLACK_ICON=':warning:'
      ;;
    ERROR)
      SLACK_ICON=':bangbang:'
      ;;
    *)
      #SLACK_ICON=':beers:'
      ;;
  esac

  curl -X POST --data "payload={\"text\": \"${SLACK_ICON} ${SLACK_MESSAGE}\"}" ${SLACK_URL}
}



#set echo off
DATE=$(date +%Y-%m-%d)
post_to_slack "Debut de la sauvegarde" "INFO"

while read SERVER
        do
        echo -e "$SERVER"
        ssh -n $SERVER "virsh list --all | grep -o i-[0-999]*-[0-999]*-VM" > /home/script_backup/info/liste_VM/liste_VM_"$SERVER"
        while read line
                do
                echo -e "$line"
		mkdir /mnt/mig-kvm/"$line"
                ssh -n $SERVER "virsh dumpxml $line" > /mnt/mig-kvm/"$line"/backup_"$line".xml
                post_to_slack "Dump XML de la VM $line sauvegardé"
                ssh -n $SERVER "virsh domblklist $line" | grep /mnt* > /home/script_backup/info/liste_disk/liste_disk_"$line".txt
        done < /home/script_backup/info/liste_VM/liste_VM_"$SERVER"
done < /home/script_backup/info/liste_SERVER.txt


while read SERVER
	do
	echo -e "$SERVER"
	while read lineVM
		do
		echo -e "$lineVM"
				#post_to_slack "$line en cours de sauvegarde"	
				ssh -n $SERVER "virsh qemu-monitor-command $lineVM --hmp "info block"" > /home/script_backup/info/info_block.txt
                                cat /home/script_backup/info/info_block.txt | grep "drive" > /home/script_backup/info/info_drive.txt
                                sed -i /inserted/d /home/script_backup/info/info_drive.txt
                                awk '{print $1}' /home/script_backup/info/info_drive.txt > /home/script_backup/info/info_drive_snap.txt
                                while read deviceVM
                                        do
                                        echo -e "$deviceVM"
					post_to_slack "$lineVM $deviceVM en cours de sauvegarde"
                                        #ssh -n $SERVER "virsh qemu-monitor-command $lineVM --hmp drive_backup -f $deviceVM /mnt/mig-kvm/"$lineVM"/backup_"$deviceVM".qcow2"
					ssh -n $SERVER "virsh qemu-monitor-command $lineVM \ '{\"execute\":\"drive-backup\",\"arguments\": {\"device\": \"$deviceVM\",\"sync\": \"full\", \"target\": \"/mnt/mig-kvm/"$lineVM"/backup_"$deviceVM".qcow2\" }}'"
                                done < /home/script_backup/info/info_drive_snap.txt
				(cd /mnt/mig-kvm/; borg create -v --stats /mnt/BACKUP::"$lineVM"_"$DATE" "$lineVM" >> /home/script_backup/info/backup.log 2>&1)
                                rm -rf /mnt/mig-kvm/"$lineVM"
                                rm -f /home/script-backup/info/info_block.txt
                                rm -f /home/script-backup/info/info_drive.txt
	done < /home/script_backup/info/liste_VM/liste_VM_"$SERVER"
done < /home/script_backup/info/liste_SERVER.txt

post_to_slack "Fin de la sauvegarde"
#borg prune --list --keep-daily=7 /mnt/BACKUP >> /home/script_backup/info/backup_list.log 2>&1
					
