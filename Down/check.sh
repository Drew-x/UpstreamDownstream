#!/bin/bash
#this script will look for all matching directories and check to see if they have any matching files
#if there are any files that match then we run the diff command on the two files
#if there is any output then we know there is some difference and we print this to the console
#if no differences were found then we print a message to the user letting them know 

#Usage string
USAGE="\nUsage: check directory1 directory2"

#check to make sure the user types the correct number of parameters
case $# in
2) ;;
*) echo "Incorrect Number of Parameters"; echo -e "$USAGE"; exit 2 ;;
esac

#make sure that the directories provided exist
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
fi

#variables for function
dis=$1
src=$1
dst=$2
flag=false
misF=false

function traverse(){

  #aquire the list of files/directories we are currently at
  list=$(ls $src)
  
  for values in $list
  do

    #if they match and they are directories then we traverse into them and look for files
    if (test -d "$src/$values") && (test -d "$dst/$values")
    then

      #append directory to the end to create path
      src="$src/$values"
      dst="$dst/$values" 

      traverse #recursive call

      #remove the path at the end for rest of function check
      src=${src%/*} 
      dst=${dst%/*}

    #if they match and they are files then we check to see if they have any differences
    elif (test -f "$src/$values") && (test -f "$dst/$values")
    then

      #this flag will let us know if we have seen any matching files
      misF=true

      #get the output of diff
      output=$(diff -q "$src/$values" "$dst/$values")

      #if some output is seen then we know there is a difference
      if (test "$output" != "")
      then
       
        #if this is our first time seeing a difference then we print a header
        if (test $flag = false)
        then
          
          #flip the flag and print header
          flag=true
          echo The Following Files have differences:
        fi

	#print the file that has a difference
        display=${src#$dis/}
        echo "$display/$values" 
      fi
    fi
  done
}

traverse

if (test $misF = false)
then
   echo No matching files found to compare
  exit 0
fi

#if the flag was never flipped then no differences were found 
if (test $flag = false)
then

  #print message to notify user
  echo Already Up to Date
fi

exit 0
