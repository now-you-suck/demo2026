#!/bin/bash

csv_file="$1"
#Create OU
awk -F ';' 'NR>1 {print $5}' "$csv_file" | sort | uniq | while read ou;
do
      samba-tool ou add OU="$ou",DC=au-team,DC=irpo;
done

#Create Users
while IFS=";" read -r firstName lastName role phone ou street zip city country password; 
do
      if [ "$firstName" == "First Name" ];
      then
          continue
      fi

      username="${firstName,,}.${lastName,,}"
      address='${zip,,}.${country,,}.${city,,}.${street,,}'
     
      samba-tool user add "$username" "$password" \
          --given-name="$firstName" \
          --surname="$lastName" \
          --telephone-number="$phone" \
          --job-title="$role" \
          --userou="OU=$ou" \
          --physical-delivery-office="$address"
      samba-tool user setexpiry "$username" --noexpiry
done < "$csv_file"
