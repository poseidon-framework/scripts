#!/bin/bash

wdir="/tmp/trident_presentation"

if [ -d "$wdir" ]; then rm -Rf $wdir; fi
mkdir $wdir
cd $wdir

# Press enter to go through the commands

present () {
  clear
  echo $2
  echo ""
  echo -e "\033[1m$1\033[0m"
  read -p ""
  eval $1
  read -p ""
}

present "trident" "See subcommands and help"

present "trident list --remote --packages" "List packages in the public repository"

present "trident fetch -d . -f '*2020_Immel_Moldova*,*2020_Wang_subSaharanAfrica*'" "Download specific packages"

present "tree" "A two-package repository"

present "trident summarise -d ." "Get summary statistics"

present "trident list -d . --individuals -j Country" "List individual-wise information"

present "trident forge -d . -f '<HYR002>,<Gordinesti>' -o test -n Testpackage" "Merge individuals/groups/packages to form a new package"

