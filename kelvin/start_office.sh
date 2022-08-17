#!/usr/bin/env sh

ws1="1:  Slack"
ws2="2:  Terminal"
ws3="3:  Browser"
ws4="4:  General"
ws5="5:  Terminal"
ws6="6:  IntelliJ"
ws7="7:  Playground"
ws8="8:  Code"
ws9="9:  Chat"
ws10="10:  Spotify"

i3-msg "workspace $ws1; exec /usr/bin/slack"
i3-msg "workspace $ws3; exec /usr/bin/firefox-developer-edition"
i3-msg "workspace $ws4; exec /usr/bin/thunderbird"
i3-msg "workspace $ws10; exec /usr/bin/spotify"
i3-msg "workspace $ws2; exec /usr/bin/alacrity"

betterlockscreen -u ~/Pictures/lockscreen.jpg
