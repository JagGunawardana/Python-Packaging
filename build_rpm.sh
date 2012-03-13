#!/usr/bin/env bash
# Script to build an RPM from Pypi or some tarball
# @param $1 package name
# @param $2 package version
# @param $3 python version [default 2.7]
# @param $4 alternative source URL [optional]

if [ -z $3 ]; then
#Default to Python2.7 
    PYVER=python2.7
else
    PYVER=python$3
fi

# Where do we want the packages to install to?
# please pick somewhere better.
LOCATION=/usr/lib/$PYVER/site-packages
SUFFIX=mycorp

echo Building packages for location $LOCATION, for organisation $SUFFIX

# Check for py2pack
(which py2pack &> /dev/null) || (echo "Exiting - you need to install py2pack" && exit 1)

echo building $1 at version $2 with $PYVER

# Setup
SPEC=$1.spec
rm -rf rpm
rm $SPEC &> /dev/null
mkdir -p rpm &> /dev/null
LOC=`pwd`/rpm
mkdir -p rpm/SOURCES
mkdir -p rpm/BUILD
mkdir -p rpm/BUILDROOT
mkdir -p rpm/RPMS
mkdir -p rpm/SRPMS
test -d $LOC || (echo "Can't find directory $LOC... exiting" && exit 1)

echo Generating spec file
# Generate the spec file
py2pack generate $1 $2
# Fiddle the macros first
sed -i "1i%define _prefix $LOCATION" $SPEC
sed -i "1i%define _topdir $LOC" $SPEC
sed -i "1i%define python_version $PYVER" $SPEC
# Now ensure that all goes to our directory
sed -i "s/%{python_sitelib}\/\*/$LOCATOIN\/\*/g" $SPEC
# Correct the install line
sed -i "/%install$/{n; s/.*/%{python_version} setup.py install -O1 --root=%{buildroot} --prefix=%{_prefix} --install-lib=%{_prefix} --install-purelib=%{_prefix}/}" $SPEC

# Finally correct the build line
sed -e '/%build/,$d' $SPEC > $SPEC.tmp1
sed -e '1,/%install/d' $SPEC > $SPEC.tmp2
echo %build >> $SPEC.tmp1
echo CFLAGS=\"%{optflags}\" %{python_version} setup.py build >> $SPEC.tmp1
echo >> $SPEC.tmp1
sed -i "1i%install" $SPEC.tmp2
cat $SPEC.tmp1 > $SPEC
cat $SPEC.tmp2 >> $SPEC

# Append a suffix to the name (to personalise the package)
sed -i "s/\(^Name:.*$\)/\1-$SUFFIX/g" $SPEC

# Clean up
rm $SPEC.tmp1 $SPEC.tmp2

# Fetch the source
if [ "$4" == "" ]; then
    py2pack fetch $1 $2
    mv $1-$2.* rpm/SOURCES
else
    if [ -f "$4" ]; then
        # We're fetching a file
        cp $4 rpm/SOURCES
        FNAME=$4
        cp $FNAME rpm/SOURCES
    else
        # We'll try to  fetch a URL
        wget $4
        FNAME=`echo $4 | sed "s/.*\/\([^/]*$\)/\1/"`
        mv $FNAME rpm/SOURCES
    fi
    sed -i "s/^Source:.*$/Source: $FNAME/g" $SPEC
fi

# Build it
rpmbuild -ba $SPEC

# Copy it
cp `find rpm -name "*.rpm"` .

#################### THE END ####################################

