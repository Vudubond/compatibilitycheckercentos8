#!/bin/sh
#Name:    find_centos8_needs_elrepo.sh
#version: 1.0.0
#Date:    2020-03-17
#Author:  David Mathog
#
#  list any ElRepo drivers needed to install CentOS 8 on this system
#
#  assumes wget, lspci, and access to the internet are available
#  If access is not available specify one parameter to the already downloaded
#  file.
#
#  Derived from find_centos8_needs_elreop.pl.  Instead of using hashes it makes file
#  names under /tmp/fcne_tmp.  Slower than the perl version but should be able to run
#  even under busybox, assuming lscpi is also present.
#
IDLIST="http://elrepo.org/tiki/DeviceIDs"
count=0
real_filename="/tmp/fcne_DeviceIDsFile"
tmpdir="/tmp/fcne_tmp"
id_hash_type="$tmpdir/id_hash_type"
id_hash_driver="$tmpdir/id_hash_driver"
pci_hash_longname="$tmpdir/pci_hash_longname"

if [ $# != 1 ]
then
     echo "Usage: find_centos8_needs_elrepo.sh DeviceIDsFile"
     echo ""
     echo "If internet access is available let DeviceIDsFile = \"-\" and it will be downloaded"
     echo "automatically.  Otherwise on some machine do:"
     echo ""
     echo "   wget -O DeviceIDsFile $IDLIST"
     echo ""
     echo "Then copy that file by some means to the target and specify"
     echo "the file name on the command line."
     exit
fi
filename=$1;


if [ "$filename" = "-" ]
then
   wmessages=`wget -q -O $real_filename $IDLIST 2>/dev/null`
   if [ $wmessages ]
   then
      echo "Some problem running:"
      echo ""
      echo   "  wget -q -O $real_filename 2>/dev/null"
      echo ""
      echo "returned:"
      echo "$wmessages"
      exit;
   fi
else
   real_filename=$filename;
fi

if [ -d $tmpdir ]
then
   rm -rf $tmpdir
fi
mkdir -p $tmpdir
mkdir -p $id_hash_type
mkdir -p $id_hash_driver
mkdir -p $pci_hash_longname

echo "Checking this machine for drivers missing from CentOS 8 but present in ElRepo"
echo "Getting Device ID list from $IDLIST"
#avoid arrays so this can work with ash, sh, bash
grep '[[:blank:]]kmod-' $real_filename | tr -d '\r' | while read line;
do
  dev_type=`echo $line | cut -d ' ' -f1`
  dev_id=`echo $line | cut -d ' ' -f2`
  dev_driver=`echo $line | cut -d ' ' -f3`
  echo -n $dev_type   > $id_hash_type/$dev_id
  echo -n $dev_driver > $id_hash_driver/$dev_id
done

echo "Getting pci IDs and long names from lspci"
lspci | while read line;
do
  pci_id=`echo $line | cut -d ' ' -f1 | tr '[:lower:]' '[:upper:]'`
  ln=`echo $line | cut -d ' ' -f2-`
  dev_driver=`echo $line | awk '{ print $3 }'`
  echo -n $ln   > $pci_hash_longname/$pci_id
done

echo "Checking pci and device IDs from lspci -n, listing only those in ElRepo"
lspci -n | while read line;
do
  pci_id=`echo $line | cut -d ' ' -f1 | tr '[:lower:]' '[:upper:]'`
  dev_id=`echo $line | cut -d ' ' -f3 | tr '[:lower:]' '[:upper:]'`
  if [ -f $id_hash_driver/$dev_id ]
  then
     count=`expr $count + 1`
     ihd=`cat $id_hash_driver/$dev_id`
     iht=`cat $id_hash_type/$dev_id`
     phl=`cat $pci_hash_longname/$pci_id`
     echo "$pci_id $dev_id $ihd $iht $phl"
  fi
done

if [ ! $count ]
then
   echo "none found"
fi

#clean up
if [ "$filename" = "-" ]
then
   rm -f $real_filename
fi
rm -rf $tmpdir

echo "Done"
