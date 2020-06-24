#!/bin/sh
set -e

cd `dirname $0`
cd ..

if git branch | grep -q '\* clean' ; then
	true
else
	echo "Refusing to run $0 when not on branch 'clean'" 1>&2
	exit 1
fi

set +e
for x in a b c d e f g h i j k l m ; do
	echo "$x-root"
	find ???? -name "$x-root-*.yaml" -type f -print \
	| sort -t/ -k 4 \
	| parallel -k -n 100 yamllint -d relaxed --no-warnings \
	>yamllint/$x-root.txt 2>&1
	test -s yamllint/$x-root.txt || rm yamllint/$x-root.txt
done
