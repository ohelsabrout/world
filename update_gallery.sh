#!/bin/bash
echo "const studioImages = [" > gallery_data.js
ls images/studio | sed 's/.*/"&"/' | paste -sd, - >> gallery_data.js
echo "];" >> gallery_data.js

echo "const tattooImages = [" >> gallery_data.js
ls images/tattoo | sed 's/.*/"&"/' | paste -sd, - >> gallery_data.js
echo "];" >> gallery_data.js