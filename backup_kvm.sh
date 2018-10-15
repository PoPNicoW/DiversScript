#!/bin/bash

function post_to_slack () {
  # format message as a code block ```${msg}```
  SLACK_MESSAGE="\`\`\`$1\`\`\`"
  SLACK_URL=https://hooks.slack.com/services/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

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
      SLACK_ICON=':beers:'
      ;;
  esac

  curl -X POST --data "payload={\"text\": \"${SLACK_ICON} ${SLACK_MESSAGE}\"}" ${SLACK_URL}
}



#set echo off
post_to_slack "Debut de la sauvegarde" "INFO"

while read SERVER
        do
        echo -e "$SERVER"
        ssh -n $SERVER "virsh list --all | grep -o i-[0-999]*-[0-999]*-VM" > /home/script_backup/info/liste_VM/liste_VM_"$SERVER"
        while read line
                do
                echo -e "$line"
                ssh -n $SERVER "virsh dumpxml $line" > /home/script_backup/info/bck_xml/backup_"$line".xml
		post_to_slack "Dump XML de la VM $line sauvegardé"
                ssh -n $SERVER "virsh domblklist $line" | grep /mnt* > /home/script_backup/info/liste_disk/liste_disk_"$line".txt
        done < /home/script_backup/info/liste_VM/liste_VM_"$SERVER"
done < /home/script_backup/info/liste_SERVER.txt

while read SERVER
	do
	echo -e "$SERVER"
                if [ -s  /home/script_backup/info/liste_VM/liste_VM_"$SERVER" ]
                        then
                        while read lineVM
                                do
                                echo -e "$lineVM"
                                while read linedisk
                                        do
                                        echo -e "$linedisk"
                                        DISK=${linedisk::3}
                                        DiskPath=$(awk '{print $2}' /home/script_backup/info/liste_disk/liste_disk_"$lineVM".txt)
                                        awk '{print $2}' /home/script_backup/info/liste_disk/liste_disk_"$lineVM".txt > /home/script_backup/info/liste_disk/diskpath.txt
                                        Disk_ID=$(awk -F/ '{print $4}' /home/script_backup/info/liste_disk/diskpath.txt)
                                        sed -i 's/07cc8e4c-92e4-39ff-875a-15e05e524684/KVM_STR_SSD/g' /home/script_backup/info/liste_disk/diskpath.txt
                                        NewDiskPath=$(awk '{print $1}' /home/script_backup/info/liste_disk/diskpath.txt)
					post_to_slack "debut de la sauvegarde du disque $DISK de la VM  $lineVM" "INFO"
                                        ssh -n $SERVER "virsh snapshot-create-as --domain $lineVM --name backup_"$lineVM"_"$DISK".qcow2 --diskspec $DISK,snapshot=external --disk-only --atomic –-quiesce" 2> error.log

                                        if [ -s /home/script_backup/error.log ]
                                                then
							#echo "snapshot normal"
                                                        ssh -n $SERVER "virsh snapshot-create-as --domain $lineVM --name backup_"$lineVM"_"$DISK".qcow2 --diskspec $DISK,snapshot=external --disk-only --atomic"
                                                        borg create -v --stats /mnt/BACKUP::"$lineVM" $NewDiskPath >> /home/script_backup/info/backup.log 2>&1                                                          ssh -n $SERVER "virsh blockcommit $lineVM $DISK -–pivot --active"
                                                        rm /mnt/KVM_STR_SSD/"$Disk_ID".backup_"$lineVM"_"$DISK".qcow2
                                                        ssh -n $SERVER "virsh snapshot-delete $lineVM --metadata backup_"$lineVM"_"$DISK".qcow2"
						else	
							#echo "snapshot quiesce"
                                                        borg create -v --stats /mnt/BACKUP::"$lineVM" $NewDiskPath >> /home/script_backup/info/backup.log 2>&1
                                                        ssh -n $SERVER "virsh blockcommit $lineVM $DISK --pivot --active"
                                                        rm /mnt/KVM_STR_SSD/"$Disk_ID".backup_"$lineVM"_"$DISK".qcow2
                                                        ssh -n $SERVER "virsh snapshot-delete $lineVM --metadata backup_"$lineVM"_"$DISK".qcow2"
                                        fi
					rm /home/script_backup/error.log
					post_to_slack "Fin de la sauvegarde du disque $DISK de la VM  $lineVM"
                                done < /home/script_backup/info/liste_disk/liste_disk_"$lineVM".txt
                        done < /home/script_backup/info/liste_VM/liste_VM_"$SERVER"
                        else
                        post_to_slack "Rien a sauvegarde sur le serveur $SERVER"
                fi
done < /home/script_backup/info/liste_SERVER.txt
borg list /mnt/BACKUP >> /home/script_backup/info/backup_list.log 2>&1
post_to_slack "Fin de la sauvegarde"
#borg prune -v --list --keep-daily=7 /mnt/BACKUP
