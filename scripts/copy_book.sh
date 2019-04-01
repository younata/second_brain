/bin/sh

set -e

infoplist="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"
bookURLFile="${PROJECT_DIR}/.book_url"

if [[ -e ${bookURLFile} ]]; then
    contents=`cat "${bookURLFile}"`

    if [[ "${contents}" != "" ]]; then
        /usr/libexec/PlistBuddy -c "Add :BookURL string ${contents}" "${infoplist}"
        /usr/libexec/PlistBuddy -c "Set :BookURL ${contents}" "${infoplist}"
    else
        echo "warning: .book_url is empty"
    fi
else
    echo "warning: No .book_url file found"
fi
