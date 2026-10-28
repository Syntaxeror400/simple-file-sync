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
LONG_ARGS=${LONG_ARGS},quiet
SHORT_ARGS=${SHORT_ARGS}q
QUIET=false
LONG_ARGS=${LONG_ARGS},dry-run
DRY_RUN=false
LONG_ARGS=${LONG_ARGS},diff
DIFF_FILES=false
LONG_ARGS=${LONG_ARGS},bckp-playcount
BCKP_PLAYCOUNT=false

# Function to print help text
print_help() {
	if [ $# -ge 1 ]
	then
		SHORT=$1
	else
		SHORT=true
	fi

	if [ "$SHORT" = false ] || [ "$QUIET" = false ]
	then
		echo "Usage: simple-file-sync [options] <source> <destination>"
		echo "Use simple-file-sync -h for a list of options"
	fi

	if [ "$SHORT" = true ]
	then
		exit 1
	else
		echo -e "\n"Options:
		echo -e "\t-q/--quiet \t Removes all text output from this script (auto-accepts synchronization)"
		echo -e "\t-v/--verbose \t Prints more information while copying and delete files"
		echo ""
		echo -e "\t--dry-run \t Run through all the program but do not copy or delete any file"
		echo -e "\t--diff \t\t Diff files that have matching name and overwirte them if different"
		echo -e "\t--bckp-playcount \t When '--diff' is used, writes the value of the EXIF FMPS_PLAYCOUNT tag to a file before updating a file"
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
	-q | --quiet)
		QUIET=true
		shift
		;;
	--dry-run)
		DRY_RUN=true
		shift
		;;
	--diff)
		DIFF_FILES=true
		shift
		;;
	--bckp-playcount)
		BCKP_PLAYCOUNT=true
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

# Getting the folders names
if [ $# -ne 2 ]
then
	print_help true
fi

if [ "$QUIET" = true ] ; then
	VERBOSE=false		# Force verbose to false if quiet
fi

if [ -d "$1" ]
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

if [ -d "$2" ]
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

NB_FILES=$(find -L "$SOURCE_DIR" -type f -printf x | wc -c)
CURR_F=0
# Copying files from source to destination
if [ "$QUIET" = false ]; then
	echo -e "\n"Copying missing files from $SOURCE_DIR to $DEST_DIR
fi
find -L $SOURCE_DIR -type f | while read SRC_F
do
	if [ "$VERBOSE" = false ] && [ "$QUIET" = false ] ; then
		echo -en "\tProcessing file $CURR_F/$NB_FILES...\r"
	fi
	DEST_F=${DEST_DIR}${SRC_F:${#SOURCE_DIR}}
	if [ ! -f "$DEST_F" ]
	then
		if [ "$VERBOSE" = true ] ; then
			echo -e "\t($CURR_F/$NB_FILES) $SRC_F >>> $DEST_F"
		fi
		if [ "$DRY_RUN" = false ]; then
			mkdir -p "$(dirname "$DEST_F")"
			cp -L "$SRC_F" "$DEST_F"
		fi
		touch $FILE_DID_COPY
	elif [ "$DIFF_FILES" = true ]
	then
		if ! cmp -s "$SRC_F" "$DEST_F"
		then
			if [ "$BCKP_PLAYCOUNT" = true ]
			then
				PLAYCOUNT=$(exiftool -s3 -FMPS_PLAYCOUNT "$DEST_F")
				if [ ! -z "$PLAYCOUNT"]; then
					echo ${SRC_F:${#SOURCE_DIR}} : $PLAYCOUNT >> $PLAYCOUNT_FILE
				fi
			fi

			if [ "$VERBOSE" = true ] ; then
				echo -e "\t($CURR_F/$NB_FILES) $SRC_F ->- $DEST_F"
			fi
			if [ "$DRY_RUN" = false ]; then
				cp -L "$SRC_F" "$DEST_F"
			fi
			touch $FILE_DID_COPY
		fi
	fi
	((CURR_F++))
done
if [ "$VERBOSE" = false ] && [ "$QUIET" = false ] ; then
	echo -e "\tDone.                              "
fi
if [ ! -f $FILE_DID_COPY ]
then
	if [ "$QUIET" = false ] ; then
		echo "Already up to date, nothing to copy."
	fi
else
	rm $FILE_DID_COPY
fi

# Removing files that are not in the source
CURR_F=0
if [ "$QUIET" = false ] ; then
	echo -e "\n"Removing files that are only in $DEST_DIR
fi
find $DEST_DIR -type f | while read DEST_F
do
	if [ "$VERBOSE" = false ] && [ "$QUIET" = false ] ; then
		echo -en "\tProcessing file $CURR_F/$NB_FILES...\r"
	fi
	SRC_F=${SOURCE_DIR}${DEST_F:${#DEST_DIR}}
	if [ ! -f "$SRC_F" ]
	then
		if [ "$VERBOSE" = true ] ; then
			echo -e "\t($CURR_F/$NB_FILES) - $DEST_F"
		fi
		if [ "$DRY_RUN" = false ]; then
			rm "$DEST_F"
		fi
		touch $FILE_DID_REMOVE
	fi
	((CURR_F++))
done
if [ "$VERBOSE" = false ] && [ "$QUIET" = false ] ; then
	echo -e "\tDone.                              "
fi
if [ ! -f $FILE_DID_REMOVE ]
then
	if [ "$QUIET" = false ] ; then
		echo "Already up to date, nothing to delete."
	fi
else
	rm $FILE_DID_REMOVE
fi


# Removing empty directories
if [ "$QUIET" = false ] ; then
	echo -e "\n"Cleaning empty directories in $DEST_DIR
fi
if [ "$DRY_RUN" = false ]; then
	find $DEST_DIR/* -type d -empty -delete
fi

if [ "$QUIET" = false ] ; then
	echo -e "\n"All done, files are now synced !
fi
