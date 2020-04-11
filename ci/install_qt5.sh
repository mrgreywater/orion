#!/bin/bash
set -e -x

# https://github.com/benlau/qtci

if [[ ! -d $HOME/Qt ]]; then mkdir $HOME/Qt; fi

cd $HOME/Qt

export QT_VERSION=$1
ENVFILE=qt-${QT_VERSION}.env

sudo apt-fast -y install axel libssl-dev libssl1.0.0 libxkbcommon-x11-0 > /dev/null

if [[ ! -f ./${ENVFILE} ]]; then
    wget -q https://raw.githubusercontent.com/benlau/qtci/master/bin/extract-qt-installer
    chmod +x extract-qt-installer

    INSTALLER=qt-opensource-linux-x64-${QT_VERSION}.run
    axel --quiet -n 16 https://download.qt.io/archive/qt/$(echo ${QT_VERSION} |cut -d "." -f-2)/${QT_VERSION}/${INSTALLER}

    ./extract-qt-installer --list-packages $PWD/$INSTALLER
    ./extract-qt-installer $PWD/$INSTALLER $PWD
else
    rm -f ./$ENVFILE
fi

cat << EOM > $ENVFILE
export QTDIR=$PWD/${QT_VERSION}/gcc_64
export PATH=$QTDIR/bin:$PATH
EOM

