/*
 * The compiler is the ABI oracle here: every selector below names a real Objective-C method, and every signature
 * comes from that method's runtime metadata. No handwritten encoding or libffi descriptor drives a call.
 *
 * Each method records its input and returns an independently chosen value. Check both directions separately,
 * including forwarding: an echo alone can hide two compensating mistakes in argument and return classification.
 * The catalogue expands across seven register-pressure layouts, always with trailing GP and FP sentinels.
 */
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSObject.h>
#import "Test.h"

#import <objc/runtime.h>

#include <limits.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpadded"
/* These comparisons check exact, binary-representable ABI sentinels; no arithmetic tolerance is involved. */
#pragma clang diagnostic ignored "-Wfloat-equal"

typedef struct { float values[1]; } Float1;
typedef struct { float values[2]; } Float2;
typedef struct { float values[3]; } Float3;
typedef struct { float values[4]; } Float4;
typedef struct { float values[5]; } Float5;
typedef struct { double values[1]; } Double1;
typedef struct { double values[2]; } Double2;
typedef struct { double values[3]; } Double3;
typedef struct { double values[4]; } Double4;
typedef struct { double values[5]; } Double5;
typedef struct { float values[2][2]; } FloatMatrix;
typedef struct { Float2 pairs[2]; } FloatPairs;
typedef struct { Float4 inner; } NestedFloat4;
typedef struct { double head; float tail; } DoubleFloat;
typedef struct { float head; double tail; } FloatDouble;
typedef struct { float head; int tail; } FloatInt;
typedef struct { int head; float tail; } IntFloat;
typedef struct { char head; double middle; short tail; } Padded;
typedef struct { int values[4]; } Int4;
typedef struct { long values[3]; } Long3;
typedef struct { void *pointer; double value; } PointerDouble;
typedef struct { Int4 integer; Double4 floating; } LargeMixed;

#define BYTE_TYPE(N) typedef struct { unsigned char values[N]; } Bytes##N;
BYTE_TYPE(1)
BYTE_TYPE(7)
BYTE_TYPE(8)
BYTE_TYPE(9)
BYTE_TYPE(15)
BYTE_TYPE(16)
BYTE_TYPE(17)
BYTE_TYPE(31)
BYTE_TYPE(32)
BYTE_TYPE(33)
BYTE_TYPE(64)
#undef BYTE_TYPE

typedef enum : unsigned short { SmallLow = 3, SmallHigh = 65530 } SmallEnum;
typedef enum : unsigned long long { WideLow = 7, WideHigh = ULLONG_MAX } WideEnum;
typedef float FourFloats[4];
typedef float MatrixFloats[2][4];
typedef float *FloatPointer;
typedef float const *ConstFloatPointer;
typedef float volatile *VolatileFloatPointer;
typedef float (*RowPointer)[4];
typedef float (*WholeArrayPointer)[4];
typedef Float4 *StructPointer;
typedef int *IntPointer;
typedef double *DoublePointer;
typedef unsigned char *BytePointer;
typedef char *CharPointer;
typedef int (*FunctionPointer)(int);
typedef id __unsafe_unretained ObjectSlot;
typedef int (^__unsafe_unretained BlockSlot)(int);

static int
AddOne(int value)
{
	return value + 1;
}

static int
SubtractOne(int value)
{
	return value - 1;
}

typedef struct CallFixtures {
	float floats[4], otherFloats[4];
	float matrix[2][4], otherMatrix[2][4];
	Float4 structures[2], otherStructures[2];
	int integers[17], otherIntegers[17];
	double doubles[5], otherDoubles[5];
	unsigned char bytes[33], otherBytes[33];
	char chars[4], otherChars[4];
	ObjectSlot object, otherObject;
	BlockSlot block, otherBlock;
	void *pointer, *otherPointer;
} CallFixtures;

/*
 * X(layout, name, declared parameter type, adjusted/storage type, input, independent return, equality).
 * Array spellings are deliberately used in method declarations; their storage variables hold adjusted pointers.
 * Comparisons inspect fields or payload arrays, never unspecified structure padding. Scalar FP comparisons are
 * bitwise so signed zero and NaN payloads are checked without numerical equality obscuring the distinction.
 */
#define CASES(X, L) \
	X(L, SignedChar, signed char, signed char, (round == 0 ? SCHAR_MIN : SCHAR_MAX), -13, a == b) \
	X(L, UnsignedChar, unsigned char, unsigned char, (round == 0 ? 0 : UCHAR_MAX), 219, a == b) \
	X(L, Short, short, short, (round == 0 ? SHRT_MIN : SHRT_MAX), -1901, a == b) \
	X(L, UnsignedShort, unsigned short, unsigned short, (round == 0 ? 0 : USHRT_MAX), 53001, a == b) \
	X(L, Int, int, int, (round == 0 ? INT_MIN : INT_MAX), -1234567, a == b) \
	X(L, UnsignedInt, unsigned int, unsigned int, (round == 0 ? 0U : UINT_MAX), 0xa1234567U, a == b) \
	X(L, Long, long, long, (round == 0 ? LONG_MIN : LONG_MAX), -1234567890123L, a == b) \
	X(L, UnsignedLong, unsigned long, unsigned long, (round == 0 ? 0UL : ULONG_MAX), 0xfedcba9876543210UL, a == b) \
	X(L, LongLong, long long, long long, (round == 0 ? LLONG_MIN : LLONG_MAX), -9876543210123LL, a == b) \
	X(L, UnsignedLongLong, unsigned long long, unsigned long long, (round == 0 ? 0ULL : ULLONG_MAX), 0x87654321fedcba98ULL, a == b) \
	X(L, Bool, bool, bool, (round != 0), (round == 0), a == b) \
	X(L, Float, float, float, (round == 0 ? -0.0f : round == 1 ? -13.25f : __builtin_nanf("0x123")), 91.5f, memcmp(&a, &b, sizeof(a)) == 0) \
	X(L, Double, double, double, (round == 0 ? -0.0 : round == 1 ? 0x1.23456789abcp+23 : __builtin_nan("0x456")), -0x1.987654321p-17, memcmp(&a, &b, sizeof(a)) == 0) \
	X(L, SmallEnum, SmallEnum, SmallEnum, (round == 0 ? SmallLow : SmallHigh), SmallLow, a == b) \
	X(L, WideEnum, WideEnum, WideEnum, (round == 0 ? WideLow : WideHigh), WideLow, a == b) \
	X(L, ConstInt, const int, int, -7301, 5809, a == b) \
	X(L, InInt, in int, int, -2311, 6703, a == b) \
	X(L, Pointer, void *, void *, (round == 0 ? nullptr : fixtures->floats), fixtures->otherFloats, a == b) \
	X(L, PointerPointer, void **, void **, &fixtures->pointer, &fixtures->otherPointer, a == b) \
	X(L, Function, FunctionPointer, FunctionPointer, AddOne, SubtractOne, a == b) \
	X(L, Selector, SEL, SEL, @selector(description), @selector(hash), sel_isEqual(a, b)) \
	X(L, Class, Class, Class, [NSObject class], [NSInvocation class], a == b) \
	X(L, Object, ObjectSlot, ObjectSlot, fixtures->object, fixtures->otherObject, a == b) \
	X(L, Block, BlockSlot, BlockSlot, fixtures->block, fixtures->otherBlock, a == b) \
	X(L, CString, char *, CharPointer, fixtures->chars, fixtures->otherChars, a == b) \
	X(L, FloatArray1, float[1], FloatPointer, fixtures->floats, fixtures->otherFloats, a == b) \
	X(L, FloatArray4, float[4], FloatPointer, fixtures->floats, fixtures->otherFloats, a == b) \
	X(L, NullArray, float[4], FloatPointer, (round == 0 ? nullptr : fixtures->floats), fixtures->otherFloats, a == b) \
	X(L, UnsizedArray, float[], FloatPointer, fixtures->floats, fixtures->otherFloats, a == b) \
	X(L, DoubleArray5, double[5], DoublePointer, fixtures->doubles, fixtures->otherDoubles, a == b) \
	X(L, IntArray17, int[17], IntPointer, fixtures->integers, fixtures->otherIntegers, a == b) \
	X(L, ByteArray33, unsigned char[33], BytePointer, fixtures->bytes, fixtures->otherBytes, a == b) \
	X(L, CharArray4, char[4], CharPointer, fixtures->chars, fixtures->otherChars, a == b) \
	X(L, ArrayTypedef, FourFloats, FloatPointer, fixtures->floats, fixtures->otherFloats, a == b) \
	X(L, ConstArray, const float[4], ConstFloatPointer, fixtures->floats, fixtures->otherFloats, a == b) \
	X(L, VolatileArray, volatile float[4], VolatileFloatPointer, fixtures->floats, fixtures->otherFloats, a == b) \
	X(L, InArray, in float[4], FloatPointer, fixtures->floats, fixtures->otherFloats, a == b) \
	X(L, MatrixArray, float[2][4], RowPointer, fixtures->matrix, fixtures->otherMatrix, a == b) \
	X(L, MatrixTypedef, MatrixFloats, RowPointer, fixtures->matrix, fixtures->otherMatrix, a == b) \
	X(L, StructArray, Float4[2], StructPointer, fixtures->structures, fixtures->otherStructures, a == b) \
	X(L, PointerToArray, WholeArrayPointer, WholeArrayPointer, &fixtures->floats, &fixtures->otherFloats, a == b) \
	X(L, Float1, Float1, Float1, ((Float1){{-1.25f}}), ((Float1){{9.5f}}), memcmp(a.values, b.values, sizeof(a.values)) == 0) \
	X(L, Float2, Float2, Float2, ((Float2){{-1.25f, 7.5f}}), ((Float2){{9.5f, -13.25f}}), memcmp(a.values, b.values, sizeof(a.values)) == 0) \
	X(L, Float3, Float3, Float3, ((Float3){{-1.25f, 7.5f, 11.75f}}), ((Float3){{9.5f, -13.25f, 31.5f}}), memcmp(a.values, b.values, sizeof(a.values)) == 0) \
	X(L, Float4, Float4, Float4, ((Float4){{-1.25f, 7.5f, 11.75f, -19.25f}}), ((Float4){{9.5f, -13.25f, 31.5f, 61.75f}}), memcmp(a.values, b.values, sizeof(a.values)) == 0) \
	X(L, Float5, Float5, Float5, ((Float5){{-1, 2, -3, 4, -5}}), ((Float5){{11, -12, 13, -14, 15}}), memcmp(a.values, b.values, sizeof(a.values)) == 0) \
	X(L, Double1, Double1, Double1, ((Double1){{-1.25}}), ((Double1){{9.5}}), memcmp(a.values, b.values, sizeof(a.values)) == 0) \
	X(L, Double2, Double2, Double2, ((Double2){{-1.25, 7.5}}), ((Double2){{9.5, -13.25}}), memcmp(a.values, b.values, sizeof(a.values)) == 0) \
	X(L, Double3, Double3, Double3, ((Double3){{-1.25, 7.5, 11.75}}), ((Double3){{9.5, -13.25, 31.5}}), memcmp(a.values, b.values, sizeof(a.values)) == 0) \
	X(L, Double4, Double4, Double4, ((Double4){{-1.25, 7.5, 11.75, -19.25}}), ((Double4){{9.5, -13.25, 31.5, 61.75}}), memcmp(a.values, b.values, sizeof(a.values)) == 0) \
	X(L, Double5, Double5, Double5, ((Double5){{-1, 2, -3, 4, -5}}), ((Double5){{11, -12, 13, -14, 15}}), memcmp(a.values, b.values, sizeof(a.values)) == 0) \
	X(L, FloatMatrix, FloatMatrix, FloatMatrix, ((FloatMatrix){{{1, -2}, {3, -4}}}), ((FloatMatrix){{{11, 12}, {-13, 14}}}), memcmp(a.values, b.values, sizeof(a.values)) == 0) \
	X(L, FloatPairs, FloatPairs, FloatPairs, ((FloatPairs){{{{1, -2}}, {{3, -4}}}}), ((FloatPairs){{{{11, 12}}, {{-13, 14}}}}), memcmp(a.pairs[0].values, b.pairs[0].values, sizeof(a.pairs[0].values)) == 0 && memcmp(a.pairs[1].values, b.pairs[1].values, sizeof(a.pairs[1].values)) == 0) \
	X(L, NestedFloat4, NestedFloat4, NestedFloat4, ((NestedFloat4){{{1, -2, 3, -4}}}), ((NestedFloat4){{{11, 12, -13, 14}}}), memcmp(a.inner.values, b.inner.values, sizeof(a.inner.values)) == 0) \
	X(L, DoubleFloat, DoubleFloat, DoubleFloat, ((DoubleFloat){-13.5, 7.25f}), ((DoubleFloat){83.75, -19.5f}), a.head == b.head && a.tail == b.tail) \
	X(L, FloatDouble, FloatDouble, FloatDouble, ((FloatDouble){7.25f, -13.5}), ((FloatDouble){-19.5f, 83.75}), a.head == b.head && a.tail == b.tail) \
	X(L, FloatInt, FloatInt, FloatInt, ((FloatInt){7.25f, -731}), ((FloatInt){-19.5f, 8901}), a.head == b.head && a.tail == b.tail) \
	X(L, IntFloat, IntFloat, IntFloat, ((IntFloat){-731, 7.25f}), ((IntFloat){8901, -19.5f}), a.head == b.head && a.tail == b.tail) \
	X(L, Padded, Padded, Padded, ((Padded){17, -13.75, -791}), ((Padded){31, 67.5, 931}), a.head == b.head && a.middle == b.middle && a.tail == b.tail) \
	X(L, Int4, Int4, Int4, ((Int4){{INT_MIN, 17, -83, INT_MAX}}), ((Int4){{91, -13, 77, -1301}}), memcmp(a.values, b.values, sizeof(a.values)) == 0) \
	X(L, Long3, Long3, Long3, ((Long3){{LONG_MIN, 0x123456789L, LONG_MAX}}), ((Long3){{91, -1301234567L, 77}}), memcmp(a.values, b.values, sizeof(a.values)) == 0) \
	X(L, PointerDouble, PointerDouble, PointerDouble, ((PointerDouble){fixtures->floats, 17.5}), ((PointerDouble){fixtures->otherFloats, -31.25}), a.pointer == b.pointer && a.value == b.value) \
	X(L, LargeMixed, LargeMixed, LargeMixed, ((LargeMixed){{{1, -2, 3, -4}}, {{5.5, -6.5, 7.5, -8.5}}}), ((LargeMixed){{{11, 12, -13, 14}}, {{-15.5, 16.5, -17.5, 18.5}}}), memcmp(a.integer.values, b.integer.values, sizeof(a.integer.values)) == 0 && memcmp(a.floating.values, b.floating.values, sizeof(a.floating.values)) == 0) \
	BYTE_CASE(X, L, 1) \
	BYTE_CASE(X, L, 7) \
	BYTE_CASE(X, L, 8) \
	BYTE_CASE(X, L, 9) \
	BYTE_CASE(X, L, 15) \
	BYTE_CASE(X, L, 16) \
	BYTE_CASE(X, L, 17) \
	BYTE_CASE(X, L, 31) \
	BYTE_CASE(X, L, 32) \
	BYTE_CASE(X, L, 33) \
	BYTE_CASE(X, L, 64)

#define BYTE_CASE(X, L, N) \
	X(L, Bytes##N, Bytes##N, Bytes##N, MakeBytes##N(round + 1), MakeBytes##N(round + 101), memcmp(a.values, b.values, sizeof(a.values)) == 0)
#define BYTE_MAKER(N) \
	static Bytes##N MakeBytes##N(unsigned seed) \
	{ \
		Bytes##N value = {}; \
		for (unsigned i = 0; i < N; ++i) \
			value.values[i] = (unsigned char)((seed + i * 37U) & 255U); \
		return value; \
	}
BYTE_MAKER(1)
BYTE_MAKER(7)
BYTE_MAKER(8)
BYTE_MAKER(9)
BYTE_MAKER(15)
BYTE_MAKER(16)
BYTE_MAKER(17)
BYTE_MAKER(31)
BYTE_MAKER(32)
BYTE_MAKER(33)
BYTE_MAKER(64)

/* GP3 straddles the amd64 boundary; GP5 straddles arm64. FP7 leaves one SIMD slot, FP8 leaves none.
 * Both exhausts both banks even when a large return consumes a hidden argument register on amd64. */
#define Bare_DECL(P) :(P)value tail:(long)tail marker:(double)marker
#define Bare_CALL :input tail:-901L marker:23.75
#define Bare_SEL :tail:marker:
#define Bare_CHECK
#define Bare_GP 0
#define Bare_FP 0

#define GP3_DECL(P) :(long)g0 g1:(long)g1 g2:(long)g2 value:(P)value tail:(long)tail marker:(double)marker
#define GP3_CALL :101L g1:-203L g2:307L value:input tail:-901L marker:23.75
#define GP3_SEL :g1:g2:value:tail:marker:
#define GP3_CHECK TEST(g0 == 101 && g1 == -203 && g2 == 307);
#define GP3_GP 3
#define GP3_FP 0

#define GP5_DECL(P) :(long)g0 g1:(long)g1 g2:(long)g2 g3:(long)g3 g4:(long)g4 value:(P)value tail:(long)tail marker:(double)marker
#define GP5_CALL :101L g1:-203L g2:307L g3:-409L g4:503L value:input tail:-901L marker:23.75
#define GP5_SEL :g1:g2:g3:g4:value:tail:marker:
#define GP5_CHECK GP3_CHECK TEST(g3 == -409 && g4 == 503);
#define GP5_GP 5
#define GP5_FP 0

#define GP6_DECL(P) :(long)g0 g1:(long)g1 g2:(long)g2 g3:(long)g3 g4:(long)g4 g5:(long)g5 value:(P)value tail:(long)tail marker:(double)marker
#define GP6_CALL :101L g1:-203L g2:307L g3:-409L g4:503L g5:-607L value:input tail:-901L marker:23.75
#define GP6_SEL :g1:g2:g3:g4:g5:value:tail:marker:
#define GP6_CHECK GP5_CHECK TEST(g5 == -607);
#define GP6_GP 6
#define GP6_FP 0

#define FP7_DECL(P) :(double)f0 f1:(double)f1 f2:(double)f2 f3:(double)f3 f4:(double)f4 f5:(double)f5 f6:(double)f6 value:(P)value tail:(long)tail marker:(double)marker
#define FP7_CALL :1.25 f1:-2.5 f2:3.75 f3:-4.25 f4:5.5 f5:-6.75 f6:7.25 value:input tail:-901L marker:23.75
#define FP7_SEL :f1:f2:f3:f4:f5:f6:value:tail:marker:
#define FP7_CHECK TEST(f0 == 1.25 && f1 == -2.5 && f2 == 3.75 && f3 == -4.25 && f4 == 5.5 && f5 == -6.75 && f6 == 7.25);
#define FP7_GP 0
#define FP7_FP 7

#define FP8_DECL(P) :(double)f0 f1:(double)f1 f2:(double)f2 f3:(double)f3 f4:(double)f4 f5:(double)f5 f6:(double)f6 f7:(double)f7 value:(P)value tail:(long)tail marker:(double)marker
#define FP8_CALL :1.25 f1:-2.5 f2:3.75 f3:-4.25 f4:5.5 f5:-6.75 f6:7.25 f7:-8.5 value:input tail:-901L marker:23.75
#define FP8_SEL :f1:f2:f3:f4:f5:f6:f7:value:tail:marker:
#define FP8_CHECK FP7_CHECK TEST(f7 == -8.5);
#define FP8_GP 0
#define FP8_FP 8

#define Both_DECL(P) :(long)g0 g1:(long)g1 g2:(long)g2 g3:(long)g3 g4:(long)g4 g5:(long)g5 g6:(long)g6 g7:(long)g7 f0:(double)f0 f1:(double)f1 f2:(double)f2 f3:(double)f3 f4:(double)f4 f5:(double)f5 f6:(double)f6 f7:(double)f7 f8:(double)f8 value:(P)value tail:(long)tail marker:(double)marker
#define Both_CALL :101L g1:-203L g2:307L g3:-409L g4:503L g5:-607L g6:709L g7:-811L f0:1.25 f1:-2.5 f2:3.75 f3:-4.25 f4:5.5 f5:-6.75 f6:7.25 f7:-8.5 f8:9.75 value:input tail:-901L marker:23.75
#define Both_SEL :g1:g2:g3:g4:g5:g6:g7:f0:f1:f2:f3:f4:f5:f6:f7:f8:value:tail:marker:
#define Both_CHECK GP6_CHECK FP8_CHECK TEST(g6 == 709 && g7 == -811 && f8 == 9.75);
#define Both_GP 8
#define Both_FP 9

#define ALL_LAYOUTS(X) CASES(X, Bare) CASES(X, GP3) CASES(X, GP5) CASES(X, GP6) CASES(X, FP7) CASES(X, FP8) CASES(X, Both)
#define DECLARE(L, N, P, S, I, R, E) - (S)call##N##L L##_DECL(P);
#define FIELDS(L, N, P, S, I, R, E) S seen##N; S answer##N;

@interface CompilerSubject : NSObject
ALL_LAYOUTS(DECLARE)
@end

#define IMPLEMENT(L, N, P, S, I, R, E) \
	- (S)call##N##L L##_DECL(P) \
	{ \
		L##_CHECK \
		TEST(tail == -901 && marker == 23.75); \
		seen##N = value; \
		return answer##N; \
	}
@implementation CompilerSubject {
@public
	CASES(FIELDS, Unused)
}
ALL_LAYOUTS(IMPLEMENT)
@end

static NSUInteger ForwardCount;

@interface CompilerProxy : NSObject
+ (instancetype)proxyWithSubject:(CompilerSubject *)subject;
@end

@implementation CompilerProxy {
	CompilerSubject *_subject;
}
+ (instancetype)proxyWithSubject:(CompilerSubject *)subject
{
	CompilerProxy *proxy = [self new];
	proxy->_subject = subject;
	return proxy;
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
	return [_subject methodSignatureForSelector:selector];
}
- (void)forwardInvocation:(NSInvocation *)invocation
{
	++ForwardCount;
	[invocation invokeWithTarget:_subject];
}
@end

#define EQUALITY(L, N, P, S, I, R, E) \
	static bool Same##N(S a, S b) { return E; }
CASES(EQUALITY, Unused)

static void
SetPrefix(NSInvocation *invocation, NSUInteger gpCount, NSUInteger fpCount)
{
	long gp[] = { 101, -203, 307, -409, 503, -607, 709, -811 };
	double fp[] = { 1.25, -2.5, 3.75, -4.25, 5.5, -6.75, 7.25, -8.5, 9.75 };
	NSUInteger index = 2;
	for (NSUInteger i = 0; i < gpCount; ++i)
		[invocation setArgument:&gp[i] atIndex:index++];
	for (NSUInteger i = 0; i < fpCount; ++i)
		[invocation setArgument:&fp[i] atIndex:index++];
}

static NSUInteger CasesRun;

#define RUN(L, N, P, S, I, R, E) \
	static void Run##N##L(CompilerSubject *subject, CompilerSubject *proxy, CallFixtures *fixtures) \
	{ \
		(void)fixtures; \
		SEL selector = @selector(call##N##L L##_SEL); \
		NSUInteger const index = 2 + L##_GP + L##_FP; \
		Method method = class_getInstanceMethod([CompilerSubject class], selector); \
		NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)]; \
		TEST_EQ_UNSIGNED(signature.numberOfArguments, index + 3); \
		for (unsigned round = 0; round < 3; ++round) { \
			S input = I; \
			S expected = R; \
			S result = {}; \
			S roundTrip = {}; \
			long tail = -901; \
			double marker = 23.75; \
			subject->answer##N = expected; \
			result = [subject call##N##L L##_CALL]; \
			TESTF(Same##N(subject->seen##N, input), "%s direct argument", #N "/" #L); \
			TESTF(Same##N(result, expected), "%s direct return", #N "/" #L); \
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature]; \
			invocation.target = subject; \
			invocation.selector = selector; \
			SetPrefix(invocation, L##_GP, L##_FP); \
			[invocation setArgument:&input atIndex:index]; \
			[invocation setArgument:&tail atIndex:index + 1]; \
			[invocation setArgument:&marker atIndex:index + 2]; \
			[invocation getArgument:&roundTrip atIndex:index]; \
			TESTF(Same##N(roundTrip, input), "%s argument round trip", #N "/" #L); \
			for (unsigned entry = 0; entry < 3; ++entry) { \
				subject->seen##N = (S){}; \
				result = (S){}; \
				if (entry == 0) \
					[invocation invoke]; \
				else if (entry == 1) \
					[invocation invokeUsingIMP:method_getImplementation(method)]; \
				else { \
					NSUInteger before = ForwardCount; \
					result = [proxy call##N##L L##_CALL]; \
					TEST_EQ_UNSIGNED(ForwardCount, before + 1); \
				} \
				if (entry != 2) \
					[invocation getReturnValue:&result]; \
				TESTF(Same##N(subject->seen##N, input), "%s argument, entry %u", #N "/" #L, entry); \
				TESTF(Same##N(result, expected), "%s return, entry %u", #N "/" #L, entry); \
			} \
		} \
		++CasesRun; \
	}
ALL_LAYOUTS(RUN)

int
main(int argc, char **argv)
{
	@autoreleasepool {
		CompilerSubject *subject = [CompilerSubject new];
		CompilerSubject *proxy = (CompilerSubject *)[CompilerProxy proxyWithSubject:subject];
		__attribute__((objc_precise_lifetime)) NSObject *first = [NSObject new];
		__attribute__((objc_precise_lifetime)) NSObject *second = [NSObject new];
		int (^firstBlock)(int) = ^(int value) { return value + 71; };
		int (^secondBlock)(int) = ^(int value) { return value - 39; };
		CallFixtures fixtures = {};
		fixtures.object = first;
		fixtures.otherObject = second;
		fixtures.block = firstBlock;
		fixtures.otherBlock = secondBlock;
		/* An optional exact case name makes a compiler-derived regression runnable by itself. */
#define CALL(L, N, P, S, I, R, E) \
		if (argc == 1 || strcmp(argv[1], #N "/" #L) == 0) \
			Run##N##L(subject, proxy, &fixtures);
		ALL_LAYOUTS(CALL)
		TEST(CasesRun != 0);
		printf("Compiler calls: %lu type/layout cases, three value rounds, four call paths\n", (unsigned long)CasesRun);
	}
	return TestFinish();
}

#pragma clang diagnostic pop
