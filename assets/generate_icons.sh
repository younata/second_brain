#!/bin/bash -e

export APP_NAME="Second Brain"

function chevron_icon {
    parallel --progress -j 0 << EOF
svgexport Chevron.xml Chevron@2x.png 48:48
svgexport Chevron.xml Chevron@3x.png 72:72
EOF

    parallel --progress -j 0 << EOF
convert Chevron@2x.png -rotate -180 "../$APP_NAME/Images.xcassets/DownChevron.imageset/DownChevron@2x.png"
convert Chevron@3x.png -rotate -180 "../$APP_NAME/Images.xcassets/DownChevron.imageset/DownChevron@3x.png"
EOF
    rm Chevron@2x.png Chevron@3x.png
}

function app_icon {
    parallel --progress -j 0 << EOF
svgexport AppIcon.xml "../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon@2x.png" 120:120
svgexport AppIcon.xml "../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon@3x.png" 180:180
svgexport AppIcon.xml "../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon-iPadPro@2x.png" 167:167
svgexport AppIcon.xml "../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon-iPad.png" 76:76
svgexport AppIcon.xml "../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon-iPad@2x.png" 152:152
svgexport AppIcon.xml "../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon-AppStore.png" 1024:1024
EOF
    export ASSET_PATH="../$APP_NAME/Images.xcassets/AppIcon.appiconset"
    parallel --progress -j 0 << EOF
convert "$ASSET_PATH/Icon@2x.png" -background white -alpha remove "$ASSET_PATH/Icon@2x.png"
convert "$ASSET_PATH/Icon@3x.png" -background white -alpha remove "$ASSET_PATH/Icon@3x.png"
convert "$ASSET_PATH/Icon-iPadPro@2x.png" -background white -alpha remove $ASSET_PATH/Icon-iPadPro@2x.png"
convert "$ASSET_PATH/Icon-iPad.png" -background white -alpha remove $ASSET_PATH/Icon-iPad.png"
convert "$ASSET_PATH/Icon-iPad@2x.png" -background white -alpha remove $ASSET_PATH/Icon-iPad@2x.png"
convert "$ASSET_PATH/Icon-AppStore.png" -background white -alpha remove $ASSET_PATH/Icon-AppStore.png"
EOF
}

if [ $# -eq 1 ]; then
    case "$1" in
        "app") app_icon ;;
        "chevron") chevron_icon ;;
        *)
            echo "Usage: $0 [app, chevron]"
            echo "No arguments will recreate all icons."
            ;;
    esac
else
    export -f app_icon
    export -f chevron_icon

    parallel --progress -j 0 << EOF
app_icon
chevron_icon
EOF
fi

