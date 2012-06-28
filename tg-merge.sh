#!/bin/bash
# topgit-merge: do an octopus merge of multiple topgit branches
# Copyright (C) 2011-2012 Marcin Owsiany <porridge@debian.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

set -e
#set -x
debug=""

# Get a list of topgit branches
if [ -z "$1" ]; then
	echo "Usage:" >&2
	echo " $0 {-a|--all} - merge all topgit branches into current branch" >&2
	echo " $0 <name>     - merge topgit branches containing <name> into current branch" >&2
	exit 1
elif [ "$1" = "-a" -o "$1" = "--all" ]; then
	tops="$(tg summary -t)"
else
	tops="$(tg summary -t | grep -- $1)"
fi

if [ -z "$tops" ]; then
	echo "\"tg summary\" returned no names" >&2
	exit 1
fi

# Make sure nothing is lying around, as we do a reset --hard at the end.
if [ "$(git status --porcelain | wc -l)" -ne 0 ]; then
	git status
	echo "Working tree must match the index completely." >&2
	echo "Aborting." >&2
	exit 1
fi

# Merge them one by one, deleting the .top{deps,msg} files each time
for top in $tops
do
	echo "Merging $top..." >&2
	$debug git read-tree -m -i top-bases/$top $top
	$debug git reset -q HEAD .topdeps .topmsg
done
echo "Done merging topgit branches." >&2

# Write the tree
tree=$($debug git write-tree)

# Commit it as a merge of all the topgit branches
declare -a parents
parents=([0]='-p' [1]='HEAD')
for top in $tops
do
	parents[${#parents[*]}]='-p'
	parents[${#parents[*]}]=$top
done
msgfile=$(mktemp)
trap "rm -f $msgfile" EXIT
(echo "Merged topgit branches:"; for top in $tops; do echo "  $top";done) > $msgfile
commit=$($debug git commit-tree $tree ${parents[*]} < $msgfile)

# Point the current branch at that commit
$debug git reset --hard $commit
