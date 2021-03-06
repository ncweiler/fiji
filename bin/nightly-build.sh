#!/bin/sh

compile () {
	# make sure that JAVA_HOME is set to Java5
	JAVA5_HOME="$(ls -d "$(pwd)"/java/*/jdk1.5* 2>/dev/null)" &&
	export JAVA_HOME="$JAVA5_HOME"

	git reset --hard $1 &&
	# make sure that the cross compilers are not removed
	for d in root-x86_64-pc-linux chroot-dapper-i386 livecd
	do
		test ! -d $d ||
		git update-index --add --cacheinfo \
			160000 1234567890123456789012345678901234567890 $d ||
		break
	done &&
	git clean -q -x -d -f &&
	# remove empty directories
	for d in $(git ls-files --other --directory)
	do
		rm -r $d || break
	done &&
	git reset &&
	./Build.sh
}

nightly_build () {
	EMAIL=fiji-devel@googlegroups.com
	TMPFILE=.git/build.$$.out

	(git fetch origin master &&
	 compile FETCH_HEAD) > $TMPFILE 2>&1  &&
	rm $TMPFILE || {
		mail -s "Fiji nightly build failed" \
			-a "Content-Type: text/plain; charset=UTF-8" \
			$EMAIL < $TMPFILE
		echo Failed: see $TMPFILE
	}
}


case "$1" in
--stdout)
	case "$(basename "$(cd "$(dirname "$0")"/.. && pwd)")" in
	nightly-build)
		cd "$(dirname "$0")"/..
		;; # okay
	*)
		echo "Refusing to run outside nightly-build/" >&2
		exit 1
		;;
	esac &&
	compile ${2:-HEAD}
	;;
--full)
	case "$(basename "$(cd "$(dirname "$0")"/.. && pwd)")" in
	full-nightly-build)
		cd "$(dirname "$0")"/.. &&
		git fetch origin master &&
		git reset --hard FETCH_HEAD &&
		git submodule update &&
		nightly_build &&
		if test -d /var/www/update
		then
			find -name \*.java |
			grep -ve ij-plugins/Sun_JAI_Sample_IO_Source_Code \
				-e ij-plugins/Quickvol |
			./fiji --jar-path $(./fiji --print-java-home)/../lib/ \
				--main-class=com.sun.tools.javadoc.Main \
				-d /var/www/javadoc \
				@/dev/stdin > javadoc.out 2>&1 ||
			(echo "JavaDoc failed"; false)
		fi
		;; # okay
	*)
		if test ! -d full-nightly-build
		then
			git clone . full-nightly-build
		fi &&
		HEAD=${2:-$(git rev-parse --symbolic-full-name HEAD)}
		cd full-nightly-build &&
		git fetch .. "$HEAD" &&
		git reset --hard FETCH_HEAD &&
		git submodule update --init &&
		compile FETCH_HEAD
		;;
	esac
	;;
'')
	case "$(basename "$(cd "$(dirname "$0")"/.. && pwd)")" in
	nightly-build)
		cd "$(dirname "$0")"/..
		;; # okay
	*)
		exec "$0" HEAD
		;;
	esac

	nightly_build
	;;
*)
	test -d nightly-build ||
	git clone . nightly-build &&
	cd nightly-build &&
	if test -z "$(find java -maxdepth 3 -type f)"
	then
		export JAVA_HOME=$(../fiji --print-java-home)
	fi &&
	git fetch .. "$1" &&
	compile FETCH_HEAD
	;;
esac
