.PHONY: install uninstall

install:
	install -d -m 0755 $(DOCDIR)
	find . -type d -exec install -d -m 0755 $(DOCDIR)/{} \;
	find . -type f -not -name Makefile -exec install -m 0644 {} $(DOCDIR)/{} \;

uninstall:
	find . -type f -not -name Makefile -exec rm -f $(DOCDIR)/{} \;
	find . -depth -type d -exec rmdir $(DOCDIR)/{} \;
	rmdir $(DOCDIR) || true
