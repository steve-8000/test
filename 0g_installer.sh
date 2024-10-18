#!/bin/bash

# Read all the text into a variable
text="......                                                                   .',:clllllc;,.               .,cdkO000KK0ko:.                                                            ,ldddoooooooooooo:.          ,oxxxxkkOO000KKKXXk;                                                        ,odddddddolclooooooooc.      'oddddxxxolllok00KKKXXk.                                                     lxdddddc'.     .'coooooo;    ;ddddddl'       .;k0KKKXX,                                                   :xxxxdo.           .looooo,  .oooddo.            c00KKKK.                                                  xxxxxx.         .   .oooool  :ooooo'              :ooddd'                                                 .xxxxxo        'll.   looooo. cooooo.    .................                                                 .xxxxxx      'oo'     oooooo  ;ooooo,   .:::cccccclxkkOOO,                                                  cxxxxx:   ,oo'     .lddooo;  .oooooo,           .cxxxkkx                                                    oxxo'  ;do'     .:ddddddc    .ooooool,.      .:dddxxxd.                                                     :' .;dxxdlcccldddddddo,      .:oooooooolclloddddddd:                                                         .xxxxxxxxxxxxxxddd;          .;oooooooooooooddo;.                                                            ':ldxxxxxxxoc;.               .';:clllllc;'.                                                                    ....."

# Function to center text
center_text() {
    local term_width term_height text_height
    term_width=$(tput cols)
    term_height=$(tput lines)
    text_height=$(echo "$1" | wc -l)
    # Calculate the top margin
    top_margin=$(( (term_height - text_height) / 2 ))
    # Print top margin
    for ((i = 0; i < top_margin; i++)); do
        echo ""
    done
    # Print centered text
    echo "$1" | while IFS= read -r line; do
        printf "%*s\n" $(((${#line} + term_width) / 2)) "$line"
    done
}

clear
center_text "$text"
