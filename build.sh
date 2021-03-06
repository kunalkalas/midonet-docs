#!/bin/bash

#
# Fail on error.
#
set -o pipefail
fail_on_error() {
    if [ $? -ne 0 ]; then
        echo "---------------------------------------------------------------"
        echo "BUILD FAILURE"
        echo "---------------------------------------------------------------"
        exit 1
    fi
}

#
# Remove stale build target directories manually
# to avoid trouble when running within Jenkins.
#
cd $(dirname "${BASH_SOURCE[0]}") || exit
find build -type d -name "target" | xargs rm -rfv

#
# Force UTC timestamps.
#
export TZ="Etc/UTC"

#
# Clean and build.
#
mvn clean install 2>&1 | tee build.log
fail_on_error

#
# Search the build log for AsciiDoc warnings.
#
echo "Checking for Asciidoctor warnings..."
ASCIIDOC_WARNINGS=$(grep -i "asciidoctor.*warning" build.log)
if [ $? -eq 0 ]; then
    echo ""
    echo "############################################################"
    echo "${ASCIIDOC_WARNINGS}"
    echo "############################################################"
    echo ""
    echo "BUILD FAILURE: ASCIIDOC WARNING(S) FOUND!"
    exit 1
fi
echo "Ok."

#
# Search generated HTML files for duplicate Disqus identifiers.
#
echo "Checking for duplicate Disqus IDs..."
DUPLICATE_DISQUS_IDS=$(find . -path "*/docbkx/webhelp/*.html" -print0 | xargs -0 grep --no-filename "var disqus_identifier =" | sort | uniq -cd | sort -nr)
if [ "${#DUPLICATE_DISQUS_IDS}" -ne 0 ]; then
    echo ""
    echo "############################################################"
    echo "${DUPLICATE_DISQUS_IDS}"
    echo "############################################################"
    echo ""
    echo "BUILD FAILURE: DUPLICATE DISQUS ID(S) FOUND!"
    exit 1
fi
echo "Ok."

#
# Search generated FO files for unintended ":leveloffset:" identifiers.
#
echo "Checking for wrong level offsets..."
UNINTENDED_LEVELOFFSETS=$(find . -path "*/docbkx/autopdf/*.fo" -print0 | xargs -0 grep -l ":leveloffset:" | sort | uniq)
if [[ ! -z ${UNINTENDED_LEVELOFFSETS} ]]; then
    echo ""
    echo "############################################################"
    echo "${UNINTENDED_LEVELOFFSETS}"
    echo "############################################################"
    echo ""
    echo "BUILD FAILURE: UNINTENDED \":leveloffset:\" IN FO OUTPUT FOUND!"
    exit 1
fi
echo "Ok."

echo "---------------------------------------------------------------"
echo "BUILD SUCCESS"
echo "---------------------------------------------------------------"
