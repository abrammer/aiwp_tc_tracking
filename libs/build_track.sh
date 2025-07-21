repodir=$(dirname $(readlink -f ${BASH_SOURCE[0]} ))
echo ${repodir}
cd GFDL-VortexTracker
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=${CONDA_PREFIX} -DCMAKE_PREFIX_PATH=${CONDA_PREFIX} ../code
make -j2
make test
make install

cp -fv ${repodir}/GFDL-VortexTracker/code/exec/*.x ${repodir}/../exec  
