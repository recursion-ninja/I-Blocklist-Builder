#!/bin/bash


# Constants
CURL_RETRY_OPTIONS='--connect-timeout 30 --retry 5 --retry-connrefused --retry-delay 10 --retry-max-time 300'
CURL_OTHER_OPTIONS='--insecure --location-trusted --output - --silent'
CURL_TOTAL_OPTIONS="$CURL_RETRY_OPTIONS $CURL_OTHER_OPTIONS"
IBLOCKLIST_URI_HTTP='https://'
IBLOCKLIST_URI_SITE='iblocklist.com/'
IBLOCKLIST_URI_TYPE='&fileformat=p2p&archiveformat=gz'
IBLOCKLIST_URI_LIST="${IBLOCKLIST_URI_HTTP}list.${IBLOCKLIST_URI_SITE}?list="
IBLOCKLIST_URI_JSON="${IBLOCKLIST_URI_HTTP}www.${IBLOCKLIST_URI_SITE}lists.json"
IBLOCKLIST_OUTPUT='I-Blocklist.blocklist'
IBLOCKLIST_STRUCT='I-Blocklist-Builder-Buffer.XXXX'


# Command line argument derived variables
PROVIDED_USERNAME='' # Default to no authentication
PROVIDED_PASSWORD='' # Default to no authentication
PROVIDED_VERBIAGE=3  # Default to verbosity, set to '5' for DEBUG output
PROVIDED_OUTPATHS='' # Default to STDOUT


# General purpose function for standardized output
report() {
  if [ "$PROVIDED_VERBIAGE" -le 0 ]; then return 0; fi
  local prefix=''
  case "$1" in
      tech) if [[ $PROVIDED_VERBIAGE -ge 5 ]]; then prefix='# '   ; else return 0; fi ;;
      loud) if [[ $PROVIDED_VERBIAGE -ge 4 ]]; then prefix='  '   ; else return 0; fi ;;
      warn) if [[ $PROVIDED_VERBIAGE -ge 2 ]]; then prefix='! '   ; else return 0; fi ;;
      fail) if [[ $PROVIDED_VERBIAGE -ge 1 ]]; then prefix='X '   ; else return 0; fi ;;
      *)    if [[ $PROVIDED_VERBIAGE -ge 3 ]]; then prefix='  '   ; else return 0; fi ;;
  esac
  echo -e "$prefix$2"
}


maximize_verbiage() {
    local PROPOSED_VERBIAGE="$1"
    PROVIDED_VERBIAGE=$(( PROPOSED_VERBIAGE > PROVIDED_VERBIAGE ? PROPOSED_VERBIAGE : PROVIDED_VERBIAGE ))
}


# Process the command line arguments
arguments() {
    local OPTIND
    while getopts ":u:p:xweq" opt; do
        case $opt in
            u) PROVIDED_USERNAME="$OPTARG" ;; # I-Blocklist Username
            p) PROVIDED_PASSWORD="$OPTARG" ;; # I-Blocklist PIN
            x) maximize_verbiage 4 ;;
            w) maximize_verbiage 2 ;;
            e) maximize_verbiage 1 ;;
            q) maximize_verbiage 0 ;;
            \?) report 'fail' "Invalid option -$OPTARG" >&2 && exit 1 ;;
        esac
    done

    shift "$((OPTIND - 1))"
    # Now "$@" contains the rest of the arguments

    # If there are one or more remaining command line arguments,
    # they are the source code filepaths!
    if [ "$#" -ne 0 ]; then
        IFS=$'\n'
        PROVIDED_OUTPATHS="$*"
    fi
    
    report 'tech' 'Collected parameters:'
    report 'tech' "PROVIDED_USERNAME:\t'$PROVIDED_USERNAME'"
    report 'tech' "PROVIDED_PASSWORD:\t'$PROVIDED_PASSWORD'"
    report 'tech' "PROVIDED_QUIETUDE:\t'$PROVIDED_VERBIAGE'"
    report 'tech' "PROVIDED_OUTPATHS:\t'$PROVIDED_OUTPATHS'"
}


# Determine subscription status
subscription() {
    report 'tech' "Entering function call: 'subscription'"

    # Check for environment defined values if not supplied on command line
    if [[ -z "${PROVIDED_USERNAME}" ]] && [[ -n "${IBLOCKLIST_USERNAME}" ]]; then
        PROVIDED_USERNAME="$IBLOCKLIST_USERNAME"
    fi  
    if [[ -z "${PROVIDED_PASSWORD}" ]] && [[ -n "${IBLOCKLIST_PIN}" ]]; then
        PROVIDED_PASSWORD="$IBLOCKLIST_PIN"
    fi

    # Decide if subscription authentication information exists
    if [[ -n "${PROVIDED_USERNAME}" ]] && [[ -n "${PROVIDED_PASSWORD}" ]]; then
        report 'tech' 'Using provided I-Blocklist subscription information'
        report 'tech' "$PROVIDED_USERNAME"
        report 'tech' "$PROVIDED_PASSWORD"
        return 0
    else
        report 'warn' 'No I-Blocklist subscription information found!'
        return 1
    fi
}


# Gather all possible blocklists
blocklists() {
    report 'tech' "Entering function call: 'blocklists'"
    
    local result=$1

    # Request the JSON file of all blocklists
    json=$(eval "curl $CURL_TOTAL_OPTIONS '$IBLOCKLIST_URI_JSON'")
    
    status=$?
    report 'tech' "JSON cURL request exit code: $status"        
    report 'tech' "JSON result from $IBLOCKLIST_URI_JSON"
    report 'tech' "JSON:\n$json"

    # Check if the response is valid JSON
    if  [ ![ jq -reM '""' >/dev/null 2>&1 <<<"$json" ]]; then
        report 'fail' "Invalid JSON received from $IBLOCKLIST_URI_LIST\n\n$JSON"
        exit 89
    fi
	
    report 'tech' "Valid JSON received"
    
    # Remove ISP based block lists
    local filterISPs='This list is not recommended for those that are subscribers of the ISP'
    local filterCountries=' IP ranges.'
    local selection1="(.description | index(\"${filterISPs}\")      | not)"
    local selection2="(.description | index(\"${filterCountries}\") | not)"
    local blocklists_pruned=$(jq --raw-output \
        ".[] | map(select($selection1 and $selection2)) | .[] | [.name, .list, .subscription] | @tsv" \
        <<<"$json")
    
    # If there is no subscription authentication information available,
    # then remove the subscription blocklists
    local blocklists_access=$blocklists_pruned
    if [ $SUBSCRIPTION_INFO -ne 0 ]; then
        blocklists_access=$(sed '/	true$/d' <<<"$blocklists_pruned")
        report 'tech' "Removed subscription blocklists"
    fi
    
    local blocklists_sorted=$(sort -k1,1 -t$'\t' <<<"$blocklists_access")
    local blocklists_closed=$(sort -k3   -t$'\t' <<<"$blocklists_sorted")

    # Return the tab-seperated value table with columns:
    # | Subscription | Name | List |
    eval $result="\"$blocklists_closed\""
}


# Download the specified blocklist and append the contents to the buffer
download() {
    report 'tech' "Entering function call: 'download'"
    
    local prefix="$1"
    local handle="$2"
    local source="$3"
    local locked="$4"
    local suffix=''
    local bullet='*'
    
    if [[ $locked == 'true' ]]; then
        if [ $SUBSCRIPTION_INFO ]; then
            suffix="&username=$PROVIDED_USERNAME&pin=$PROVIDED_PASSWORD"
            bullet='$'
        else
            return 1
        fi
    fi
        
    local webpage="$IBLOCKLIST_URI_LIST$source$IBLOCKLIST_URI_TYPE$suffix"
    local request="curl $CURL_TOTAL_OPTIONS '$webpage'"
    
    report 'tech' "$request"
    report 'loud' "\t$bullet $prefix: $handle"
    content=$(eval "$request" | gunzip)
    status=$?
    report 'tech' "cURL | gunzip == $status"
    if [ $status -ne 0 ]; then
        report 'tech' "CONTENT: $content"
        payload=$(eval $request)
        report 'tech' "PAYLOAD: $payload"
        report 'warn' "Skipping $handle"
        return 1;
    fi

    if [ -z "$content" ]; then
        report 'tech' "CONTENT: $content"
        payload=$(eval $request)
        report 'tech' "PAYLOAD: $payload"
        report 'warn' "Skipping $handle"
        return 1;
    fi
    
    local grepped=$(egrep -v '^#' <<<"$content")
    local clipped=$(sed '/^$/d'   <<<"$grepped")
    echo "$clipped" >>$IBLOCKLIST_BUFFER
}


# Create a temporary workspace
setup() {
    report 'tech' "Entering function call: 'setup'"

    local result=$1
    local buffer=$(mktemp -t $IBLOCKLIST_STRUCT)
    touch $buffer
    
    report 'tech' "Buffer file created"
    report 'tech' "IBLOCKLIST_BUFFER: $buffer"
    
    eval $result="\"$buffer\""
}


# Remove temporary workspace
cleanup () {
    report 'tech' "Entering function call: 'cleanup'"
    rm -rf $IBLOCKLIST_BUFFER
    report 'tech' "Buffer file removed: $IBLOCKLIST_BUFFER"
}


# 1st:
# Parse and process the commandline arguments.
arguments "$@"


# 2nd:
# Determine the whther or not subscription information is available.
subscription;
SUBSCRIPTION_INFO=$?


# 3rd:
# Enumerating the blocklists.
blocklists IBLOCKLIST_VALUES


# 4th:
# Precompute pretty printing variables
BLOCKLIST_OVERALL=$(   wc -l <<<"$IBLOCKLIST_VALUES")
BLOCKLIST_MAXIMUM=$(($(wc -c <<<"$BLOCKLIST_OVERALL") - 1))
BLOCKLIST_CURRENT=0
BLOCKLIST_SUCCESS=0


# 5th:
# Setup a temporary workspace.
setup IBLOCKLIST_BUFFER


# 6th:
# Combine all blocklists
if [ $PROVIDED_VERBIAGE -ge 4 ]; then
    report 'loud' 'Downloading I-Blocklist content:'
else
    report 'info' 'Downloading I-Blocklist content...'
fi
while IFS=$'\t' read -r HANDLE SOURCE LOCKED
do
     ((BLOCKLIST_CURRENT+=1))
     COUNTER_PREFIX=$(printf "%${BLOCKLIST_MAXIMUM}d/%d" $BLOCKLIST_CURRENT $BLOCKLIST_OVERALL)
     download "$COUNTER_PREFIX" "$HANDLE" "$SOURCE" "$LOCKED"
     status=$?
     if [ $status -eq 0 ]; then
         ((BLOCKLIST_SUCCESS+=1))         
     fi
          
done <<< "$IBLOCKLIST_VALUES"
report 'info' "Successfully combined $BLOCKLIST_SUCCESS/$BLOCKLIST_OVERALL blocklists!"


# 7th:
# Output the combined blocklist
if [[ -z "$PROVIDED_OUTPATHS" ]]; then
    cat $IBLOCKLIST_BUFFER
else
    report 'loud' 'Copying combined blocklist to specified filepaths:'
    while read -r OUTPATH
    do
        cp "$IBLOCKLIST_BUFFER" "$OUTPATH/$IBLOCKLIST_OUTPUT"
        report 'loud' "\t> $OUTPATH/$IBLOCKLIST_OUTPUT"
    done <<< "$PROVIDED_OUTPATHS"
fi


# 8th:
# Remove temporarily allocated resources
cleanup
report 'loud' 'Finished update of current I-Blocklist entries!'

