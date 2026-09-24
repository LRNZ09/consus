#!/bin/sh
# The work-term guard over every commit being pushed. lefthook passes the
# remote as $1 and git's ref lines on stdin.
exec bin/placeholders check-push "$1"
