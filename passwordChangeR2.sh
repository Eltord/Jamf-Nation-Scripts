#!/bin/sh

# Title: passwordChange2
# Current Version: 1.2
# Author Dan Shelton
# Last Editor If not Author:  
# Original Release Date     - 06-24-2019
# Current Release Date      - 05-23-2019
# Description:  Script can be triggered by EC or Kerberos Extension via that tools own functions, then can clear out any keychain items you define down in core logic.

######## LOGGING SETUP ########

#get logged in username
user=$(python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')
if [[ $user != "" ]]; then
    uid=$(id -u "$user")
fi

#create log path
LOG_PATH="/Users/$user/Library/Logs"
LOG_NAME="passwordChangeR2.sh.log"
LOG_FILE="$LOG_PATH/$LOG_NAME"


#check if log exists, then create if not already
if [ ! -f "$LOG_FILE" ]
    then
        sudo touch $LOG_FILE
        addlog "$LOG_FILE successfully created"
    else
        addlog "$LOG_FILE already exists, moving on to next steps"
fi

#function for logging
addlog () {
    echo "[$(date "+%F %T")]: " $1 >> ${LOG_FILE}
}

######## GLOBAL VARIABLES #######

#Define the login keychain into userKeychain variable
if [ -e /Users/$user/Library/Keychains/login.keychain-db ]
    then
	    userKeychain=/Users/$user/Library/Keychains/login.keychain-db
    else
	    userKeychain=/Users/$user/Library/Keychains/login.keychain
fi

######## PASSWORD DELETION FUNCTIONS DEFINITIONS ########


# Function to delete generic passwords in login keychain
genericPassRemove () {
    addlog "-------------New Generic Password Removal-----------"
    if /usr/bin/security find-generic-password -l "$1" $userKeychain
        then
            genericPasswordClearStatus=0
            until (( $genericPasswordClearStatus == 1 ))
                do
                    addlog "Looking for existing entry for $1 password..."
                    if /usr/bin/security find-generic-password -l "$1" $userKeychain
                        then
                            addlog "Found an existing password in user keychain for $1. Attempting to delete..."
                            /usr/bin/security delete-generic-password -l "$1" $userKeychain
                                if (( $? == 0 ))
                                    then
                                        addlog "$1 password deleted"
                                fi
                        else
                            addlog "Did NOT find any more passwords in user keychain for $1"
                            genericPasswordClearStatus=1
                    fi
                done
        else
            addlog "Did not find a saved password for $1 in $userKeychain"
    fi
}

# Function to delete internet passwords in login keychain
internetPassRemove () {
    addlog "-------------New Internet Password Removal-----------"
    if /usr/bin/security find-internet-password -l "$1" $userKeychain
        then
            internetPasswordClearStatus=0
            until (( $internetPasswordClearStatus == 1 ))
                do
                    addlog "Looking for existing entry for $1 password..."
                    if /usr/bin/security find-internet-password -l "$1" $userKeychain
                        then
                            addlog "Found an existing password in user keychain for $1. Attempting to delete..."
                            /usr/bin/security delete-internet-password -l "$1" $userKeychain
                                if (( $? == 0 ))
                                    then
                                        addlog "$1 password deleted"
                                fi
                        else
                            addlog "Did NOT find any more passwords in user keychain for $1"
                            internetPasswordClearStatus=1
                    fi
                done
        else
            addlog "Did not find a saved password for $1 in $userKeychain"
    fi
}

# Function to delete saved wireless SSID's in the login keychain
peapPassRemove () {
    addlog "-------------New Saved Wireless Network Removal-----------"
    if /usr/bin/security find-generic-password -s "com.apple.network.eap.user.item.wlan.ssid.$1" $userKeychain
	    then
		    peapPasswordClearStatus=0
		    until (( $peapPasswordClearStatus == 1 ))
			    do
				    addlog "Looking for existing entries for $1 password..."
				    if /usr/bin/security find-generic-password -s "com.apple.network.eap.user.item.wlan.ssid.$1" $userKeychain
					    then
						    addlog "Found an existing password in user keychain for $1.  Attempting to delete..."
						    /usr/bin/security delete-generic-password -s "com.apple.network.eap.user.item.wlan.ssid.$1"
							    if (( $? == 0 ))
								    then 
									    addlog "SSID password for $1 deleted"
							    fi
					    else
						    addlog "Did NOT find any more passwords in user keychain for SSID $1."
                            peapPasswordClearStatus=1
				    fi
			    done
	    else 
		    addlog "Did not find a saved password for $1"
    fi
}

checkCreate() {
    if [ ! -f "$1" ]
        then
            sudo touch $1
            addlog "$1 successfully created"
        else
            addlog "$1 already exists, moving on to next steps"
    fi
}

######## CALLING THE FUNCTIONS ########

addlog "------Starting to go through and delete keychains------"

#examples of how to call functions
#EX: function-name-for-type-of-keychain-entry "Name-of-keychain-entry"
genericPassRemove "Skype for Business"

internetPassRemove "Microsoft Office Credentials "

peapPassRemove "wirelessSSID"

#display message to users saying password update process is complete.
/usr/bin/osascript -e 'display dialog "Password update process is complete." buttons {"Ok"} default button 1'

addlog "-----Finishing off going through keychains-----"

######## END OF SCRIPT ########