cd NCEPLIBS-bacio
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=${CONDA_PREFIX} ..
make -j2
make install
