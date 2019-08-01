#!/bin/bash

apt-get install -y apt-transport-https
echo 'deb https://repo.unipi.technology/debian testing main' > /etc/apt/sources.list.d/unipi.list
wget https://repo.unipi.technology/debian/unipi_pub.gpg -O - | apt-key add -
apt-get update
NEURON_KERNEL=`apt-cache show --no-all-versions neuron-kernel | sed -n 's/^Depends: .*raspberrypi-kernel (= \([^)]*\).*$/\1/p'`
RPI_KERNEL=`apt-cache show --no-all-versions raspberrypi-kernel | sed -n 's/^Version: //p'`
if [ "${NEURON_KERNEL}" == "${RPI_KERNEL}" ]; then
    echo "No new Raspbian kernel"
    exit
fi

# create map commit->tag
git show-ref --tags -d | awk -F "[ /^]" '{printf("s/^%s/(%s)/g\n",$1,$4)}' > commit_and_tags
# find the last tag from master branch
TAG=$(git log --branches=master, origin/master \
		--date="format:%Y%m%d%H%M%S" \
		--pretty="%H" \
 | sed -f commit_and_tags \
 | sed -n '/^(/p;/^(/q' \
 | sed 's/^(//;s/)$//')

echo ${TAG}
rm commit_and_tags

git checkout ${TAG} && /ci-scripts/build-package-for-master.sh $*
