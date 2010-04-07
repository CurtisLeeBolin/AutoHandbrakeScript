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
readonly DEFAULT_OUTPUT_DIRECTORY="output"
readonly DEFAULT_PROCESSED_DIRECTORY="processed"
readonly DEFAULT_LOG_FILE="handbrake.log"
otherSettings="--markers"

logger ()
{
   echo "$(date +'[ %d %b %Y %H:%M ]') :: $*" | tee -a "$DEFAULT_LOG_FILE"
}

checkForAc3 ()
{
   # Checks for ac3 audio
   inputAudioCodec=`mplayer -vo null -ao null -frames 0 -identify 2>&1 /dev/null "$inputFileName" | grep "^ID_AUDIO_CODEC=a52"`

   # if ac3 is detected, then ac3 pass through, else default audio setting
   audioSettings="$DEFAULT_AUDIO_SETTINGS"
   [ "$inputAudioCodec" =  "ID_AUDIO_CODEC=a52" ] && audioSettings="--audio 1 --aencoder ac3"
}

encode ()
{
   checkForAc3
   logger "Encoding $inputFileName to $videoName.$DEFAULT_CONTAINER_TYPE ..."
   HandBrakeCLI $DEFAULT_VIDEO_SETTINGS $DEFAULT_X264_SETTINGS $audioSettings $DEFAULT_SUBTITLE_SETTINGS $otherSettings $DEFAULT_CONTAINER_SETTINGS --input "$inputFileName" --output "$outputDirectory"/"$videoName"."$DEFAULT_CONTAINER_TYPE" || encoderStatus="error"
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
         [ $predicate ] && $encodeCommand
         fi
   done
}

fileEncode ()
{
   outputDirectory="$DEFAULT_OUTPUT_DIRECTORY"
   [ ! -d "$outputDirectory" ] && mkdir -p "$outputDirectory"  #  creates the output directory if it doesn't exist
   encode
   mv "$inputFileName" "$DEFAULT_PROCESSED_DIRECTORY"/
}

isoEncode ()
{
   outputDirectory="$DEFAULT_OUTPUT_DIRECTORY/${inputFileName%.*}"
   [ ! -d "$outputDirectory" ] && mkdir -p "$outputDirectory"  #  creates the output directory if it doesn't exist
#   encoderStatus="run"                                                      #
#   for (( chapterNumber=1 ; "encoderStatus" = "error" ; chapterNumber++ ))  # currently handbrakecli isn't exiting on errors properly 
   for (( count=1; count<50; count++ ))
   do
      otherSettings="--markers --chapters $count $chapterOption"
      [ $encodeType=="title" ] && otherSettings="--markers --title $count"
      videoName="$encodeType$count"
      [ "$count" -lt "10" ] && videoName="${encodeType}0$count"
      encode
   done
   mv "$inputFileName" "$DEFAULT_PROCESSED_DIRECTORY"/
}

[ ! -d "$DEFAULT_PROCESSED_DIRECTORY" ] && mkdir "$DEFAULT_PROCESSED_DIRECTORY"  #  creates the processed directory if it doesn't exist

case "$1" in

-h|--help)

   echo
   echo "Usage: auto-handbrakecli-script.sh [OPTION]"
   echo
   echo "-h, --help                     Prints this help information."
   echo
   echo "-c, --chapter [FILE] [TITLE]   Encodes each chapter of the loggest"
   echo "                               title of the iso files in that directory."
   echo "                               File name is optional and title number of"
   echo "                               the file is optional."
   echo
   echo "-t, --title [FILE]             Encodes each title of the iso files in that"
   echo "                               directory."
   echo "                               File name is optional."
   echo
   echo "-d, --directory                Endodes files one directory deep."
   echo
   echo "With no option all video files in the directory will be encoded. Loggest title"
   echo "of an iso file."
   echo "If a file name is given, only that file will be encoded"
   ;;

-c|--chapter)
   encodeType="chapter"
   fileType=( iso )
   chapterOption="--longest"
   if [ -n "$2" ]
   then
      inputFileName="$2"
      [ -n "$3" ] && chapterOption="--title $3"
      isoEncode
   else
      encodeCommand="isoEncode"
      fileSearch
   fi
   ;;

-t|--title)
   encodeType="title"
   fileType=( iso )
   if [ -n "$2" ]
   then
      inputFileName="$2"
      isoEncode
   else
      encodeCommand="isoEncode"
      fileSearch
   fi
   ;;

-d|--directory)
   startingDiretory=`pwd`
   [ ! -d "$DEFAULT_PROCESSED_DIRECTORY" ] && mkdir -p "$DEFAULT_PROCESSED_DIRECTORY"
   [ ! -d "$DEFAULT_OUTPUT_DIRECTORY" ] && mkdir -p "$DEFAULT_OUTPUT_DIRECTORY"
   encodeCommand="fileEncode"
   fileSearch
   for directoryName in *
   do
      if [ -d "$directoryName" ]  # test if it is a true directory
      then
         cd "$directoryName"
         [ ! -d "$DEFAULT_PROCESSED_DIRECTORY" ] && mkdir -p "$DEFAULT_PROCESSED_DIRECTORY"
         [ ! -d "$DEFAULT_OUTPUT_DIRECTORY" ] && mkdir -p "$DEFAULT_OUTPUT_DIRECTORY"
         fileSearch
         cd ../
      fi
   done
   cd $startingDiretory 
   ;;
   

*)
   if [ -n "$1" ]
   then
      inputFileName="$1"
      videoName=${inputFileName%.*}
      fileEncode
   else
      encodeCommand="fileEncode"
      fileSearch
   fi
   ;;
esac

exit 0
