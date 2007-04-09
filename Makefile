NAME	=	lltag
ifeq ($(shell [ -d .svn ] && echo 1),1)
	VERSION	=	$(shell cat VERSION)+svn.$(shell date +%Y%m%d)
else
	VERSION	=	$(shell cat VERSION)
endif

LIB_SUBDIR	=	lib
DOC_SUBDIR	=	doc

DESTDIR	=	
PREFIX	=	/usr/local
EXEC_PREFIX	=	$(PREFIX)
BINDIR	=	$(EXEC_PREFIX)/bin
DATADIR	=	$(PREFIX)/share
SYSCONFDIR	=	$(PREFIX)/etc
MANDIR	=	$(PREFIX)/man
DOCDIR	=	$(DATADIR)/doc
PERL_INSTALLDIRS	=	

TARBALL	=	$(NAME)-$(VERSION)
DEBIAN_TARBALL	=	$(NAME)_$(VERSION).orig

.PHONY: lltag clean install uninstall tarball

lltag:: lltag.in VERSION build-lib
	sed -e 's!@SYSCONFDIR@!$(DESTDIR)$(SYSCONFDIR)!g' -e 's!@VERSION@!$(DESTDIR)$(VERSION)!g' \
		< lltag.in > lltag
	chmod 755 lltag

clean:: clean-lib
	rm -f lltag

install:: install-lib
	install -d -m 0755 $(DESTDIR)$(BINDIR)/ $(DESTDIR)$(SYSCONFDIR)/lltag/
	install -m 0755 lltag $(DESTDIR)$(BINDIR)/lltag
	install -m 0644 formats $(DESTDIR)$(SYSCONFDIR)/lltag/

uninstall:: uninstall-lib
	rm $(DESTDIR)$(BINDIR)/lltag
	rm $(DESTDIR)$(SYSCONFDIR)/lltag/formats
	rmdir $(DESTDIR)$(SYSCONFDIR)/lltag/

tarball::
	mkdir /tmp/$(TARBALL)
	cp lltag.in /tmp/$(TARBALL)
	cp formats /tmp/$(TARBALL)
	cp lltag.1 lltag_config.5 lltag_formats.5 /tmp/$(TARBALL)
	cp Makefile /tmp/$(TARBALL)
	cp COPYING README VERSION /tmp/$(TARBALL)
	cp Changes /tmp/$(TARBALL)
	cp -a $(DOC_SUBDIR)/ /tmp/$(TARBALL)
	cp -a $(LIB_SUBDIR) /tmp/$(TARBALL)
	cd /tmp && tar cfz $(DEBIAN_TARBALL).tar.gz $(TARBALL)
	cd /tmp && tar cfj $(TARBALL).tar.bz2 $(TARBALL)
	mv /tmp/$(DEBIAN_TARBALL).tar.gz /tmp/$(TARBALL).tar.bz2 ..
	rm -rf /tmp/$(TARBALL)

# Perl modules
.PHONY: build-lib clean-lib install-lib uninstall-lib prepare-lib

$(LIB_SUBDIR)/Makefile.PL: $(LIB_SUBDIR)/Makefile.PL.in VERSION
	sed -e 's!@VERSION@!$(VERSION)!g' < $(LIB_SUBDIR)/Makefile.PL.in > $(LIB_SUBDIR)/Makefile.PL

$(LIB_SUBDIR)/Makefile: $(LIB_SUBDIR)/Makefile.PL
	cd $(LIB_SUBDIR) && perl Makefile.PL INSTALLDIRS=$(PERL_INSTALLDIRS)

prepare-lib: $(LIB_SUBDIR)/Makefile

build-lib: prepare-lib
	$(MAKE) -C $(LIB_SUBDIR)

install-lib: prepare-lib
	$(MAKE) -C $(LIB_SUBDIR) install PREFIX= SITEPREFIX=$(PREFIX) PERLPREFIX=$(PREFIX) VENDORPREFIX=$(PREFIX)

clean-lib: prepare-lib
	$(MAKE) -C $(LIB_SUBDIR) distclean
	rm $(LIB_SUBDIR)/Makefile.PL

uninstall-lib: prepare-lib
	$(MAKE) -C $(LIB_SUBDIR) uninstall

# Install the doc, only called on-demand by distrib-specific Makefile
.PHONY: install-doc uninstall-doc

install-doc:
	$(MAKE) -C $(DOC_SUBDIR) install DOCDIR=$(DESTDIR)$(DOCDIR)

uninstall-doc:
	$(MAKE) -C $(DOC_SUBDIR) uninstall DOCDIR=$(DESTDIR)$(DOCDIR)

# Install the manpages, only called on-demand by distrib-specific Makefile
.PHONY: install-man uninstall-man

install-man::
	install -d -m 0755 $(DESTDIR)$(MANDIR)/man1/ $(DESTDIR)$(MANDIR)/man5/
	install -m 0644 lltag.1 $(DESTDIR)$(MANDIR)/man1/
	install -m 0644 lltag_config.5 $(DESTDIR)$(MANDIR)/man5/
	install -m 0644 lltag_formats.5 $(DESTDIR)$(MANDIR)/man5/

uninstall-man::
	rm $(DESTDIR)$(MANDIR)/man1/lltag.1
	rm $(DESTDIR)$(MANDIR)/man5/lltag_config.5
	rm $(DESTDIR)$(MANDIR)/man5/lltag_formats.5
