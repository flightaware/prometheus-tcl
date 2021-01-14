#
# Makefile for Tcl-based Prometheus client package 
#
# basically we make a pkgIndex.tcl package file and install stuff
#

PACKAGE=prometheus-tcl
PREFIX?=/usr/local
TCLSH=tclsh
PACKAGELIBDIR?=$(PREFIX)/lib/$(PACKAGE)_tcl
LIBSOURCES= config.tcl client_api.tcl client_api_internals.tcl shared_utils.tcl validators.tcl metric_family.tcl metric.tcl counter.tcl gauge.tcl histogram.tcl summary.tcl registry.tcl exposition_http.tcl exposition.tcl exposition_text_format.tcl exposition_mt.tcl

all:    pkgIndex.tcl
	@echo "'make install' to install"

package:   $(LIBSOURCES)
	rm -f pkgIndex.tcl
	$(TCLSH) create_pkgIndex.tcl $(LIBSOURCES) > pkgIndex.tcl

install:    install-package

install-package:    package
	-mkdir -p $(PACKAGELIBDIR)
	rm -f $(PACKAGELIBDIR)/*.tcl
	cp $(LIBSOURCES) pkgIndex.tcl $(PACKAGELIBDIR)
	cd $(PACKAGELIBDIR); echo "package require $(PACKAGE)" | tclsh

.PHONY: docs
docs:
ifeq ("$(shell which doxygen)", "")
	@echo "No doxygen found: cannot create docs"
else
	@echo "Generating doxygen docs for $(PACKAGE) package"
	@doxygen
endif

.PHONY: tests
tests:
	tclsh tests/all.tcl

test: tests

clean:
	rm -f pkgIndex.tcl
