#!/bin/bash

usage() {
	echo "$(basename $0) [-u username] [-e email] "
}

USERNAME=$(git config -l | grep user.name | cut -d '=' -f 2)
USERMAIL=$(git config -l | grep user.email | cut -d '=' -f 2)

while getopts "u:e:" OPTION; do
    case "$OPTION" in
        u)
            USERNAME=${OPTARG}
            ;;
        e)
            USERMAIL=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

if [ "$USERNAME" == "" ] || [ "$USERMAIL" == "" ]; then
	usage
	exit 1
fi

# 1. descargamos del parche creado para raspberry-pi y la configuración del
#    kernel necesaria
wget https://tenllado.github.io/linux-rt-docs/patch-5.10.92-v7-dovetail_rpi.patch.bz2
wget https://tenllado.github.io/linux-rt-docs/config_linux_rpi_xenomai

# 2. creamos la copia de trabajo con el repo de raspberrypi
mkdir linux-xenomai
cd linux-xenomai
git init
git config user.email "$USERNAME"
git config user.name "$USERMAIL"
git remote add origin https://github.com/raspberrypi/linux
git fetch --depth 1 origin 650082a559a570d6c9d2739ecc62843d6f951059
git checkout -b 5.10.92 FETCH_HEAD

# 3. Creamos un nuevo branch para el parche, lo aplicamos y añadimos los
# cambios a la rama
git checkout -b 5.10.92-dovetail
bzcat ../patch-5.10.92-v7-dovetail_rpi.patch.bz2 | patch -p1
git add -A
git commit -m "dovetail patch applied"

# 4. Clonamos xenomai y lo preparamos
cd ..
git clone https://source.denx.de/Xenomai/xenomai.git
cd xenomai
git checkout -b v3.2.x origin/stable/v3.2.x
scripts/bootstrap

# 5. Aplicamos el parche xenomai
cd ../linux-xenomai
git checkout -b 5.10.92-dovetail-xenomai
../xenomai/scripts/prepare-kernel.sh --arch=arm
git add -A
git commit -m "xenomai patch for cobalt applied"

# 6. Configuramos el kernel
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
export KERNEL=kernel7
#make bcm2709_defconfig
cp ../config_linux_rpi_xenomai .config
make oldconfig

# 7. Compilamos el kernel
make -j4 zImage modules dtbs

# 8. Intalamos el kernel en un directorio local
mkdir ../kernel-xenomai
make INSTALL_MOD_PATH=../kernel-xenomai/ modules_install
make INSTALL_DTBS_PATH=../kernel-xenomai/boot dtbs_install
cp arch/arm/boot/zImage ../kernel-xenomai/boot/kernel7-xenomai.img

# 9. Creamos un tar.gz para distribuirlo
cd ../kernel-xenomai
rm lib/modules/5.10.92-v7-cobalt+/build
rm lib/modules/5.10.92-v7-cobalt+/source
fakeroot -- tar cvzf ../kernel-xenomai.tar.gz *
