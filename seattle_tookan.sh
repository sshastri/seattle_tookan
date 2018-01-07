#!/bin/bash
# Script to pull ticket data using Tookan API for Seattle Market
# 
# ./seattle_tookan.sh 
#

# Adjust start_date and end_date as needed here
# Format example: "2018-01-02"
start_date="2017-12-25"
end_date="2017-12-31"

# token.txt must exist that contains the api_key
# user.txt must exist that contains the userid
api_key=$(cat token.txt)
userid=$(cat user.txt)

# get_all_tasks
# Read the total_page data returned from the api call and 
# continue to request until all tasks are returned
# This generates a file job_ids.txt that contains a list of tasks 
# between the requested start and end date
get_all_tasks() {
  # Clean up previous run
  rm job_ids.txt
  
  requested_page=1
  total_page=1

  while ((requested_page <= total_page ))
  do
    echo "Requesting page $requested_page of tasks.."
    
# Payload Data 
payload=$(cat  << EOF
{
  "api_key": "$api_key",
  "job_status": [0,1,2,3,4,5,6,7,8,9],
  "job_type": [0,1,2,3],
  "start_date": "$start_date",
  "end_date": "$end_date",
  "is_pagination":1,
  "requested_page": $requested_page
}
EOF
)
    data=$(curl -H "Content-Type: application/json" \
    -X POST \
    -d "$payload" \
    https://api.tookanapp.com/v2/get_all_tasks)
    
    echo $data |  jq '.data[] | select (.fleet_name=="Seattle Proper") | .job_id' >> job_ids.txt
  
    total_page=$(echo $data | jq '.total_page_count')
    requested_page=$[$requested_page+1]
    
  done
}

# get_task_datails
# Take ids in job_ids.txt file and make a separate call to get details 
# for each task. Task details are stored in individual files "order-<ID>.txt"
get_task_details(){
  
  #Clean up previous run
  rm order-*.txt

  for id in `cat job_ids.txt` ; do

    echo 'Retrieving details for job id:' $id
  
    curl -H "Content-Type: application/json" \
    -X POST \
    -d '{"api_key":"'$api_key'","job_id":"'$id'","user_id": '$userid'}' \
    https://api.tookanapp.com/v2/get_task_details > "order-$id".txt
  
  done;
}

# process_tasks
# Parse each of the order-<id>.txt files for the relevant data
# and produce a .csv file called SeattleIssues
process_tasks() {

  filename=SeattleIssues"$start_date"to"$end_date".csv


  echo "Model of Bicycle,Who Initiated,Task#, Job Status, Fleet Name, Bicycle Plate Number, Time request made,	Time bike removed from service app,Time bike physically repaired or removed from street,	Issue Code,Issue Code Detail,Disposition" > $filename

  hard_coded="LB8,Customer"

  for file in `ls order-*` ; do
    #Grab the easy items from the JSON
    line=$(cat $file | jq '.data[] | [(.job_id|tostring), (.job_status|tostring),.fleet_name,.customer_username,.job_pickup_datetime,.job_pickup_datetime,.completed_datetime_local] | join(",")' | sed 's/^.\(.*\).$/\1/') 
    
   #Issues Processing
   issues_list=""
   total_issue=""
   issues_list=$(cat $file | jq -r '.data[] | .fields | .custom_field[] | select (.input ==true) | .label')
  
   for issue in `echo $issues_list` ; do
     total_issue=$(echo $issue,$total_issue)
   done;
   
   echo $hard_coded,$line,"$total_issue" >> $filename

  done;
}

get_all_tasks
get_task_details
process_tasks


