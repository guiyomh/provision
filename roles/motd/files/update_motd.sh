#!/bin/bash
echo -e "\e[38;5;39m"
figlet -c $HOSTNAME
echo -e "\e[0m"
/usr/bin/FireMotD.sh
echo -e "\e[38;5;17m          \e[38;5;39mDate \e[38;5;93m=  \e[38;5;27m$(date)"
echo -e "\e[0m"