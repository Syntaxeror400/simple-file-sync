#! /bin/bash

################################################################################
# Function to print help text
help_text() {
	echo "Usage: simple-file-sync [options] <source> <destination>"
	echo "Use simple-file-sync -h for a list of options"
}

print_help() {
	help_text
	exit 1
}

print_options() {
	help_text
	echo -e "\n"Options:
	echo -e "\t -q/--quiet Removes all text output from this script (auto-accepts synchronization)"
	echo -e "\t -v/--verbose Prints more information while copying and delete files"
	echo -e "\t -h/--help Print this message"
	exit 0
}

################################################################################
# Option parsing
OPTS=$(getopt -o hvq --long help,verbose,quiet -n'simple-file-sync' -- "$@")
if [ $? -ne 0 ]
then
  echo "Failed to parse arguments" >&2
  exit 1
fi

VERBOSE=false
QUIET=false

eval set -- "$OPTS"
while true
do
	case "$1" in
	-h | --help)
		print_options
		;;
	-v | --verbose)
		VERBOSE=true
		shift
		;;
	-q | --quiet)
		QUIET=true
		shift
		;;
	--)
		shift
		break
		;;
	*)
		if [ "$QUIET" = false ] ; then
			echo "Unknown argument from getopt" $1 >&2
		fi
		exit 1
		;;
	esac
done

if [ $# -ne 2 ]
then
	if [ "$QUIET" = false ] ; then
		print_help
	else
		exit 1
	fi
fi

if [ -d $1 ]
then
	if [ "$QUIET" = false ] ; then
		echo Setting $1 as source directory.
	fi

	SOURCE_DIR=$1
	if [ "${SOURCE_DIR:${#SOURCE_DIR}-1}" != "/" ]
	then
		SOURCE_DIR=${SOURCE_DIR}/
	fi
else
	if [ "$QUIET" = false ] ; then
		echo $1 is not a directory. >&2
	else
		exit 1
	fi
fi

if [ -d $2 ]
then
	if [ "$QUIET" = false ] ; then
		echo Setting $2 as destination directory.
	fi

	DEST_DIR=$2
	if [ "${DEST_DIR:${#DEST_DIR}-1}" != "/" ]
	then
		DEST_DIR=${DEST_DIR}/
	fi
else
	if [ "$QUIET" = false ] ; then
		echo $2 is not a directory. >&2
	else
		exit 1
	fi
fi

################################################################################
# Processing
if [ "$QUIET" = false ] ; then
	echo ""
	read -n 1 -p "Synchronize files from $SOURCE_DIR to $DEST_DIR ?(y/n) " ynAnswer
	case ${ynAnswer:0:1} in
		y|Y|o|O )
			echo ""
		;;
		* )
			echo -e "\n"Aborting.
			exit 2
		;;
	esac
fi

# Copying files from source to destination
if [ "$QUIET" = false ]; then
	echo -e "\n"Copying missing files from $SOURCE_DIR to $DEST_DIR
fi
DID_SOMETHING=false
find $SOURCE_DIR -type f | while read SRC_F
do
	DEST_F=${DEST_DIR}${SRC_F:${#SOURCE_DIR}}
	if [ ! -f "$DEST_F" ]
	then
		if [ "$VERBOSE" = true ] ; then
			echo -e "\t""$SRC_F" '>>>' "$DEST_F"
		fi
		mkdir -p "$(dirname "$DEST_F")"
		cp "$SRC_F" "$DEST_F"
		DID_SOMETHING=true
	fi
done
if [ "$DID_SOMETHING" = false ] && [ "$QUIET" = false ] ; then
	echo "Already up to date, nothing to copy."
fi

# Removing files that are not in the source
if [ "$QUIET" = false ] ; then
	echo -e "\n"Removing files that are only in $DEST_DIR
fi
DID_SOMETHING=false
find $DEST_DIR -type f | while read DEST_F
do
	SRC_F=${SOURCE_DIR}${DEST_F:${#DEST_DIR}}
	if [ ! -f "$SRC_F" ]
	then
		if [ "$VERBOSE" = true ] ; then
			echo -e "\t"- "$DEST_F"
		fi
		rm "$DEST_F"
		DID_SOMETHING=true
	fi
done
if [ "$DID_SOMETHING" = false ] && [ "$QUIET" = false ] ; then
	echo "Already up to date, nothing to delete."
fi


# Removing empty directories
if [ "$QUIET" = false ] ; then
	echo -e "\n"Cleaning empty directories in $DEST_DIR
fi
find $DEST_DIR/* -type d -empty -delete

