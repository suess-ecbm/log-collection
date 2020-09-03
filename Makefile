README.html:

%.html: %.md
	pandoc "$<" -o "$@"
