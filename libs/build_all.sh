#!/bin/bash

nfconfig=$(nf-config)
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

./init_subs.sh
./build_bacio.sh
./build_w3emc.sh
./build_g2.sh
./build_track.sh





