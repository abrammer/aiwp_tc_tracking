year=$1
model=$2
version=${3:-100}
aname=${4:-$2}
icon=${5:-GFS}
grep " ${year}" files/vitals/syndat_tcvitals.${year} | grep -v " 8[0-9][A-Z]" > tmp.${year}
dates=()
while read line;
do 
	date="${line:19:8}${line:28:2}"
	if [[ "${date}" != "${dates[-1]}" ]] ; then
	    dates+=("${line:19:8}${line:28:2}");
        fi;
done < tmp.${year}

for date in "${dates[@]}";
do
	echo ${date};
	./run/run_cira_tracker.sh ${date} ${model} ${version} ${aname} ${icon}
	#if [ $? -ne 0 ];
	#then 
	#	break
	#fi
done
