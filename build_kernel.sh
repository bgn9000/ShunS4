#!/bin/sh

rm modules.* Module.symvers .missing-syscalls.d .version
rm -f arch/arm/boot/zImage zImage arch/arm/boot/compressed/*.o arch/arm/boot/compressed/.*.cmd arch/arm/boot/compressed/vmlinux arch/arm/boot/compressed/piggy.xzkern arch/arm/boot/compressed/ashldi3.S arch/arm/boot/compressed/vmlinux.lds arch/arm/boot/compressed/lib1funcs.S arch/arm/boot/Image arch/arm/boot/.*.cmd 
rm -rf .tmp* .vm* ..tmp* vmlinux* System.map usr/.initramfs_data.* usr/*.o usr/.*.cmd usr/initramfs_data.cpio usr/gen_init_cpio usr/modules.* init/*.o init/.*.cmd init/modules.*

export PLATFORM="AOSP"
export MREV="JB4.3"
export CURDATE=`date "+%Y%m%d_%H%M%S"`
export MUXEDNAMELONG="ShunS4-$MREV-$PLATFORM-INTL-$CURDATE"
export MUXEDNAMESHRT="ShunS4-$MREV-$PLATFORM-INTL"
export ShunS4Ver="--$MUXEDNAMESHRT--"
export RAMFS_SOURCE=`readlink -f ..`/SGS4-RAMDISKS/$PLATFORM"_INTL-JB4.3"
RAMFS_TMP="/tmp/ramfs-source-sgs4"
export KERNELDIR=`readlink -f .`
export PARENT_DIR=`readlink -f ..`

export CONFIG_$PLATFORM_BUILD=y
export PACKAGEDIR=$PARENT_DIR/Packages/$PLATFORM
#Enable FIPS mode
export USE_SEC_FIPS_MODE=true
export ARCH=arm
export CROSS_COMPILE=$PARENT_DIR/../arm-2012/bin_472/arm-linux-

echo "Remove old Package Files"
rm -rf $PACKAGEDIR/*

echo "Setup Package Directory"
mkdir -p $PACKAGEDIR/system/app
mkdir -p $PACKAGEDIR/system/lib/modules
mkdir -p $PACKAGEDIR/system/etc/init.d

rm -rf $RAMFS_TMP/*
mkdir -p $RAMFS_TMP
cp -R $RAMFS_SOURCE/* $RAMFS_TMP
chmod -R g-w $RAMFS_TMP/*
rm $(find $RAMFS_TMP -name EMPTY_DIRECTORY -print)
rm -rf $(find $RAMFS_TMP -name .git -print)

if [ ! -f $KERNELDIR/.config ];
then
  make VARIANT_DEFCONFIG=jf_INTL_defconfig SELINUX_DEFCONFIG=jfselinux_defconfig SELINUX_LOG_DEFCONFIG=jfselinux_log_defconfig KT_jf_defconfig
fi

. $KERNELDIR/.config

echo "Modding .config file - "$ShunS4Ver
sed -i 's,CONFIG_LOCALVERSION="-KT-SGS4",CONFIG_LOCALVERSION="'$ShunS4Ver'",' .config

nice -n 10 make -j4 || exit 1

echo "Copy modules to Package"
cp -a $(find . -name *.ko -print |grep -v initramfs) $PACKAGEDIR/system/lib/modules/

if [ -e $KERNELDIR/arch/arm/boot/zImage ]; then
	echo "Copy zImage to Package"
	cp arch/arm/boot/zImage $PACKAGEDIR/zImage
	
	echo "Copy KT app"
	cp -v $PARENT_DIR/Packages/com.ktoonsez.KTweaker.apk $PACKAGEDIR/system/app/

	echo "Make boot.img"
	./mkbootfs $RAMFS_TMP | gzip > $PACKAGEDIR/ramdisk.gz
	./mkbootimg --cmdline 'console = null androidboot.hardware=qcom user_debug=31 zcache' --kernel $PACKAGEDIR/zImage --ramdisk $PACKAGEDIR/ramdisk.gz --base 0x80200000 --pagesize 2048 --ramdisk_offset 0x02000000 --output $PACKAGEDIR/boot.img 
	cd $PACKAGEDIR
	cp -R ../META-INF .
	rm ramdisk.gz
	rm zImage
	zip -r ../$MUXEDNAMELONG.zip .
	
	cd $KERNELDIR
else
	echo "KERNEL DID NOT BUILD! no zImage exist"
fi;
