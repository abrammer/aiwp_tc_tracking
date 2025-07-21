#!/usr/bin/bash

git apply patch_gettrk_subroutines.patch

nfconfig=$(nf-config --has-f90)
if [[ $? != 0 ]]; then
    echo "Make sure netcdf libraries are installed"
    echo "Will try to continue in 5s"
    sleep 5
fi

jlib=$(which jasper)
if [[ $? != 0 ]]; then
    echo "Make sure njasper libraries are installed"
    echo "Will try to continue in 5s"
    sleep 5
fi

mkdir ../exec
./init_subs.sh
./build_bacio.sh
./build_w3emc.sh
./build_g2.sh
./build_track.sh
./build_ndate.sh





