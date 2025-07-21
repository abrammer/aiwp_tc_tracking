cd NCEPLIBS-g2
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=${CONDA_PREFIX} -DCMAKE_PREFIX_PATH=${CONDA_PREFIX} ..
make -j2
make test
make install
