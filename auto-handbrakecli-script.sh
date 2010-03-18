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

fileType=( avi flv iso mkv mp4 mpeg mpg wmv )

videoSettings="--encoder x264 --two-pass --turbo --vb 768 --decomb --loose-anamorphic"
x264Settings="--x264opts b-adapt=2:rc-lookahead=50"
#x264Settings="--x264opts subq=6:partitions=all:8x8dct:me=umh:frameref=5:bframes=3:b-pyramid=1:weightb=1"
#x264Settings="--x264opts ref=6:mixed-refs=1:bframes=3:b-pyramid=1:weightb=1:subme=7:trellis=2:analyse=all:8x8dct=1:no-fast-pskip=1:no-dct-decimate=1:me=umh:merange=64:filter=-2,-1:direct=auto"
audioSettings="--audio 1 --aencoder faac --ab 128 --mixdown dpl2 --arate 48 --drc 2.5"
subtitleSettings="--native-language eng --subtitle-forced scan --subtitle scan"
otherSettings="--markers"
containerType="mkv"
containerSettings="--format $containerType"

readonly DEFAULT_OUTPUT_FOLDER="output"
processedFolder="processed"
logFile="handbrake.log"

logger ()
{
   echo "$(date +'[ %d %b %Y %H:%M ]') :: $*" | tee -a "$logFile"
}

checkForAc3 ()
{
   # Checks for ac3 audio
   inputAudioCodec=`mplayer -vo null -ao null -frames 0 -identify 2>&1 /dev/null "$inputFileName" | grep "^ID_AUDIO_CODEC=a52"`

   # if ac3 is detected, then ac3 pass through, else default audio setting
   [ "$inputAudioCodec" =  "ID_AUDIO_CODEC=a52" ] && audioSettings="--audio 1 --aencoder ac3"
}

encode ()
{
   checkForAc3
   logger "Encoding $inputFileName to $videoName.$containerType ..."
   HandBrakeCLI $videoSettings $x264Settings $audioSettings $subtitleSettings $otherSettings $containerSettings --input "$inputFileName" --output "$outputFolder"/"$videoName"."$containerType" || encoderStatus="error"
   logger "Encoding Completed."
}

fileSearch ()
{
#   [ ! -d "$outputFolder" ] && mkdir "$outputFolder"  #  creates the output folder if it doesn't exist
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
   outputFolder="$DEFAULT_OUTPUT_FOLDER"
   [ ! -d "$outputFolder" ] && mkdir -p "$outputFolder"  #  creates the output folder if it doesn't exist
   encode
   mv "$inputFileName" "$processedFolder"
}

chapterEncode ()
{
   encoderStatus="run"
   outputFolder="$DEFAULT_OUTPUT_FOLDER/${inputFileName%.*}"
   chapterNumber=1
   [ ! -d "$outputFolder" ] && mkdir -p "$outputFolder"  #  creates the output folder if it doesn't exist
#   until [ "encoderStatus" = "error" ]  # currently handbrakecli isn't exiting on errors properly 
   until [ $chapterNumber == 50 ]
   do
      otherSettings="--chapters $chapterNumber $titleOption"
      videoName="$chapterNumber"
      encode
      ((chapterNumber++))
   done
   mv "$inputFileName" "$processedFolder"
}

titleEncode ()
{
   encoderStatus="run"
   outputFolder="$DEFAULT_OUTPUT_FOLDER/${inputFileName%.*}"
   titleNumber=1
   [ ! -d "$outputFolder" ] && mkdir -p "$outputFolder"  #  creates the output folder if it doesn't exist
   until [ "encoderStatus" = "error" -o $titleNumber == 50 ]
   do
      otherSettings="--title $titleNumber"
      videoName="$titleNumber"
      encode
      ((titleNumber++))
   done
   mv "$inputFileName" "$processedFolder"
}

[ ! -d "$processedFolder" ] && mkdir "$processedFolder"  #  creates the processed folder if it doesn't exist
#[ ! -d "$outputFolder" ] && mkdir "$outputFolder"  #  creates the output folder if it doesn't exist

case "$1" in

-h|--help)

   echo
   echo "Usage: handbrake [OPTION]"
   echo
   echo "-h, --help                     Prints this help information."
   echo
   echo "-c, --chapter [FILE] [TITLE]   Encodes each chapter of the loggest title of the iso files"
   echo "                               in that directory"
   echo "                               File name is optional and title number of the file is optional"
   echo
   echo "-t, --title [FILE]             Encodes each title of the iso files in that directory"
   echo "                               File name is optional"
   echo
   echo "With no option all video files in the directory will be encoded. Loggest title of an iso file."
   echo "If a file name is given, only that file will be encoded"
   ;;

-c|--chapter)
   if [ -n "$2" ]
   then
      inputFileName="$2"
      if [ -n "$3" ]
      then
         chapterOption="--title $3"
      else
         chapterOption="--longest"
      fi
      chapterEncode
   else
      encodeCommand="chapterEncode"
      fileSearch
   fi
   ;;

-t|--title)
   if [ -n "$2" ]
   then
      inputFileName="$2"
      titleEncode
   else
      encodeCommand="titleEncode"
      fileSearch
   fi
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
