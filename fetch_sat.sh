#!/bin/bash


fetch_sat(){
    # fetches sat from ordinals.com
    # usage: fetch_sat <inscription_id>
    # example: fetch_sat 8ae1bcf23e58f88f895dab98fba21e7c66aa58858b4d14b2f848fb807c404cf9i0
    # returns: 0 if sat is found, 1 if not
    # output: sat value
    sat=$(curl -s https://ordinals.com/inscription/${inscription} | grep -oP '(?<=<a href=/sat/)[^"]+' | grep -o '[0-9]\{13\}' | uniq 2>/dev/null)
    inscription_id=$(curl -s https://ordinals.com/inscription/${inscription} | grep -o '<title>Inscription [0-9]\+</title>' | grep -o '[0-9]\+' 2>/dev/null)
}


tmp_file=tmp_sat_out.json
inscribe_log=inscribe_log.json
last_inscription=$(jq -r '.[] | .inscription' $inscribe_log | tail -1)

cp $inscribe_log inscribe_log.bak
rm $tmp_file 2>/dev/null

echo "[" > $tmp_file

for inscription in $(jq -r '.[] | .inscription' $inscribe_log); do
    fetch_sat $inscription
    filename=$(ls ./done/ | grep $inscription |  cut -d_ -f2)
    if [ -z "$filename" ]; then
        filename="unknown"
    fi

    if [ -z "$sat" ] && [ -z "$inscription_id" ]; then
        echo "inscription: $inscription - no value yet for sat and inscription_id - skipping"
        jq --arg inscription "$inscription" '.[] | select(.inscription == $inscription)' $inscribe_log >> $tmp_file
    else
        echo "inscription: $inscription - sat: $sat - inscription_id: $inscription_id "
        # if the keys exist they will not be overwritten
        jq --arg inscription "$inscription" --arg sat "$sat" --arg inscription_id "$inscription_id" --arg filename "$filename" \
            '.[] | select(.inscription == $inscription) | . + {sat: $sat, inscription_id: $inscription_id, filename: $filename}' $inscribe_log >> $tmp_file
    fi
    # Check if $inscription is equal to the last element in the loop
    if [ "$inscription" == "$last_inscription" ]; then
        echo "]" >> $tmp_file
        break
    else
        echo "," >> $tmp_file
        continue
    fi
 done

echo "$inscribe_log"
cat $inscribe_log | grep -wc "inscription"
cat $inscribe_log | grep -wc "sat"

echo "$tmp_file"
cat $tmp_file | grep -wc "inscription" 
cat $tmp_file | grep -wc "sat"

#de-duplicate values:
# jq '[.[] | group_by(.commit | map(add) | .[]]' $tmp_file > new_file.txt
jq --slurp '[.[] | group_by(.inscription) | map(reduce .[] as $item ({}; . * $item))]' $tmp_file | jq '.[0]' > new_file.txt

echo "new_file.txt"
cat new_file.txt | grep -wc "inscription"
cat new_file.txt | grep -wc "sat"

mv new_file.txt $inscribe_log


