# install ace0
git clone --recursive https://github.com/nianticlabs/acezero.git
cd acezero
conda env create -f environment.yml
cd ..

# install colmap
sudo apt update
sudo apt install colmap

# install openmvg
sudo apt-get install libpng-dev libjpeg-dev libtiff-dev libxxf86vm1 libxxf86vm-dev libxi-dev libxrandr-dev
sudo apt-get install graphviz
git clone --recursive https://github.com/openMVG/openMVG.git
cd openmvg
mkdir openMVG_Build && cd openMVG_Build

## Configure and build openMVG
cmake -DCMAKE_BUILD_TYPE=RELEASE ../openMVG/src/
cmake --build . --target install