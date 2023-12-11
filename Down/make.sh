#!/bin/bash
#This script first counts all the level of the directory requested and prints out each level
#then using a recursive function we travel to each level creating directories along the way
#once it reaches the last level it prints the path of directories that it created

trap "" 1 2 3 4 6 15

USAGE="\nUsage: make sourceDirectory directoryPath
sourceDirectory is the directory specified to make the folders in
directoryPath example: \"Dir1_1|Dir2_1 Dir2_2|Dir3_1\"\n"

case $# in #Check for correct amount of arguments for make 
2) ;;
*) echo "Incorrect Number of Parameters"; echo -e "$USAGE"; exit 2 ;; # print usage if not correct number of parameter 
esac

if !(test -d $1)
then
  echo "$1 is not a valid directory"
  echo -e "$USAGE"
  exit 2
fi

#Log variables for creating a log file of all user activity in the system  
log="./log.txt" 
logDelimiter="****************************************************************************************************************************************"

if !(test -e $log) #Create log file in current directory if it does not exist
then
  touch $log
  echo "$logDelimiter" >> $log
fi

# backup variables for rollback when script is interrupted
backup="/tmp/makebackup$$.sh"
touch $backup

#Rollback function for when the script is interrupted 
function rollback(){

  trap "" 1 2 3 4 6 15 #make sure that the set up and rollback cannot be interrupted
  echo make script was interrupted>>$log;
  echo 
  echo "make was interrupted, would you like to rollback (delete any directories made)? [y/n]"

  read roll
  if [ $roll == "y" ]
  then

    echo -e "\nDeleting all created directories"
    sh $backup
    echo "Rollback was initiated, all created directories were deleted" >> $log
  fi

  rm $backup
  echo "$logDelimiter">>$log

}

#run rollback when script is interrupted 
trap "rollback; exit 1" 1 2 3 4 6 15

# Enter initial information about when and who ran this script into log file.
echo Command run: make.sh '"'"$@"'"' >> $log
echo "User: `whoami`" >> $log
echo `date | awk '//{print "Date:",$0}'` >> $log

# Flag to check if any copies/makeFolders/commits were executed
print_to_log=false

#Variables used for traverse()
count=0
level=0
path="$1"       # path is the specified directory

#IFS is used to describe how input is read and when to separate one from another
#orignially IFS is set to any whitespace, we set it to only a newline so that when
#awk prints one of the separated arguments, the whitespace does not interfere with the argument
#being loaded into the array
IFS=$'\n'

pathArgs=($(echo $2 | awk -F\| '{for(i = 1; i <= NF; i++){print($i)}}'))

for values in "${pathArgs[@]}"
do 
 count=$((count+1))
done

IFS=$' \t\n' #revert IFS to default value for the loop in traverse function 

#Traversal function for traversing the pathArgs string 
function traverse(){

 if [ $level -eq $count ] 	#if we get to the last level print the path
 then

  echo -e "\b\b" # do nothing and traverse back up the traverse function calls   

 else				#else we need to go to the next level

  for values in ""${pathArgs[$level]}"" #for all folders requested in the current level
  do

    if [ "$values" != "" ]	#edge case that needs to be ignored if values == ""
    then			
      
      sub=$1
      path="$path/$values"	#add the next level path to the current path already made
      
      if !(test -d $path)       #Check if the folder already exists 
      then
        mkdir $path		# The folders are created as intended in each level.
        
	if (test $sub = false)
        then
	  echo "rm -r $path" >> $backup 
          sub=true
        fi

        echo "Folder $path has been created "

        if (test $print_to_log = false) #Print Header of folders created when successfully created a folder  
        then
        
          echo "FOLDER/DIRECTORIES CREATED:" >> $log
          print_to_log=true

        fi

        echo "Created Folder: $path" >> $log #log the created folders 
      else
        echo "Folder $path already exists "
      fi

      level=$((level+1))   	#increment right before recursion
      traverse $sub			#then recurse to the next level
      level=$((level-1))   	#decrement for backtracking

      path=${path%/*}		#once we return from the recursion, the $values variable is removed
                                #from the end of the string for backtracking
   
    fi
  done
 fi
}

traverse false		#call the function after defining it

trap "" 1 2 3 4 6 15 #make sure that clean up code cannot be interrupted

if !(test $print_to_log = true)
then
  echo "NOTICE: make script ran, but no folders were created" >> $log
fi

echo "$logDelimiter" >> $log

rm $backup

exit 0
