#!/bin/bash

readarray -t keywords < keywords.txt
declare -a pidArray                        
declare -a processArray

rm -f temp.txt pid.csv
touch temp.txt pid.csv

function GetProcess (){
	server=$(hostname)
	date=$(date +%m-%d-%Y"="%H:%M:%S)

	for (( i=0; i<${#keywords[@]}; i++ ))
	do
		if [ -z "${keywords[$i]}" ]; then
			continue
		fi

		ps -e | grep java | grep -v grep |  awk '{print $1}' | while read PID
		do
			if grep -q "$PID" pid.csv; then
				continue
			else
				processName=$(ps -p "$PID" -o comm=)
				userName=$(ps -p "$PID" -o user= | tr -d '[:space:]')
				path=$(ps avwwwg | egrep "$PID" | grep -v grep | awk '{print $13}')
				counter=1
				commandLine=$(ps -p "$PID" -o args= | tr -d '[:space:]')
				condensedCommand=${commandLine:${#commandLine}<398?0:-398}
				FirstDiscovered="$date"
				LastDiscovered="$date"
				IFS='/' read -r -a pathArray <<< "$path"
			
				#### error handling - if any of the below fields are empty move on
				if [ -z "$processName" ] || [ -z "$userName" ] || [ -z "$path" ] || [ -z "$commandLine" ]; then
					printf '%s\n' "$server,$processName,$user,$path,$commandLine,$date" >> error.txt
					continue
				fi 
	
				version=$("$path" -version 2>&1 | head -1 | cut -d '"' -f 2)

				### error handling - in case version does not show up, we set version to none 
				if echo "$version" | egrep -q "(No|Error|Such|File|Directory)" || [ -z "$path" ];then
					version='NONE'
				fi
				
				if egrep -q "$commandLine" temp.txt; then
					echo "$(awk -v process="$processName" -v user="$user" -v path="$path" -v commandLine="$condensedCommand" 'BEGIN{FS=OFS=";"}{if($1==process && $2==user && $3==path && $$NF ~ commandLine) $6+=1}1' temp.txt)" > temp.txt
				else
					printf "%s\n" "$server;$processName;$userName;$path;$version;$counter;$FirstDiscovered;$LastDiscovered;$commandLine" >> temp.txt
				fi

				printf '%s\n' "$PID" >> pid.csv 
			fi
		done 
	done
	readarray -t processArray < temp.txt
} 

function CreateFile () {
	echo "Server;ProcessName;UserName;Path;Version;Counter;FirstDiscovered;LastDiscovered;CommandLine" > java_process.txt
	printf "%s\n" "${processArray[@]}" >> java_process.txt
}

function ModifyFile () {
	date=$(date +%m-%d-%Y"="%H:%M:%S)
	for (( j=0; j<${#processArray[@]}; j++ ))
	do
		### All of these variables need to match in order for the last discovered date to update 
		checkCommand=($(printf "%s\n" "${processArray[$j]}" | awk 'BEGIN{FS=";"} {print $NF}' | tr -d '[:space:]' ))
		checkProcess=($(printf "%s\n" "${processArray[$j]}" | awk 'BEGIN{FS=";"} {print $2}' | tr -d '\n' ))
		checkUser=($(printf "%s\n" "${processArray[$j]}" | awk 'BEGIN{FS=";"} {print $3}' | tr -d '\n' ))
		checkPath=($(printf "%s\n" "${processArray[$j]}" | awk 'BEGIN{FS=";"} {print $4}' | tr -d '\n' ))
		checkFirstDis=($(printf "%s\n" "${processArray[$j]}" | awk 'BEGIN{FS=";"} {print $7}' | tr -d '\n' ))
		condensed=${checkCommand:${#checkCommand}<398?0:-398} # Pick the last 400 characters due to AIX char limit
		
		if egrep -q "$checkCommand" java_process.txt; then
			runningCounter=($(awk -v commandLine="$condensed" 'BEGIN{FS=OFS=";"}{if($NF ~ commandLine) {print $6}}' temp.txt))
			echo "Found and counter: " "$runningCounter"	

			counter=$(echo "$runningCounter" | tr -d '\n')
			echo "New: " "$counter"	

			echo "$(awk -v c="$condense" -v p="$checkPath" -v u="$checkUser" -v proc="$checkProcess" -v d="$date" -v f="$checkFirstDis" -v count="$counter" 'BEGIN{FS=OFS=";"}{if($NF ~ /c/ && $2==proc && $3==u && $4==p && $7==f){$6+=count; $8=d}}1' java_process.txt)" > java_process.txt
		else
			printf "%s\n" "${processArray[$j]}" >> java_process.txt
		fi
	done 
}

GetProcess 
if [ ! -f java_process.txt ];then
	echo "Creating file"
	CreateFile
elif [ -f java_process.txt ]; then
	echo "Modifiying file"
	ModifyFile
fi
rm temp.txt pid.csv
