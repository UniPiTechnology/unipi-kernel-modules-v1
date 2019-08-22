#!/bin/bash

# load $DEBIAN_VERSION
[ -r /ci-scripts/include.sh ] && . /ci-scripts/include.sh

REPO="https://repo3.unipi.technology/debian"
MODULES_PKG=unipi-kernel-modules
LINUX_KERNEL_PKG=axon-kernel-image

## find last generated kernel-module version in UniPi repo
apt-get install -y apt-transport-https
echo "deb $REPO $DEBIAN_VERSION main" > /etc/apt/sources.list.d/unipi.list
wget "$REPO/unipi_pub.gpg" -q -O - | apt-key add -
apt-get update
MODULES_VER=`apt-cache show --no-all-versions $MODULES_PKG | sed -n "s/^Depends: .*$LINUX_KERNEL_PKG (= \([^)]*\).*$/\1/p"`
LINUX_KERNEL_VER=`apt-cache show --no-all-versions $LINUX_KERNEL_PKG | sed -n 's/^Version: //p'`
echo "${MODULES_VER} =?= ${LINUX_KERNEL_VER}"
if [ "${MODULES_VER}" == "${LINUX_KERNEL_VER}" ]; then
    echo "No new Linux kernel"
    exit
fi

apt-get install -y axon-kernel-headers

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

echo ${TAG}
rm commit_and_tags
## be carefull, this running script can be changed after checkout
exec /bin/bash -c "export CI_COMMIT_TAG=$TAG; git checkout ${TAG} && /ci-scripts/build-package.sh -m $*"