#! /bin/bash

print_help() {
	echo "Usage: cp_musique.sh <source> <destination>"
	exit
}

if [ $# -ne 2 ]
then
	print_help
fi

if [ -d $1 ]
then
	echo Setting $1 as source directory.
	SOURCE_DIR=$1
	if [ "${SOURCE_DIR:${#SOURCE_DIR}-1}" != "/" ]
	then
		SOURCE_DIR=${SOURCE_DIR}/
	fi
else
	echo $1 is not a directory. >&2
	print_help
fi

if [ -d $2 ]
then
	echo Setting $2 as destination directory.
	DEST_DIR=$2
	if [ "${DEST_DIR:${#DEST_DIR}-1}" != "/" ]
	then
		DEST_DIR=${DEST_DIR}/
	fi
else
	echo $2 is not a directory. >&2
	print_help
fi

read -n 1 -p "Synchronize files from $SOURCE_DIR to $DEST_DIR ?(y/n) " ynAnswer
case ${ynAnswer:0:1} in
    y|Y|o|O )
        echo ""
    ;;
    * )
        echo -e "\n"Aborting.
		exit
    ;;
esac

# Copying files from source to destination
echo -e "\n"Copying missing files from $SOURCE_DIR to $DEST_DIR
find $SOURCE_DIR -type f | while read SRC_F
do
	DEST_F=${DEST_DIR}${SRC_F:${#SOURCE_DIR}}
	if [ ! -f "$DEST_F" ]
	then
		echo -e "\t""$SRC_F" '>>>' "$DEST_F"
		mkdir -p "$(dirname "$DEST_F")"
		cp "$SRC_F" "$DEST_F"
	fi
done

# Removing files that are not in the source
echo -e "\n"Removing files that are only in $DEST_DIR
find $DEST_DIR -type f | while read DEST_F
do
	SRC_F=${SOURCE_DIR}${DEST_F:${#DEST_DIR}}
	if [ ! -f "$SRC_F" ]
	then
		echo -e "\t"- "$DEST_F"
		rm "$DEST_F"
	fi
done

# # Removing empty directories
# find $DEST_DIR/* -type d -empty -delete

