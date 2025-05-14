#!/bin/sh

if [ -d "/pnpm-temp" ] && [ "$(ls -A /pnpm-temp)" ]; then
  echo "Copying pnpm cache from shared read-only volume..."
  mkdir -p /pnpm/store
  cp -r /pnpm-temp/store/* /pnpm/store/
  echo "PNPM cache successfully copied to internal store"
  rm -rf /pnpm-temp
  echo "Removed temporary pnpm cache directory"
fi

exec "$@"
