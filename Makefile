
.OBJDIR: ${.CURDIR}
.MAIN: debug

ARCH = arm64
CC = clang

OBJROOT ?= ${.CURDIR}/obj
PREFIX ?= /usr
DESTDIR ?=

PROJECT_CFLAGS = -Weverything -std=c23 -fPIC -march=native -fblocks -fobjc-arc -fobjc-runtime=gnustep-2.2 \
	-march=native -Wno-c++98-compat -Wno-pre-c11-compat -Wno-pre-c23-compat -Wno-implicit-void-ptr-cast \
	-Wno-unsafe-buffer-usage -Wno-reserved-identifier -Wno-reserved-macro-identifier -Wno-switch-default \
	-Wno-declaration-after-statement -Wno-direct-ivar-access -Wno-objc-designated-initializers \
	-Wno-cstring-format-directive -Wno-gcc-compat
PROJECT_LDFLAGS = -fuse-ld=lld -L/usr/lib -rdynamic
PROJECT_LDLIBS = -lobjc -lBlocksRuntime -lunwind

CFLAGS = -I${.CURDIR}/Headers ${PROJECT_CFLAGS}
LDFLAGS = ${PROJECT_LDFLAGS}
LDLIBS = ${PROJECT_LDLIBS}

# A named mode affects every other goal in the same invocation.  Thus "bmake release test NSInvocation" builds both
# the library and those tests with the release configuration.
_REQUESTED_MODES = ${.TARGETS:Mdebug} ${.TARGETS:Mrelease} ${.TARGETS:Msan} ${.TARGETS:Mcoverage}
.if make(coverage-report) && empty(.TARGETS:Mcoverage)
_REQUESTED_MODES += coverage
.endif
.if ${_REQUESTED_MODES:[#]} > 1
.error Only one build mode may be requested at a time!
.endif

MODE ?= debug
.if make(coverage) || make(coverage-report)
MODE = coverage
.elif !empty(.TARGETS:Mrelease)
MODE = release
.elif !empty(.TARGETS:Msan)
MODE = san
.elif !empty(.TARGETS:Mdebug)
MODE = debug
.endif

.if ${MODE} == "release"
MODE_CFLAGS = -O3 -flto=full
MODE_LDFLAGS = -flto=full
.elif ${MODE} == "san"
CLANG_RESOURCE_DIR != ${CC} -print-resource-dir
SANITIZER_LIBRARY_DIR = ${CLANG_RESOURCE_DIR}/lib/linux
MODE_CFLAGS = -O1 -g -fno-omit-frame-pointer -fno-optimize-sibling-calls -fno-sanitize-recover=all \
	-fsanitize=address,undefined,integer
MODE_LDFLAGS = -fsanitize=address,undefined -shared-libsan -L${SANITIZER_LIBRARY_DIR} \
	-Wl,-rpath,${SANITIZER_LIBRARY_DIR}
.elif ${MODE} == "coverage"
MODE_CFLAGS = -O1 -g -fprofile-instr-generate -fcoverage-mapping -fprofile-update=atomic
MODE_LDFLAGS = -fprofile-instr-generate -Wl,--build-id
.elif ${MODE} == "debug"
MODE_CFLAGS = -O1 -g
MODE_LDFLAGS =
.else
.error Unknown build mode "${MODE}"; expected debug, release, san, or coverage.
.endif

CFLAGS += ${MODE_CFLAGS}
LDFLAGS += ${MODE_LDFLAGS}
ASFLAGS += -fPIC -march=native
.if ${MODE} != "release"
ASFLAGS += -g
.endif

BUILD_DIR = ${OBJROOT}/${MODE}
LIBRARY = ${BUILD_DIR}/libFoundation.so

SOURCES = \
	NSObject/NSObjCRuntime.m \
	NSObject/NSObject.m \
	NSObject/NSTypeEncodingString.m \
	NSMethodSignature/NSMethodSignature.m \
	NSInvocation/${ARCH}/NSInvocation.m \
	NSException/NSException.m \
	NSEnumerator/NSEnumerator.m \
	NSIndexSet/NSIndexSet.m \
	NSIndexSet/NSIndexSetTemplate.m \
	NSIndexSet/NSZeroIndexSet.m \
	NSIndexSet/NSSingleEntryIndexSet.m \
	NSIndexSet/NSSingleRangeIndexSet.m \
	NSIndexSet/NSInlineIndexSet.m \
	NSIndexSet/NSMutableIndexSet.m \
	NSIndexSet/NSMutableIndexSetTemplate.m \
	NSIndexSet/NSMutableInlineIndexSet.m \
	NSOrderedCollectionChange/NSOrderedCollectionChange.m \
	NSArray/NSArray.m \
	NSArray/NSArrayTemplate.m \
	NSArray/NSZeroArray.m \
	NSArray/NSSingleEntryArray.m \
	NSArray/NSInlineArray.m \
	NSArray/NSSubrangeArray.m \
	NSArray/NSMutableArray.m \
	NSArray/NSMutableArrayTemplate.m \
	NSArray/NSMutableInlineArray.m \
	NSArray/NSArrayEnumerators.m \
	NSValue/NSValue.m \
	NSValue/NSValueTemplate.m \
	NSValue/NSInlineValue.m \
	NSValue/NSVoidPointerValue.m \
	NSValue/NSNullVoidPointerValue.m \
	NSNumber/NSNumber.m \
	NSNumber/NSNumberTemplate.m \
	NSNumber/NSTaggedIntegerNumber.m \
	NSNumber/NSNegativeIntegerNumber.m \
	NSNumber/NSPositiveIntegerNumber.m \
	NSNumber/NSTaggedFloatNumber.m \
	NSNumber/NSDoubleNumber.m \
	NSNumber/NSNegativeInfinityFloatNumber.m \
	NSNumber/NSPositiveInfinityFloatNumber.m \
	NSNumber/NSNegativeInfinityDoubleNumber.m \
	NSNumber/NSPositiveInfinityDoubleNumber.m \
	NSNumber/NSNaNFloatNumber.m \
	NSNumber/NSNaNDoubleNumber.m \
	NSString/NSString.m \
	NSString/NSStringTemplate.m \
	NSString/NSStringBuilder.m \
	NSString/NSTaggedConstantString.m \
	NSString/NSConstantString.m \
	NSString/NSASCIIString.m \
	NSString/NSUTF16String.m \
	NSData/NSData.m \
	NSData/NSDataTemplate.m \
	NSData/NSZeroData.m \
	NSData/NSInlineData.m \
	NSData/NSSubrangeData.m \
	NSData/NSMutableData.m \
	NSData/NSMutableDataTemplate.m \
	NSData/NSMutableInlineData.m \
	NSNull/NSNull.m \
	NSUUID/NSUUID.m \
	Routines/NSCallOnce/NSCallOnce.m \
	Routines/NSDoubleToDecimal/NSDoubleToDecimal.m \
	Routines/NSMutex/NSMutex.m \
	Routines/NSRandom/NSRandom.m \
	Routines/NSSipHash/NSSipHash.m \
	NSInvocation/${ARCH}/NSInvocationTrampolines.S \
	Routines/NSRandom/${ARCH}/ChaCha20RandomBlocks.S

OBJECTS =
DEPENDENCY_FILES =
# Included dependency files add discovered headers to .ALLSRC, so compile only the translation unit named by the rule.
.for _source in ${SOURCES}
OBJECTS += ${BUILD_DIR}/${_source:R}.o
DEPENDENCY_FILES += ${BUILD_DIR}/${_source:R}.d

${BUILD_DIR}/${_source:R}.o: ${_source}
	@mkdir -p ${.TARGET:H}
.if ${_source:E} == "m"
	${CC} ${CFLAGS} -MMD -MP -MF ${.TARGET:R}.d -c ${_source} -o ${.TARGET}
.else
	${CC} ${ASFLAGS} -MMD -MP -MF ${.TARGET:R}.d -c ${_source} -o ${.TARGET}
.endif
.endfor

${LIBRARY}: ${OBJECTS}
	@mkdir -p ${.TARGET:H}
	${CC} -shared ${LDFLAGS} -Wl,-soname,libFoundation.so -o ${.TARGET} ${.ALLSRC} ${LDLIBS}

.PHONY: debug release san coverage
debug release san coverage: ${LIBRARY}

TEST_SOURCES != find Testing -type f -name '*.m' \
	! -path '*/.AppleDouble/*' ! -path 'Testing/Support/Test.m' -print

TEST_COMPONENTS = ${TEST_SOURCES:H:T:O:u}
TEST_SUPPORT_OBJECT = ${BUILD_DIR}/Testing/Support/Test.o
TEST_CFLAGS = ${CFLAGS} -I${.CURDIR}/Testing/Support
.if ${MODE} == "coverage"
TEST_CFLAGS += -DFOUNDATION_TEST_COVERAGE=1
TEST_RUN_ENV = LLVM_PROFILE_FILE=${BUILD_DIR}/profiles/%b-%m-%p.profraw
.else
TEST_RUN_ENV =
.endif
TEST_LDLIBS = ${LDLIBS} -lm
TEST_BINARIES =
TEST_DEPENDENCY_FILES = ${TEST_SUPPORT_OBJECT:R}.d
TEST_RUN_TARGETS =

${TEST_SUPPORT_OBJECT}: Testing/Support/Test.m Testing/Support/Test.h
	@mkdir -p ${.TARGET:H}
	${CC} ${TEST_CFLAGS} -MMD -MP -MF ${.TARGET:R}.d -c Testing/Support/Test.m -o ${.TARGET}

.for _test_source in ${TEST_SOURCES}
TEST_BINARIES += ${BUILD_DIR}/${_test_source:R}
TEST_DEPENDENCY_FILES += ${BUILD_DIR}/${_test_source:R}.d
TEST_RUN_TARGETS += test-run-${_test_source:H:T}-${_test_source:T:R}

${BUILD_DIR}/${_test_source:R}.o: ${_test_source}
	@mkdir -p ${.TARGET:H}
	${CC} ${TEST_CFLAGS} -MMD -MP -MF ${.TARGET:R}.d -c ${_test_source} -o ${.TARGET}

${BUILD_DIR}/${_test_source:R}: ${BUILD_DIR}/${_test_source:R}.o ${TEST_SUPPORT_OBJECT} ${LIBRARY}
.if ${_test_source} == "Testing/NSInvocation/ABI.m"
	${CC} ${LDFLAGS} -L${BUILD_DIR} -Wl,-rpath,'$$ORIGIN/../..' \
	    -o ${.TARGET} ${.ALLSRC:M*.o} -lFoundation ${TEST_LDLIBS} -lffi
.else
	${CC} ${LDFLAGS} -L${BUILD_DIR} -Wl,-rpath,'$$ORIGIN/../..' \
	    -o ${.TARGET} ${.ALLSRC:M*.o} -lFoundation ${TEST_LDLIBS}
.endif

.PHONY: ${_test_source:H:T}-${_test_source:T:R}
${_test_source:H:T}-${_test_source:T:R}: ${BUILD_DIR}/${_test_source:R}

.PHONY: test-run-${_test_source:H:T}-${_test_source:T:R}
test-run-${_test_source:H:T}-${_test_source:T:R}: ${BUILD_DIR}/${_test_source:R}
	@echo "==> ${_test_source:H:T}/${_test_source:T:R}"
	@${TEST_RUN_ENV} ${BUILD_DIR}/${_test_source:R}
.endfor

.for _component in ${TEST_COMPONENTS}
_COMPONENT_TEST_SOURCES = ${TEST_SOURCES:MTesting/${_component}/*.m}
_COMPONENT_TEST_BINARIES =
_COMPONENT_RUN_TARGETS =
.for _component_source in ${_COMPONENT_TEST_SOURCES}
_COMPONENT_TEST_BINARIES += ${BUILD_DIR}/${_component_source:R}
_COMPONENT_RUN_TARGETS += test-run-${_component_source:H:T}-${_component_source:T:R}
.endfor
.PHONY: ${_component} test-run-${_component}
${_component}: ${_COMPONENT_TEST_BINARIES}
test-run-${_component}: ${_COMPONENT_RUN_TARGETS}
.endfor

.PHONY: test test-run
# With no selector, "test" builds the complete native test suite.  When a selector is another command-line goal, that
# selector supplies the narrower dependency set instead.
.if make(test) && empty(.TARGETS:Ndebug:Nrelease:Nsan:Ncoverage:Ntest)
test: ${TEST_BINARIES}
.else
test:
.endif
test-run: ${TEST_RUN_TARGETS}

# Report only Foundation's instrumented library; test code is exercised but excluded from the denominator.
# Each report starts a fresh profile directory and runs the selected correctness tests, excluding benchmarks.
PYTHON ?= python3
COVERAGE_COMPONENTS ?= ${TEST_COMPONENTS}
COVERAGE_TIMEOUT ?= 120
COVERAGE_TEST_SOURCES =
.for _coverage_component in ${COVERAGE_COMPONENTS}
.if empty(TEST_COMPONENTS:M${_coverage_component})
.error Unknown coverage component "${_coverage_component}".
.endif
COVERAGE_TEST_SOURCES += ${TEST_SOURCES:MTesting/${_coverage_component}/*.m:N*/Benchmark.m}
.endfor
COVERAGE_BINARIES = ${COVERAGE_TEST_SOURCES:S,^,${BUILD_DIR}/,:R}

.PHONY: coverage-report
coverage-report: ${LIBRARY} ${COVERAGE_BINARIES}
	${PYTHON} Testing/Support/coverage.py --root ${.CURDIR:Q} --build-dir ${BUILD_DIR:Q} \
	    --compiler ${CC:Q} --timeout ${COVERAGE_TIMEOUT:Q} ${COVERAGE_BINARIES:@binary@${binary:Q}@}

.PHONY: clean clean-debug clean-release clean-san clean-coverage
clean:
	rm -rf -- ${OBJROOT}
clean-debug:
	rm -rf -- ${OBJROOT}/debug
clean-release:
	rm -rf -- ${OBJROOT}/release
clean-san:
	rm -rf -- ${OBJROOT}/san
clean-coverage:
	rm -rf -- ${OBJROOT}/coverage

.PHONY: install
install: ${LIBRARY}
	install -d ${DESTDIR}${PREFIX}/lib ${DESTDIR}${PREFIX}/include/Foundation
	install -m 755 ${LIBRARY} ${DESTDIR}${PREFIX}/lib/libFoundation.so
	install -m 644 ${.CURDIR}/Headers/Foundation/*.h ${DESTDIR}${PREFIX}/include/Foundation/

.for _dependency_file in ${DEPENDENCY_FILES} ${TEST_DEPENDENCY_FILES}
.sinclude "${_dependency_file}"
.endfor
