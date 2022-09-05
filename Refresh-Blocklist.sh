#!/bin/bash


# Constants
BLOCKLIST_OUTPUT='I-Blocklist.blocklist'
BLOCKLIST_STRUCT="${0##*/}.XXXX"

# Command line argument derived variables
PROVIDED_VERBIAGE=5  # Default to verbosity, set to '5' for DEBUG output


# General purpose function for standardized output
report()
{
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


# Process the command line arguments
arguments()
{
    local OPTIND
    while getopts ":u:p:xweq" opt; do
        case $opt in
            x) PROVIDED_VERBIAGE=4;;
            w) PROVIDED_VERBIAGE=2;;
            e) PROVIDED_VERBIAGE=1;;
            q) PROVIDED_VERBIAGE=0;;
            \?) report 'fail' "Invalid option -$OPTARG" >&2 && exit 1 ;;
        esac
    done

    shift "$((OPTIND - 1))"
    # Now "$@" contains the rest of the arguments

    report 'tech' 'Collected parameters:'
    report 'tech' "PROVIDED_QUIETUDE:\t'$PROVIDED_VERBIAGE'"
}


generate()
{
    report 'tech' "Entering function call: 'generate'"

    local verbosity=''
    if   [[ $PROVIDED_VERBIAGE -ge 4 ]]; then verbosity='-x';
    elif [[ $PROVIDED_VERBIAGE -ge 2 ]]; then verbosity='-w';
    elif [[ $PROVIDED_VERBIAGE -ge 1 ]]; then verbosity='-e';
    fi

    I-Blocklist-Builder.sh $verbosity "${BLOCKLIST_BUFFER}"
    
    report 'tech' "Created fresh blocklist in buffer: ${BLOCKLIST_BUFFER}"
}


upload()
{
    report 'tech' "Entering function call: 'upload'"

    sshpass -p "${BLOCKLIST_SFTP_PASS}" sftp \
        -oBatchMode=no \
        -oCompression=yes \
        -oPort="${BLOCKLIST_SFTP_PORT}" \
        "${BLOCKLIST_SFTP_USER}@${BLOCKLIST_SFTP_HOST}" \
        <<< $"put -p ${BLOCKLIST_BUFFER}/${BLOCKLIST_OUTPUT}"
}


setup()
{
    report 'tech' "Entering function call: 'setup'"

    BLOCKLIST_BUFFER=$(mktemp -d -t $BLOCKLIST_STRUCT)
    touch "${BLOCKLIST_BUFFER}"

    report 'tech' "Buffer file created"
    report 'tech' "IBLOCKLIST_BUFFER: ${BLOCKLIST_BUFFER}"

}


# Remove temporary workspace
cleanup ()
{
    report 'tech' "Entering function call: 'cleanup'"
    
    rm -fr "${BLOCKLIST_BUFFER}"
    
    report 'tech' "Buffer file removed: ${BLOCKLIST_BUFFER}"
}


# 1st:
# Parse and process the commandline arguments.
arguments "$@"


# 2nd:
# Setup a temporary workspace.
setup BLOCKLIST_BUFFER


# 3rd:
# (Re)generate a fresh blocklist.
generate


# 4th:
# (Re)upload block list to URI via sFTP.
upload


# 5th:
# Remove temporarily allocated resources
cleanup
report 'loud' 'Finished refreshing blocklist'

