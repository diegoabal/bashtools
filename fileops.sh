#!/bin/bash
if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Provide filenames as args eg:"
    echo "	./fileops.sh file1 file2.txt file3.sh"
fi
for var in "$@"
do
    echo "File operations:"
    echo "v) View File"
    echo "e) Edit File"
    echo "c) Change Permissions"
	echo "q) Quit"
    read -p "What are you going to do with $var ? " options
	case "${options}" in
        v) less $var;;
        e) vi $var;;
		c) 	read -p "Enter the new Permissions for $var: (eg. 777) " perm
			chmod $perm $var;;
		q) exit 1;;
    esac
done
