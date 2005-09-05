NAME	=	lltag
VERSION	=	0.4

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
	install -d -m 0755 $(DESTDIR)$(BINDIR)
	install -m 0755 lltag $(DESTDIR)$(BINDIR)/lltag

uninstall::
	rm $(DESTDIR)$(BINDIR)/lltag

tarball::
	mkdir /tmp/$(TARBALL)
	cp lltag /tmp/$(TARBALL)
	cp Makefile /tmp/$(TARBALL)
	cd /tmp && tar cfz $(TARBALL).tar.gz $(TARBALL)
	rm -rf /tmp/$(TARBALL)
	mv /tmp/$(TARBALL).tar.gz ..
