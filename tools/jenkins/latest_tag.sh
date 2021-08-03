#!/bin/bash
#
# Determines the latest tag of the mercurial repository pointed to by
# JDK_REPO. If there is a newer tag found that was written in
# 'latest_tag.txt', then another file 'build_trigger.txt' is being
# produced with the current timestamp (YY-MM-DD HH:mm) as content.
#set -xv

# 11u update cycle release version number
UPDATE="11.0.13"
JDK_URL=https://github.com/openjdk/jdk11u
JDK_REPO=jdk11u-git
BASE_PATH="$1"

if [ -z "${WORKSPACE}" ]; then
  WORKSPACE="$(pwd)"
fi
if [ -z "${BASE_PATH}" ]; then
  BASE_PATH="$(pwd)"
fi

check_clone() {
  echo "Checking top Git repo exists..."
  # Ensure parent folder exists
  if [ ! -e "$BASE_PATH" ]; then
    mkdir -p "$BASE_PATH"
  fi
  if [ -d "$BASE_PATH/$JDK_REPO" ]; then
    echo "$JDK_REPO exists, skipping clone."
  else
    pushd $BASE_PATH
      git clone $JDK_URL $JDK_REPO
    popd
  fi
}

# Export a local home so hg doesn't use some user-local aliases
tmp_dir="$(mktemp -d)"
export HOME=$tmp_dir

echo "Using base path: $BASE_PATH"

# Ensure clone exists
check_clone

pushd "$BASE_PATH/$JDK_REPO"

git pull --tags origin

LAST_TAG="$(cat ${WORKSPACE}/latest_tag.txt 2> /dev/null || true)"

# We restrict the tag listing for the current update cycle. Hence the pattern to -l
#
# refname:lstrip=2   transforms refs/tags/<tag> => <tag>
# -taggerdate        sorts descending by the date a tag got created (newest first)
for i in $(git tag -l "jdk-$UPDATE*" --format='%(refname:lstrip=2)' --sort=-taggerdate); do
  echo $i
done | tee revs.txt
num_tags=$(cat revs.txt | wc -l)

# One revision might have been tagged multiple times, or we
# might have a swtich from one GA release to the beginning of a
# new update (build 0).
if [ $num_tags -gt 1 ]; then
   candidate=$(sed 's/jdk-\([0-9]\{2\}\.[0-9]\+\.[0-9]\+\)+.*/\1/g' revs.txt | sort -n | tail -n1)
   candidates=$(grep $candidate revs.txt | wc -l)
   if [ $candidates -gt 1 ]; then
     # same revision tagged twice (no changes) case
     TAG=$(sort revs.txt | tail -n1)
   else
     # GA => new update case
     TAG=$(grep $candidate revs.txt)
   fi
else
   TAG="$(cat revs.txt)"
fi

if [ -z "$TAG" ]; then
  echo "No tags for update $UPDATE found. This is an error." 1>&2
  exit 1
fi
if ! echo $TAG | grep -q $UPDATE; then
  echo "Latest tag ($TAG) does not match configured update ($UPDATE). This is an error." 1>&2
  echo "It appears a new update cycle has started. Please update the job config" 1>&2
  echo "to the latest update." 1>&2
  exit 1
fi

if [ -z "$LAST_TAG" ]; then
   LATEST_TAG=$TAG
else
   # Check whether we have a newer tag
   num_tags=$(echo -e "$TAG\n$LAST_TAG" | sort | grep -v '^$'| uniq | wc -l)
   if [ $num_tags -gt 1 ]; then
      LATEST_TAG=$(echo -e "$TAG\n$LAST_TAG" | sort | grep -v '^$' | uniq | tail -n1)
   fi
fi

if [ ! -z "$LATEST_TAG" ]; then
  # Add bread-crumbs for downstream build
  date '+%Y-%m-%d %H:%M' > ${WORKSPACE}/build_trigger.txt
  echo "$LATEST_TAG" > ${WORKSPACE}/latest_tag.txt
else
  echo "No new tag found (old tag was $TAG). Nothing to do."
fi

rm -rf $tmp_dir
popd
