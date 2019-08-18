#!/bin/sh

sed -i -E 's_(//)?flowFile:.*_flowFile: "flows.json",_' /root/.node-red/settings.js

exec node-red
