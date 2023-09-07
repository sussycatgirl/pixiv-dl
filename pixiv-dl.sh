#!/bin/bash

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.


print_curl_err () {
    if [[ $1 -ne 0 ]]; then
        setcolour red
        setcolour bold
        printf "Error:"
        setcolour reset
        printf " Curl failed with code $1\n"
        exit 1
    else
        setcolour bold
        echo "Done."
        setcolour reset
    fi
}

setcolour () {
    case $1 in
      grey)    col=$'\e[90m' ;;
      red)     col=$'\e[91m' ;;
      bold)    col=$'\e[1m'  ;;
      reset)   col=$'\e[0m'  ;;
    esac

    printf "%s" "${col}"
}


URL=$1
if [[ $1 == "" ]]; then
    setcolour bold
    printf "Usage: "
    setcolour grey
    printf "pixiv-dl "
    setcolour reset 
    setcolour grey 
    printf "<URL> [Destination File]\n"
    exit 1
fi

# If destination file name is not specified, it will be set to the illustration name after file info has been extracted
DESTNAME=$2


## Downloading html ##

printf "Downloading webpage to "

mkdir -p /tmp/pixiv-dl
TMPFILE="$(mktemp /tmp/pixiv-dl/XXXXXX.html)"
setcolour grey
printf "$TMPFILE"
setcolour reset
printf " ... "
curl $URL -Lso "$TMPFILE"

print_curl_err $?


## Extracting info from HTML ##

IMGNAME=$(grep -o -E '"illustTitle":"[^"]+"' $TMPFILE)
IMGNAME=${IMGNAME#*illustTitle\":\"}
IMGNAME=${IMGNAME%*\"}

IMGURL=$(grep -o -E '"original":"[^"]+"' $TMPFILE)
IMGURL=${IMGURL#*original\":\"}
IMGURL=${IMGURL%*\"}

rm $TMPFILE

if [[ $IMGNAME == "" || $IMGURL == "" ]]; then
    echo "Error: Failed to extract info. Is the URL correct?"
    exit 1
fi

printf "Extracted info: "
setcolour bold
printf "$IMGNAME"
setcolour reset
printf " - "
setcolour grey
printf "$IMGURL\n"
setcolour reset

if [[ $DESTNAME == "" ]]; then
    EXT=${IMGURL##*.}
    if [[ "$EXT" != "" ]]; then
        DESTNAME="$IMGNAME.$EXT"
    else
        DESTNAME="$IMGNAME"
    fi
fi

# If the destination file already exists, append a number to the file name
if [[ -f "$DESTNAME" ]]; then

    # Seperate the file name and the rest of the path, to avoid replacing relative
    # paths like this if the destination has no extension: ../asdf -> ..1./asdf
    BNAME=$(basename "$DESTNAME")
    PATHPREFIX=${DESTNAME%$BNAME}

    # Now we just count up in a loop until the file doesn't exist
    COUNTER=1
    EXT=${BNAME##*.}
    if [[ "$EXT" == "$BNAME" ]]; then EXT=""; fi
    if [[ "$EXT" != "" ]]; then EXT=".$EXT"; fi
    BNAME="${BNAME%.*}"

    while [[ -f "${PATHPREFIX}${BNAME}.${COUNTER}${EXT}" ]]; do
        COUNTER=$((COUNTER+1))
    done

    DESTNAME="${PATHPREFIX}${BNAME}.${COUNTER}${EXT}"
fi


## Downloading image ##

printf "Downloading image to "
setcolour grey
printf "$DESTNAME"
setcolour reset
printf " ... "


# Pixiv 403's you when you attempt to download the image without setting a proper Referer header
curl -Ls -H "Referer: $URL" -o "$DESTNAME" "$IMGURL"

print_curl_err $?
