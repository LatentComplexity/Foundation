/*
 * libffi is the independent ABI oracle in this test. For each generated Objective-C method signature, an ffi
 * closure decodes the registers and stack prepared by NSInvocation. The callback compares every received value
 * with the bytes supplied through -setArgument:atIndex:. This avoids duplicating NSInvocation's placement logic
 * in the test and makes large, deterministic signature matrices practical.
 */

#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSObject.h>
#import "Test.h"

#include <ffi.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

enum {
	MaxArguments = 24,
	MaxValueSize = 48,
	EncodingCapacity = 1024
};

typedef union TestValue {
	max_align_t alignment;
	unsigned char bytes[MaxValueSize];
} TestValue;

typedef struct TypeSpec {
	char const *name;
	char const *encoding;
	ffi_type *ffiType;
	size_t size;
	uint64_t significantBytes;
	NSUInteger GPRegisters;
	NSUInteger FPRegisters;
} TypeSpec;

typedef struct Scenario {
	TypeSpec const *types[MaxArguments];
	TestValue values[MaxArguments];
	NSUInteger count;
	uintptr_t target;
	uintptr_t selector;
	uint64_t returnValue;
	uintptr_t matched;
	char padding[8];
} Scenario;

#define BYTE_MASK(count) ((UINT64_C(1) << (count)) - UINT64_C(1))

static ffi_type *G2Elements[] = { &ffi_type_sint64, &ffi_type_sint64, nullptr };
static ffi_type G2Type = { 0, 0, FFI_TYPE_STRUCT, G2Elements };
static ffi_type *I3Elements[] = { &ffi_type_sint64, &ffi_type_sint64, &ffi_type_sint64, nullptr };
static ffi_type I3Type = { 0, 0, FFI_TYPE_STRUCT, I3Elements };
static ffi_type *F2Elements[] = { &ffi_type_float, &ffi_type_float, nullptr };
static ffi_type F2Type = { 0, 0, FFI_TYPE_STRUCT, F2Elements };
static ffi_type *F3Elements[] = { &ffi_type_float, &ffi_type_float, &ffi_type_float, nullptr };
static ffi_type F3Type = { 0, 0, FFI_TYPE_STRUCT, F3Elements };
static ffi_type *F4Elements[] = { &ffi_type_float, &ffi_type_float, &ffi_type_float, &ffi_type_float, nullptr };
static ffi_type F4Type = { 0, 0, FFI_TYPE_STRUCT, F4Elements };
static ffi_type *D2Elements[] = { &ffi_type_double, &ffi_type_double, nullptr };
static ffi_type D2Type = { 0, 0, FFI_TYPE_STRUCT, D2Elements };
static ffi_type *D3Elements[] = { &ffi_type_double, &ffi_type_double, &ffi_type_double, nullptr };
static ffi_type D3Type = { 0, 0, FFI_TYPE_STRUCT, D3Elements };
static ffi_type *D4Elements[] = { &ffi_type_double, &ffi_type_double, &ffi_type_double, &ffi_type_double, nullptr };
static ffi_type D4Type = { 0, 0, FFI_TYPE_STRUCT, D4Elements };
static ffi_type *D5Elements[] = {
	&ffi_type_double, &ffi_type_double, &ffi_type_double, &ffi_type_double, &ffi_type_double, nullptr
};
static ffi_type D5Type = { 0, 0, FFI_TYPE_STRUCT, D5Elements };
static ffi_type *IIElements[] = { &ffi_type_sint32, &ffi_type_sint32, nullptr };
static ffi_type IIType = { 0, 0, FFI_TYPE_STRUCT, IIElements };
static ffi_type *I4Elements[] = {
	&ffi_type_sint32, &ffi_type_sint32, &ffi_type_sint32, &ffi_type_sint32, nullptr
};
static ffi_type I4Type = { 0, 0, FFI_TYPE_STRUCT, I4Elements };
static ffi_type *FDElements[] = { &ffi_type_float, &ffi_type_double, nullptr };
static ffi_type FDType = { 0, 0, FFI_TYPE_STRUCT, FDElements };
static ffi_type *NestedF3Elements[] = { &F2Type, &ffi_type_float, nullptr };
static ffi_type NestedF3Type = { 0, 0, FFI_TYPE_STRUCT, NestedF3Elements };

static TypeSpec const G1 = { "G1", "q", &ffi_type_sint64, 8, BYTE_MASK(8), 1, 0 };
static TypeSpec const G2 = { "G2", "{G2=qq}", &G2Type, 16, BYTE_MASK(16), 2, 0 };
static TypeSpec const I3 = { "I3", "{I3=qqq}", &I3Type, 24, BYTE_MASK(24), 1, 0 };
static TypeSpec const Float = { "float", "f", &ffi_type_float, 4, BYTE_MASK(4), 0, 1 };
static TypeSpec const Double = { "double", "d", &ffi_type_double, 8, BYTE_MASK(8), 0, 1 };
static TypeSpec const F2 = { "F2", "{F2=ff}", &F2Type, 8, BYTE_MASK(8), 0, 2 };
static TypeSpec const F3 = { "F3", "{F3=fff}", &F3Type, 12, BYTE_MASK(12), 0, 3 };
static TypeSpec const F4 = { "F4", "{F4=ffff}", &F4Type, 16, BYTE_MASK(16), 0, 4 };
static TypeSpec const D2 = { "D2", "{D2=dd}", &D2Type, 16, BYTE_MASK(16), 0, 2 };
static TypeSpec const D3 = { "D3", "{D3=ddd}", &D3Type, 24, BYTE_MASK(24), 0, 3 };
static TypeSpec const D4 = { "D4", "{D4=dddd}", &D4Type, 32, BYTE_MASK(32), 0, 4 };

/* Recursion / rejection representatives for _NSInvocationHFAWalk(). */
static TypeSpec const D3Array = { "double array field", "{D3Array=[3d]}", &D3Type, 24, BYTE_MASK(24), 0, 3 };
static TypeSpec const NestedF3 = {
	"nested F3", "{NestedF3={F2=ff}f}", &NestedF3Type, 12, BYTE_MASK(12), 0, 3
};
static TypeSpec const MixedFD = {
	"mixed float/double", "{MixedFD=fd}", &FDType, 16,
	BYTE_MASK(4) | (BYTE_MASK(8) << 8), 2, 0
};
static TypeSpec const IntPair = { "int leaves", "{IntPair=ii}", &IIType, 8, BYTE_MASK(8), 1, 0 };
static TypeSpec const IntArray = { "int array field", "{IntArray=[4i]}", &I4Type, 16, BYTE_MASK(16), 2, 0 };
static TypeSpec const D5 = { "five doubles", "{D5=ddddd}", &D5Type, 40, BYTE_MASK(40), 1, 0 };
static TypeSpec const QualifiedDouble = { "qualified double", "rd", &ffi_type_double, 8, BYTE_MASK(8), 0, 1 };

static bool
CompareSignificantBytes(TypeSpec const *type, void const *actual, void const *expected)
{
	unsigned char const *a = actual;
	unsigned char const *e = expected;

	for (size_t byte = 0; byte < type->size; ++byte)
		if ((type->significantBytes & (UINT64_C(1) << byte)) != 0 && a[byte] != e[byte])
			return false;

	return true;
}

static void
ClosureCallback(ffi_cif *cif, void *returnStorage, void **arguments, void *context)
{
	Scenario *scenario = context;
	uintptr_t target;
	uintptr_t selector;

	(void)cif;
	memcpy(&target, arguments[0], sizeof(target));
	memcpy(&selector, arguments[1], sizeof(selector));
	scenario->matched = target == scenario->target && selector == scenario->selector;

	for (NSUInteger index = 0; index < scenario->count; ++index)
		if (CompareSignificantBytes(scenario->types[index], arguments[index + 2],
				scenario->values[index].bytes) == false) {
			scenario->matched = false;
			break;
		}

	memcpy(returnStorage, &scenario->returnValue, sizeof(scenario->returnValue));
}

[[clang::no_sanitize("integer")]]
static void
FillValue(Scenario *scenario, NSUInteger index, uint64_t seed)
{
	TypeSpec const *type = scenario->types[index];
	uint64_t state = seed ^ (UINT64_C(0x9e3779b97f4a7c15) * (index + 1));

	memset(scenario->values[index].bytes, 0, MaxValueSize);
	for (size_t byte = 0; byte < type->size; ++byte) {
		state ^= state >> 12;
		state ^= state << 25;
		state ^= state >> 27;
		scenario->values[index].bytes[byte] = (unsigned char)(state >> 56);
	}

	/* Keep padding deterministic even though the callback deliberately ignores it. */
	for (size_t byte = 0; byte < type->size; ++byte)
		if ((type->significantBytes & (UINT64_C(1) << byte)) == 0)
			scenario->values[index].bytes[byte] = 0;
}

static bool
BuildEncoding(Scenario const *scenario, char encoding[EncodingCapacity])
{
	size_t offset = 0;

	memcpy(encoding, "Q@:", 3);
	offset = 3;

	for (NSUInteger index = 0; index < scenario->count; ++index) {
		size_t const length = strlen(scenario->types[index]->encoding);

		if (offset + length >= EncodingCapacity)
			return false;

		memcpy(encoding + offset, scenario->types[index]->encoding, length);
		offset += length;
	}

	encoding[offset] = '\0';
	return true;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-strict"

static bool
RunScenario(TypeSpec const *const *types, NSUInteger count, uint64_t seed)
{
	@autoreleasepool {
		Scenario scenario = { 0 };
		ffi_type *argumentTypes[MaxArguments + 2];
		ffi_cif cif;
		ffi_closure *closure;
		void *code = nullptr;
		char encoding[EncodingCapacity];
		NSObject *target = [NSObject new];
		SEL selector = @selector(description);
		NSMethodSignature *signature;
		NSInvocation *invocation;
		uint64_t actualReturn = 0;
		ffi_status status;

		if (count > MaxArguments)
			return false;

		scenario.count = count;
		scenario.target = (uintptr_t)(__bridge void *)target;
		scenario.selector = (uintptr_t)(void *)selector;
		scenario.returnValue = seed ^ UINT64_C(0xd1b54a32d192ed03);
		scenario.matched = true;
		argumentTypes[0] = &ffi_type_pointer;
		argumentTypes[1] = &ffi_type_pointer;

		for (NSUInteger index = 0; index < count; ++index) {
			scenario.types[index] = types[index];
			argumentTypes[index + 2] = types[index]->ffiType;
			FillValue(&scenario, index, seed);
		}

		if (BuildEncoding(&scenario, encoding) == false)
			return false;

		status = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (unsigned int)(count + 2),
			&ffi_type_uint64, argumentTypes);
		if (status != FFI_OK)
			return false;

		closure = ffi_closure_alloc(sizeof(*closure), &code);
		if (closure == nullptr || code == nullptr)
			return false;

		status = ffi_prep_closure_loc(closure, &cif, ClosureCallback, &scenario, code);
		if (status != FFI_OK) {
			ffi_closure_free(closure);
			return false;
		}

		signature = [NSMethodSignature signatureWithObjCTypes:encoding];
		invocation = [NSInvocation invocationWithMethodSignature:signature];
		invocation.target = target;
		invocation.selector = selector;
		for (NSUInteger index = 0; index < count; ++index)
			[invocation setArgument:scenario.values[index].bytes atIndex:index + 2];

		[invocation invokeUsingIMP:(IMP)code];
		[invocation getReturnValue:&actualReturn];
		ffi_closure_free(closure);

		return scenario.matched && actualReturn == scenario.returnValue;
	}
}

#pragma clang diagnostic pop

static void
TestClassificationCatalogue(void)
{
	TypeSpec const *const catalogue[] = {
		&Float, &Double, &F2, &F3, &F4, &D2, &D3, &D4,
		&D3Array, &NestedF3, &MixedFD, &IntPair, &IntArray, &D5, &QualifiedDouble
	};

	for (NSUInteger index = 0; index < sizeof(catalogue) / sizeof(catalogue[0]); ++index) {
		TypeSpec const *type = catalogue[index];
		bool const passed = RunScenario(&type, 1, UINT64_C(0x1000) + index);

		TESTF(passed, "classification representative failed: %s", type->name);
	}
}

static void
TestEveryArm64RegisterState(void)
{
	/*
	 * x0/x1 are self/_cmd, leaving six GP registers; the SIMD bank has all eight registers. For every reachable
	 * pair of occupancies, append every representative class. When it cannot fit, append a scalar from the same
	 * bank as well: this verifies C.3/C.11's bank-closing rule rather than merely checking the first spill.
	 */
	TypeSpec const *const candidates[] = { &G1, &G2, &I3, &Double, &D2, &D3, &D4 };
	uint64_t scenarioNumber = 0;

	for (unsigned char gpUsed = 0; gpUsed <= 6; ++gpUsed)
		for (unsigned char fpUsed = 0; fpUsed <= 8; ++fpUsed)
			for (NSUInteger candidateIndex = 0;
			     candidateIndex < sizeof(candidates) / sizeof(candidates[0]); ++candidateIndex) {
				TypeSpec const *types[MaxArguments];
				TypeSpec const *candidate = candidates[candidateIndex];
				NSUInteger count = 0;
				bool spills;

				for (unsigned char index = 0; index < gpUsed; ++index)
					types[count++] = &G1;
				for (unsigned char index = 0; index < fpUsed; ++index)
					types[count++] = &Double;

				types[count++] = candidate;
				spills = candidate->GPRegisters != 0 ? gpUsed + candidate->GPRegisters > 6 :
					fpUsed + candidate->FPRegisters > 8;
				if (spills)
					types[count++] = candidate->GPRegisters != 0 ? &G1 : &Double;

				bool const passed = RunScenario(types, count,
					UINT64_C(0x20000000) + scenarioNumber++);
				TESTF(passed, "arm64 state failed: GP=%u FP=%u candidate=%s spill=%u",
					gpUsed, fpUsed, candidate->name, spills);
			}
}

static void
TestMixedOverflowOrder(void)
{
	TypeSpec const *const sequences[][20] = {
		{ &G1, &Double, &G1, &Double, &G1, &Double, &G1, &Double, &G1, &Double,
		  &G1, &Double, &Double, &Double, &Double, &G2, &D3, &I3, &G1, &Double },
		{ &Double, &Double, &Double, &Double, &Double, &Double, &Double, &G1, &G2,
		  &Double, &D2, &G1, &G1, &G1, &I3, &G1, &D4, &G2, &Double, &G1 },
		{ &I3, &D4, &G2, &D3, &G1, &D2, &G1, &Double, &G1, &F4,
		  &G1, &F3, &I3, &F2, &G2, &Float, &G1, &Double, &I3, &F4 }
	};

	for (NSUInteger index = 0; index < sizeof(sequences) / sizeof(sequences[0]); ++index)
		TESTF(RunScenario(sequences[index], 20, UINT64_C(0x30000000) + index),
			"mixed overflow sequence %lu failed", index);
}

[[clang::no_sanitize("integer")]]
static void
TestGeneratedCombinations(void)
{
	TypeSpec const *const choices[] = { &G1, &G2, &I3, &Float, &Double, &F2, &F3, &F4, &D2, &D3, &D4 };
	uint64_t state = UINT64_C(0x6a09e667f3bcc909);

	for (NSUInteger scenario = 0; scenario < 2048; ++scenario) {
		TypeSpec const *types[MaxArguments];
		NSUInteger const count = 1 + scenario % 20;

		for (NSUInteger index = 0; index < count; ++index) {
			state ^= state >> 12;
			state ^= state << 25;
			state ^= state >> 27;
			types[index] = choices[state % (sizeof(choices) / sizeof(choices[0]))];
		}

		TESTF(RunScenario(types, count, state), "generated ABI combination %lu failed", scenario);
	}
}

int
main(void)
{
	TestClassificationCatalogue();
	TestEveryArm64RegisterState();
	TestMixedOverflowOrder();
	TestGeneratedCombinations();

	return TestFinish();
}
