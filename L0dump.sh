#!/bin/bash
# Takes level0 dump
# Tested against CentOS7

SFDISK="/sbin/sfdisk"
BLKID="/sbin/blkid"
VGCFGBACKUP="/sbin/vgcfgbackup"
XFSDUMP="/sbin/xfsdump"

if [ ! -x ${XFSDUMP} ]; then
	echo "Cannot execute ${XFSDUMP}. Exiting." >&2
	exit 1
fi

BACKBASE="/mnt/landisk1"
PROC_MOUNTS="/proc/mounts"

if [ ! -r ${PROC_MOUNTS} ]; then
	echo "Cannot read ${PROC_MOUNTS}. Exiting." >&2
	exit 1
fi

MSTAT=$(cat ${PROC_MOUNTS} | awk -v backbase=${BACKBASE} '{if ($2==backbase) print}')
if [ -z "${MSTAT}" ]; then
	echo "Backup location \"${BACKBASE}\" is not properly mounted. Exiting." >&2
	exit 1
fi

HOSTNAME=$(hostname -s)
BACKDIR=${BACKBASE}/backup/${HOSTNAME}
LIVEDIR=${BACKDIR}/live
OLDDIR=${BACKDIR}/old

if [ -d ${LIVEDIR} ]; then
	if [ -d ${OLDDIR} ]; then
		echo -n "Removing old backup dir... "
		rm -rf ${OLDDIR}
		echo "done."
	fi
	echo -n "Moving ${LIVEDIR} to ${OLDDIR}... "
	mv ${LIVEDIR} ${OLDDIR}
	echo "done."
fi
echo -n "Creating ${LIVEDIR}... "
mkdir -p ${LIVEDIR}
echo "done."

for disk in $(lsblk -l | awk -v disk=disk '{if ($6==disk) print $1}')
do
	dd if=/dev/${disk} of=/dev/null count=1 2> /dev/null
	if [ $? -eq 0 ]; then
		${SFDISK} -d /dev/${disk} > ${LIVEDIR}/sfdisk_${disk}.txt
	fi
done
${BLKID} > ${LIVEDIR}/blkid.txt
cat /etc/fstab > ${LIVEDIR}/fstab.txt
${VGCFGBACKUP} -f ${LIVEDIR}/lvm_cfg.txt

for xfs in $(cat ${PROC_MOUNTS} | awk -v xfs=xfs '{if ($3==xfs) print $1}')
do
	DUMPFILE=$(echo ${xfs} | sed 's/\//_/g').dump0
	DUMPFILEFP=${LIVEDIR}/${DUMPFILE}
	echo "Taking level 0 dump of ${xfs} to ${DUMPFILEFP} ..."
	${XFSDUMP} -l0  - ${xfs} | gzip -9 > ${DUMPFILEFP}
	echo "done."
done

# bottom of file
