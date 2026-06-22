WIDGET_ID = com.mi.widget.bateria

install:
	kpackagetool6 -i . -t Plasma/Applet || kpackagetool6 -u . -t Plasma/Applet
	systemctl --user restart plasma-plasmashell

uninstall:
	kpackagetool6 -r $(WIDGET_ID) -t Plasma/Applet || true
	systemctl --user restart plasma-plasmashell

restart:
	systemctl --user restart plasma-plasmashell
