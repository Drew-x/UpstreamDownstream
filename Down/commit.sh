#!/bin/bash

#Commands can be laced into this code to preform recursive path dependent tasks using the provided
#This script's goal is commit folders and files for git to push to an online repo

#The flag character for staging folder contents is a ! currently but may need to be changed
#or users need to agree that ! are not allowed in their file/directory names

trap "echo ; echo Interrupted; exit 1" 1 2 3 4 6 15

USAGE="\nUsage: commit filepath
filepath example: \"Dir1_1 File1_1|Dir2_1 Dir2_2|File3_1 Dir3_1!\"
Use an ! at the end of the directory in the filepath to commit it and its contents\n"

case $# in
1) ;;
*) echo "Incorrect Number of Parameters"; echo -e "$USAGE"; exit 2 ;;
esac

log="./log.txt"

if !(test -e $log)
then
  touch $log
  echo "****************************************************************************************************************************************" >> $log
fi

# Enter initial information about when and who ran this script.
echo Command run: commit.sh '"'"$@"'"' >> $log
echo "User: `whoami`" >> $log
echo `date | awk '//{print "Date:",$0}'` >> $log

# Flag to check if any copies/makeFolders/commits were executed
print_to_log=false

count=0
level=0        	#current level in Unix Directory (0 being the earliest)
current="."	#current directory to build path and find files and directories

IFS=$'\n'

pathArgs=($(echo $1 | awk -F\| '{for(i = 1; i <= NF; i++){print($i)}}'))

for values in "${pathArgs[@]}"
do
  count=$(($count+1))
done

IFS=$' \t\n'

function traverse(){

  if [ $level -eq $count ]	#check if we are at the deepest level with nothing stated for git
  then

    echo Folder $current reached but nothing staged for git

  else				#else we need to go to the next level

    for values in ""${pathArgs[$level]}"" #for all folders and files in the current level
    do

      if [ "$values" != "" ] 	#edge case that needs to be ingnored if values == ""
      then			#this can also be done in the count loop if code gets messy here

        current="$current/$values" #add the next level path to the current path already made

        if (test -d ${current%!})  #check if path without trailing ! is a valid directory
        then	

          if [ "${current:${#current}-1:1}" = "!" ] #if ! is at the end then add and commit folder
          then

            current=${current%!} #remove the ! at the end of targeting

            echo Staging Files to Commit in Folder "$current"
            git add $current

            if (test $print_to_log = false)
            then

              echo "FILES/FOLDERS STAGED:" >> $log
              print_to_log=true

            fi

            echo "Staged Files to Commit in Folder $current" >> $log

          else			#else recurse to the next level

            level=$((level+1)) 	#increment right before recursion
            traverse		#recursive call
            level=$((level-1)) 	#decrement after for backtracking

          fi

        elif (test -f $current)	#check if the path is a file
        then

          echo Staging File to Commit $current
          git add $current
          
          if (test $print_to_log = false)
          then
            
            echo "FILES/FOLDERS STAGED:" >> $log
            print_to_log=true

          fi

          echo "Staged File to Commit $current" >> $log

        else			#error message if path is invalid

          echo ${current%!} is not a folder or file

        fi

        current=${current%/*}	#once we return from the recursion, the $values needs to be removed from the

      fi
    done	                #end of the target for backtracking
  fi
}

traverse			#call the function after defining it

if !(test $print_to_log = true)
then
  echo "NOTICE: commit script ran, but no folders/files were commited" >> $log
  echo "****************************************************************************************************************************************" >> $log
  exit 0
fi

git commit -m "Initial"
git push

echo "****************************************************************************************************************************************" >> $log

exit 0
