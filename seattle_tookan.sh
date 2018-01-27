#!/bin/bash
# Script to pull ticket data using Tookan API for Seattle Market
#
# ./seattle_tookan.sh
#

echo 'Hi Jason. Heres a cool script so you dont have to stare at Tookan all night :) CTRL-C will exit this script'

echo "Enter the start date in the format YYYY-MM-DD and press ENTER:"
read start_date
while [[ ! $start_date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]];
do
  echo "Invalid Start Date. Use format YYYY-MM-DD. Ex: 2018-01-01"
  read start_date
done

echo "Enter the end date in the format YYYY-MM-DD and press ENTER:"
read end_date
while [[ ! $end_date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]];
do
  echo "Invalid End Date. Use format YYYY-MM-DD. Ex: 2018-01-01"
  read end_date
done

echo "Which market? Select a number and press ENTER:"
echo "   [1] Seattle North, Seattle South"
echo "   [2] DC Inner 1, DC Outer1, DC Inner2"
echo "   [3] SS Inner, SS Outer"
read market
while [[ ! $market =~ ^[1-3] ]];
do
  echo "Invalid market. Choose value 1-3. Try again"
  read market
done

case "$market" in
  1) declare -a market=("Seattle North" "Seattle South ")
     title="Seattle"
  ;;
  2) declare -a market=("DC Inner 1" "DC Outer 1" "DC Inner2")
     title="DC"
  ;;
  3) declare -a market=("SS Inner" "SS Outer")
    title="SilverSprings"
  ;;
esac


# Forced Values
# Format example: "2018-01-02"
#start_date="2018-01-07"
#end_date="2018-01-08"
#declare -a market=("Seattle North" "Seattle South ")

echo "Pulling report for ${market[@]} from $start_date to $end_date"


# token.txt must exist that contains the api_key
# user.txt must exist that contains the userid
api_key=$(cat token.txt)
userid=$(cat user.txt)

# get_all_tasks
# This generates a file job_ids.txt that contains a list of tasks
# between the requested start and end date
# Read the total_page data returned from the api call and
# continue to request until all tasks are returned
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
  "job_status": [0,1,2,3,4,5,6,7,8,9,10],
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

  #Loop through each market value
  for val in "${market[@]}"
  do
    #echo $val
    #echo $data |  jq --arg m "$val" '.data[] | select (.fleet_name == $m)| .job_id'
    echo $data |  jq --arg m "$val" '.data[] | select (.fleet_name == $m)| .job_id' >> job_ids.txt
  done

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

  filename="${title}Issues${start_date}to${end_date}.csv"

  #Header
  echo "Task#,Model of Bicycle,Who Initiated,Job Status,Fleet Name, Bicycle Plate Number,Time request made,Time bike removed from service app,Time bike physically repaired or removed from street,Issue Code,Issue Code Detail,Disposition,Job Description" > $filename

  for file in `ls order-*` ; do

    #Grab data from JSON file and create a JSON object
    data=$(jq '.data[] | { jobid: .job_id, status: .job_status, description: .job_description, fleet_name: .fleet_name, customer_username: .customer_username, completed_time: .completed_datetime_local, task_history: .task_history, issues: .fields.custom_field }' $file)

    model="LB8"
    initiated="Customer"
    job_id=$(echo $data | jq '.jobid')
    fleet_name=$(echo $data | jq '.fleet_name')
    plate_number=$(echo $data | jq '.customer_username')
    completed_time=$(echo $data | jq '.completed_time')
    job_statusnum=$(echo $data | jq '.status')

    #Remove commas from description
    job_description=$(echo $data | jq '.description' | sed 's/,//g')

    #Job Status - Translate number
    job_status=$(case "$job_statusnum" in
      (0) echo 'Assigned' ;;
      (1) echo 'Started' ;;
      (2) echo 'Successful' ;;
      (3) echo 'Failed' ;;
      (4) echo 'In Progress' ;;
      (6) echo 'Unassigned' ;;
      (7) echo 'Accepted' ;;
      (8) echo 'Declined' ;;
      (9) echo 'Cancel' ;;
      (10) echo 'Deleted' ;;
      (*) echo 'Unknown' ;;
    esac)

    #Job Creation Date - ASSUMING FIRST VALUE IN TASK HISTORY ARRAY IS CREATION
    #This is ugly.. but dates ugh.
    # Example: "2018-01-07T05:59:43.000Z"
    # 1. remove the T, .000Z and quotes
    # 2. convert to UTC epoch seconds
    # 3. convert epoch seconds to local time
    gmt_date=$(echo $data | jq '.task_history[0] | .creation_datetime' | sed 's/T/ /g' | sed 's/.000Z//g' | sed 's/^.\(.*\).$/\1/')

    epoch_time=$(date -j -u -f "%Y-%m-%d %H:%M:%S" "$gmt_date" +%s)
    creation_date=$(date -r $epoch_time '+%m/%d/%Y %H:%M:%S')

    #Notes
    notes=$(echo $data | jq '.task_history[] | select (.reason != null) | .reason ')

    #Issues Processing
   issues_list=$(echo $data | jq -r '.issues[] | select (.input ==true) | .label')

    echo $job_id,$model,$initiated,$job_status,$fleet_name,$plate_number,$creation_date,$creation_date,$completed_time,$issues_list,$notes,"",$job_description >> $filename

  done;
}

get_all_tasks
get_task_details
process_tasks
