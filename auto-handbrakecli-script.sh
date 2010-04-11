#! /bin/bash
#auto-handbrakecli-script.sh

###############################################################################
#   Auto HandbrakeCLI Script
#   Copyright (C) 2009-2010  Curtis Lee Bolin <curtlee2002(at)gmail.com>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTaudioBitRateILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
###############################################################################

fileType=( avi flv iso mp4 mpeg mpg wmv )

readonly DEFAULT_VIDEO_SETTINGS="--encoder x264 --two-pass --turbo --vb 768 --decomb --loose-anamorphic"
readonly DEFAULT_X264_SETTINGS="--x264opts b-adapt=2:rc-lookahead=50"
readonly DEFAULT_AUDIO_SETTINGS="--audio 1 --aencoder faac --ab 128 --mixdown dpl2 --arate 48 --drc 2.5"
readonly DEFAULT_SUBTITLE_SETTINGS="--native-language eng --subtitle-forced scan --subtitle scan"
readonly DEFAULT_CONTAINER_TYPE="mkv"
readonly DEFAULT_CONTAINER_SETTINGS="--format $DEFAULT_CONTAINER_TYPE"
readonly DEFAULT_PROCESSED_DIRECTORY="processed"
readonly DEFAULT_LOG_FILE="handbrake.log"
otherSettings="--markers"

logger ()
{
   echo "$(date +'[ %d %b %Y %H:%M ]') :: $*" | tee -a "$DEFAULT_PROCESSED_DIRECTORY"/"$DEFAULT_LOG_FILE"
}

checkForAc3 ()
{
   # Checks for ac3 audio
   inputAudioCodec=`mplayer -vo null -ao null -frames 0 -identify 2>&1 /dev/null "$inputFileName" | grep "^ID_AUDIO_CODEC=a52"`

   # if ac3 is detected, then ac3 pass through, else default audio setting
   audioSettings="$DEFAULT_AUDIO_SETTINGS"
   [ "$inputAudioCodec" =  "ID_AUDIO_CODEC=a52" ] && audioSettings="--audio 1 --aencoder ac3"
}

fileTranscode ()
{
   checkForAc3
   logger "Encoding $inputFileName to $videoName.$DEFAULT_CONTAINER_TYPE ..."
   mv "$inputFileName" "$DEFAULT_PROCESSED_DIRECTORY"/
   HandBrakeCLI $DEFAULT_VIDEO_SETTINGS $DEFAULT_X264_SETTINGS $audioSettings $DEFAULT_SUBTITLE_SETTINGS $otherSettings $DEFAULT_CONTAINER_SETTINGS --input "$DEFAULT_PROCESSED_DIRECTORY"/"$inputFileName" --output "$videoName"."$DEFAULT_CONTAINER_TYPE" || encoderStatus="error"
   logger "Encoding Completed."
}

fileSearch ()
{
   for inputFileName in *  # stores each file in the directory into inputFileName 1 at a time, then does the loop
   do
      if [ -f "$inputFileName" ]  # test if it is a true file
      then
         fileNameExt="${inputFileName##*.}"  # extracts the extension name from the file name
         predicate="\"$fileType\" = \"$fileNameExt\""                         #
         for (( i=1; i<${#fileType[@]}; i++ ))                                # creates and list of or's and stores it in predicate 
         do                                                                   #
            predicate="$predicate -o \"$fileNameExt\" = \"${fileType[i]}\""   #
         done
         videoName=${inputFileName%.*}  # extracts the video name from the file name
         mv "$inputFileName" "$DEFAULT_PROCESSED_DIRECTORY"/
         [ $predicate ] && $encodeCommand
         fi
   done
}

isoTranscode ()
{
   mv "$inputFileName" "$DEFAULT_PROCESSED_DIRECTORY"/
   outputDirectory="${inputFileName%.*}/"
   [ ! -d "$outputDirectory" ] && mkdir -p "$outputDirectory"  #  creates the output directory if it doesn't exist
   #   encoderStatus="run"                                                      #
   #   for (( chapterNumber=1 ; "encoderStatus" = "error" ; chapterNumber++ ))  # currently handbrakecli isn't exiting on errors properly 
   for (( count=1; count<50; count++ ))
   do
      otherSettings="--markers --chapters $count $chapterOption"
      [ $encodeType=="title" ] && otherSettings="--markers --title $count"
      videoName="$encodeType$count"
      [ "$count" -lt "10" ] && videoName="${encodeType}0$count"
      fileTranscode
   done
}

chapterMode ()
{
   encodeType="chapter"
   fileType=( iso )
   chapterOption="--longest"
   if [ -n "$fileName" ]
   then
      inputFileName="$fileName"
      [ -n "$titleNumber" ] && chapterOption="--title $titleNumber"
      isoTranscode
   else
      encodeCommand="isoTranscode"
      fileSearch
   fi
}

titleMode ()
{
   encodeType="title"
   fileType=( iso )
   if [ -n "$fileName" ]
   then
      inputFileName="$fileName"
      isoTranscode
   else
      encodeCommand="isoTranscode"
      fileSearch
   fi
}

directoryMode ()
{
   startingDiretory=`pwd`
   [ ! -d "$DEFAULT_PROCESSED_DIRECTORY" ] && mkdir -p "$DEFAULT_PROCESSED_DIRECTORY"
   encodeCommand="fileTranscode"
   fileSearch
   for directoryName in *
   do
      if [ -d "$directoryName" ]  # test if it is a true directory
      then
         cd "$directoryName"
         [ ! -d "$DEFAULT_PROCESSED_DIRECTORY" ] && mkdir -p "$DEFAULT_PROCESSED_DIRECTORY"
         fileSearch
         cd ../
      fi
   done
   cd $startingDiretory 
}

simpleDirectoryMode ()
{
   [ ! -d "$DEFAULT_PROCESSED_DIRECTORY" ] && mkdir -p "$DEFAULT_PROCESSED_DIRECTORY"
   encodeCommand="fileTranscode"
   fileSearch
}

fileMode ()
{
   [ ! -d "$DEFAULT_PROCESSED_DIRECTORY" ] && mkdir -p "$DEFAULT_PROCESSED_DIRECTORY"
      inputFileName="$fileName"
      videoName="${inputFileName%.*}"
      fileTranscode
}

errorFound ()
{
   echo "Error with options."
   printUsage
   exit 1
}

printUsage ()
{
   echo
   echo "Usage: auto-handbrakecli-script.sh [OPTION]"
   echo
   echo "-h, --help"
   echo "   Prints this help information."
   echo
   echo "-c, --chapter [FILE] [TITLE]"
   echo "   Transcodes each chapter of the loggest title or title number given of"
   echo "   the iso files in that directory."
   echo "   File name is optional and title number of the file is optional."
   echo
   echo "-t, --title [FILE]"
   echo "   Transcodes each title of the iso files in that directory."
   echo "   File name is optional."
   echo
   echo "-d, --directory"
   echo "   Transcodes files one directory deep."
   echo
   echo "-- [FILE]"
   echo "   If a file name is given, only that file will be encoded"
   echo
   echo "With no option all video files in the directory will be encoded and"
   echo "loggest title of an iso file."
   echo
}

mode=""

if [ -z "$1" ]
   then
      simpleDirectoryMode
   else
      until [ -z "$1" ]; do
      	# use a case statement to test vars. we always test
      	# test $1 and shift at the end of the for block.
      	case $1 in
      	   -h|--help)
               printUsage
               exit 0
            ;;
      		-c|--chapter )
      		   # shift, so the string after --home becomes
   	    		# our new $1. then save the value.
   	    		[ -n "$mode" ] && errorFound
      		   shift
      		   [ -n "$1" -a "$1" != "-*" ] && fileName="$1"
      		   shift
      		   [ -n "$1" -a "$1" != "-*" ] && titleNumber="$1"
      		   mode="chapterMode"
            ;;
      		-t|--title )
      		   [ -n "$mode" ] && errorFound
      		   shift
      		   [ -n "$1" -a "$1" != "-*" ] && fileName="$1"
      		   shift
      		   mode="titleMode"
      		;;
      		-d|--directory )
      		   [ -n "$mode" ] && errorFound
      		   mode="directoryMode"
   		   ;;
      		-- )
      		   [ -n "$mode" ] && errorFound
      			# set all the following arguments as files
      			shift
      		   [ -n "$1" -a "$1" != "-*" ] && fileName="$1"
      		   mode="fileMode"
      		   #filelist=
               #filelist="$filelist $@"
      		;;
      		-* )
      			echo "Unrecognized option: $1"
      			[ -n "$mode" ] && errorFound
      		;;
      		--* )
      			echo "Unrecognized option: $1"
      			[ -n "$mode" ] && errorFound
      		;;
      		* )
      		   printUsage
               exit 0
      		;;
      	esac

      	shift

      	if [ "$#" = "0" ]; then
      		break
      	fi
      done
fi

$mode

exit 0
