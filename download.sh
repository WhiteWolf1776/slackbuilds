#!/bin/sh

ARCH=$(uname -m)
PKGS=$(find -type f -name '*.info' -exec basename {} .info \;)

checksum()
{
  sum=$(md5sum $1 | cut -d ' ' -f1)

  if [ "$sum" != "$2" ]; then
    echo ""
    echo "WARNING: checksum failed: $1"
    echo ""

    sleep 2
  fi
}

for pkg in $PKGS; do
  . $pkg/$pkg.info

  DOWNLOAD=($DOWNLOAD)
  MD5SUM=($MD5SUM)

  len=${#DOWNLOAD[@]}

  for (( i=0; i < $len; i++ )); do
    src=$(basename ${DOWNLOAD[$i]})

    echo $DOWNLOAD | grep -qi "github.com"

    if [ "$?" = "0" ]; then
      ext=$(echo $src | rev | cut -d. -f1-2 | rev)
      src=$PRGNAM-$VERSION.$ext
    fi

    if [ -e "$pkg/$src" ]; then
      if [ -f "$pkg/$src" ]; then
        checksum $pkg/$src ${MD5SUM[$i]}
      fi

      continue;
    fi

    file=$(cd $pkg; find ../ -type f -name $src)

    if [ -z "$file" ]; then
      cd $pkg
      wget --content-disposition ${DOWNLOAD[$i]}
      checksum $pkg/$src ${MD5SUM[$i]}
      cd ..
    else
      ln -sf $file $pkg
    fi
  done
done
