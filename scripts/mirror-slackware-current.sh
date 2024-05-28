#!/bin/bash
#
# $Id: mirror-slackware-current.sh,v 1.99 2023/05/31 19:02:29 root Exp root $
#
# Mirror Slackware-current to our local machine
#
# Examples of use:
# + Show all available options: "mirror-slackware-current.sh -h"
# + A crontab entry which checks for updates every night at 06:00, downloads
#   new stuff if present and creates a new DVD ISO (if updates were found):
#   00 6 * * *   /usr/local/bin/mirror-slackware-current.sh -q -o DVD
#
# ===========================================================================
#
# - Check at our master rsync site if the ChangeLog.txt has been altered
# - If no changes, then no further actions are needed (abort script)
# - If ChangeLog.txt has changed since our last mirror, do the following:
# - Mirror the slackware release tree
# - Create a bootable mini ISO containing just the kernel and the installer,
#   or a single bootable DVD from the current tree,
#   (guidelines are in the ./isolinux/README.TXT)
#   All ISOs are hybrid: they can be copied to USB stick using 'dd' or 'cp'.
#   CDROM ISO images must be at most 737.280.000 bytes (703 MB)
#   in order to fit on a 80min CD medium.
#   A typical DVD max size is 4.706.074.624 bytes (4.38GB better known as 4.7G)
#
#
# Good rsync mirrors are:
#
#  rsync.osuosl.org::slackware/slackware-current
#  slackware.mirrors.tds.net::slackware/slackware-current
#  rsync.slackware.pl::slackware/slackware-current
#  rsync.slackware.at::slackware/slackware-current
#  mirrors.vbi.vt.edu::slackware/slackware-current
#  rsync.slackware.no::slackware/slackware-current
#
# Author: Eric Hameleers <alien@slackware.com>
#
# ===========================================================================

# Read configuration file if it exists;
#  - usually called 'mirror-slackware-current.conf'
CONFFILE=${CONFFILE:-"$(dirname $0)/$(basename $0 .sh).conf"}
[ -f ${CONFFILE} ] && . ${CONFFILE}

# ---------------------------------------------------------------------------
# Configurable options - edits should go into the .conf file
# ---------------------------------------------------------------------------

set_defaults() {
# Binaries to use:
RSYNC=${RSYNC:-"/usr/bin/rsync"}
MKISOFS=${MKISOFS:-"/usr/bin/mkisofs"}
MD5SUM=${MD5SUM:-"/usr/bin/md5sum"}
ISOHYBRID=${ISOHYBRID:-"/usr/bin/isohybrid"}
XORRISO=${XORRISO:-"/usr/bin/xorriso"}

# Your name/email:
BUILDER=${BUILDER:-"Eric Hameleers <alien@slackware.com>"}

# Where do you want to create the local mirror? The Slackware directory tree
# will be stored as ${SLACKROOTDIR}/${SLACKRELEASE}
# This value can be overruled via the '-l' commandline parameter;
SLACKROOTDIR=${SLACKROOTDIR:-"/home/ftp/pub/Linux/Slackware"}

# What architecture will we be mirroring? The default is 'x86_64' meaning 64bit.
# Alternatively you can specify 'x86' meaning 32bit or 'arm' meaning ARM.
# The value of ARCH determines the name of the slackware directories.
# This value can be overruled via the '-a' commandline parameter;
ARCH=${ARCH:-"x86_64"}

# The slackware release we're mirroring (defaults to 'current').
# You can use the script's '-r' switch to alter this to another release,
# for instance mirror Slackware 13.37 by passing '-r 13.37' to the script.
RELEASE=${RELEASE:-"current"}

# The RSYNC mirror:
# Supply a full rsync URI in the RSYNCURLROOT variable, while leaving out
# the final "slackware-current" directory. Do not remove the trailing slash!
# RSYNCURL will become ${RSYNCURLROOT}${SLACKRELEASE} further down.
# An alternative rsync mirror URI can also be passed to the script with
# the '-m' option - that URI must *not* have a trailing slash.
RSYNCURLROOT=${RSYNCURLROOT:-"rsync.osuosl.org::slackware/"}
RSYNCURL=${RSYNCURL:-""}

# If you need to feed rsync's "external" program additional options (such as
# an identity file for passwordless login over ssh if your remote server is
# no real rsync server), Use EXTOPTS for passing those additional options.
# Example: EXTOPTS="-oIdentityFile=/home/alien/.ssh/id_rsa -l alien"
# This is an option you can also set using the '-s' parameter on the command
# line, like so:
# -s '-oIdentityFile=/home/alien/.ssh/id_rsa -l alien'
# If this is defined, then "ssh" will be used as the "external" program.
EXTOPTS=${EXTOPTS:-""}

# The defaults: somewhat moderate output in all cases;
# You can alter this behaviour by passing either the
# '-q' (totally silent unless there is an update) or the '-v' (be verbose)
# switch to the script.
DEBUG=${DEBUG:-1}
VERBOSE=${VERBOSE:-"-q"}

# Set ISO="DVD" if you want a single DVD instead of four CD ISOs.
# Set ISO="ALL" if you want a mini CD ISO as well as a single DVD ISO.
# Set ISO="NONE" if you just want to sync the local mirror but don't need ISOs.
# Set ISO="MINI" if you want only the mini ISO (network installer).
#    Note: setting ISO="MINI" will result in a partial sync (no packages)!
# You can set the ISO variable using the '-o <iso_type>' switch too.
ISO=${ISO:-"ALL"}

# If you want to skip the rsync stage entirely, and just want to build
# ISO image(s) from your local tree, then set ISOONLY="yes"
# (or use '-i' parameter with the script)
ISOONLY=${ISOONLY:-"no"}

# Normally, when no update is found in the ChangeLog.txt, the script exits
# without creating ISO images. If you want ISO images nonetheless, set
# the variable FORCE to "yes" (or pass the '-f' switch to the script).
FORCE=${FORCE:-"no"}

# You might just want to check if the ChangeLog.txt changed...
# In that case, set ONLYDIFF to '1'. The script will exit after showing the
# diff between your local and the remote server's version.
# Corresponds to the '-n' option.
ONLYDIFF=${ONLYDIFF:-0}

# The default is not to remove the previous ISO until the new ISO has been
# created. Set PREREMOVE to '1' if you want the old ISO to be removed before
# running 'mkisofs' - this is useful in case you are short on disk space.
# Corresponds to the '-p' option.
PREREMOVE=${PREREMOVE:-0}

# The value of EXCLUDES is what the script will exclude from the mirroring
# process; there is no parameter for the script to change this value, but you
# can use '-X excludefile' to define more excluded directories/files if you
# wish. Or directly edit the line below of course:
EXCLUDES=${EXCLUDES:-"--exclude pasture"}

# By default we do not use an 'excludes' file to rsync, but you can override
# that by using the '-X' parameter or set EXCLUDEFILE to a filename:
# By default the script does not mirror /pasture , use '-X none' (the 'none'
# is taken as a special value by the script) to also mirror /pasture .
EXCLUDEFILE=${EXCLUDEFILE:-""}

# If you want to exclude more from the DVD ISO than just the ./testing
# directory, you can add the directories to DVD_EXCLUDES.
# The pathnames must be local to the top level and must start with ./
#DVD_EXCLUDES=${DVD_EXCLUDES:-"-x ./testing"}
DVD_EXCLUDES=${DVD_EXCLUDES:-"-x ./testing  -x ./source -x ./extra/source"}

# By default, this script will use all available bandwidth (BWLIMIT=0).
# If you want to limit bandwith usage to NN KBytes/sec, set BWLIMIT=NN
# or use the '-b NN' parameter.
BWLIMIT=${BWLIMIT:-0}

# The script can check if a newer version of itself is available for download.
# If you want this, set CHECKVER="yes" or use the '-c' parameter to the script.
CHECKVER=${CHECKVER:-"no"}

# By default, this script uses a 'boot-load-size' of 4 (KB) as argument
# to the 'mkisofs' command.
# Slackware's bootable DVD and CDROM use a value of 32, and although that
# value follows the standard better, it will create an ISO that will not boot
# on many older 'broken' PC BIOSes.
# The script will use the value of "32" if you pass the parameter '-e'
# or change the value below:
BOOTLOADSIZE=${BOOTLOADSIZE:-4}

} # end set_defaults, do not change this line.

set_defaults

# ---------------------------------------------------------------------------
# End of configurable options as far as I'm concerned.
# ---------------------------------------------------------------------------

DATE=$(date +"%d_%b_%Y")

# Where we will write temporary files (like the downloaded ChangeLog.txt):
TMP=${TMP:-/tmp}

# We prevent the mirror script from running more than one instance:
# If you have a reason to want to run multiple instances at the same time, just
# make a symlink to this script and run the script using the symlinked name.
# This will create a unique PIDFILE name.
PIDFILE=/var/tmp/$(basename $0 .sh).pid

# We will also allow multiple *versions* of this script to run in parallel.
# This will work by creating 'new' names for the script as symlinks.
SCRIPTID=$(basename $0 .sh)

# Location of the original script:
ORIGSCR="http://www.slackware.com/~alien/tools/mirror-slackware-current.sh"

# Make sure the PID file is removed when we kill the process
trap 'rm -f $PIDFILE; exit 1' TERM INT

while getopts "a:b:cehfil:m:no:pr:qs:vwX:" Option
do
  case $Option in
    h ) cat <<-"EOH"
	-----------------------------------------------------------------
	$Id: mirror-slackware-current.sh,v 1.99 2023/05/31 19:02:29 root Exp root $
	-----------------------------------------------------------------
	EOH
        echo "Usage:"
        echo "  $0 [OPTION] ..."
        echo "or:"
        echo "  SLACKROOTDIR=/your/repository/dir $0 [OPTION] ..."
        echo ""
        echo "The SLACKROOTDIR is the directory that contains the directories"
        echo "  slackware-<RELEASE> and slackware-<RELEASE>-iso"
        echo "Current value of SLACKROOTDIR : $SLACKROOTDIR"
        echo ""
        echo "You can change the script defaults in a file '$(basename $0 .sh).conf'"
        echo ""
        echo "The script's parameters are:"
        echo "  -h            This help."
        echo "  -a <arch>     Architecture to mirror (defaults to '$ARCH',"
        echo "                can be 'x86_64', 'x86' or 'arm')."
        echo "  -b <number>   Limit bandwidth usage to <number> KBytes/sec."
        echo "  -c            Check for newer version of this script."
        echo "  -e            Use 'boot-load-size=32' instead of the value 4."
        echo "                 (32 is a more standard value, but a value of 4"
        echo "                 will let the ISO boot with old 'broken' BIOSes)."
        echo "  -f            Force sync and the creation of new ISO image(s)"
        echo "                even if no update of the ChangeLog.txt was found."
        echo "                This is how you resume after an aborted attempt."
        echo "                Note: this will also create any missing local"
        echo "                      directories needed for the mirror."
        echo "  -i            Only generate ISO images from our local copy;"
        echo "                do not attempt to contact the remote server."
        echo "  -l <localdir> The root directory where you keep your local"
        echo "                Slackware mirror; this directory contains"
        echo "                slackware-<RELEASE> and slackware-<RELEASE>-iso"
        echo "  -m <uri>      The rsync URI that you want to use instead of"
        echo "                the script default. Example:"
        echo "                -m mirrors.tuxq.com::slackware/slackware-current"
        echo "                (no trailing slash!)"
        echo "  -n            Only show the changes in the ChangeLog.txt"
        echo "                but don't sync anything and don't generate ISOs."
        echo "  -o <iso_type> The type of hybrid ISO that you want to generate."
        echo "                iso_type can be one of:"
        echo "                MINI : produce a mini CDROM (netinstall) image"
        echo "                DVD  : produce a single DVD image"
        echo "                ALL  : produce mini CDROM and DVD images"
        echo "                NONE : produce no images at all (just sync)."
        echo "                The default iso_type is ${ISO}."
        echo "  -p            Remove old ISOs before building the new ones"
        echo "                (in case you're suffering from low free space)."
        echo "  -r <release>  The release ('$RELEASE' by default); use '-r 15.0'"
        echo "                if you want to mirror and image slackware 15.0"
        echo "  -q            Non-verbose output (for cron jobs)."
        echo "  -s            Additional ssh options, in case rsync needs to"
        echo "                login to the remote server using ssh. Example:"
        echo "                -s \"-l alien -o IdentityFile=/home/alien/.ssh/id_rsa\""
        echo "  -v            Verbose progress indications."
        echo "  -w            Write a .conf file containing script defaults."
        echo "                It will be created in the script's directory,"
        echo "                as '$(basename $0 .sh).conf'"
        echo "  -X <xfile>    File 'xfile' contains a list of exclude patterns"
        echo "                for directories that you do not want mirrored."
        echo "                Note: this will override the default exclusion of"
        echo "                the 'pasture' directory so if you still want that"
        echo "                excluded, add it explicitly to the file 'xfile'."
        echo "                If your intention is *not* to exclude '/pasture'"
        echo "                from the mirror, use '-X none'."
        exit
        ;;
    a ) ARCH=${OPTARG}
        ;;
    b ) BWLIMIT=${OPTARG}
        ;;
    c ) CHECKVER="yes"
        ;;
    e ) BOOTLOADSIZE=32
        ;;
    f ) FORCE="yes"
        ;;
    i ) ISOONLY="yes"
        ;;
    l ) SLACKROOTDIR=$(readlink -f ${OPTARG})
        ;;
    m ) RSYNCURL=${OPTARG}
        ;;
    n ) ONLYDIFF=1
        ;;
    o ) ISO=${OPTARG}
        ;;
    p ) PREREMOVE=1
        ;;
    r ) RELEASE=${OPTARG}
        ;;
    q ) # No output at all if we are already in sync
        DEBUG=0
        VERBOSE="-q"
        ;;
    s ) EXTOPTS="${OPTARG}"
        export RSYNC_RSH="ssh $EXTOPTS"
        ;;
    v ) echo "Enabling verbose output...."
        DEBUG=1
        VERBOSE="-v --progress"
        ;;
    w ) # Write a configuration file
        if [ -r ${CONFFILE} ]; then
          echo "Backing up current '${CONFFILE}'...."
          mv -f ${CONFFILE} ${CONFFILE}.$(date +%Y%m%d_%H%M)
        fi
        echo "Writing '${CONFFILE}'...."
        sed  -n '/^set_defaults() {/,/^} # end set_defaults, do not change this line./p' $0 \
          | grep -v set_defaults \
          | sed -e 's/^\([^=]*\)=\${\1:-\([^}]*\)}/\1=\2/' \
          > ${CONFFILE}
        if [ -r ${CONFFILE} ]; then
          echo "Taking no further action."
          exit 0
        else
          echo "Could not write '${CONFFILE}'...!"
          exit 1
        fi
        ;;
    X ) EXCLUDEFILE=${OPTARG}
        ;;
    * ) echo "You passed an illegal switch to the program!"
        echo "Run '$0 -h' for more help."
        exit
        ;;   # DEFAULT
  esac
done

# End of option parsing.
shift $(($OPTIND - 1))

#  $1 now references the first non option item supplied on the command line
#  if one exists.
# ---------------------------------------------------------------------------

# Sanity checks - 
if ! echo "MINI DVD ALL NONE" | grep -wq $ISO ; then
  echo "Error! Invalid iso_type '-o ${ISO}' passed as parameter!"
  echo "Possible values are 'MINI', 'DVD', 'ALL' or 'NONE'."
  exit 1
fi

if  [ $ONLYDIFF -eq 1 -a "$FORCE" == "yes" ]; then
  echo "Error! The '-n' and '-f' switches cannot be used together!"
  exit 1
fi

if  [ "$ISOONLY" == "yes" -a "$FORCE" == "yes" ]; then
  echo "Error! The '-i' and '-f' switches cannot be used together!"
  exit 1
fi

if  [ -n "$EXCLUDEFILE" -a "$EXCLUDEFILE" != "none" ]; then
  if [ ! -r "$EXCLUDEFILE" ]; then
    echo "Can not read excludes-file '$EXCLUDEFILE'!"
    exit 1
  fi
fi

if [ "$ARCH" = "x86_64" ]; then
  SLACKRELEASE="slackware64-${RELEASE}"
  PKGMAIN="slackware64"
elif [ "$ARCH" = "arm" ]; then
  SLACKRELEASE="slackwarearm-${RELEASE}"
  PKGMAIN="slackware"
else
  SLACKRELEASE="slackware-${RELEASE}"
  PKGMAIN="slackware"
fi

if [ ! -d ${SLACKROOTDIR}/${SLACKRELEASE} ]; then
  if  [ "$FORCE" == "yes" ]; then
    if ! mkdir -p ${SLACKROOTDIR}/${SLACKRELEASE} ; then
      echo "Failure in creating '${SLACKROOTDIR}/${SLACKRELEASE}'!"
      echo "  Aborting now..."
      exit 1
    fi
  else
    echo "$(date) [$$]: Cannot find ${SLACKRELEASE} directory:"
    echo "  (${SLACKROOTDIR}/${SLACKRELEASE})!"
    echo "  Use '-f' parameter to force the creation of this directory."
    echo "  Aborting now..."
    exit 1
  fi
fi

if [ ${ISO} != "NONE" -a ! -d ${SLACKROOTDIR}/${SLACKRELEASE}-iso ]; then
  if  [ "$FORCE" == "yes" ]; then
    if ! mkdir -p ${SLACKROOTDIR}/${SLACKRELEASE}-iso ; then
      echo "Failure in creating '${SLACKROOTDIR}/${SLACKRELEASE}-iso'!"
      echo "  Aborting now..."
      exit 1
    fi
  else
    echo "$(date) [$$]: Cannot find directory to create the ISO image(s):"
    echo "  '${SLACKROOTDIR}/${SLACKRELEASE}-iso'!"
    echo "  Use '-f' parameter to force the creation of this directory."
    echo "  Aborting now..."
    exit 1
  fi
fi

# Compose the RSYNCURL if it was not passed as an argument:
[ -z $RSYNCURL ] && RSYNCURL=${RSYNCURLROOT}${SLACKRELEASE}

# Check for an updated version of this script:
if [ "$CHECKVER" == "yes" ]; then
  if [ $DEBUG -eq 1 ]; then
    echo "#"
    echo "# Checking version of '${ORIGSCR}' ..."
    echo "#"
  fi
  CVRS=$(cat ${0} | grep 'Id: ' | head -1 | \
    sed -e 's/^.*Id: mirror-slackware-current.sh,v \([0-9.]*\) .*$/\1/')
  NVRS=$(wget -T 10 -q -O - ${ORIGSCR} | grep 'Id: ' | \
    head -1 | \
    sed -e 's/^.*Id: mirror-slackware-current.sh,v \([0-9.]*\) .*$/\1/')
  if [ -z "$CVRS" -o -z "$NVRS" ]; then
    echo "# Cannot compare version against the script's original;"
    echo "# Your script version reports '$CVRS', the original reports '$NVRS'"
    if [ -z "$NVRS" ]; then
      echo "# Possible cause is a failure to retrieve the remote script:"
      echo "#   '${ORIGSCR}'."
    fi
  elif [ "$CVRS" != "$NVRS" ]; then
    echo "# Your version of this script is '$CVRS', while version '$NVRS' is reported"
    echo "# by remote '${ORIGSCR}'"
  elif [ "$CVRS" == "$NVRS" -a $DEBUG -eq 1 ]; then
    echo "# You have the most recent version of this script"
  fi
fi

if which $XORRISO 1>/dev/null 2>/dev/null ; then
  # Prefer xorriso over mkisofs:
  USEXORR=${USEXORR:-"yes"}
else
  USEXORR=${USEXORR:-"no"}
fi

if [ "$ISOONLY" == "no" ]; then
  if [ $DEBUG -eq 1 ]; then
    echo "#"
    echo "# Mirroring ${SLACKRELEASE} from ${RSYNCURL} ..."
    echo "#"
  fi

  RSYNCOUT=$($RSYNC $RSYNCURL 2>&1 1>/dev/null) ; RES=$?
  if [ $RES -ne 0 ]; then
    echo "Error while testing the connection to rsync mirror ${RSYNCURL}!"
    echo "Did you make a typing mistake perhaps in the URI '-m ${RSYNCURL}'?"
    echo ""
    echo "The command's exit code was ${RES}."
    echo "The error output was: '${RSYNCOUT}'"
    exit $RES
  fi
fi

# Compose the exclusion parameter to rsync. Either you pass an "excludes" file,
# or else we exclude only /pasture by default. Exclusion of /pasture can be
# prevented by using the '-X none' parameter:
# The default value for EXCLUDES is defined in the top section of this script.
if [ "$EXCLUDEFILE" == "none" ]; then
  EXCLUDES="" 
elif [ -r "$EXCLUDEFILE" ]; then
  EXCLUDES="--exclude-from=$EXCLUDEFILE"
fi

# ---------------------------------------------------------------------------

if [ -e $PIDFILE ]; then

  echo "Another instance ($(cat $PIDFILE)) still running?"
  echo "If you are sure that no other instance is running, delete the lockfile"
  echo "'${PIDFILE}' and re-start this script."
  echo "Aborting now..."
  exit 1

else

  echo $$ > $PIDFILE

  [ $DEBUG == 1 ] && echo "Changing to ${SLACKROOTDIR}/${SLACKRELEASE} ..."
  cd ${SLACKROOTDIR}/${SLACKRELEASE}
  umask 022

  if [ "$ISOONLY" == "no" ]; then

    # First get the ChangeLog.txt (no further action needed,
    # when there are no changes in this file)
    if [ $DEBUG == 1 ]; then
      echo "$(date) [$$]: Getting ChangeLog.txt..."
    fi

    rm -f $TMP/${SCRIPTID}_${SLACKRELEASE}_ChangeLog.txt
    $RSYNC -az ${VERBOSE} ${RSYNCURL}/ChangeLog.txt $TMP/${SCRIPTID}_${SLACKRELEASE}_ChangeLog.txt

    if [ ! -s $TMP/${SCRIPTID}_${SLACKRELEASE}_ChangeLog.txt ]; then
      echo "$(date) [$$]: Could not retrieve ChangeLog.txt! Aborting..."
      rm -f $PIDFILE
      exit 1
    fi

    # If the ChangeLog.txt on our local mirror doesn't exist, it might mean that
    # this is a first-time mirror. To prevent the script from aborting, we
    # create an empty ChangeLog.txt file...
    if [ ! -e ${SLACKROOTDIR}/${SLACKRELEASE}/ChangeLog.txt ]; then
      touch ${SLACKROOTDIR}/${SLACKRELEASE}/ChangeLog.txt
    fi

    diff -b ${SLACKROOTDIR}/${SLACKRELEASE}/ChangeLog.txt $TMP/${SCRIPTID}_${SLACKRELEASE}_ChangeLog.txt
    STATUS="$?"
    if [ "$STATUS" == "2" ]; then
      echo "$(date) [$$]: Trouble when running diff, aborting..."
      rm -f $TMP/${SCRIPTID}_${SLACKRELEASE}_ChangeLog.txt
      rm -f $PIDFILE
      exit 1
    elif [ "$STATUS" == 0 ]; then
      [ $DEBUG == 1 ] && echo -n "$(date) [$$]: No difference found"
      if [ $FORCE == "yes" ]; then
        # we will continue as requested
        [ $DEBUG == 1 ] && echo ", continuing anyway..."
      else
        # quit the script now. 
        [ $DEBUG == 1 ] && echo ", exiting now...."
        rm -f $TMP/${SCRIPTID}_${SLACKRELEASE}_ChangeLog.txt
        rm -f $PIDFILE
        exit 0
      fi
    else
      echo -n "$(date) [$$]: ChangeLog.txt has been updated"
      if [ $ONLYDIFF -eq 1 ]; then
        # quit the script now. 
        echo ", that's all you wanted to know...."
        rm -f $TMP/${SCRIPTID}_${SLACKRELEASE}_ChangeLog.txt
        rm -f $PIDFILE
        exit 0
      else
        # we will continue.
        echo ", starting mirror of ${SLACKRELEASE}."
      fi
    fi

    echo "*** Using ${RSYNCURL} ***"

    # Use '-rlptD' instead of '-a' so that we don't preserve file ownership -
    # so that we can switch mirrors and still all files will be owned root:root.

    if [ "$ISO" == "MINI" ]; then

      # If all we need is the mini ISO then we do a partial sync:
      echo "$(date) [$$]: Performing a partial rsync for a mini ISO image."
      $RSYNC --delete -rlptD --bwlimit $BWLIMIT \
           $VERBOSE \
           --exclude=bootdisks \
           --exclude=extra \
           --exclude=pasture \
           --exclude=patches \
           --exclude=rootdisks \
           --exclude=${PKGMAIN} \
           --exclude=source \
           --exclude=testing \
           --exclude=usb-and-pxe-installers \
           --exclude=zipslack \
           ${RSYNCURL}/ .

      # Actually, run rsync again, since it happens that we hit
      # the master server while it is still sync-ing itself.
      $RSYNC --delete -rlptD --bwlimit $BWLIMIT \
           $VERBOSE \
           --exclude=bootdisks \
           --exclude=extra \
           --exclude=pasture \
           --exclude=patches \
           --exclude=rootdisks \
           --exclude=${PKGMAIN} \
           --exclude=source \
           --exclude=testing \
           --exclude=usb-and-pxe-installers \
           --exclude=zipslack \
           ${RSYNCURL}/ .

      echo "$(date) [$$]: Done mirroring ${SLACKRELEASE} (exit code $?)."

    else

      # Do a full sync with the remote mirror server, excluding ChangeLog.txt:
      $RSYNC \
           --delete -rlptD \
           --exclude=ChangeLog.txt \
           --bwlimit $BWLIMIT \
           $VERBOSE \
           ${EXCLUDES} \
           ${RSYNCURL}/ .

      # Run rsync again, since it may happen that we hit
      # the master server while it is still sync-ing itself.
      # And this time we'll also get the ChangeLog.txt:
      $RSYNC \
           --delete -rlptD \
           --delete-excluded \
           --bwlimit $BWLIMIT \
           $VERBOSE \
           ${EXCLUDES} \
           ${RSYNCURL}/ .

      echo "$(date) [$$]: Done mirroring ${SLACKRELEASE} (exit code $?)."

    fi

  fi

#
# Now create a bootable ISO install images
# (log the used command line for reference purposes)
# 
# ... unless we explicitly don't want ISOs...
#
  if [ "$ISO" == "NONE" ]; then
    rm -f $TMP/${SCRIPTID}_${SLACKRELEASE}_ChangeLog.txt
    rm -f $PIDFILE
    exit 0
  fi

# Determine whether we add UEFI boot capabilities to the ISO:
# Note, this excludes 32-bit Slackware since a 32-bit kernel will not boot
# on UEFI (UEFI starts the system in x86_64 mode):
if [ -f isolinux/efiboot.img ]; then
  UEFI_OPTS="-eltorito-alt-boot -no-emul-boot -eltorito-platform 0xEF -eltorito-boot isolinux/efiboot.img"
  ISOHYBRID_OPTS="-u"
else
  UEFI_OPTS=""
  ISOHYBRID_OPTS=""
fi


  if [ "$ISO" == "MINI" -o  "$ISO" == "ALL" ]; then

  cat <<_EOT_ > ${SLACKROOTDIR}/${SLACKRELEASE}-iso/readme_mini.mkisofs
  #
  # Slackware installation "mini" ISO.
  # This ISO does not contain any packages, and can be used for network
  # installs.
  #
  # Command used to create the ISO:
  # (see also /isolinux/README.TXT on the CDROM you'll burn from the ISO)

  # Mini ISO

  mkisofs -o ${SLACKRELEASE}-mini-install.iso \\
    -R -J -V "Slackware Mini Install" \\
    -x ./bootdisks \\
    -x ./extra \\
    -x ./pasture \\
    -x ./patches \\
    -x ./rootdisks \\
    -x ./slackbook \\
    -x ./${PKGMAIN} \\
    -x ./source \\
    -x ./testing \\
    -x ./usb-and-pxe-installers \\
    -x ./zipslack \\
    -v -d -N \\
    -hide-rr-moved -hide-joliet-trans-tbl \\
    -no-emul-boot -boot-load-size 4 -boot-info-table \\
    -sort isolinux/iso.sort \\
    -b isolinux/isolinux.bin \\
    -c isolinux/isolinux.boot \\
    -preparer "Slackware-${RELEASE} build for $ARCH by ${BUILDER}" \\
    -publisher "The Slackware Linux Project - http://www.slackware.com/" \\
    -A "Slackware-${RELEASE} for ${ARCH} Mini Install CD - build $DATE" \\
    ${UEFI_OPTS} \\
    .

_EOT_

  echo "$(date) [$$]: Creating MINI ISO image for ${SLACKRELEASE}..."

  if [ $PREREMOVE -eq 1 ]; then
    # Deleting the previous ISO prior to creating the new ISO
    # This is good if you're short on free disk space...
    [ $DEBUG == 1 ] && echo "Deleting old ISO first ..."
    rm -f ${SLACKROOTDIR}/${SLACKRELEASE}-iso/${SLACKRELEASE}mini-install.iso
  fi

  MKISOERR=0

  $MKISOFS -o ${SLACKROOTDIR}/${SLACKRELEASE}-iso/.building-slackware-mini-install.iso \
    -R -J -V "Slackware Mini Install" \
    -x ./bootdisks \
    -x ./extra \
    -x ./pasture \
    -x ./patches \
    -x ./rootdisks \
    -x ./slackbook \
    -x ./${PKGMAIN} \
    -x ./source \
    -x ./testing \
    -x ./usb-and-pxe-installers \
    -x ./zipslack \
    -hide-rr-moved -hide-joliet-trans-tbl \
    -v -d -N -no-emul-boot -boot-load-size 4 -boot-info-table \
    -b isolinux/isolinux.bin \
    -c isolinux/isolinux.boot \
    -sort isolinux/iso.sort \
    -preparer "Slackware-${RELEASE} build for $ARCH by ${BUILDER}" \
    -publisher "The Slackware Linux Project - http://www.slackware.com/" \
    -A "Slackware-${RELEASE} for ${ARCH} Mini Install CD - build $DATE" \
    ${UEFI_OPTS} \
    . \
  > ${SLACKROOTDIR}/${SLACKRELEASE}-iso/mkisofs_mini.log 2>&1

  MKISOERR=$?

  if [ $MKISOERR -eq 0 ]; then
    # Create a hybrid ISO if requested:
    if [ -x $ISOHYBRID ]; then
      echo "$(date) [$$]: Creating hybrid ISO."
      $ISOHYBRID ${ISOHYBRID_OPTS} ${SLACKROOTDIR}/${SLACKRELEASE}-iso/.building-slackware-mini-install.iso
    fi
  fi

  if [ $PREREMOVE -eq 0 ]; then
    # Deleting the previous ISO after creating the new ISO
    rm -f ${SLACKROOTDIR}/${SLACKRELEASE}-iso/${SLACKRELEASE}-mini-install.iso
  fi

  # Make the new ISO "visible"
  mv ${SLACKROOTDIR}/${SLACKRELEASE}-iso/.building-slackware-mini-install.iso \
     ${SLACKROOTDIR}/${SLACKRELEASE}-iso/${SLACKRELEASE}-mini-install.iso

  echo "$(date) [$$]: MINI CDROM ISO created (exit code ${MKISOERR}) ..."

  fi ## end of [ "$ISO" == "MINI" -o  "$ISO" == "ALL" ]


  if [ "$ISO" == "DVD" -o  "$ISO" == "ALL" ]; then

  cat <<_EOT_ > ${SLACKROOTDIR}/${SLACKRELEASE}-iso/readme_dvd.mkisofs
  #
  # Slackware installation as DVD. 
  #
  # Contains: bootable INSTALL DVD (including /extra)
  #
  # Command used to create the ISOs for this DVD:
  # (see also /isolinux/README.TXT on the DVD you'll burn from the ISO)

  # DVD

  mkisofs -o ${SLACKRELEASE}-install-dvd.iso \\
    -R -J -V "Slackware-${RELEASE} DVD" \\
    -hide-rr-moved -hide-joliet-trans-tbl \\
    -v -d -N -no-emul-boot -boot-load-size ${BOOTLOADSIZE} -boot-info-table \\
    -sort isolinux/iso.sort \\
    -b isolinux/isolinux.bin \\
    -c isolinux/isolinux.boot \\
    -preparer "Slackware-${RELEASE} build for ${ARCH} by ${BUILDER}" \\
    -publisher "The Slackware Linux Project - http://www.slackware.com/" \\
    -A "Slackware-${RELEASE} DVD - build $DATE" \\
    ${DVD_EXCLUDES} \\
    ${UEFI_OPTS} \\
    .

_EOT_

  echo "$(date) [$$]: Creating DVD ISO image for ${SLACKRELEASE}..."

  if [ $PREREMOVE -eq 1 ]; then
    # Deleting the previous ISO prior to creating the new ISO
    # This is good if you're short on free disk space...
    [ $DEBUG == 1 ] && echo "Deleting old ISO first ..."
    rm -f ${SLACKROOTDIR}/${SLACKRELEASE}-iso/${SLACKRELEASE}-install-dvd.iso
  fi

  MKISOERR=0

  $MKISOFS -o ${SLACKROOTDIR}/${SLACKRELEASE}-iso/.building-slackware-install-dvd.iso \
    -R -J -V "Slackware-${RELEASE} DVD" \
    -hide-rr-moved -hide-joliet-trans-tbl \
    -v -d -N -no-emul-boot -boot-load-size ${BOOTLOADSIZE} -boot-info-table \
    -sort isolinux/iso.sort \
    -b isolinux/isolinux.bin \
    -c isolinux/isolinux.boot \
    -preparer "Slackware-${RELEASE} build for ${ARCH} by ${BUILDER}" \
    -publisher "The Slackware Linux Project - http://www.slackware.com/" \
    -A "Slackware-${RELEASE} DVD - build $DATE" \
    ${DVD_EXCLUDES} \
    ${UEFI_OPTS} \
    . \
    > ${SLACKROOTDIR}/${SLACKRELEASE}-iso/mkisofs-dvd.log 2>&1

  MKISOERR=$?

  if [ $MKISOERR -eq 0 ]; then
    # Create a hybrid ISO if requested:
    if [ -x $ISOHYBRID ]; then
      echo "$(date) [$$]: Creating hybrid ISO."
      $ISOHYBRID ${ISOHYBRID_OPTS} ${SLACKROOTDIR}/${SLACKRELEASE}-iso/.building-slackware-install-dvd.iso
    fi
  else
    tail -10 ${SLACKROOTDIR}/${SLACKRELEASE}-iso/mkisofs-dvd.log | \
      sed -e 's/^/! /'
  fi

  echo "$(date) [$$]: DVD ISO created (exit code ${MKISOERR}) ..."

  if [ $PREREMOVE -eq 0 ]; then
    # Deleting the previous ISO after creating the new ISO
    rm -f ${SLACKROOTDIR}/${SLACKRELEASE}-iso/${SLACKRELEASE}-install-dvd.iso
  fi

  # Make the new ISO "visible"
  mv ${SLACKROOTDIR}/${SLACKRELEASE}-iso/.building-slackware-install-dvd.iso \
     ${SLACKROOTDIR}/${SLACKRELEASE}-iso/${SLACKRELEASE}-install-dvd.iso

  fi ## end of [ "$ISO" == "DVD" -o  "$ISO" == "ALL" ]


  # Compute MD5 checksums for the downloaders
  echo "$(date) [$$]: Computing MD5 checksums of the ISOs (time consuming)."

  cd ${SLACKROOTDIR}/${SLACKRELEASE}-iso
  $MD5SUM *install*.iso > MD5SUM
  LATEST_ADD=$(head -n 40 ${SLACKROOTDIR}/${SLACKRELEASE}/ChangeLog.txt|grep -Ei "^(mon|tue|wed|thu|fri|sat|sun)"|head -n 1)
  echo ${LATEST_ADD} > LATEST_ADDITION_TO_CURRENT

  echo "$(date) [$$]: Resulting ISO files:"
  ls -l ${SLACKROOTDIR}/${SLACKRELEASE}-iso/*install*.iso

  # You can define the function 'post_current()' in the configuration file
  # 'mirror-slackware-current.conf'.  It will then be executed here.
  # Use this for instance to kick of other scripts:
  if type post_current 1>/dev/null 2>/dev/null ; then
    [ $DEBUG -ne 0 ] && echo "$(date) [$$]: Running custom function 'post_current'"
    post_current
  fi

  echo "$(date) [$$]: Done!"

  # Clean up after ourselves:
  rm -f $TMP/${SCRIPTID}_${SLACKRELEASE}_ChangeLog.txt
  rm -f $PIDFILE
fi

