#!/bin/sh
# TopGit - A different patch queue manager
# (c) Petr Baudis <pasky@suse.cz>  2008
# GPLv2

populate= # Set to 1 if we shall seed local branches with this
name=


## Parse options

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	--populate)
		populate=1;;
	-*)
		echo "Usage: tg [...] remote [--populate] REMOTE" >&2
		exit 1;;
	*)
		name="$arg";;
	esac
done

git config "remote.$name.url" >/dev/null || die "unknown remote '$name'"


## Configure the remote

git config --add "remote.$name.fetch" "+refs/top-bases/*:refs/remotes/$name/top-bases/*"
git config --add "remote.$name.push" "+refs/top-bases/*:refs/top-bases/*"
git config --add "remote.$name.push" "+refs/heads/*:refs/heads/*"

info "Remote $name can now follow TopGit topic branches."
if [ -z "$populate" ]; then
	info "Next, do: git fetch $name"
	exit
fi


## Populate local branches

info "Populating local topic branches from remote '$name'..."

git fetch "$name"
git for-each-ref "refs/remotes/$name/top-bases" |
	while read rev type ref; do
		branch="${ref#refs/remotes/$name/top-bases/}"
		if git rev-parse "$branch" >/dev/null 2>&1; then
			git rev-parse "refs/top-bases/$branch" >/dev/null 2>&1 ||
				git update-ref "refs/top-bases/$branch" "$rev"
			info "Skipping branch $branch: Already exists"
			continue
		fi
		info "Adding branch $branch..."
		git update-ref "refs/top-bases/$branch" "$rev"
		git update-ref "refs/heads/$branch" "$(git rev-parse "$name/$branch")"
	done

git config "topgit.remote" "$name"
info "The remote '$name' is now the default source of topic branches."