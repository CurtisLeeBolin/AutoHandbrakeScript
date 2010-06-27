#! /bin/bash
#ahs.sh

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
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
###############################################################################

fileType=( avi flv iso mov mp4 mpeg mpg ogg ogm ogv wmv )

readonly DEFAULT_VIDEO_SETTINGS="--encoder x264 --quality 22.5 --detelecine --decomb --loose-anamorphic"
#readonly DEFAULT_VIDEO_SETTINGS="--encoder x264 --two-pass --turbo --vb 768 --decomb --loose-anamorphic"
readonly DEFAULT_X264_SETTINGS="--x264opts b-adapt=2:rc-lookahead=50"
readonly DEFAULT_AUDIO_SETTINGS="--audio 1 --aencoder faac --ab 128 --mixdown dpl2 --arate 48 --drc 2.5"
readonly DEFAULT_SUBTITLE_SETTINGS="--native-language eng --subtitle-forced scan --subtitle scan"
readonly DEFAULT_CHAPTER_SETTINGS="--markers"
readonly DEFAULT_CONTAINER_TYPE="mkv"
readonly DEFAULT_CONTAINER_SETTINGS="--format $DEFAULT_CONTAINER_TYPE"
readonly DEFAULT_PROCESSED_DIRECTORY="processed"
readonly DEFAULT_LOG_FILE="handbrake.log"
otherSettings="--markers"
mode=""
titleOptions=""
fileName=""
cropFlag=false

Logger ()
{
   echo "$(date +'[ %d %b %Y %H:%M:%S ]') :: $*" | tee -a "$DEFAULT_PROCESSED_DIRECTORY"/"$DEFAULT_LOG_FILE"
}

CheckForAc3 ()
{
   if [ "${inputFileName##*.}" == "iso" ]
   then
      audioSettings="--audio 1 --aencoder ac3"
   else
      inputAudioCodec=`HandBrakeCLI --scan -i "$inputFileName" 2>&1 | grep "Audio: ac3"`
      audioSettings="$DEFAULT_AUDIO_SETTINGS"
   fi
}

FileTranscode ()
{
   CheckForAc3
   Logger "Encoding $inputFileName to $videoName.$DEFAULT_CONTAINER_TYPE ..."
   mv "$inputFileName" "$DEFAULT_PROCESSED_DIRECTORY"/
   HandBrakeCLI $DEFAULT_VIDEO_SETTINGS $DEFAULT_X264_SETTINGS $audioSettings $DEFAULT_SUBTITLE_SETTINGS $DEFAULT_CONTAINER_SETTINGS $DEFAULT_CHAPTER_SETTINGS $otherSettings --input "$DEFAULT_PROCESSED_DIRECTORY"/"$inputFileName" --output "$outputDirectory""$videoName"."$DEFAULT_CONTAINER_TYPE" || encoderStatus="error"
   Logger "Encoding Completed."
}

FileSearch ()
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

IsoTranscode ()
{
   mv "$inputFileName" "$DEFAULT_PROCESSED_DIRECTORY"/
   outputDirectory="${inputFileName%.*}/"
   [ ! -d "$outputDirectory" ] && mkdir -p "$outputDirectory"  #  creates the output directory if it doesn't exist
   #   encoderStatus="run"                                                      #
   #   for (( count=1 ; "$encoderStatus" == "error" ; count++ ))  # currently handbrakecli isn't exiting on errors properly 
   for (( count=1; count<50; count++ ))
   do
      [ "$count" -lt "10" ] && number=0$count || number=$count
      [ $mode == "TitleMode" ] && otherSettings="--title $count" && videoName="Title$number"
      [ $mode == "ChapterMode" ] && otherSettings="--chapters $count $titleOptions" && videoName="Chapter$number"
      FileTranscode
   done
}

ChapterMode ()
{
   [ ! -d "$DEFAULT_PROCESSED_DIRECTORY" ] && mkdir -p "$DEFAULT_PROCESSED_DIRECTORY"
   fileType=( iso )
   [ -z titleOptions ] && titleOptions="--main-feature"
   if [ -n "$fileName" ]
   then
      inputFileName="$fileName"
      IsoTranscode
   else
      encodeCommand="IsoTranscode"
      FileSearch
   fi
}

TitleMode ()
{
   [ ! -d "$DEFAULT_PROCESSED_DIRECTORY" ] && mkdir -p "$DEFAULT_PROCESSED_DIRECTORY"
   fileType=( iso )
   if [ -n "$fileName" ]
   then
      inputFileName="$fileName"
      if [ -n "$titleOptions" ]
      then
         otherSettings="$titleOptions"
         FileTranscode
      else
         [ -z titleOptions ] && titleOptions="--main-feature"
         otherSettings="$titleOptions"
         IsoTranscode
      fi
   else
      encodeCommand="IsoTranscode"
      FileSearch
   fi
}

DirectoryMode ()
{
   startingDiretory=`pwd`
   [ ! -d "$DEFAULT_PROCESSED_DIRECTORY" ] && mkdir -p "$DEFAULT_PROCESSED_DIRECTORY"
   encodeCommand="FileTranscode"
   FileSearch
   for directoryName in *
   do
      if [ -d "$directoryName" && "$directoryName" != "$DEFAULT_PROCESSED_DIRECTORY" ]  # test if it is a true directory
      then
         cd "$directoryName"
         [ ! -d "$DEFAULT_PROCESSED_DIRECTORY" ] && mkdir -p "$DEFAULT_PROCESSED_DIRECTORY"
         FileSearch
         cd ../
      fi
   done
   cd "$startingDiretory" 
}

SimpleDirectoryMode ()
{
   [ ! -d "$DEFAULT_PROCESSED_DIRECTORY" ] && mkdir -p "$DEFAULT_PROCESSED_DIRECTORY"
   encodeCommand="FileTranscode"
   FileSearch
}

FileMode ()
{
   [ ! -d "$DEFAULT_PROCESSED_DIRECTORY" ] && mkdir -p "$DEFAULT_PROCESSED_DIRECTORY"
      inputFileName="$fileName"
      videoName="${inputFileName%.*}"
      FileTranscode
}

ErrorFound ()
{
   [ -z "$error" ] && error="Unrecognized option: $@"
   echo
   echo "**********Error with options**********"
   echo
   echo "Error: $error"
   echo
   echo "**************************************"
   PrintUsage
   exit 1
}

PrintUsage ()
{
echo
echo "Usage: $0 [OPTION]"
cat << EOF

-h, --help
   Prints this help information.

Modes:

   -c, --chapter [TITLE]
      Transcodes each chapter of the loggest title or title number given of the
      iso file or files in that directory.

   -t, --title [TITLE]
      Transcodes each title of the iso file or files in that directory or the
      title you selected.

   -d, --directory
      Transcodes files one directory deep.

Other Options:
   
   -i, --input [FILE]
      If a file name is given, only that file will be encoded

   -C, --crop <T:B:L:R>
      Manually sets the cropping
      Top:Bottom:Left:Right 

   -m, --mythtv [4:3 or 16:9]
      Sets extra setting for mythtv recordings.

With no option all video files in the directory will be transcoded and loggest
title of an iso file.

EOF
}

if [ -z "$1" ]
then
   SimpleDirectoryMode
else
   until [ -z "$1" ]; do
   	# use a case statement to test vars. we always test
   	# test $1 and shift at the end of the for block.
   	case $1 in
   	   -h|--help)
            PrintUsage
            exit 0
         ;;
         -c|--chapter )
   		   # shift, so the string after -c or --chapter becomes our new $1
   	   	[ -n "$mode" ] && error="Only one mode can be selected." && ErrorFound
      	   shift
      	   [ -n "$1" -a "$1" != "-*" ] && titleOptions="--title $1"
      	   mode="ChapterMode"
         ;;
      	-t|--title )
      	   [ -n "$mode" ] && error="Only one mode can be selected." && ErrorFound
      	   [ -n "$2" -a "${2:0:1}" != "-" ] && shift && titleOptions="--title $1"
      	   mode="TitleMode"
      	;;
      	-d|--directory )
      	   [ -n "$mode" ] && error="Only one mode can be selected." && ErrorFound
      	   [ -n "$2" -a "$2" = "-i" ] && error="Can't use input file with directory mode" && ErrorFound
      	   mode="DirectoryMode"
   		;;
         -C|--crop )
            [ $cropFlag ] && error="Only one crop can be set." && ErrorFound
            cropFlag=true
            shift
            otherSettings="$otherSettings --crop $1"
         ;;
      	-i|--input )
      	   shift
      	   if [ -n "$1" -a "${1:0:1}" != "-" ] # "${1:0:1}" means get the first charater of string $1
      	   then
      	      fileName="$1"
      	   else
      	      error="$1 is not a valid input file."
      	      ErrorFound
      	   fi
      	;;
      	-m|--mythtv )
      	   shift
      	   [ -z "$1" ] && error="Options required for mythtv mode." && ErrorFound
      	   if [ "$1" == "4:3" ]
      	   then
      	      otherSettings="$otherSettings --crop 6:0:0:0 --width 640 --height 480"
      	   elif [ "$1" == "16:9" ]
      	   then
      	      otherSettings="$otherSettings --crop 66:60:0:0 --width 640 --height 360"
      	   else
      	      error="$1 is not a valid option for mythtv mode."
      	      ErrorFound
      	   fi
      	;;
      	* )
      		ErrorFound $@
      	;;
      esac

     	shift

     	if [ "$#" = "0" ]; then
     		break
     	fi
   done
fi

[ -z "$mode" ] && mode="FileMode"
$mode

exit 0
