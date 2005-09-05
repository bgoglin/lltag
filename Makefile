NAME	=	lltag
VERSION	=	0.5.4

.PHONY: install uninstall tarball

DESTDIR	=	
PREFIX	=	/usr/local
EXEC_PREFIX	=	$(PREFIX)
BINDIR	=	$(EXEC_PREFIX)/bin
DATADIR	=	$(PREFIX)/share
SYSCONFDIR	=	$(PREFIX)/etc
MANDIR	=	$(PREFIX)/man

TARBALL	=	$(NAME)-$(VERSION)
DEBIAN_TARBALL	=	$(NAME)_$(VERSION).orig

lltag::
	sed -e 's!@SYSCONFDIR@!$(SYSCONFDIR)!g' -e 's!@VERSION@!$(VERSION)!g' < lltag.in > lltag

install:: lltag
	install -d -m 0755 $(DESTDIR)$(BINDIR) $(DESTDIR)$(SYSCONFDIR)/lltag $(DESTDIR)$(MANDIR)/man1
	install -m 0755 lltag $(DESTDIR)$(BINDIR)/lltag
	install -m 0644 formats $(DESTDIR)$(SYSCONFDIR)/lltag
	install -m 0644 lltag.1 $(DESTDIR)$(MANDIR)/man1

uninstall::
	rm $(DESTDIR)$(BINDIR)/lltag
	rm $(DESTDIR)$(SYSCONFDIR)/lltag/format
	rmdir $(DESTDIR)$(SYSCONFDIR)/lltag
	rm $(DESTDIR)$(MANDIR)/man1/lltag.1

tarball::
	mkdir /tmp/$(TARBALL)
	cp lltag.in /tmp/$(TARBALL)
	cp formats /tmp/$(TARBALL)
	cp lltag.1 /tmp/$(TARBALL)
	cp Makefile /tmp/$(TARBALL)
	cd /tmp && cp -a $(TARBALL) $(DEBIAN_TARBALL) && tar cfz $(DEBIAN_TARBALL).tar.gz $(DEBIAN_TARBALL) && rm -rf $(DEBIAN_TARBALL)
	cd /tmp && tar cfj $(TARBALL).tar.bz2 $(TARBALL) && rm -rf /tmp/$(TARBALL)
	mv /tmp/$(DEBIAN_TARBALL).tar.gz /tmp/$(TARBALL).tar.bz2 ..
