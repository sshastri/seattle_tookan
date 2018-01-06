# seattle_tookan

This script is to pull ticket data using Tookan API for Seattle Market

### Prerequisites:
- Requires that jq is installed
- A token.txt file exists in the same directory. (https://app.tookanapp.com/#/app/settings/apikey) 
  Menu -> Settings -> API Key -> "V2 API Keys"
- A user.txt file exists in the same directory (https://app.tookanapp.com/#/app/settings/teams)

### Setup
Before running the script, edit the "start_date" and "end_date" variables at the top of the
script for the dates you wish to pull

### Run
Run at the command line by
./seattle_tookan.sh 