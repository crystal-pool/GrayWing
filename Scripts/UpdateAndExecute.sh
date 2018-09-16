#!/usr/bin/env bash

# Interactively update the application.

pushd .
git pull
# Build client first
cd ../graywing-client/
npm install
ng build --prod

# Build the server app
cd ../GrayWing/
dotnet publish -c Release

# Start app
cd bin/Release/netcoreapp2.1/publish
dotnet GrayWing.dll

# Until Ctrl+C
popd
