#!/bin/sh
# The work-term guard over the staged diff. A lefthook script rather than a
# command: see lefthook.yml.
exec bin/work-terms check-staged
