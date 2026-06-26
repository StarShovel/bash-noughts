#!/bin/bash

# Bash Noughts & Crosses - a Bash implementation of the simple game known as
# 'Noughts & Crosses' or 'Tic Tac Toe'.
#
# Copyright (C) 2026 James Gibbon
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Version 1.0 - June 2026.
# Requires Bash >= 4.3


cleanup () {
 printf '\e[?1000l\e[?1006l' # disable mouse tracking
 while IFS= read -r -t 0.005 -n 1 _; do :; done # drain any spurious mouse input

 # restore terminal normality
 printf "%s%s" "$curnorm"

 stty sane
 printf '\e[%d;1H' $LINES
 exit 0
}

getclick () {
 local -n mb=$1 mx=$2 my=$3
 local ev ch

 # swallow any pending junk / impatient clicks
 while IFS= read -rsn1 -t 0.01 ch; do :; done

 while : ; do
    ev=
    while IFS= read -rsn1 ch; do
       ev+="$ch"
       [[ $ch == [Mm] ]] && break
    done
    [[ ${ev: -1} == M ]] && break
 done

 [[ $ev =~ $re ]]

 (( mb = BASH_REMATCH[1], mx = BASH_REMATCH[2], my = BASH_REMATCH[3] ))

 # swallow the user's release
 if (( mb < 64 )); then
    while IFS= read -rsn1 ch; do
       ev+="$ch"
       [[ $ch == m ]] && break
    done
 fi
}

announce () {
 local m=$1
 printf '\e[3;23H'
 if (( m == 9 )); then
    printf "ＣＯＭＰＵＴＥＲ　ＷＩＮＳ!"
 elif (( m == 1 )); then
    printf "ＹＯＵ　ＷＩＮ!"
 else 
    printf "ＩＴ’Ｓ　Ａ　ＤＲＡＷ"
 fi
}

printboard () {
 top='   ┌────┬────┬────┐'
 row='   │    │    │    │'
 mid='   ├────┼────┼────┤'
 bot='   └────┴────┴────┘'

 printf '\e[2;1H'
 printf '%s\n' "$top" "$row" "$mid" "$row" "$mid" "$row" "$bot"
}

iswin () {
 local mrk=$1 brd=$2
 local a b c line

 for line in "${wins[@]}"; do
    read -r a b c <<< "$line"
    [[ ${brd:a:1} == $mrk && ${brd:b:1} == $mrk && ${brd:c:1} == $mrk ]] && return 0
 done

 return 1
}

boardscore () {

 local brd=$1
 local -i mark=$2
 local -i depth=$3
 local -i othermark sq bestscore n

 if (( depth == maxdepth)); then
    (( rscore = 0 ))
 else
    if [[ -v scorecache[$brd] ]]; then
       (( rscore = scorecache[$brd] ))
    else    
       (( othermark = 10 - mark )) # flip between 1 & 9
   
       if iswin "$othermark" "$brd"; then
          (( rscore = othermark - 5 ))
       elif [[ $brd != *0* ]]; then
          (( rscore=0 ))
   
       else
          if (( mark == 9 )); then
             bestscore=-999  # computer wants to maximise
          else
             bestscore=999   # human wants to minimise
          fi
   
          for sq in {0..8}; do
   
             (( ${brd:$sq:1} )) && continue
             nbrd="${brd:0:sq}${mark}${brd:sq+1}"
             boardscore $nbrd $othermark $((depth+1))
             (( n = rscore ))
   
             if (( mark == 9 )); then
                (( n > bestscore )) && (( bestscore=n ))
             else
                (( n < bestscore )) && (( bestscore=n ))
             fi
   
          done
   
          (( rscore = bestscore ))
       fi
       scorecache[$brd]=$rscore
    fi
 fi
}

printmark () {
 local pindex=$1 pmark=$2
 local pcol prow px py

 pcol=$(( pindex % 3 ))
 prow=$(( pindex / 3 ))

 px=$(( 6 + pcol * 5 ))
 py=$(( 3 + prow * 2 ))

 printf '\e[%d;%dH%s' $py $px $pmark
}

### MAIN

declare -i maxdepth

(( maxdepth=6 ))
while getopts ":c" opt; do
  [[ $opt = c ]] && (( maxdepth=2 ))
done

curoff=$'\e[?25l'   # hide cursor
curnorm=$'\e[?25h'  # show cursor
stty -echo

printf "%s" "$curoff"
printf '\033[2J\033[H' # clear

# mouse reporting
printf '\e[?1000h\e[?1006h'
declare -r re=$'\x1b\\[<([0-9]+);([0-9]+);([0-9]+)M'

trap cleanup EXIT INT

declare -i score csq bestmove rscore comphighscore
declare -i mcol mrow vb vx vy msq opp step
declare -A scorecache

declare board="000000000"
declare nboard
declare -a bestmoves

declare -r wins=(
  "0 1 2"
  "3 4 5"
  "6 7 8"
  "0 3 6"
  "1 4 7"
  "2 5 8"
  "0 4 8"
  "2 4 6"
)

printboard

while : ; do

  while : ; do
     getclick vb vx vy
     if (( vb == 0 )) && (( vx >= 4 && vx <= 18 )) && (( vy >= 3 && vy <= 8 )); then
        mcol=$(( (vx - 4) / 5 ))
        mrow=$(( (vy - 3) / 2 ))
        msq=$(( mrow * 3 + mcol )) 
        ! (( ${board:msq:1} )) && break
     fi
  done

  board="${board:0:msq}1${board:msq+1}"
  printmark $msq "❌"

  if iswin 1 $board; then
     announce 1
     break
  elif [[ $board != *0* ]]; then
     announce 0
     break
  fi

  #computer's turn

  (( comphighscore=-999 ))
  bestmoves=()

  for csq in {0..8} ; do 
     (( ${board:$csq:1} )) && continue
     nboard="${board:0:csq}9${board:csq+1}"
     boardscore $nboard 1 0
     (( score=rscore ))
     if (( score > comphighscore )); then
        (( comphighscore=score ))
        bestmoves=( "$csq" )
     elif (( score == comphighscore )); then
        bestmoves+=( $csq )
     fi
  done

  (( bestmove = bestmoves[RANDOM % ${#bestmoves[@]}] ))

  board="${board:0:bestmove}9${board:bestmove+1}"
  printmark $bestmove "⭕"
  
  if iswin 9 $board; then
     announce 9
     break
  elif [[ $board != *0* ]]; then
     echo DRAW
     break
  fi

done
