#! /bin/sh

sudo launchctl unload /Library/LaunchDaemons/com.madda.Stats.SMC.Helper.plist
sudo rm /Library/LaunchDaemons/com.madda.Stats.SMC.Helper.plist
sudo rm /Library/PrivilegedHelperTools/com.madda.Stats.SMC.Helper
sudo rm $HOME/Library/Application Support/Stats
