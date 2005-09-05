NAME	=	lltag
VERSION	=	0.4.2

.PHONY: install uninstall tarball

DESTDIR	=	
PREFIX	=	/usr/local
EXEC_PREFIX	=	$(PREFIX)
BINDIR	=	$(EXEC_PREFIX)/bin
DATADIR	=	$(PREFIX)/share
SYSCONFDIR	=	$(PREFIX)/etc
MANDIR	=	$(PREFIX)/man

TARBALL	=	$(NAME)_$(VERSION).orig

install::
	install -d -m 0755 $(DESTDIR)$(BINDIR) $(DESTDIR)$(MANDIR)/man1
	install -m 0755 lltag $(DESTDIR)$(BINDIR)/lltag
	install -m 0644 lltag.1 $(DESTDIR)$(MANDIR)/man1

uninstall::
	rm $(DESTDIR)$(BINDIR)/lltag
	rm $(DESTDIR)$(MANDIR)/man1/lltag.1

tarball::
	mkdir /tmp/$(TARBALL)
	cp lltag /tmp/$(TARBALL)
	cp Makefile /tmp/$(TARBALL)
	cp lltag.1 /tmp/$(TARBALL)
	cd /tmp && tar cfz $(TARBALL).tar.gz $(TARBALL)
	rm -rf /tmp/$(TARBALL)
	mv /tmp/$(TARBALL).tar.gz ..
