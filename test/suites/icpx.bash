icpx_PROBE() {
    if [ -z "$REAL_ICPX" ]; then
        echo "icpx is not available"
    fi
}

icpx_SETUP() {
    cat <<EOF >test.cpp
int main() {
    return 0;
}
EOF

    cat <<EOF >test_sycl.cpp
#include <sycl/sycl.hpp>

int main() {
    sycl::queue q;
    q.submit([&](sycl::handler &h) {
        h.single_task([=]() {});
    });
    return 0;
}
EOF
}

icpx_tests() {
    ccache_icpx="$CCACHE $REAL_ICPX -c"

    # -------------------------------------------------------------------------
    TEST "Simple mode"

    $REAL_ICPX -c -o reference_test.o test.cpp

    $ccache_icpx test.cpp
    expect_stat preprocessed_cache_hit 0
    expect_stat cache_miss 1
    expect_stat files_in_cache 1

    $ccache_icpx test.cpp
    expect_stat preprocessed_cache_hit 1
    expect_stat cache_miss 1
    expect_stat files_in_cache 1

    # -------------------------------------------------------------------------
    TEST "SYCL compilation with -fsycl"

    $REAL_ICPX -fsycl -c -o reference_sycl.o test_sycl.cpp

    $ccache_icpx -fsycl test_sycl.cpp
    expect_stat preprocessed_cache_hit 0
    expect_stat cache_miss 1
    expect_stat files_in_cache 1

    $ccache_icpx -fsycl test_sycl.cpp
    expect_stat preprocessed_cache_hit 1
    expect_stat cache_miss 1
    expect_stat files_in_cache 1

    # -------------------------------------------------------------------------
    TEST "SYCL with different -fsycl-targets"

    $ccache_icpx -fsycl -fsycl-targets=spir64 test_sycl.cpp
    expect_stat preprocessed_cache_hit 0
    expect_stat cache_miss 1
    expect_stat files_in_cache 1

    $ccache_icpx -fsycl -fsycl-targets=spir64 test_sycl.cpp
    expect_stat preprocessed_cache_hit 1
    expect_stat cache_miss 1
    expect_stat files_in_cache 1

    # Different target should be a cache miss.
    $ccache_icpx -fsycl -fsycl-targets=spir64_gen test_sycl.cpp
    expect_stat preprocessed_cache_hit 1
    expect_stat cache_miss 2
    expect_stat files_in_cache 2

    # -------------------------------------------------------------------------
    TEST "With and without -fsycl should produce different cache entries"

    $ccache_icpx test.cpp
    expect_stat preprocessed_cache_hit 0
    expect_stat cache_miss 1
    expect_stat files_in_cache 1

    $ccache_icpx -fsycl test.cpp
    expect_stat preprocessed_cache_hit 0
    expect_stat cache_miss 2
    expect_stat files_in_cache 2

    # -------------------------------------------------------------------------
    TEST "SYCL device link with -fsycl-link should be cacheable"

    # First compile a SYCL source to .o
    $REAL_ICPX -fsycl -c -o test_sycl.o test_sycl.cpp

    # Run device link through ccache - first time is a miss.
    $CCACHE $REAL_ICPX -fsycl -fsycl-link test_sycl.o -o test_sycl_dev.o
    expect_stat cache_miss 1
    expect_stat files_in_cache 1

    # Same device link again should be a hit.
    $CCACHE $REAL_ICPX -fsycl -fsycl-link test_sycl.o -o test_sycl_dev.o
    expect_stat preprocessed_cache_hit 0
    expect_stat direct_cache_hit 1
    expect_stat cache_miss 1
    expect_stat files_in_cache 1

    # -------------------------------------------------------------------------
    TEST "SYCL device link with different -Xs options should produce different cache entries"

    $REAL_ICPX -fsycl -c -o test_sycl.o test_sycl.cpp

    $CCACHE $REAL_ICPX -fsycl -fsycl-link -fsycl-targets=spir64 test_sycl.o -o test_sycl_dev.o
    expect_stat cache_miss 1
    expect_stat files_in_cache 1

    $CCACHE $REAL_ICPX -fsycl -fsycl-link -fsycl-targets=spir64_gen test_sycl.o -o test_sycl_dev.o
    expect_stat cache_miss 2
    expect_stat files_in_cache 2
}

SUITE_icpx_PROBE() {
    icpx_PROBE
}

SUITE_icpx_SETUP() {
    icpx_SETUP
}

SUITE_icpx() {
    icpx_tests
}
