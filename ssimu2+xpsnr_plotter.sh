#!/bin/bash

# MIT License

# Copyright (c) 2023 Gianni Rosato

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# ~

# Usage: ./ssimu2+xpsnr_plotter.sh [input.y4m] [output.csv] [x264|x265|svt] [q_begin] [q_end] [q_increment] [preset]
# Dependencies: FFmpeg, ssimulacra2_rs, bc, ffmpeg_xpsnr (custom binary)

infile="$1"
extension=${1##*.}
noextension=${1%.*}
noextension=${noextension##*/}
noextension2=${2%.*}
noextension2=${noextension2##*/}
algorithm=$3

Q_BEGIN=$4
Q_END=$5
Q_INC=$6

preset=$7

PINK="\033[38;5;206m"
RED="\033[38;5;196m"
GREY="\033[38;5;248m"
BOLD="\033[1m"
BLINK="\033[5m"
RESET="\033[0m"

cur_q=$Q_BEGIN
outdir=$noextension2

case $algorithm in
	x264)
		algorithm=1
		;;
	x265)
		algorithm=2
		;;
	svt)
		algorithm=3
		;;
	*)
		algorithm=0
		;;
esac

# Check usage
if [ $# -ne 7 ]; then
    echo -e "	${PINK}${BOLD}SSIMULACRA2${RESET} ${GREY}${BLINK}+${RESET} ${PINK}${BOLD}XPSNR${RESET} ${BOLD}Plotter${RESET}"
    echo -e "	${GREY}Usage:${RESET} ${PINK}./${RESET}ssimu2+xpsnr_plotter.sh [${PINK}input.y4m${RESET}] [${PINK}output.csv${RESET}] [${PINK}x264${RESET}|${PINK}x265${RESET}|${PINK}svt${RESET}] [${PINK}q_begin${RESET}] [${PINK}q_end${RESET}] [${PINK}q_increment${RESET}] [${PINK}preset${RESET}]"
    exit 1
fi

if [ $algorithm -eq 3 ] ; then
	exte="ivf"
	encoding () {
		u=$( ffmpeg -y -hide_banner -loglevel quiet -i "$infile" -pix_fmt yuv420p10le -strict -2 -f yuv4mpegpipe - | /usr/bin/time -f "%e %S %U" SvtAv1EncApp -i - -b "$outdir/$noextension-$1.$exte" --crf $1 --preset $preset --input-depth 10 --tune 2 --aq-mode 2 --enable-cdef 0 --enable-qm 1 --qm-min 0 2>&1)
		echo "$u" >> "$outdir/tail-$1.txt"
		s=$( cat "$outdir/tail-$1.txt" | tail -n 1 2>&1)
		echo "$s"
		rm "$outdir/tail-$1.txt"
	}
elif [ $algorithm -eq 2 ] ; then
	exte="265"
	encoding () {
		u=$( /usr/bin/time -f "%e %S %U" x265 --input "$infile" --output "$outdir/$noextension-$1.$exte" --output-depth 10 --profile main10 --crf $1 --preset $preset 2>&1)
		echo "$u" >> "$outdir/tail-$1.txt"
		s=$( cat "$outdir/tail-$1.txt" | tail -n 1 2>&1)
		echo "$s"
		rm "$outdir/tail-$1.txt"
	}
elif [ $algorithm -eq 1 ] ; then
	exte="264"
	encoding () {
		u=$( /usr/bin/time -f "%e %S %U" x264 --preset $preset --crf $1 --open-gop "$infile" -o "$outdir/$noextension-$1.$exte" 2>&1)
		echo "$u" >> "$outdir/tail-$1.txt"
		s=$( cat "$outdir/tail-$1.txt" | tail -n 1 2>&1)
		echo "$s"
		rm "$outdir/tail-$1.txt"
	}
elif [ $algorithm -eq 0 ] ; then
	echo "${RED}Incorrect algorithm argument.${RESET} Specify either ${PINK}x264${RESET}, ${PINK}x265${RESET}, or ${PINK}svt${RESET}."
	rm $output_file
fi

get_bitrate () {
    if [ $algorithm -eq 1 ] ; then
    	ffmpeg -hide_banner -loglevel quiet -y -i "$1" -c copy -an "$1.mp4"
    	ffprobe -hide_banner -loglevel quiet -show_format "$1.mp4" | grep bit_rate | tr -dc ".0123456789-"
    	rm "$1.mp4"
    elif [ $algorithm -eq 2 ] ; then
    	ffmpeg -hide_banner -loglevel quiet -y -i "$1" -c copy -an "$1.mp4"
    	ffprobe -hide_banner -loglevel quiet -show_format "$1.mp4" | grep bit_rate | tr -dc ".0123456789-"
    	rm "$1.mp4"
    elif [ $algorithm -eq 3 ] ; then
        ffprobe -hide_banner -loglevel quiet -show_format "$1" | grep bit_rate | tr -dc ".0123456789-"
    fi
}

do_ssimu2 () {
    ssimulacra2_rs video -f 14 "$1" "$2" | grep Mean | tr -dc ".0123456789-"
}

do_xpsnr () {
    if [ $algorithm -eq 1 ] ; then
	ffmpeg_xpsnr -y -hide_banner -loglevel quiet -i "$1" -i "$2" -lavfi xpsnr=stats_file=$outdir/xpsnr.log -f null -
    elif [ $algorithm -eq 2 ] ; then
	ffmpeg_xpsnr -y -hide_banner -loglevel quiet -i "$1" -i "$2" -lavfi xpsnr=stats_file=$outdir/xpsnr.log -f null -
    elif [ $algorithm -eq 3 ] ; then
	ffmpeg -y -hide_banner -loglevel quiet -i "$2" -pix_fmt yuv420p10le -strict -2 -f yuv4mpegpipe - | ffmpeg_xpsnr -y -hide_banner -loglevel quiet -i "$1" -i - -lavfi xpsnr=stats_file=$outdir/xpsnr.log -f null - 2>&1
    fi
	# Extract XPSNR values
	y_psnr=$(cat "$outdir/xpsnr.log" | tail -n 1 | grep "Y" | awk '{print $6}')
	u_psnr=$(cat "$outdir/xpsnr.log" | tail -n 1 | grep "U" | awk '{print $8}')  
	v_psnr=$(cat "$outdir/xpsnr.log" | tail -n 1 | grep "V" | awk '{print $10}')
	rm "$outdir/xpsnr.log"
	# Calculate weighted XPSNR
	weighted_xpsnr=$(bc <<< "scale=8; ($y_psnr * 4 + $u_psnr + $v_psnr) / 6")
	# Print result  
	echo "$weighted_xpsnr"
}

mkdir "$outdir"

echo "q bitrate xpsnr ssimu2 real sys usr" >> $2

done=0
while [[ $done -eq 0 ]] ; do
    echo -en "Encoding at ${PINK}Q$cur_q${RESET} ... "
    
    time=$(encoding $cur_q)
    timec=$(echo $time | awk '{print $1}')
    echo -n "$cur_q " >> $2
    echo -e "Encoded at ${PINK}Q$cur_q${RESET} in ${PINK}$timec${RESET} seconds"
    
    fname="$outdir/$noextension-"$cur_q"."$exte""
    bitrate=$(get_bitrate "$fname")
    echo -n "$bitrate " >> $2
    echo -n "Got bitrate " && echo -e "${PINK}$bitrate${RESET}"
    # echo -n "Got bitrate $bitrate"
    
    xpsnr=$(do_xpsnr "$infile" "$fname")
    echo -n "$xpsnr " >> $2
    echo -e "Got average Weighted XPSNR across frames: ${PINK}$xpsnr${RESET}"
    
    ssim2=$(do_ssimu2 "$infile" "$fname")
    echo -n "$ssim2 " >> $2
    echo " Complete" && echo -e "Got average SSIMULACRA2 across frames: ${PINK}$ssim2${RESET} \n"
    
    echo "$time" >> $2
    
    if [[ $cur_q -eq $Q_END ]] ; then
    	# rm *.lwi
        done=1
    fi
    cur_q=$(($cur_q + $Q_INC))
done
