#!/bin/bash

#Commands can be laced into this code to preform recursive path dependent tasks using the provided
#This script's goal is to copy files over to another stream assuming identical structure
#The flag character for downloading files is a ! currently but may need to be changed
#or users need to agree that ! are not allowed in their file/directory names

trap "" 1 2 3 4 6 15

#we check and remove the flag if it is there with shift so that we can check if the number
#of parameters is correct without having to consider flag
force=false

case $1 in
"-f")force=true; shift; ;;
esac

#usage string
USAGE="\nUsage: copy sourceDirectory destinationDirectory filepath
filepath example: \"Dir1_1 File1_1|Dir2_1 Dir2_2|File3_1 Dir3_1!\"
Use an ! at the end of a directory in the filepathe to copy it and its contents\n"

#case to check the number of parameters is correct
case $# in
3) ;;
*) echo "Incorrect Number of Parameters"; echo -e "$USAGE"; exit 2 ;;
esac

#testing for simple user error
if !(test -d $1)
then
  echo "$1 is not a valid directory"
  echo -e "$USAGE"
  exit 2
elif !(test -d $2)
then
  echo "$2 is not a valid directory"
  echo -e "$USAGE"
  exit 2
elif [ "$1" == "$2" ]
then
  echo "Cannot copy from and to the same directory"
  echo -e "$USAGE"
  exit 2
fi

logDelimiter="****************************************************************************************************************************************"

log="./log.txt"
if !(test -e $log)
then
  touch $log
  echo "$logDelimiter" >> $log
fi

# Enter initial information about when and who ran this script.
echo Command run: copy.sh "$1 $2 `echo '"'"$3"'"'` " >> $log
echo "User: `whoami`" >> $log
echo `date | awk '//{print "Date:",$0}'` >> $log

# Flag to check if any copies/makeFolders/commits were executed
print_to_log=false

count=0
level=0    #current level in Unix Directory (0 being the earliest, but starts at 2 to ignore first two inputs)
dst=$2  #beginning input of target directory
backup="/tmp/backup$$"
mkdir $backup
src=$1 #beginning input of directory to be copied from
finaldst=$2

#IFS is used to describe how input is read and when to separate one from another
#orignially IFS is set to any whitespace, we set it to only a newline so that when
#awk prints one of the separated arguements, the whitespace does not interfere with the argument
#being loaded into the array

IFS=$'\n'

#this is an awk command that seperates the single string path seperated by '|' and loads all values into an array

pathArgs=($(echo $3 | awk -F\| '{for(i = 1; i <= NF; i++){print($i)}}'))

#this is here for now but there is most likely a function to get the length of the array
#but this works for now and we can improve later

for values in "${pathArgs[@]}"; do
  count=$((count + 1))
done

#we need to return IFS back to its orginal value so that the loop read the arguments correctly

IFS=$' \t\n'

function rollback(){
  
  trap "" 1 2 3 4 6 15
 
  #ask the user if they want to rollback, rolling back is as simple as removing the backup folder
  #keeping files means that we need to use the finalize function to finish copying over  
  echo copy script was interrupted>>$log;
  echo
  echo "copy script interrupted, would like to rollback (delete and files/directories copied over)? [y/n]"
  read roll

  if [ $roll == "y" ]
  then

    echo
    echo "Deleting all files/directories copied over"
   
    #clean up and remove the backup folder
    rm -r "/tmp/backup$$"

    echo "Rollback was initiated, all copied files/directories were restored to their original state before the script">>$log

  else

    finalize

  fi

  echo "$logDelimiter">>$log  
}

function finalize(){

  trap "" 1 2 3 4 6 15

  #load all the top level files/directories from the backup folder
  #copy them over recursively, this does not delete any files/folders not in the backup folder, 
  #it simply updates any files that were already there or creates them if they did not exist  

  backup="/tmp/backup$$"
  list=$(ls $backup) 
  
  for values in $list
  do

    if (test -d $backup/$values)
    then

      cp -r $backup/$values $finaldst

    elif (test -f $backup/$values)
    then

      cp $backup/$values $finaldst

    fi

  done
  
  #clean up and remove the backup folder
  rm -r "/tmp/backup$$" 
}

trap "rollback; exit 1" 1 2 3 4 6 15

function traverse() {

  if [ $level -eq $count ]; then #check if we are at the deepest level with nothing stated for copy

    echo Directory $src reached but nothing copied

  else #else we need to go to the next level

    for values in ""${pathArgs[$level]}""; do #for all folders and files in the current level

      if [ "$values" != "" ]; then #edge case that needs to be ingnored if values == ""
      #this can also be done in the count loop if code gets messy here

        dst="$dst/$values"   #add the next level path to the current path already made
        src="$src/$values" #create the matching path for the current directory
        dst=${dst%!}         #we remove a ! if it exists so we can check if it exists correctly

        backup="$backup/$values"
        backup=${backup%!}

        if (test -d ${src%!}); then #check if path without trailing ! is a valid directory

          if [ "${src:${#src}-1:1}" = "!" ]; then #if ! is at the end then copy folder

            src=${src%!} #remove the ! at the end of targeting
            
            if (test -d $dst) && (test $force = false); then

              echo Directory $dst already exists would you like to override? "[y/n]"
              read copyInput

              if [ $copyInput == "y" ]; then

                echo Copying Directory $src to ${dst%/*}
                cp -r $src ${backup%/*}
            
                if (test $print_to_log = false); then #If flag not true, print header in log and set it to to true

                  echo "FILES/FOLDERS COPIED:" >> $log
	          print_to_log=true

                fi

                echo "Copied Folder $src to ${dst%/*}" >> $log

              else

                echo Directory not copied

              fi
            else


              echo Copying Directory $src to ${dst%/*}
              cp -r $src ${backup%/*} 

              if (test $print_to_log = false); then

                echo "FILES/FOLDERS COPIED:" >> $log
                print_to_log=true

              fi

              echo "Copied Folder $src to ${dst%/*}" >> $log

            fi

          else #else recurse to the next level

            if !(test -d $dst)
            then

              echo Directory $dst does not exist
              read -p "Would you like to search in its subdirectories? [y|n]" answer
              echo

              if [ $answer = "y" ]; then

                local temp=$values
                dst=${dst%/*}
                backup=${backup%/*}

                for direcs in $(ls $dst); do

                  dst="$dst/$direcs"

                  if !(test -d $dst/$temp); then
                    if (test -d $dst); then   
                       echo Directory $dst/$temp does not exist
                       echo
                    fi 
                  else

                    echo We found $dst/$temp
                    read -p "Do you want to copy the files there? [y|n]" answer
                    echo

                    if [ $answer = "y" ]; then
                    
                      backup="$backup/$direcs"
                      mkdir $backup
                      backup="$backup/$temp"
                      mkdir $backup
                      dst="$dst/$temp"

                      level=$((level + 1))
                      traverse
                      level=$((level - 1))

                      backup=${backup%/*}
                      backup=${backup%/*}
                      dst=${dst%/*}

                    fi
                  fi
                  dst=${dst%/*}

                done
                dst="$dst/$values"
                backup="$backup/$values"
              else

                echo Skipped subdirectory search
                echo
              fi
            else

              #before going to the next level we need to make the folder in tmp so that when we copy there cp will have the appropiate path
              mkdir $backup

              level=$((level + 1))
              traverse #recursive call
              level=$((level - 1))

            fi

          fi

        elif (test -f $src); then #check if the path is a file

          if (test -f $dst) && (test $force = false); then

            echo File $dst already exists would you like to override? "[y/n]"
            read copyInput

            if [ $copyInput == "y" ]; then

              echo Copying File $src to ${dst%/*}
              cp $src ${backup%/*}
              
              if (test $print_to_log = false); then

                echo "FILES/FOLDERS COPIED:" >> $log
                print_to_log=true
       
              fi

              echo "Copied File $src to ${dst%/*}" >> $log
 
            else

              echo File not copied

            fi
          else

            echo Copying File $src to ${dst%/*}
            cp $src ${backup%/*}

            if (test $print_to_log = false); then
            
              echo "FILES/FOLDER COPIED:" >> $log
              print_to_log=true

            fi

            echo "Copied File $src to ${dst%/*}" >> $log

          fi

        else #error message if path is invalid

          echo Directory or File ${src%!} does not exist
          read -p "Would you like to check in the subdirectories? [y|n]" answer
          echo

          if [ $answer = "y" ]; then

            local temp=$values
            src=${src%/*}

            for direcs in $(ls $src); do

              src="$src/$direcs/$temp"

              if [ "${src:${#src}-1:1}" = "!" ]; then

                src=${src%!}

                if !(test -d $src); then
                   if ( test -d ${src%/*} ); then
		      echo Directory $src does not exist
		      echo
                   fi

                else

                  echo We found $src
                  read -p "Do you want to copy the files there? [y|n]" answer
                  echo

                  if [ $answer = "y" ]; then

                    if !(test -d $dst); then

                      echo Target $dst does not match current path $src
                      echo Aborting copy for this path
                      echo

                    else

                      echo Copying $src to ${dst%/*}
                      echo
                      cp -r $src ${dst%/*}

                      if (test $print_to_log = false); then
                        echo "FILES/FOLDERS COPIED:">>$log
                        print_to_log=true
                      fi

                      echo "Copied Folder $src to ${dst%/*}">>$log
                    fi
                  else

                    echo Not copying files
                  fi
                fi
              elif !(test -d $src); then
                if ( test -d ${src%/*} ); then
		   echo Directory $src does not exist
		   echo
                fi
              else

                echo We found $src
                read -p "Do you want to copy the files there? [y|n]" answer
                echo

                if [ $answer = "y" ]; then
                  level=$((level + 1))
                  traverse
                  level=$((level - 1))
                fi

              fi
              src=${src%/*/*}

            done

            src="$src/$values"

          else

            echo Skipped subdirectory search
            echo
          fi
        fi
        dst=${dst%/*} #once we return from the recursion, the $values needs to be removed from the
        src=${src%/*}
        backup=${backup%/*}
      fi
    done #end of the target for backtracking
  fi
}

traverse  #call the function after defining it sending the command line input to it

trap "" 1 2 3 4 6 15

finalize

if !(test $print_to_log = true); then #if it is false then nothing was copied
  echo "NOTICE: copy: copy script ran, but no folders/files were copied from $1 to $2" >> $log
fi

echo "$logDelimiter" >> $log

exit 0
