#!/bin/bash

echo "Resetting ServiceChecker preferences"

rm -rf ~/Library/Containers/org.yanson.ServiceChecker/Data/Library/Application\ Support/ServiceChecker
rm -rf ~/Library/Saved\ Application\ State/org.yanson.ServiceChecker.savedState
rm -rf ~/Library/Caches/org.yanson.ServiceChecker

defaults delete org.yanson.ServiceChecker
