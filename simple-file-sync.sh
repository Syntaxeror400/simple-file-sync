#! /bin/bash

################################################################################
# Defining filenames to flag wheter we did someting
FILE_DID_COPY=.simple-file-sync-copied-file
FILE_DID_REMOVE=.simple-file-sync-removed-file
PLAYCOUNT_FILE=simple-file-sync-dest-playcounts

SHORT_ARGS="h"
LONG_ARGS="help"
# Options that will be set by arguments
SHORT_ARGS=${SHORT_ARGS}v
LONG_ARGS=${LONG_ARGS},verbose
VERBOSE=false
LONG_ARGS=${LONG_ARGS},dry-run
DRY_RUN=false
LONG_ARGS=${LONG_ARGS},update
UPDATE_FILES=false

# Function to print help text
print_help() {
	if [ $# -ge 1 ]
	then
		SHORT=$1
	else
		SHORT=true
	fi

	if [ "$SHORT" = false ]
	then
		echo "Usage: simple-file-sync [options] <source> <destination>"
		echo "Use simple-file-sync -h for a list of options"
	fi

	if [ "$SHORT" = true ]
	then
		exit 1
	else
		echo -e "\n"Options:
		echo -e "\t-v/--verbose \t Prints more information while copying and delete files"
		echo ""
		echo -e "\t--dry-run \t Run through all the program but do not copy or delete any file"
		echo -e "\t--update \t\t Check the last modified timestamps of files with matching names and overwrite new files"
		echo ""
		echo -e "\t-h/--help \t Print this message"
		exit 0
	fi
}

################################################################################
# Option parsing
OPTS=$(getopt -o $SHORT_ARGS --long $LONG_ARGS -n'simple-file-sync' -- "$@")
if [ $? -ne 0 ]
then
  echo "Failed to parse arguments" >&2
  exit 1
fi

eval set -- "$OPTS"
while true
do
	case "$1" in
	-h | --help)
		print_help false
		;;
	-v | --verbose)
		VERBOSE=true
		shift
		;;
	--dry-run)
		DRY_RUN=true
		shift
		;;
	--update)
		UPDATE_FILES=true
		shift
		;;
	--)
		shift
		break
		;;
	*)
		echo "Unknown argument from getopt" $1 >&2
		exit 1
		;;
	esac
done

# Getting the folders names
if [ $# -ne 2 ]
then
	print_help true
fi

if [ -d "$1" ]
then
	echo Setting $1 as source directory.

	SOURCE_DIR=$1
	if [ "${SOURCE_DIR:${#SOURCE_DIR}-1}" != "/" ]
	then
		SOURCE_DIR=${SOURCE_DIR}/
	fi
else
	echo $1 is not a directory. >&2
	exit 1
fi

if [ -d "$2" ]
then
	echo Setting $2 as destination directory.

	DEST_DIR=$2
	if [ "${DEST_DIR:${#DEST_DIR}-1}" != "/" ]
	then
		DEST_DIR=${DEST_DIR}/
	fi
else
	echo $2 is not a directory. >&2
	exit 1
fi

################################################################################
# Processing
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

NB_FILES=$(find -L "$SOURCE_DIR" -type f -printf x | wc -c)
CURR_F=0
# Copying files from source to destination
echo -e "\n"Copying missing files from $SOURCE_DIR to $DEST_DIR
find -L $SOURCE_DIR -type f | while read SRC_F
do
	if [ "$VERBOSE" = false ] ; then
		echo -en "\tProcessing file $CURR_F/$NB_FILES...\r"
	fi
	DEST_F=${DEST_DIR}${SRC_F:${#SOURCE_DIR}}
	if [ ! -f "$DEST_F" ]
	then
		if [ "$VERBOSE" = true ] ; then
			echo -e "\t($CURR_F/$NB_FILES) $SRC_F >>> $DEST_F"
		fi
		if [ "$DRY_RUN" = false ] ; then
			mkdir -p "$(dirname "$DEST_F")"
			cp -L "$SRC_F" "$DEST_F"
		fi
		touch $FILE_DID_COPY
	elif [ "$UPDATE_FILES" = true ]
	then
		if [ "$SRC_F" -nt "$DEST_F" ]
		then
			if [ "$VERBOSE" = true ] ; then
				echo -e "\t($CURR_F/$NB_FILES) $SRC_F ->- $DEST_F"
			fi
			if [ "$DRY_RUN" = false ] ; then
				cp -L "$SRC_F" "$DEST_F"
			fi
			touch $FILE_DID_COPY
		fi
	fi
	((CURR_F++))
done
if [ "$VERBOSE" = false ] ; then
	echo -e "\tDone.                              "
fi
if [ ! -f $FILE_DID_COPY ]
then
	echo "Already up to date, nothing to copy."
else
	rm $FILE_DID_COPY
fi

# Removing files that are not in the source
CURR_F=0
echo -e "\n"Removing files that are only in $DEST_DIR
find $DEST_DIR -type f | while read DEST_F
do
	if [ "$VERBOSE" = false ] ; then
		echo -en "\tProcessing file $CURR_F/$NB_FILES...\r"
	fi
	SRC_F=${SOURCE_DIR}${DEST_F:${#DEST_DIR}}
	if [ ! -f "$SRC_F" ]
	then
		if [ "$VERBOSE" = true ] ; then
			echo -e "\t($CURR_F/$NB_FILES) - $DEST_F"
		fi
		if [ "$DRY_RUN" = false ] ; then
			rm "$DEST_F"
		fi
		touch $FILE_DID_REMOVE
	fi
	((CURR_F++))
done
if [ "$VERBOSE" = false ] ; then
	echo -e "\tDone.                              "
fi
if [ ! -f $FILE_DID_REMOVE ]
then
	echo "Already up to date, nothing to delete."
else
	rm $FILE_DID_REMOVE
fi


# Removing empty directories
echo -e "\n"Cleaning empty directories in $DEST_DIR
if [ "$DRY_RUN" = false ] ; then
	find $DEST_DIR/* -type d -empty -delete
fi

echo -e "\n"All done, files are now synced !
