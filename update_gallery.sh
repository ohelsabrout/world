#!/bin/bash
echo "const sculptureImages = [" > gallery_data.js
ls images/sculpture | sed 's/.*/"&"/' | paste -sd, - >> gallery_data.js
echo "];" >> gallery_data.js

echo "const tattooImages = [" >> gallery_data.js
ls images/tattoo | sed 's/.*/"&"/' | paste -sd, - >> gallery_data.js
echo "];" >> gallery_data.js