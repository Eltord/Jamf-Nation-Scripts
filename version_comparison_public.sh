#!/bin/bash

# Title: Next_OS_Readiness.sh
# Current Version: 1.0
# Author Dan Shelton
# Last Editor If not Author:
# Original Release Date     - 12-20-2019
# Current Release Date      - 12-20-2019
# Discription:  Verifies installed version of app is greater than the given minimum version number.
#               The called function will return true if the installed app's version number is higher
#               or equal to the minimum version being provided here. Then we check to see if all the apps
#               that are being targeted return true or not, and exit/return with a true if all return
#               true or exit/return false if all return false.


# VARIABLE DEFINITIONS
# ACTIVE_VER = current version number of the installed application
# TARGET_VER = minimum version number that the application has to meet for verification to be true
# TARGET_POSITION_COUNT = How many segmented by "." positions the targeted application has in its version number

######## LOGGING SETUP ########

# Change this variable to the OS name this script is checking for
os_version="Catalina"

LOG_FILE=/private/var/log/${os_version}_OS_Readiness.sh.log

#Checks if log file exists. If does, deletes it so it can be recreated fresh. This type of function does not really
#require a historical log.
if [ -f "$LOG_FILE" ]
then
    rm $LOG_FILE
fi

log () {
    echo "[$(date "+%F %T")]: " $1 >> ${LOG_FILE}
}

######## FUNCTIONS ########

# Call this function to compare two separate version numbers.
# Usage: compareVersions "ACTIVE_VER" "TARGET_VER" "TARGET_POSITION_COUNT"
# Return: TRUE or FALSE
compareVersions() {
    
    #initiate named variables from passed.
    ACTIVE_VER="$1"
    TARGET_VER="$2"
    TARGET_POSITION_COUNT="$3"
    
    #initiating "i" variable
    i=0
    
    #initiating the target and active arrays for the loop
    targetArray=($(echo $TARGET_VER | tr "." "\n"))
    activeArray=($(echo $ACTIVE_VER | tr "." "\n"))
    
    log "###Beginning comparison loop###"
    
    # loop through each segment (array item) and compare on each separately.
    while [ $i -le $(($TARGET_POSITION_COUNT-1)) ]
    do
        log "Target array value is: ${targetArray[$i]}"
        log "Active array value is: ${activeArray[$i]}"
        
        #casting array value into integer
        targetNum=$((${targetArray[$i]}+0))
        activeNum=$((${activeArray[$i]}+0))
        
        # if active array value is not equal to the targeted array value, check if its greater than or less than and
        # then return a true/false value accordingly
        if [ $activeNum != $targetNum ]
        then
            log "$activeNum is not equal to $targetNum, checking if less or greater than"
            if [ $activeNum -gt $targetNum ]
            then
                log "$activeNum is greater than $targetNum, returning TRUE"
                return_value="TRUE"
            elif [ $activeNum -lt $targetNum ]
            then
                log "$activeNum is less than $targetNum, returning FALSE"
                return_value="FALSE"
            fi
        else
            # numbers are equal, so minimum value of this segment is being met, moving onto next segment.
            log "$activeNum is equal to $targetNum, moving onto next number"
        fi
        
        # Check to see if there is a returned value now from the previous if statement. If not, adds 1 to i and checks if
        # i equals the positions count now. If they do, logic has determined that all segmented numbers are equal, meaning
        # minimum has been met, so ending the loop with a true value to return. Otherwise, ending the loop with the already
        # passed return value.
        if [ -z $return_value ]
        then
            ((i++))
            if [ $i -eq $TARGET_POSITION_COUNT ]
            then
                log "$i is the same as $TARGET_POSITION_COUNT, ran out of numbers to check so they are all equal, returning TRUE"
                return_value="TRUE"
            fi
        else
            log "a return value was passed, matching $i to $TARGET_POSITION_COUNT to break the loop"
            i=$TARGET_POSITION_COUNT
        fi
    done
    
    log "###Ending Loop###"
    
    #ending function by returning the return value from previous loop.
    log "Return value is: $return_value"
    echo $return_value
}

######## CORE LOGIC ########

log "########## Start of Script ##########"

# TEMPLATE FOR APP COMPARISON
# Replace blanks with app shorthand name
# __AppName="__.app" Ex: chromeAppName
# __ActiveVer=$(defaults read /Applications"${__AppName}"/Contents/Info.plist CFBundleShortVersionString) NOTE: replace CFBundleShortVersionString with CFBundleVersion for some apps
# __TargetVer="minimum_version_number_you_want_to_check_against" Ex: chromeTargetVer="78.0.3904.97"
# __TargetPositionCount="amount_of_segments_in_target_ver_number" Ex: chromeTargetPositionCount="4"
# __Comparison=$(compareVersions "$__ActiveVer" "$__TargetVer" "$__TargetPositionCount")

# Comparing Chrome
chromeAppName="Google Chrome.app"
chromeActiveVer=$(defaults read /Applications/"${chromeAppName}"/Contents/Info.plist CFBundleShortVersionString)
chromeTargetVer="79.0.3945.88"
chromeTargetPositionCount="4"
log "Attempting comparison of $chromeAppName active version $chromeActiveVer to the minimum target version of $chromeTargetVer"
chromeComparison=$(compareVersions "$chromeActiveVer" "$chromeTargetVer" "$chromeTargetPositionCount")

# Comparing Slack
slackAppName="Slack.app"
slackActiveVer=$(defaults read /Applications"${slackAppName}"/Contents/Info.plist CFBundleShortVersionString)
slackTargetVer="4.2.0"
slackTargetPositionCount="3"
slackComparison=$(compareVersions "$slackActiveVer" "$slackTargetVer" "$slackTargetPositionCount")


# Tests all the returns for the apps checked earlier to see if all returned true. Add the __comparison variables here if you create more.
if [ "$chromeComparison" = "TRUE" ] && [ "$slackComparison" = "TRUE" ]
then
    # If all comparisons return TRUE, return true to EA.
    log "All comparison tests returned true, echoing true for EA"
    echo "<result>TRUE</result>"
else
    # If any comparison does not return TRUE, return false to EA.
    log "One or more comparisons failed or returned false, echoing false for EA"
    echo "<result>FALSE</result>"
fi

log "########## End of Script ##########"