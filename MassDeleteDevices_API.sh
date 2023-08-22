#!/bin/bash
#==============================================================================
#                           HEADER                                  
#==============================================================================
#- SYNOPSIS
#+      ${SCRIPT_NAME} [-hvt] [-u Username] [-p Password] [-j URL] [-s SerialNumbers] [-o /path/to/file.csv] ([-i /path/to/file.txt] or [-s SerialNumbers])
#-   
#- DESCRIPTION:
#-      This script will delete devices from a jamf environment via their serial numbers using the API and Bearer Token authentication. After inputting serial numbers, the script uses the given api details to find all the associated jamf id's to the serial numbers. It will then output the matching id's and serial numbers to a csv, then will either close, or delete them one by one, based on the test mode setting.
#-
#-      If any information needed to perform these tasks are missing from the given parameters, you will be asked to provide them individually before continuing.
#-
#- OPTIONS:
#-      -h
#-          Print this help
#-      -v
#-          Print script information
#-      -u Username
#-          Username for API user account
#-      -p Password
#-          Password for API user account
#-      -j URL
#-          URL for Jamf tenant. Ex: https://jamfURL.jamfcloud.com
#-      -s SerialNumbers
#-          List of serial numbers that are to be checked against, separated by a comma. Ex: SDFQWERVX12,QWERC1235,ZCK20DN12C,... Cannot be used alongside -s parameter
#-      -o /path/to/file.csv
#-          Path to output csv file. Defaults to /var/tmp/serialAndID.csv
#-      -i /path/to/file.txt
#-          Input txt file if wanting to import serial numbers via a txt file. Cannot be used alongside -s parameter. Separate serial numbers by line for best results.
#-      -t
#-          Indicates that the script is being ran in test mode, which will not delete any devices, just write the found data into the csv.
#-
#- EXAMPLES:
#-      ${SCRIPT_NAME} -u apiUser -p apiPass -j https://jamfURL.jamfcloud.com -s SDFQWERVX12
#-			Gain a bearer token using the apiUser credentials against the given Jamf URL, and get the id of the serial number given, if found, and output that to /var/tmp/serialAndID.csv.
#-		
#-
#==============================================================================
#% IMPLEMENTATION:
#%      Version                 ${SCRIPT_NAME} 1.0
#%      Author                  Eltord (https://github.com/Eltord)
#%      Original release date	8/7/23
#%      Current release date	8/9/23
#%
#==============================================================================
# HISTORY
#
#==============================================================================
# END OF HEADER
#==============================================================================
# VARIABLES REQUIRED FOR HEADER INFORMATION
SCRIPT_NAME="$(basename ${0})"
SCRIPT_HEADSIZE=$(grep -sn "^# END OF HEADER" ${0} | head -1 | cut -f1 -d:)

# FUNCTIONS FOR HELP AND VERSION PARAMETERS
usage() { 
    headText=$(head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#[+]" | sed -e "s/^#[+]//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" | sed -e 's/^[ \t]*//')
    underlinedHeadText=$(echo "$headText" | sed -E "s/(-[a-z]+) ([A-Za-z\/:/]+[A-Za-z.]+)/\1 $(tput smul)\2$(tput sgr0)/g")
    echo -e "Usage: $underlinedHeadText"
    exit 1
}

usagefull() { 
    headText=$(head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#[%+-]" | sed -e "s/^#[%+-]//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g")
    underlinedHeadText=$(echo "$headText" | sed -E "s/(-[a-z]+) ([A-Za-z\/:.]+[A-Za-z.]+)/\1 $(tput smul)\2$(tput sgr0)/g")
    echo -e "$underlinedHeadText"
    exit 1
}

scriptinfo() {
    headText=$(head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#%" | sed -e "s/^#%//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g")
    underlinedHeadText=$(echo "$headText" | sed -E "s/(-[a-z]+) ([A-Za-z\/:.]+[A-Za-z.]+)/\1 $(tput smul)\2$(tput sgr0)/g")
    echo -e "$underlinedHeadText"
    exit 1
}

#==========================
# Logging Setup
#==========================
scriptName="$(basename "$0")"

LOG_PATH="/private/var/log"
LOG_NAME="$scriptName.log"
LOG_FILE="$LOG_PATH/$LOG_NAME"

# $1 = Message to be added to log and/or echo'd out
# $2 = if set to 'noecho' then will not echo out message, otherwise will
# Ex = addlog "This is a message to echo"
# Ex = addlog "This is a message to not echo" noecho
addlog() {
    local message="$1"
    local timestamp="$(date "+%F %T")"
    echo "[$timestamp]: $message" >> "$LOG_FILE"
    
    if [ "$2" != "noecho" ]; then
        echo -e "$message\n"
    fi
}

#==========================
# Global Variables
#==========================

serials=""
testResponse=""
outputCSV="/var/tmp/serialAndID.csv"
idArray=()
serialArray=()

# Create an XSLT template for getting all serials and id's of devices
cat << EndOfXSLT > /tmp/getSpecificInfo.xslt
<?xml version="1.0" encoding="UTF-8"?> 
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"> 
<xsl:output method="text"/> 
<xsl:template match="/computers"> 
<xsl:for-each select="computer"> 
	<xsl:value-of select="serial_number"/> 
	<xsl:text>,</xsl:text> 
	<xsl:value-of select="id"/>  
	<xsl:text>&#xa;</xsl:text>
</xsl:for-each> 
</xsl:template> 
</xsl:stylesheet>
EndOfXSLT

#==========================
# PARSE OPTIONS WITH GETOPTS
#==========================
# ADD IN ALL ACCEPTABLE PARAMETER OPTIONS HERE
# Add a colon after a flag in order to accept the leading argument. 
optstring=":hvu:p:j:o:i:s:t"

while getopts ${optstring} arg
do
    case ${arg} in
    h)
        usagefull
        ;;
    v)
        scriptinfo
        ;;
    u)
		jUsername="${OPTARG}"
		;;
	p)
		jPassword="${OPTARG}"
		;;
	j)
        jUrl="${OPTARG}"
        ;;
	o)
		outputCSV="${OPTARG}"
		;;
	i)
		pathToFile="${OPTARG}"

		if [[ -f "$pathToFile" ]]
			then
				oldIFS=$IFS
				IFS=$' \t\n'

				while IFS= read -r serial
				do
					# Append the cleaned line to the serialArray
					serialArray+=("$serial")
				done < "$pathToFile"

				IFS=$oldIFS

				serials="notBlank"
		fi
		inputFlag=true
		;;
	s)
		serials="${OPTARG}"

		# trimming any spaces given in the serial numbers
		serialList=$(echo "$serials" | sed 's/ //g')

		# importing serial list into an array for later
		oldIFS=$IFS
		IFS=','
		read -r -a serialArray <<< "$serialList"
		IFS=$oldIFS

		serialsFlag=true
		;;
	t)
		test="y"
		;;
    ?)
        echo "Invalid option: -${OPTARG}."
        usage
        ;;
    esac
done

if [[ $inputFlag ]] && [[ $serialsFlag ]]
	then
		echo "Invalid options: the options -i and -s cannot be specified together."
		usage
		exit 1
fi

#==========================
# Token Block
#==========================
if [[ "$jUsername" = "" ]]
	then
		addlog "No username provided, requesting from user" noecho
		read -p "Enter API Username: " jUsername
fi

addlog "API Username: \"$jUsername\"" noecho

if [[ "$jPassword" = "" ]]
	then
		addlog "No password provided, requesting from user" noecho
		read -sp "Enter API Password: " jPassword
fi

echo ""

if [[ "$jUrl" = "" ]]
	then
		addlog "No URL provided, requesting from user" noecho
		read -p "Enter your Jamf Server URL (https://jamfURL.jamfcloud.com): " jUrl
fi

addlog "Jamf Tenant URL is: \"$jURL\"" noecho

jUrlResource="${jUrl}/JSSResource"
jURLToken="${jUrl}/api"

# Getting bearer token for api calls
wholeTokenResponse=$(curl -su "$jUsername:$jPassword" -H "Accept: application/json" -X POST "$jURLToken/v1/auth/token")
justTheToken=$(plutil -extract token raw -<<< $wholeTokenResponse)

if [[ "$justTheToken" == \<stdin\>* ]]
	then
		addlog "Credentials or URL were invalid, unable to get bearer token. Exiting script, please verify details before running again."
		exit 1
fi

#==========================
# Core Logic
#==========================
addlog "################# START SCRIPT ######################" noecho

# Checking if test mode is set or not by parameter. if not, asking user.
if [[ "$test" = "" ]]
	then
		addlog "Test mode parameter not provided, asking user if script is being ran in test mode" noecho
		read -p "Run this script in test mode? (y/n): " test
fi

addlog "Answer to test mode question is: \"$test\"" noecho

# Checking the test response if its yes or no
testResponse="$(echo $test | tr '[:upper:]' '[:lower:]')"
if [[  "$testResponse" = "y" ]] || [[ "$testResponse" = "yes" ]]
	then
		testResponse="true"
	elif [[ "$testResponse" = "n" ]] || [[ "$testResponse" = "no" ]]
		then
			testResponse="false"
	else
		testResponse="true"
fi

addlog "Test Response translated to: \"$testResponse\"" noecho

# If the output file exists, deleting it and adding titles to columns
if [[ -f "$outputCSV" ]]
	then
		addlog "Output file exists already at \"$outputCSV\". Removing it for new file to replace." noecho
		rm "$outputCSV"
		echo "Serial,ID" >> "$outputCSV"
fi

# Process curl output using that template
returnedData=$(curl -s -H "Authorization: Bearer $justTheToken" -H "Accept: text/xml" "$jUrlResource/computers/match/*" | xsltproc /tmp/getSpecificInfo.xslt -)

# For each serial number, check if an id was returned that matches against it from the curl data. if so, add it to array and output it to the outputCSV for verification.
for element in "${serialArray[@]}"
do

	id=$(echo "$returnedData" | grep "$element" | awk -F',' '{print $2}')
	
	if [[ "$id" = "" ]]
		then
			addlog "no ID found for serial number $element, Switching to testing mode to allow for corrections"
			testResponse="true"
			echo "$element,NOT_FOUND" >> "$outputCSV"
		else
			addlog "ID found for serial number $element, adding to ID Array for deletion and outputting match to $outputCSV" noecho
			idArray+=("$id")
			echo "$element,$id" >> "$outputCSV"
	fi
done

addlog "List of serial and matching jamf id's can be found at ${outputCSV}."

if [[ "$testResponse" != "true" ]]
	then
		# Test response is false, actually deleting devices after final confirmation
		read -p "Test response is n, type 'DELETE' to begin deleting devices. This cannot be reversed: " deleteResponse
		if [[ $deleteResponse != "DELETE" ]]
			then
				addlog "invalid response, quitting script to prevent accidental deletion of devices"
			else
				addlog "Provided devices will be deleted. Do not close this window until process is complete"
				for id in "${idArray[@]}"
					do
						addlog "Deleting device with ID: $id"
						curl -s -k -u "$jUsername:$jPassword" "$jUrlResource/computers/id/$id" -X DELETE >> "$LOG_FILE"
				done
		fi
	else
		addlog "Test mode is true, please verify output is what would be expected. Can rerun script and respond 'n' for test mode to perform deletion."
fi

addlog "################# END SCRIPT ######################" noecho
#==========================
# END OF SCRIPT
#==========================