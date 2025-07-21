cd NCEPLIBS-w3emc
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=${CONDA_PREFIX} -DCMAKE_PREFIX_PATH=${CONDA_PREFIX} ..
make -j2
make install

