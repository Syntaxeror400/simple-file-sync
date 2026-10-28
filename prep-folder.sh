#! /bin/bash

if [ $# -lt 1 ] || [ $# -gt 2 ]
then
		echo "Usage:  prep-folder <file-list> [output-dir]"
		exit 1
fi
COMMON_DIR_FILE=.prep-folder-common-dir

if [ -f "$1" ]
then
	FILE_LIST=$1
	NB_FILES=$(wc -l < "$FILE_LIST")
else
	echo File $1 does not exist. >&2
	exit
fi

OUTPUT_FOLDER=Playlist/
if [ $# -eq 2 ]
then
	OUTPUT_FOLDER=$2
	if [ "${OUTPUT_FOLDER:${#OUTPUT_FOLDER}-1}" != "/" ]
	then
		OUTPUT_FOLDER=${OUTPUT_FOLDER}/
	fi
fi

# Parsing the list for a common root to all pahts
COMMON_DIR=""
echo $COMMON_DIR > $COMMON_DIR_FILE
cat "$FILE_LIST" | while read F_PATH
	do
		if [ "$COMMON_DIR" = "" ]
		then
			if [ -d "$F_PATH" ]; then
				COMMON_DIR=$F_PATH
			else
				COMMON_DIR=$(dirname "$F_PATH")/
			fi
			echo $COMMON_DIR > $COMMON_DIR_FILE
		else
			while [ "${F_PATH::${#COMMON_DIR}}" != "$COMMON_DIR" ]
			do
				COMMON_DIR=$(dirname "$COMMON_DIR")/
				echo $COMMON_DIR > $COMMON_DIR_FILE
			done
		fi
	done
if [ -f $COMMON_DIR_FILE ]
then
	COMMON_DIR=$(cat $COMMON_DIR_FILE)
	rm $COMMON_DIR_FILE
else
	echo Cannot find common root, temp file missing. >&2
fi

echo Using $FILE_LIST as file file list.
echo Using $OUTPUT_FOLDER as output directory.
echo Using $COMMON_DIR as the common source directory.


# Creating the symlink folder
CURR_F=0
cat "$FILE_LIST" | while read FILE
do
	echo -ne File $CURR_F/$NB_FILES"\r"
	if [ -f "$FILE" ]
	then
		OUT_F=${OUTPUT_FOLDER}${FILE:${#COMMON_DIR}:${#FILE}}
		mkdir -p "$(dirname "$OUT_F")"
		ln -s "$FILE" "$OUT_F"
	fi
	((CURR_F++))
done
echo -e "\n"Done !