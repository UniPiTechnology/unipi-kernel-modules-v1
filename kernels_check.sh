#!/bin/bash

set -e 

RPI_REPO="http://archive.raspberrypi.org/debian"
REPO="https://repo.unipi.technology/debian"
STABLE_CODENAME="buster"
OLDSTABLE_CODENAME="stretch"


function check_kernel ()
{
  ## find last generated kernel-module version in UniPi repo
  echo "deb [arch=${ARCH}] $REPO $DEBIAN_VERSION main g1-main zulu-main" > /etc/apt/sources.list.d/unipi.list
  if [ ${ARCH} = "armhf" ]; then
    echo "deb [arch=${ARCH}] $RPI_REPO  $DEBIAN_VERSION main" > /etc/apt/sources.list.d/rpi.list
  fi
  apt-get update
  MODULES_VER=`apt-cache show -o APT::Architecture=${ARCH} --no-all-versions $MODULES_PKG | sed -n "s/^Depends: .*$LINUX_KERNEL_PKG (= \([^)]*\).*$/\1/p"`
  LINUX_KERNEL_VER=`apt-cache show -o APT::Architecture=${ARCH} --no-all-versions $LINUX_KERNEL_PKG | sed -n 's/^Version: //p'`
  if [ "${MODULES_VER}" == "${LINUX_KERNEL_VER}" ]; then
    echo "No new Linux kernel"
    return 1
  else
    echo "${MODULES_VER}" "${LINUX_KERNEL_VER}"
    return 0
  fi
}

# prepare environment
apt-get install -y apt-transport-https
# install repo keys
curl "${RPI_REPO}/raspberrypi.gpg.key" -s | apt-key add -
curl "$REPO/unipi_pub.gpg" -s | apt-key add -

## check Neuron on Buster
LINUX_KERNEL_PKG=raspberrypi-kernel
DEBIAN_VERSION=${STABLE_CODENAME}
MODULES_PKG=unipi-kernel-modules
ARCH=armhf
check_kernel || DISABLE_STABLE_ARMHF=1

## check Neuron on Stretch
LINUX_KERNEL_PKG=raspberrypi-kernel
DEBIAN_VERSION=${OLDSTABLE_CODENAME}
MODULES_PKG=neuron-kernel
ARCH=armhf
check_kernel || DISABLE_OLDSTABLE_ARMHF=1

## check Axon on Buster
LINUX_KERNEL_PKG=axon-kernel-image
DEBIAN_VERSION=${STABLE_CODENAME}
MODULES_PKG=unipi-kernel-modules
ARCH=arm64
check_kernel || DISABLE_STABLE_ARM64=1

## check Axon on Stretch
LINUX_KERNEL_PKG=axon-kernel-image
DEBIAN_VERSION=${OLDSTABLE_CODENAME}
MODULES_PKG=unipi-kernel-modules
ARCH=arm64
check_kernel || DISABLE_OLDSTABLE_ARM64=1

## check G1 on Buster
LINUX_KERNEL_PKG=g1-kernel-image
DEBIAN_VERSION=${STABLE_CODENAME}
MODULES_PKG=g1-unipi-kernel-modules
ARCH=arm64
check_kernel || DISABLE_STABLE_G1=1

## check Zulu on Buster
LINUX_KERNEL_PKG=zulu-kernel-image
DEBIAN_VERSION=${STABLE_CODENAME}
MODULES_PKG=zulu-unipi-kernel-modules
ARCH=arm64
check_kernel || DISABLE_STABLE_ZULU=1

# create map commit->tag
git show-ref --tags -d \
  | awk -F "[ /^]" '/\.test\./{next;} {printf("s/^%s/(%s)/g\n",$1,$4)}' \
  | tac > commit_and_tags

#git show-ref --tags -d | awk -F "[ /^]" '{printf("s/^%s/(%s)/g\n",$1,$4)}' > commit_and_tags

# find the last tag from master branch
TAG=$(git log --branches=master, origin/master \
        --date="format:%Y%m%d%H%M%S" \
        --pretty="%H" \
 | sed -f commit_and_tags \
 | sed -n '/^(/p;/^(/q' \
 | sed 's/^(//;s/)$//')

# revert apt to original state
rm commit_and_tags
rm /etc/apt/sources.list.d/unipi.list /etc/apt/sources.list.d/rpi.list
apt-get update

echo ${TAG} "${DISABLE_STABLE_ARMHF}" "${DISABLE_OLDSTABLE_ARMHF}" "${DISABLE_STABLE_ARM64}" "${DISABLE_OLDSTABLE_ARM64}" "${DISABLE_STABLE_G1}" "${DISABLE_STABLE_ZULU}"

if [ "${DISABLE_STABLE_ARMHF}${DISABLE_OLDSTABLE_ARMHF}${DISABLE_STABLE_ARM64}${DISABLE_OLDSTABLE_ARM64}${DISABLE_STABLE_G1}${DISABLE_STABLE_ZULU}" != "111111" ]; then
    curl --request POST --form token=${CI_TRIGGER_TOKEN} --form "ref=${TAG}" \
         --form "variables[DISABLE_STABLE_ARMHF]=${DISABLE_STABLE_ARMHF:=0}" \
         --form "variables[DISABLE_STABLE_ARM64]=${DISABLE_STABLE_ARM64:=0}" \
         --form "variables[DISABLE_OLDSTABLE_ARMHF]=${DISABLE_OLDSTABLE_ARMHF:=0}" \
         --form "variables[DISABLE_OLDSTABLE_ARM64]=${DISABLE_OLDSTABLE_ARM64:=0}" \
         --form "variables[DISABLE_STABLE_G1]=${DISABLE_STABLE_G1:=0}" \
         --form "variables[DISABLE_STABLE_ZULU]=${DISABLE_STABLE_ZULU:=0}" \
         https://git.unipi.technology/api/v4/projects/16/trigger/pipeline
fi
## be carefull, this running script can be changed after checkout
#exec /bin/bash -c "export CI_COMMIT_TAG=$TAG; git checkout ${TAG} && /ci-scripts/build-package.sh -m $*"