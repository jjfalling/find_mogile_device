#!/usr/bin/env bash

#****************************************************************************
#*   Find Mogile Device                                                     *
#*   Find what drive is what port or device on a mogile storage server.     *
#*                                                                          *
#*   Copyright (C) 2013 by Jeremy Falling except where noted.               *
#*                                                                          *
#*   This program is free software: you can redistribute it and/or modify   *
#*   it under the terms of the GNU General Public License as published by   *
#*   the Free Software Foundation, either version 3 of the License, or      *
#*   (at your option) any later version.                                    *
#*                                                                          *
#*   This program is distributed in the hope that it will be useful,        *
#*   but WITHOUT ANY WARRANTY; without even the implied warranty of         *
#*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          *
#*   GNU General Public License for more details.                           *
#*                                                                          *
#*   You should have received a copy of the GNU General Public License      *
#*   along with this program.  If not, see <http://www.gnu.org/licenses/>.  *
#****************************************************************************


##################
#DEFINE FUNCTIONS#
##################

#help/usage message
usage()
	{
	cat << usageEOF
	
	usage: $0 options
	Example usage: $0 -c 0 -p 25  *OR*  $0 -d sdg *OR* $0 -m dev201
	
	This script will attempt to find what 3ware port is associated to a linux device/mogile device. Or vica versa.
	
	
	OPTIONS:
	-h      Show this message
	-p      3ware port number (ex 23). Must specify -c
	-c      3ware card number (ex 0).  Must specify -p
	-d      Linux device (ex sdf). 
	-m      Mogile device (ex dev201).
	
	You cannot use [ p, c] and d or m together.
	
usageEOF
}
#end help 



##### DEVICE TO PORT CONVERSION
deviceFunction()
{
	#look at /sys/block to find the device the user asked for and find its id
	output=`ls -alh /sys/block/ | grep $DEVICE | grep -o -E [[:digit:]]+:[[:digit:]]+:[[:digit:]]+:[[:digit:]]+`
	
	#check to see if drive exists, if not, exit
	if [ $? != 0 ]; then echo -e "ERROR: drive not found...\n";exit;fi;
	
	#break apart the data to use below
	card=`echo $output | awk -F":" '{print $1}'`
	enc=`echo $output | awk -F":" '{print $2}'`
	unit=`echo $output | awk -F":" '{print $3}'`
	unknown=`echo $output | awk -F":" '{print $4}'`
	
	#find the port number using tw_cli
	portnum=`tw_cli /c$card/u$unit show all |grep -o -E p[[:digit:]]+`
	portnum=`echo $portnum | tr "\n" " "`
	
	#check to see if multiple drives have been found
	drivecheck=`echo $portnum |wc -w`
	
	#give output
	echo -ne "Looks like $DEVICE is on: "
	echo -e "Card: $card | Enclosure: $enc | Unit: $unit | ??: $unknown"
	
	#check if more then one port was found
	if [ $drivecheck == 1 ]
	then
		echo -e "Note: unit is raid unit, not port. The port on card $card is more then likely: $portnum\n"
	else
		echo -e "Note: unit is raid unit, not port. *MORE THEN ONE PORT FOUND* The ports on card $card are more then likely: $portnum\n"
	fi
}
##### END DEVICE TO PORT CONVERSION

##### PORT TO DEVICE CONVERSION
portFunction()
{

#find unit number from tw_cli
unitNumber=`tw_cli /c$CARD/p$PORT show | grep -o -E u[[:digit:]]+ | grep -o -E [[:digit:]]+`

#check to see if drive exists, if not, exit
if [ $? != 0 ]; then echo -e "ERROR: card/port not found...\n";exit;fi;

#use unit number with existing card number
linuxDevice=`ls -alh /sys/block/ | grep -E  $CARD:[[:digit:]]+:$unitNumber:[[:digit:]]+ |grep -m 1 -o sd[[:alpha:]]`

#check to see if drive exists, if not, exit
if [ $? != 0 ]; then echo -e "ERROR: could not find card/unit in /sys/block. Is it mounted?\n";exit;fi;

devCount=`echo $linuxDevice | wc -w`
newLinuxDevice=`echo $linuxDevice | awk -F" " '{print $1}'`
MOGDEV=`mount |grep $newLinuxDevice |grep -E -o dev[[:digit:]]++`

#we expect sdv -> ../devices/pci0000:00/0000:00:01.0/0000:01:00.0/host0/target0:0:21/0:0:21:0/block/sdv 
# as a grep result, so if the device name was not found twice, there might be an issue.
if [ $devCount != 2 ]
then
	echo -e "WARNING: I expected to find $newLinuxDevice twice in /sys/block, and I found it $devCount times."
	echo -e "This could mean there is something funny going on....\n"
	echo -e "Otherwise, The linux device on port $PORT on card $CARD is *MIGHT* be: $newLinuxDevice \nMogile device $MOGDEV \n"
	exit 1
	

else

	echo -e "The device on port $PORT on card $CARD is more then likely: $newLinuxDevice \nMogile device $MOGDEV \n"
	
fi 
}
##### END PORT TO DEVICE CONVERSION

##### START MOGDEV TO DEVICE CONVERSION
mogdevFunction()
{
	DEVICE=`mount |grep $MOGDEV |grep -m 1 -o sd[[:alpha:]]`
	
	#check if dev was found
	if [  $?  != 0 ]; then echo -e "ERROR: mogile device not found...\n";exit;fi;
	
	echo -e "Looks like $MOGDEV is $DEVICE \n"
}

##### END MOGDEV TO DEVICE CONVERSION


##### START HOSTNAME CHECK
checkHostnameFunction()
{
	#check if hostname contains mog
	hname=`hostname | grep mog`
	
	#if not, give error
	if [  $?  != 0 ]; then echo -e "\n\nWARNING: this host appears to not be a mogile server!\nThis was designed to only look for mogile storage drives!!!\n";fi;
}

##### END HOSTNAME CHECK

#end functions 



PORT=
CARD=
DEVICE=
MOGDEV=

#getops stuff
while getopts “ht:p:c:d:m:” OPTION
do
      case $OPTION in
          h)
              usage
              exit 1
              ;;
          p)
              PORT=$OPTARG
              ;;
          c)
              CARD=$OPTARG
              ;;
          d)
              DEVICE=$OPTARG
              ;;
          m)
              MOGDEV=$OPTARG
              ;;
          ?)
              usage
              exit 1
              ;;
      esac
done


#if port and card were given
if [[ -n $PORT && -n $CARD ]]
then 

	#check for device flag w/ c or p
	if [[ -n $DEVICE ]]
	then 
		#it exits, bail the hell out
		echo -e "\n***ERROR: You cannot use -d with -p or -c \n"
		usage
		exit 1
	#check for mogdev flag w/ c or p
	elif [[ -n $MOGDEV ]]
	then
		#it exits, bail the hell out
		echo -e "\n***ERROR: You cannot use -m with -p or -c \n"
		usage
		exit 1
	else
		#device flag not given, run port function
		echo -e "\nTrying to convert 3ware card/port number to linux device. Please wait....\n"
		checkHostnameFunction
		portFunction
	fi

#neither port or card flag exist, check for device
elif  [[ -n $PORT || -n $CARD ]]
then
	echo -e "\n***ERROR: you must use -p and -c together. \n"
	usage
	exit 1


#neither port or card flag exist, check for device
elif  [[ -n $DEVICE ]] 
then
	#check if mogdev flag was used
	if [[ -n $MOGDEV ]]
	then
		#was used, bail
		echo -e "\n***ERROR: you cannot use -d and -m together. \n"
		usage
		exit 1
		
	#was mogdev flag was not given, continue		
	else
		#since device flag was given, run device function
		echo -e "\nTrying to convert linux device to 3ware card/port number. Please wait....\n"
		checkHostnameFunction
		deviceFunction
	fi

elif  [[ -n $MOGDEV ]] 
then

	#since mogile flag was given, run device function
	echo -e "\nTrying to convert mogile device to 3ware card/port number. Please wait....\n"
	checkHostnameFunction
	#run mogdev to convert to a linux device, then devicefunction to do the rest of the work
	mogdevFunction
	deviceFunction
	
#no valid usage found, give usage
else
	usage
	exit 1

fi


exit 0


