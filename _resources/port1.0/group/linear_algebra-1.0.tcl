# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# This PortGroup sets up variants for serial linear algebra (Accelerate/ATLAS/OpenBLAS/OpenBLAS-devel).
#
# Usage:
#
#   PortGroup               linear_algebra 1.0
#
#   If only BLAS and not LAPACK is used, set:
#   linalg.setup blas_only
#   If BLAS/LAPACK are only called from C and not Fortran, then Accelerate can be used
#   directly and vecLibFort is not needed. Set:
#   linalg.setup noveclibfort
#
#   in pre-configure, a line like this may be needed:
#   configure.args-append --with-blas="-L${prefix}/lib ${linalglib}"
#   or
#   configure.args-append ${cmake_linalglib} (for CMake)
#
#
#   If +threads and +atlas are set, the threaded ATLAS library will be used.
#

# scalapack.

PortGroup active_variants 1.1

options linalglib \
        cmake_linalglib \
        blas_only \
        veclibfort

default linalglib ""
default cmake_linalglib ""
default blas_only no
default veclibfort yes

proc linalg.setup {args} {
    global blas_only, veclibfort

    foreach v $args {
        if {$v eq "blas_only"} {
            blas_only yes
        } elseif {$v eq "noveclibfort"} {
            veclibfort no
        } else {
            ui_error "Internal error: Unknown argument '$v' to linalg.setup."
            return -code error "Internal error: Unknown argument '$v' to linalg.setup."
        }
    }
}

if {![variant_isset accelerate] && ![variant_isset atlas] && ![variant_isset openblas]} {
    if {${os.platform} eq "darwin" && ${os.major} < 21} {
        # see https://trac.macports.org/ticket/65260
        default_variants-append +accelerate
    } else {
        default_variants-append +openblas
    }
}

# choose one of the following for serial linear algebra
variant accelerate conflicts atlas openblas description {Build with linear algebra from built-in Accelerate framework} {
    if {$veclibfort} {
        depends_lib-append      port:vecLibFort
        linalglib               -lvecLibFort
        cmake_linalglib         -DBLAS_LIBRARIES=vecLibFort \
                                -DLAPACK_LIBRARIES=vecLibFort
    } else {
        linalglib               -framework Accelerate
        cmake_linalglib         -DBLA_VENDOR=Apple
    }
}

variant atlas conflicts accelerate openblas description {Build with linear algebra from ATLAS} {
    depends_lib-append      port:atlas
    if {[variant_isset threads]} {
        linalglib           -ltatlas
        cmake_linalglib     -DBLAS_LIBRARIES=tatlas \
                            -DLAPACK_LIBRARIES=tatlas
    } else {
        linalglib           -lsatlas
        cmake_linalglib     -DBLAS_LIBRARIES=satlas \
                            -DLAPACK_LIBRARIES=satlas
    }
    # FindBLAS.cmake and FindLAPACK.cmake do not find MacPorts Atlas properly
    # configure.args-append -DBLA_VENDOR=ATLAS
}

variant openblas conflicts accelerate atlas description {Build with linear algebra from OpenBLAS} {
    # allow OpenBLAS-devel too
    depends_lib-append      path:lib/libopenblas.dylib:OpenBLAS
    if {!$blas_only} {
        require_active_variants path:lib/libopenblas.dylib:OpenBLAS lapack
    }
    linalglib               -lopenblas
    cmake_linalglib         -DBLA_VENDOR=OpenBLAS

    # The new linker in Xcode 15 is buggy, causing build failures for many (but not all)
    # ports that link to OpenBLAS. The -Wl,-ld_classic option below reverts to the
    # classic linker.
    #
    # TODO: This is a temporary solution, the classic linker will be removed in a future release by Apple.
    if { ( [vercmp ${xcodeversion} 15 ] >= 0 ) || ( [vercmp ${xcodecltversion} 15 ] >= 0 ) } {
        linalglib-append    -Wl,-ld_classic
    }
}

if {![variant_isset accelerate] && ![variant_isset openblas] && ![variant_isset atlas] } {
    ui_error "You must select either the +accelerate, +atlas, or +openblas variant for linear algebra."
    return -code error "No linear-algebra variant selected."
}
