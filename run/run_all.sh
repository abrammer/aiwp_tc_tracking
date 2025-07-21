#!/usr/bin/env bash



script_dir=$(dirname $(readlink -fm $0))
echo ${script_dir};


rundate=$(date '+%Y%m%d')
curhour=$(date '+%H')
echo ${curhour}
if [[ ${curhour#0} -lt 12 ]]; then
	runhour='00'
else
	runhour='12'
fi

echo ${rundate}${runhour}
runcmd=${1:-${rundate}${runhour}}


${script_dir}/run_cira_tracker.sh $runcmd GRAP GFS &
${script_dir}/run_cira_tracker.sh $runcmd GRAP IFS &
${script_dir}/run_cira_tracker.sh $runcmd FOUR GFS 200 &
${script_dir}/run_cira_tracker.sh $runcmd FOUR IFS 200 &
${script_dir}/run_cira_tracker.sh $runcmd PANG GFS &
${script_dir}/run_cira_tracker.sh $runcmd PANG IFS &
${script_dir}/run_cira_tracker.sh $runcmd AURO GFS &
${script_dir}/run_cira_tracker.sh $runcmd AURO IFS &
wait


