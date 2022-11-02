#!/bin/bash
#
# Version 1.1
# NAME
#       sp-sync - AWS Profile Synchronization Tool
#
# SYNOPSIS
#       sp-sync CMD
#       sp-sync sso
#       sp-sync org
#
# where CMD is one of the following:
#
#       sso   - To sync profile using Single Sign On.
#       org   - To Sync profile using Organization.
#
# DESCRIPTION
#       This tool is used to Synchronize AWS Profile.
#


#PATH=/usr/bin:/bin:/usr/sbin:/sbin

##### Variable Declaration Area #####
### User Defined Variables ###
START_URL="https://start-url.awsapps.com/start#/";
#START_URL="https://[start-url].awsapps.com/start#/";
REGION="us-east-1";

### AWS Profile Location Related Variables ###
AWS_PROFILE_DIR=${HOME}/.aws
PROFILEFILE="${AWS_PROFILE_DIR}/config"
CONNECTIONFILE_DIR="$HOME/.steampipe/config"
CONNECTIONFILE="${CONNECTIONFILE_DIR}/aws.spc"
IGNORE_FILE="${HOME}/.aws/.ignore"
profilefile=${PROFILEFILE};
ROLE_NAME="AdministratorAccess"
OUTPUT_FORMAT="json";
AGGREGATOR_FILE="${CONNECTIONFILE_DIR}/aggregator.template"
CREDSFILE="${AWS_PROFILE_DIR}/credentials"
# Set defaults for profiles
defregion="${REGION}"
defoutput="json"
### End of User Defined Variables ###

### OS Type Detection ###
uname -a | grep -i linux >> /dev/null 2>&1
if [ $? -ne 0 ]; then
        sw_vers | grep -i mac >> /dev/null 2>&1
        if [ $? -eq 0 ]; then
                OS_TYPE="mac"
        fi
else
        OS_TYPE="linux"
fi

##### Function Declaration Area #####
# This Function will execute if there no argument with sp-sync

function aws_print_usage() {
echo "";
cat << EOF
This utility provides you the options needed to complete a command for $0

Usage:  $0 sso 
        $0 org

where CMD is one of the following:
       sso   - To sync profile using Single Sign On.
       org   - To Sync profile using Organization.

EOF
echo "";
}

# This function will execute as help for lab command 
function aws_cmds() {
echo "";
cat << EOF
   Usage:  $0 sso 
	   or
	   $0 org
EOF
echo "";
}

##### Command Validation Area #####
function aws_validate_cmd() {
echo "";
cat << EOF
   ERROR! Command Required, to complete task !!
EOF
}

function aws_org_add_profile() {
if [ -s ${PROFILEFILE} ]; then
	echo "" >> "$profilefile";
	echo "$VIEW" >> "$profilefile";
	echo "" >> "$profilefile";
else 
	echo "$VIEW" >> "$profilefile";
	echo "" >> "$profilefile";
fi
}

function aws_org_update_profile2() {
i="1"
while true; do
	cat ${profilefile} | grep "^\[profile ${OLD_PROFILE}\]$" | awk '{print $2}' | sed 's/\]//g' >> /dev/null 2>&1
	if [ $? -eq 0 ]; then
		Profile_Name="${AC_Name}_AWS_Account_${i}"
		((j++))
		VIEW=$(echo "${VIEW}" | sed "s/${profilename}/${Profile_Name}/g")
		profilename="${Profile_Name}"
		break
	else
		break
	fi
done
}

function aws_org_update_profile() {
j="1"
while true; do
	cat ${profilefile} | grep "^\[profile ${profilename}\]$" | awk '{print $2}' | sed 's/\]//g' >> /dev/null 2>&1
	if [ $? -eq 0 ]; then
		Profile_Name="${AC_Name}_AWS_Account_$j"
		sed -i "s/profile ${profilename}/profile ${Profile_Name}/g" ${profilefile}
		((j++))
		Profile_Name="${AC_Name}_AWS_Account_$j"
		VIEW=$(echo "${VIEW}" | sed "s/${profilename}/${Profile_Name}/g")
		profilename="${Profile_Name}"
		break
	else
		break
	fi
done
}


function aws_org() {

echo "";
echo "Started script for AWS Profile Generation with ORG...";
echo "";

DEFAULT_PROFILE=$(cat <<EOF
[default]
region=${defregion}
output=${defoutput}
EOF
)

## Check if AWS Profile is not Exists and no default profile
if [ ! -f ${PROFILEFILE} ]; then
	echo "Profile File missing, creating";
	touch ${PROFILEFILE};
	echo "${DEFAULT_PROFILE}" >> "$profilefile";
        echo "" >> "$profilefile";	
fi

## Create Default Profile for empty profile.
if [ ! -s ${PROFILEFILE} ]; then
	echo "Profile is empty, Creating Default Profile";
	echo "${DEFAULT_PROFILE}" >> "$profilefile";
        echo "" >> "$profilefile";	
fi
echo "";

## Take Backup of old profile file of there is any populated profile
cat ${PROFILEFILE} | grep "^\[profile" >> /dev/null 2>&1
if [ $? -eq 0 ]; then
	echo "Profile exists, creating backup";
	cp -p ${PROFILEFILE} ${PROFILEFILE}.bk
fi
####

## Create Connection dir and File if not exists
mkdir -p ${CONNECTIONFILE_DIR}

if [ ! -f ${CONNECTIONFILE} ]; then
	echo "AWS Connection Profile File missing, creating";
	touch ${CONNECTIONFILE};
fi

echo
echo "$0 will create all profiles with default values"

AWS_ORG_LIST=$(aws organizations list-accounts)
if [ $? -ne 0 ]; then
	echo "Failed"
	exit 1
else
	echo "Succeeded"
fi

declare -a created_profiles

echo "" >> "$profilefile"
echo "### The section below added by awsorgprofiletool TimeStamp: $(date +"%Y%m%d.%H%M")" >> "$profilefile"

echo "Working on aws organizations accounts lists";
AWS_ORG_LIST=$(aws organizations list-accounts)
AWS_ID=$(echo "${AWS_ORG_LIST}" | grep -o '"Id": "[^"]*' | grep -o '[^"]*$' | sort)

#echo "${AWS_ID}" | while read -r AC_ID;
for AC_ID in ${AWS_ID};
do
	echo "";
	echo "Processing for account ${AC_ID} ..."
	ORG_PROFILE=$(echo "${AWS_ORG_LIST}" | grep "\"\Id\"\: \"${AC_ID}"\" -A6)
	STATUS=$(echo "${AWS_ORG_LIST}" | grep "\"\Id\"\: \"${AC_ID}"\" -A6 | grep -o '"Status": "[^"]*' | grep -o '[^"]*$')
	AC_Name=$(echo "${AWS_ORG_LIST}" | grep "\"\Id\"\: \"${AC_ID}"\" -A6 | grep -o '"Name": "[^"]*' | grep -o '[^"]*$' | sed 's/[|]//g' | sed 's/  */_/g' | sed 's/\./_/g' | sed 's/-/_/g')
	profilename=${AC_Name}

	if [[ "${STATUS}" != "ACTIVE" ]]; then
		DELETE_PROFILE=$(cat "$profilefile" | grep "${AC_ID}" -A1 -B2 | grep -e "^\[profile" | awk '{$1="";print}' | sed 's/\]//g'| sed 's/^[[:space:]]//g')
		if [ ! -z ${DELETE_PROFILE} ]; then
			sed -i "/profile ${DELETE_PROFILE}/,+3d" ${profilefile}
			echo "	 ${STATUS} profile ${AC_Name}" removed from ${profilefile};
			continue
		fi
		echo "	 Ignoring ${AC_Name} as ${STATUS} account...";
		continue
	fi

VIEW=$(cat <<EOF
[profile ${profilename}]
source_profile=default
role_arn=aws:iam::${AC_ID}:role/${ROLE_NAME}
output=${OUTPUT_FORMAT}
EOF
)
	PROFILE_ID_COUNT=$(cat "$profilefile" | grep -ce "\[${AC_ID}\]" -A1 -B2) >> /dev/null 2>&1

	if [[ ${PROFILE_ID_COUNT} -eq 1 ]]; then
		OLD_PROFILE_VIEW=$(cat "$profilefile" | grep -e "\[${AC_ID}\]" -A1 -B2)
		if [ "${OLD_PROFILE_VIEW}" == "${VIEW}" ]; then
			continue
		else
			OLD_PROFILE=$(echo "${OLD_PROFILE_VIEW}" | grep -e "^\[profile" | awk '{$1="";print}' | sed 's/\]//g'| sed 's/^[[:space:]]//g' | sed 's/[|]//g' | sed 's/  */_/g' | sed 's/\./_/g' | sed 's/-/_/g')
			profilename="${OLD_PROFILE}"

			aws_org_update_profile2 ## Function call to update profile
			continue
		fi
	elif [[ $(cat "$profilefile" | grep -ce "^\[profile ${profilename}\]$") -ne 0 ]]; then
		OLD_PROFILE=${AC_Name}

		aws_org_update_profile
	fi

	echo -n "  Creating New Profile $profilename... "
	aws_org_add_profile ## Function call to add profile

	echo "Succeeded"

	created_profiles+=($profilename)
done

echo "" >> "$profilefile"
#echo "### The section above added by awsssoprofiletool.sh TimeStamp: $(date +"%Y%m%d.%H%M")" >> "$profilefile"

echo
echo "Processing complete."
echo

cat $profilefile | awk '!NF {if (++n <= 1) print; next}; {n=0;print}' > ${profilefile}_$(date +"%Y%m%d")
mv ${profilefile}_$(date +"%Y%m%d") $profilefile

if [[ "${#created_profiles[@]}" -eq 0 ]]; then
	echo "";
	echo "	No Changes Found, There are no New Profile in AWS!!";
	echo "";
### Delete Unnecessery Last Lines
	if [[ "${OS_TYPE}" == "mac" ]]; then
		if [[ -z $(sed -n '$p' ${profilefile}) ]]; then >> /dev/null 2>&1
			sed -i '' '$d' $profilefile >> /dev/null 2>&1
		fi

		tail -n1 $profilefile | grep "The section below added by" >> /dev/null 2>&1
		if [ $? -eq 0 ]; then
			sed -i '' '$d' $profilefile >> /dev/null 2>&1
		fi

		tail -n1 $profilefile | grep "The section above added by" >> /dev/null 2>&1
		if [ $? -eq 0 ]; then
			sed -i '' '$d' $profilefile >> /dev/null 2>&1
		fi

		if [[ -z $(sed -n '$p' ${profilefile}) ]]; then >> /dev/null 2>&1
			sed -i '' '$d' $profilefile >> /dev/null 2>&1
		fi

		if [[ -z $(sed -n '$p' ${profilefile}) ]]; then >> /dev/null 2>&1
			sed -i '' '$d' $profilefile >> /dev/null 2>&1
		fi

		tail -n1 $profilefile | grep "The section below added by" >> /dev/null 2>&1
		if [ $? -eq 0 ]; then
			sed -i '' '$d' $profilefile >> /dev/null 2>&1
		fi

	elif [[ "${OS_TYPE}" == "linux" ]]; then
		if [[ -z $(sed -n '$p' ${profilefile}) ]]; then >> /dev/null 2>&1
			sed -i '$d' $profilefile >> /dev/null 2>&1
		fi

		tail -n1 $profilefile | grep "The section below added by" >> /dev/null 2>&1
		if [ $? -eq 0 ]; then
			sed -i '$d' $profilefile >> /dev/null 2>&1
		fi

		tail -n1 $profilefile | grep "The section above added by" >> /dev/null 2>&1
		if [ $? -eq 0 ]; then
			sed -i '$d' $profilefile >> /dev/null 2>&1
		fi

		if [[ -z $(sed -n '$p' ${profilefile}) ]]; then >> /dev/null 2>&1
			sed -i '$d' $profilefile >> /dev/null 2>&1
		fi

		if [[ -z $(sed -n '$p' ${profilefile}) ]]; then >> /dev/null 2>&1
			sed -i '$d' $profilefile >> /dev/null 2>&1
		fi

		tail -n1 $profilefile | grep "The section below added by" >> /dev/null 2>&1
		if [ $? -eq 0 ]; then
			sed -i '$d' $profilefile >> /dev/null 2>&1
		fi
	fi
################
else
	echo " Added the following profiles to $profilefile:"
	echo
	for i in "${created_profiles[@]}"
	do
		echo "$i"
	done
fi

## Process .ignore profile

if [ -f ${IGNORE_FILE} ]; then
echo "";
echo "Processing Ignore Profiles...";

declare -a ignored_profiles

IGNORE_PROFILES=$(cat ${IGNORE_FILE} | grep "^\[profile" | sed 's/\]//g' | sed 's/\[//g' | sed 's/^[[:space:]]//g' | awk '{print $2}') >> /dev/null 2>&1
for IP in ${IGNORE_PROFILES}; do
	IP_PROFILE=$(cat ${IGNORE_FILE} | grep "^\[profile ${IP}" -A3)
	IP_AC_ID=$(cat ${IGNORE_FILE} | grep "^\[profile ${IP}" -A3 | grep "role_arn=" | cut -d':' -f 4 | sed 's/\]//g' | sed 's/\[//g' | sed 's/^[[:space:]]//g')
	OLD_PROFILE=$(cat "$profilefile" | grep -e "${IP_AC_ID}" -A1 -B2 | grep "^\[profile"| awk '{$1="";print}' | sed 's/\]//g'| sed 's/^[[:space:]]//g')
	ignored_profiles+=("$OLD_PROFILE")
done

else
	echo "File for Ignore Profiles not found, Creating Empty file location: ${IGNORE_FILE} ...";
	touch ${IGNORE_FILE};
fi

if [[ "${#ignored_profiles[@]}" -ne 0 ]]; then
	echo "  Ignored Profiles are..";
	for ips in "${ignored_profiles[@]}"
	do
		echo "	${ips}"
	done
fi

echo "";

## AWS Config Profiles for Steampipe
echo "Processing AWS Connections for Steampipe...";
AWS_PROFILES=$(cat ${profilefile} | grep "^\[profile" | awk '{print $2}' | sed 's/\]//g' | sort)
for ips in "${ignored_profiles[@]}"
do
	AWS_PROFILES=$(echo "${AWS_PROFILES}" | grep -v "^${ips}$");
done

rm -f ${CONNECTIONFILE}
for SC in ${AWS_PROFILES}; do

CONNECTION_VIEW=$(cat <<EOF
connection "aws_${SC}" {
plugin = "aws"
profile = "${SC}"
regions = ["us-east-1", "us-east-2", "us-west-1", "us-west-2"]
ignore_error_codes = ["AccessDenied", "AccessDeniedException", "NotAuthorized", "UnauthorizedOperation", "UnrecognizedClientException", "AuthorizationError", "InvalidInstanceId", "NoCredentialProviders", "operation", "timeout", "InvalidParameterValue"]
}
EOF
)
        echo ${SC} | grep "_Role_" >> /dev/null 2>&1
        if [ $? -eq 0 ]; then
                echo ${SC} | grep "_Role_1" >> /dev/null 2>&1
                if [ $? -ne 0 ]; then
                        continue
                fi
        fi

	echo "${CONNECTION_VIEW}" >> "${CONNECTIONFILE}";
	echo "" >> "${CONNECTIONFILE}";
done

### AGGREGATOR Default View ###
AGGREGATOR_VIEW=$(cat <<EOF
connection "aws_all" {
  type        = "aggregator"
  plugin      = "aws"
  connections = ["aws_*"]
}
EOF
)
echo "${AGGREGATOR_VIEW}" >> "${CONNECTIONFILE}";

### AGGREGATOR Connection for AGGREGATOR_FILE ###
## Process aggregator.template connection file ##
if [ -f ${AGGREGATOR_FILE} ]; then
	echo "";
	echo "Processing Aggregator Connections...";
	AGGREGATORS_NAME=$(cat ${AGGREGATOR_FILE} | grep "^connection" | cut -d' ' -f2 | sed "s/\"//g")
	if [ -z "${AGGREGATORS_NAME}" ]; then
		echo "";
		echo " No aggregator connection found in ${AGGREGATOR_FILE}";
	else
	for AGG_CONNECTION in ${AGGREGATORS_NAME}; do
		AGGREGATOR_CONNECTION=$(perl -ane "if(/^connection \"${AGG_CONNECTION}\"/ ... /^}/){print}" ${AGGREGATOR_FILE});
		echo "" >> "${CONNECTIONFILE}";
		echo "${AGGREGATOR_CONNECTION}" >> "${CONNECTIONFILE}";
	done
	fi
else
	echo "File for Aggregator Connections not found, Creating Empty file location: ${AGGREGATOR_FILE} ...";
	touch ${AGGREGATOR_FILE};
fi
##########

echo "";
echo "AWS Organization Accounts Profile Sync Task Completed.";
echo "";

exit 0
}


function aws_sso_update_profile() {
j="${i}"
while true; do
	cat ${profilefile} | grep "^\[profile ${Profile_Name}\]$" | awk '{print $2}' | sed 's/\]//g' >> /dev/null 2>&1
	if [ $? -eq 0 ]; then
		((j++))
		Profile_Name="${ac_name}_Role_$j"
		VIEW=$(echo "${VIEW}" | sed "s/${profilename}/${Profile_Name}/g")
		profilename="${Profile_Name}"
		break
#		continue
	else
		break   
	fi
done
}

function aws_sso_add_profile() {
if [ -s ${PROFILEFILE} ]; then
	echo "" >> "$profilefile";
	echo "$VIEW" >> "$profilefile";
	echo "" >> "$profilefile";
else 
	echo "$VIEW" >> "$profilefile";
	echo "" >> "$profilefile";
fi
}

function aws_sso() {

echo "";
echo "Started script for AWS Profile Generation with SSO...";
echo "";

##########
DEFAULT_PROFILE=$(cat <<EOF
[default]
region=${defregion}
EOF
)

## Check if AWS Profile is not Exists and no default profile
if [ ! -f ${PROFILEFILE} ]; then
        echo "Profile File missing, creating";
        touch ${PROFILEFILE};
        echo "${DEFAULT_PROFILE}" >> "$profilefile";
        echo "" >> "$profilefile";
fi

## Create Default Profile for empty profile.
if [ ! -s ${PROFILEFILE} ]; then
        echo "Profile is empty, Creating Default Profile";
        echo "${DEFAULT_PROFILE}" >> "$profilefile";
        echo "" >> "$profilefile";
fi
echo "";

#########


## Take Backup of old profile file of there is any populated profile
cat ${PROFILEFILE} | grep "^sso_account_id =" >> /dev/null 2>&1
if [ $? -eq 0 ]; then
        echo "Profile exists, creating backup";
        cp -p ${PROFILEFILE} ${PROFILEFILE}.bk
fi

## Create Connection dir and File if not exists
mkdir -p ${CONNECTIONFILE_DIR}

if [ ! -f ${CONNECTIONFILE} ]; then
        echo "Profile File missing, creating";
        touch ${CONNECTIONFILE};
fi

### seed aws config with sso defaults 
#aws configure set sso_start_url ${START_URL}
#aws configure set sso_region ${REGION}

# Get secret and client ID to begin authentication session

echo
echo -n "Registering client... "

out=$(aws sso-oidc register-client --client-name 'profiletool' --client-type 'public' --region "${REGION}" --output text)

if [ $? -ne 0 ];
then
    echo "";
    echo "Failed"
    exit 1
else
    echo "Succeeded"
fi

secret=$(awk -F ' ' '{print $3}' <<< "$out")
clientid=$(awk -F ' ' '{print $1}' <<< "$out")

# Start the authentication process

echo -n "Starting device authorization... "

out=$(aws sso-oidc start-device-authorization --client-id "$clientid" --client-secret "$secret" --start-url "${START_URL}" --region "${REGION}" --output text)

if [ $? -ne 0 ];
then
    echo "";
    echo "Failed"
    exit 1
else
    echo "Succeeded"
fi

regurl=$(awk -F ' ' '{print $6}' <<< "$out")
devicecode=$(awk -F ' ' '{print $1}' <<< "$out")

echo
echo "Open the following URL in your browser and sign in, then click the Allow button:"
echo
echo "$regurl"
echo
echo "Press <ENTER> after you have signed in to continue..."

read continue

# Get the access token for use in the remaining API calls

echo -n "Getting access token... "

out=$(aws sso-oidc create-token --client-id "$clientid" --client-secret "$secret" --grant-type 'urn:ietf:params:oauth:grant-type:device_code' --device-code "$devicecode" --region "${REGION}" --output text)

if [ $? -ne 0 ];
then
    echo "Failed"
    exit 1
else
    echo "Succeeded"
fi

token=$(awk -F ' ' '{print $1}' <<< "$out")

# Set defaults for profiles

defregion="${REGION}"
defoutput="json"

# Batch or interactive

echo
echo "$0 will create all profiles with default values"

# Retrieve accounts first

echo
echo -n "Retrieving accounts... "

acctsfile="$(mktemp ./sso.accts.XXXXXX)"

# Set up trap to clean up temp file
trap '{ rm -f "$acctsfile"; echo; exit 255; }' SIGINT SIGTERM
    
aws sso list-accounts --access-token "$token" --region "${REGION}" --output text | sort -k 3 > "$acctsfile"

if [ $? -ne 0 ];
then
    echo "Failed"
    exit 1
else
    echo "Succeeded"
fi

declare -a created_profiles

echo "" >> "$profilefile"
echo "### The section below added by awsssoprofiletool.sh TimeStamp: $(date +"%Y%m%d.%H%M")" >> "$profilefile"

# Read in accounts

while IFS=$'\t' read skip acctnum acctname acctowner;
do
    echo "";
    echo "Working on roles for account $acctnum ($acctname)..."
    rolesfile="$(mktemp ./sso.roles.XXXXXX)"

    # Set up trap to clean up both temp files
    trap '{ rm -f "$rolesfile" "$acctsfile"; echo; exit 255; }' SIGINT SIGTERM
    
    aws sso list-account-roles --account-id "$acctnum" --access-token "$token" --region "${REGION}" --output text | sort -k 3 > "$rolesfile"
    if [ $? -ne 0 ];
    then
	echo "Failed to retrieve roles."
	exit 1
    fi
   
    i=1
    rolecount=$(cat $rolesfile | wc -l)
    
    while IFS=$'\t' read junk junk rolename;
    do
	
	if [[ $rolecount -gt 1 ]]; then
		ac_name=$(echo ${acctname} | sed 's/-/_/g' | sed 's/[[:space:]]/_/g')
		Profile_Name="${ac_name}_Role_$i"
		((i++))
	else
		ac_name=$(echo ${acctname} | sed 's/-/_/g' | sed 's/[[:space:]]/_/g')
		Profile_Name="${ac_name}"
	fi
	profilename=$Profile_Name

VIEW=$(cat <<EOF
[profile ${profilename}_${rolename}]
granted_sso_start_url = ${START_URL}
granted_sso_region = ${REGION}
granted_sso_account_id = $acctnum
granted_sso_role_name = $rolename
region = $defregion
output = $defoutput
credential_process = granted credential-process --profile ${profilename}_${rolename}
EOF
)
	PROFILE_ID_COUNT=$(cat "$profilefile" | grep -e "sso_account_id = ${acctnum}" -A4 -B3 | grep -ce "sso_role_name = $rolename" -A3 -B4) >> /dev/null 2>&1

	if [[ ${PROFILE_ID_COUNT} -eq 1 ]]; then
		OLD_PROFILE_VIEW=$(cat "$profilefile" | grep -e "sso_account_id = ${acctnum}" -A4 -B3 | grep -e "sso_role_name = $rolename" -A3 -B4)
		if [ "${OLD_PROFILE_VIEW}" == "${VIEW}" ]; then
			continue
		else
			OLD_PROFILE=$(cat "$profilefile" | grep -e "sso_account_id = ${acctnum}" -A4 -B3 | grep -e "sso_role_name = $rolename" -A3 -B4 | grep "profile"| awk '{$1="";print}' | sed 's/\]//g'| sed 's/^[[:space:]]//g')
			echo -n "  Profile Detected, Updating ${ac_name}... "
			
			aws_sso_update_profile ## Function call to update profile
			sed -i "s/profile ${OLD_PROFILE}/profile ${profilename}/g" ${profilefile}
			echo "Succeeded"
			continue
		fi
	elif [[ ${PROFILE_ID_COUNT} -gt 1 ]]; then
		echo "	 Multiple Profile Detected for Account_Name: ${acctname}, SSO_Account_ID:${acctnum}, SSO_Role_Name: ${rolename}";
		OLD_PROFILE_NAME=$(cat "$profilefile" | grep -e "sso_account_id = ${acctnum}" -A4 -B3 | grep -e "sso_role_name = $rolename" -A3 -B4 | grep "profile" | awk '{$1="";print}' | sed 's/\]//g'| sed 's/^[[:space:]]//g')
		for PROFILE in ${OLD_PROFILE_NAME}; do
			sed -i "/profile ${PROFILE}/,+7d" ${profilefile}
		done
		aws_sso_add_profile  ## Function call to add profile

		echo "Succeeded"
		continue
	fi

	if [[ $(cat "$profilefile" | grep -ce "^\[profile ${profilename}\]$") -ne 0 ]]; then
		aws_sso_update_profile
	fi

	echo -n "  Creating New Profile $profilename... "
	aws_sso_add_profile ## Function call to add profile

	echo "Succeeded"
	created_profiles+=("$profilename")

    done < "$rolesfile"
    rm "$rolesfile"

done < "$acctsfile"
rm "$acctsfile"

echo "" >> "$profilefile"
#echo "### The section above added by awsssoprofiletool.sh TimeStamp: $(date +"%Y%m%d.%H%M")" >> "$profilefile"

echo
echo "Processing complete."
echo

cat $profilefile | awk '!NF {if (++n <= 1) print; next}; {n=0;print}' > ${profilefile}_$(date +"%Y%m%d")
mv ${profilefile}_$(date +"%Y%m%d") $profilefile

if [[ "${#created_profiles[@]}" -eq 0 ]]; then
	echo "	No Changes Found, There are no New Profile in AWS!!";
### Delete Unnecessery Last Lines

	if [[ "${OS_TYPE}" == "mac" ]]; then
		if [[ -z $(sed -n '$p' ${profilefile}) ]]; then >> /dev/null 2>&1
			sed -i '' '$d' $profilefile >> /dev/null 2>&1
		fi

		tail -n1 $profilefile | grep "The section below added by" >> /dev/null 2>&1
		if [ $? -eq 0 ]; then
			sed -i '' '$d' $profilefile >> /dev/null 2>&1
		fi

		tail -n1 $profilefile | grep "The section above added by" >> /dev/null 2>&1
		if [ $? -eq 0 ]; then
			sed -i '' '$d' $profilefile >> /dev/null 2>&1
		fi

		if [[ -z $(sed -n '$p' ${profilefile}) ]]; then >> /dev/null 2>&1
			sed -i '' '$d' $profilefile >> /dev/null 2>&1
		fi

		if [[ -z $(sed -n '$p' ${profilefile}) ]]; then >> /dev/null 2>&1
			sed -i '' '$d' $profilefile >> /dev/null 2>&1
		fi

		tail -n1 $profilefile | grep "The section below added by" >> /dev/null 2>&1
		if [ $? -eq 0 ]; then
			sed -i '' '$d' $profilefile >> /dev/null 2>&1
		fi

	elif [[ "${OS_TYPE}" == "linux" ]]; then
		if [[ -z $(sed -n '$p' ${profilefile}) ]]; then >> /dev/null 2>&1
			sed -i '$d' $profilefile >> /dev/null 2>&1
		fi

		tail -n1 $profilefile | grep "The section below added by" >> /dev/null 2>&1
		if [ $? -eq 0 ]; then
			sed -i '$d' $profilefile >> /dev/null 2>&1
		fi

		tail -n1 $profilefile | grep "The section above added by" >> /dev/null 2>&1
		if [ $? -eq 0 ]; then
			sed -i '$d' $profilefile >> /dev/null 2>&1
		fi

		if [[ -z $(sed -n '$p' ${profilefile}) ]]; then >> /dev/null 2>&1
			sed -i '$d' $profilefile >> /dev/null 2>&1
		fi

		if [[ -z $(sed -n '$p' ${profilefile}) ]]; then >> /dev/null 2>&1
			sed -i '$d' $profilefile >> /dev/null 2>&1
		fi

		tail -n1 $profilefile | grep "The section below added by" >> /dev/null 2>&1
		if [ $? -eq 0 ]; then
			sed -i '$d' $profilefile >> /dev/null 2>&1
		fi
	fi
else
	echo " Added the following profiles to $profilefile:"
	echo

	for i in "${created_profiles[@]}"
	do
		echo "$i"
	done
fi
## Process .ignore profile
if [ -f ${IGNORE_FILE} ]; then

echo "";
echo "Processing Ignore Profiles...";

declare -a ignored_profiles

IGNORE_PROFILES=$(cat ${IGNORE_FILE} | grep "^\[profile" | awk '{print $2}' | sed 's/\]//g') >> /dev/null 2>&1
for IP in ${IGNORE_PROFILES}; do
	IP_PROFILE=$(cat ${IGNORE_FILE} | grep "^\[profile ${IP}" -A7)
	IP_SSO_AC_ID=$(cat ${IGNORE_FILE} | grep "^\[profile ${IP}" -A7 | grep "sso_account_id")
	IP_SSO_RN=$(cat ${IGNORE_FILE} | grep "^\[profile ${IP}" -A7 | grep "sso_role_name")
	OLD_PROFILE=$(cat "$profilefile" | grep -e "${IP_SSO_AC_ID}" -A4 -B3 | grep -e "${IP_SSO_RN}" -A3 -B4 | grep "^\[profile"| awk '{$1="";print}' | sed 's/\]//g'| sed 's/^[[:space:]]//g')
	ignored_profiles+=("$OLD_PROFILE")
done

else
	echo "";
        echo "File for Ignore Profiles not found, Creating Empty file location: ${IGNORE_FILE} ...";
        touch ${IGNORE_FILE};
fi

if [[ "${#ignored_profiles[@]}" -ne 0 ]]; then
	echo "  Ignored Profiles are..";
	for ips in "${ignored_profiles[@]}"
	do
		echo "	${ips}"
	done
fi

echo "";

## AWS Config Profiles for Steampipe
echo "Processing AWS Connections for Steampipe...";
AWS_PROFILES=$(cat ${profilefile} | grep "^\[profile" | awk '{print $2}' | sed 's/\]//g' | sort)
for ips in "${ignored_profiles[@]}"
do
	AWS_PROFILES=$(echo "${AWS_PROFILES}" | grep -v "^${ips}$");
done

rm -f ${CONNECTIONFILE}
for SC in ${AWS_PROFILES}; do

CONNECTION_VIEW=$(cat <<EOF
connection "aws_${SC}" {
plugin = "aws"
profile = "${SC}"
regions = ["us-east-1", "us-east-2", "us-west-1", "us-west-2"]
ignore_error_codes = ["AccessDenied", "AccessDeniedException", "NotAuthorized", "UnauthorizedOperation", "UnrecognizedClientException", "AuthorizationError", "InvalidInstanceId", "NoCredentialProviders", "operation", "timeout", "InvalidParameterValue"]
}
EOF
)
	echo ${SC} | grep "_Role_" >> /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo ${SC} | grep "_Role_1" >> /dev/null 2>&1
		if [ $? -ne 0 ]; then
			continue	
		fi
	fi
	echo "${CONNECTION_VIEW}" >> "${CONNECTIONFILE}";
	echo "" >> "${CONNECTIONFILE}";
done

### AGGREGATOR Default View ###
AGGREGATOR_VIEW=$(cat <<EOF
connection "aws_all" {
  type        = "aggregator"
  plugin      = "aws"
  connections = ["aws_*"]
}
EOF
)
echo "${AGGREGATOR_VIEW}" >> "${CONNECTIONFILE}"

### AGGREGATOR Connection for AGGREGATOR_FILE ###
## Process aggregator.template connection file ##
if [ -f ${AGGREGATOR_FILE} ]; then
	echo "";
	echo "Processing Aggregator Connections...";
	AGGREGATORS_NAME=$(cat ${AGGREGATOR_FILE} | grep "^connection" | cut -d' ' -f2 | sed "s/\"//g")
	if [ -z "${AGGREGATORS_NAME}" ]; then
		echo "";
		echo " No aggregator connection found in ${AGGREGATOR_FILE}";
	else
		for AGG_CONNECTION in ${AGGREGATORS_NAME}; do
			AGGREGATOR_CONNECTION=$(perl -ane "if(/^connection \"${AGG_CONNECTION}\"/ ... /^}/){print}" ${AGGREGATOR_FILE});
			echo "" >> "${CONNECTIONFILE}";
			echo "${AGGREGATOR_CONNECTION}" >> "${CONNECTIONFILE}";
		done
	fi
else
	echo "";
	echo "File for Aggregator Connections not found, Creating Empty file location: ${AGGREGATOR_FILE} ...";
	touch ${AGGREGATOR_FILE};
fi

rm -f ${CREDSFILE}
touch ${CREDSFILE}

echo "";
echo "AWS SSO Profile Sync Task Completed.";
echo "";

exit 0
}

##### End of Function Decleration Area #####

##### Basic checkings #####
## Check AWS CLI Version 
#if [[ $(aws --version >> /dev/null 2>= ) == aws-cli/1* ]]; then
if [[ $(aws --version) == aws-cli/1* ]]; then
	echo "";
	echo "ERROR: $0 requires AWS CLI v2 or higher";
	echo "";
	exit 1
	if [ $? -ne 0 ]; then
		echo "";
		echo "AWS Cli Not Installed";
		echo "";
	fi
fi

## Check if AWS Profile Directory is not Exists, creating one
if [ ! -d ${AWS_PROFILE_DIR} ]; then
	echo "${AWS_PROFILE_DIR} is missing, creating...";
	mkdir ${AWS_PROFILE_DIR}
fi

# Main area
##### Process Arguments Area #####

##### Command Validation Area #####
if [[ -z "${1}" ]]; then
#        aws_validate_cmd
#	aws_cmds
	aws_print_usage
        exit 1
fi
##### Command Validation Area #####

if [ "$#" -ne 1 ]; then
	echo "";
	echo "Only one argument can be accepted";
	aws_cmds
	exit 2;
fi

CMD=""
if [[ -n "$1" ]]; then
        case $1 in
                sso)
                        CMD=$1          # Main Command
                ;;
                org)
                        CMD=$1          # Main Command
                ;;
                *)
                        aws_cmds;
                        exit 1
                ;;
        esac
fi
##### Process Arguments Area #####

##### Core Command for the script #####
        aws_${CMD}
##### Core Command for the script #####
### End of Variable Decleration ###

##### End of Script Execution #####
