#ifndef FOUNDATION_TESTING_NSINVOCATION_FIXTURES_H
#define FOUNDATION_TESTING_NSINVOCATION_FIXTURES_H

#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSObject.h>

#import <objc/runtime.h>

#include <string.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wc++-compat"
#pragma clang diagnostic ignored "-Wgnu-empty-struct"
#pragma clang diagnostic ignored "-Wpadded"

typedef struct { char value; } C1;
typedef struct { int a, b; } C8;
typedef struct { int a, b, c; } C12;
typedef struct { long a, b; } C16;
typedef struct { long a, b, c; } I24;
typedef struct { long a, b, c, d, e; } I40;

typedef struct { float a; } F1;
typedef struct { float a, b; } F2;
typedef struct { float a, b, c; } F3;
typedef struct { float a, b, c, d; } F4;
typedef struct { double a; } D1;
typedef struct { double a, b; } D2;
typedef struct { double a, b, c; } D3;
typedef struct { double a, b, c, d; } D4;
typedef struct { double values[3]; } D3Array;
typedef struct { F2 pair; float tail; } NestedF3;
typedef struct { float f; double d; } MixedFD;
typedef struct { double a, b, c, d, e; } D5;
typedef struct { } Empty;

#pragma clang diagnostic pop

static long InvocationRecordedLong;
static int InvocationSentinelLiveCount;
static NSUInteger InvocationForwardCount;

@interface InvocationSentinel : NSObject
@end

@implementation InvocationSentinel
- (instancetype)init
{
	self = [super init];
	if (self != nil)
		++InvocationSentinelLiveCount;

	return self;
}
- (void)dealloc
{
	--InvocationSentinelLiveCount;
}
@end

@interface InvocationSubject : NSObject
- (char)echoChar:(char)value;
- (short)echoShort:(short)value;
- (int)echoInt:(int)value;
- (long)echoLong:(long)value;
- (bool)echoBool:(bool)value;
- (float)echoFloat:(float)value;
- (double)echoDouble:(double)value;
- (id)echoObject:(id)value;
- (char *)echoCString:(char *)value;
- (SEL)echoSelector:(SEL)value;
- (Class)echoClass:(Class)value;
- (void *)echoPointer:(void *)value;
- (int)applyBlock:(int (^)(int))block value:(int)value;
- (void)recordLong:(long)value;

- (C1)bumpC1:(C1)value;
- (C8)bumpC8:(C8)value;
- (C12)bumpC12:(C12)value;
- (C16)bumpC16:(C16)value;
- (I24)bumpI24:(I24)value;
- (I40)bumpI40:(I40)value;
- (F1)bumpF1:(F1)value;
- (F2)bumpF2:(F2)value;
- (F3)bumpF3:(F3)value;
- (F4)bumpF4:(F4)value;
- (D1)bumpD1:(D1)value;
- (D2)bumpD2:(D2)value;
- (D3)bumpD3:(D3)value;
- (D4)bumpD4:(D4)value;
- (D3Array)bumpD3Array:(D3Array)value;
- (NestedF3)bumpNestedF3:(NestedF3)value;
- (MixedFD)bumpMixedFD:(MixedFD)value;
- (D5)bumpD5:(D5)value;
- (long)empty:(Empty)empty then:(long)value;

- (long)gpSlamA:(long)a b:(long)b c:(long)c d:(long)d e:(long)e pair:(C16)pair tail:(long)tail;
- (double)fpSlamA:(double)a b:(double)b c:(double)c d:(double)d e:(double)e f:(double)f g:(double)g
		pair:(D2)pair tail:(double)tail;
- (long)indirectOnStackA:(long)a b:(long)b c:(long)c d:(long)d e:(long)e f:(long)f
		large:(I24)large tail:(long)tail;
- (double)mixedOverflowL0:(long)l0 d0:(double)d0 l1:(long)l1 d1:(double)d1
		l2:(long)l2 d2:(double)d2 l3:(long)l3 d3:(double)d3
		l4:(long)l4 d4:(double)d4 l5:(long)l5 d5:(double)d5
		l6:(long)l6 d6:(double)d6 l7:(long)l7 d7:(double)d7;
@end

@implementation InvocationSubject
- (char)echoChar:(char)value { return value; }
- (short)echoShort:(short)value { return value; }
- (int)echoInt:(int)value { return value; }
- (long)echoLong:(long)value { return value; }
- (bool)echoBool:(bool)value { return value; }
- (float)echoFloat:(float)value { return value; }
- (double)echoDouble:(double)value { return value; }
- (id)echoObject:(id)value { return value; }
- (char *)echoCString:(char *)value { return value; }
- (SEL)echoSelector:(SEL)value { return value; }
- (Class)echoClass:(Class)value { return value; }
- (void *)echoPointer:(void *)value { return value; }
- (int)applyBlock:(int (^)(int))block value:(int)value { return block(value); }
- (void)recordLong:(long)value { InvocationRecordedLong = value; }

- (C1)bumpC1:(C1)value { return (C1){ (char)(value.value + 1) }; }
- (C8)bumpC8:(C8)value { return (C8){ value.a + 1, value.b + 2 }; }
- (C12)bumpC12:(C12)value { return (C12){ value.a + 1, value.b + 2, value.c + 3 }; }
- (C16)bumpC16:(C16)value { return (C16){ value.a + 1, value.b + 2 }; }
- (I24)bumpI24:(I24)value { return (I24){ value.a + 1, value.b + 2, value.c + 3 }; }
- (I40)bumpI40:(I40)value
{
	return (I40){ value.a + 1, value.b + 2, value.c + 3, value.d + 4, value.e + 5 };
}
- (F1)bumpF1:(F1)value { return (F1){ value.a + 1.0f }; }
- (F2)bumpF2:(F2)value { return (F2){ value.a + 1.0f, value.b + 2.0f }; }
- (F3)bumpF3:(F3)value { return (F3){ value.a + 1.0f, value.b + 2.0f, value.c + 3.0f }; }
- (F4)bumpF4:(F4)value
{
	return (F4){ value.a + 1.0f, value.b + 2.0f, value.c + 3.0f, value.d + 4.0f };
}
- (D1)bumpD1:(D1)value { return (D1){ value.a + 1.0 }; }
- (D2)bumpD2:(D2)value { return (D2){ value.a + 1.0, value.b + 2.0 }; }
- (D3)bumpD3:(D3)value { return (D3){ value.a + 1.0, value.b + 2.0, value.c + 3.0 }; }
- (D4)bumpD4:(D4)value
{
	return (D4){ value.a + 1.0, value.b + 2.0, value.c + 3.0, value.d + 4.0 };
}
- (D3Array)bumpD3Array:(D3Array)value
{
	return (D3Array){ { value.values[0] + 1.0, value.values[1] + 2.0, value.values[2] + 3.0 } };
}
- (NestedF3)bumpNestedF3:(NestedF3)value
{
	return (NestedF3){ { value.pair.a + 1.0f, value.pair.b + 2.0f }, value.tail + 3.0f };
}
- (MixedFD)bumpMixedFD:(MixedFD)value { return (MixedFD){ value.f + 1.0f, value.d + 2.0 }; }
- (D5)bumpD5:(D5)value
{
	return (D5){ value.a + 1.0, value.b + 2.0, value.c + 3.0, value.d + 4.0, value.e + 5.0 };
}
- (long)empty:(Empty)empty then:(long)value
{
	(void)empty;
	return value * 3;
}

- (long)gpSlamA:(long)a b:(long)b c:(long)c d:(long)d e:(long)e pair:(C16)pair tail:(long)tail
{
	return a + 2 * b + 3 * c + 4 * d + 5 * e + 6 * pair.a + 7 * pair.b + 8 * tail;
}
- (double)fpSlamA:(double)a b:(double)b c:(double)c d:(double)d e:(double)e f:(double)f g:(double)g
		pair:(D2)pair tail:(double)tail
{
	return a + 2 * b + 3 * c + 4 * d + 5 * e + 6 * f + 7 * g + 8 * pair.a + 9 * pair.b + 10 * tail;
}
- (long)indirectOnStackA:(long)a b:(long)b c:(long)c d:(long)d e:(long)e f:(long)f
		large:(I24)large tail:(long)tail
{
	return a + 2 * b + 3 * c + 4 * d + 5 * e + 6 * f +
		7 * large.a + 8 * large.b + 9 * large.c + 10 * tail;
}
- (double)mixedOverflowL0:(long)l0 d0:(double)d0 l1:(long)l1 d1:(double)d1
		l2:(long)l2 d2:(double)d2 l3:(long)l3 d3:(double)d3
		l4:(long)l4 d4:(double)d4 l5:(long)l5 d5:(double)d5
		l6:(long)l6 d6:(double)d6 l7:(long)l7 d7:(double)d7
{
	return (double)l0 + d0 + 2 * ((double)l1 + d1) + 3 * ((double)l2 + d2) +
		4 * ((double)l3 + d3) + 5 * ((double)l4 + d4) + 6 * ((double)l5 + d5) +
		7 * ((double)l6 + d6) + 8 * ((double)l7 + d7);
}
@end

@interface InvocationProxy : NSObject
+ (instancetype)proxyWithBacking:(id)backing;
@end

@implementation InvocationProxy {
	NSObject *_backing;
}
+ (instancetype)proxyWithBacking:(id)backing
{
	InvocationProxy *proxy = [self new];

	proxy->_backing = backing;
	return proxy;
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];

	return signature != nil ? signature : [_backing methodSignatureForSelector:aSelector];
}
- (void)forwardInvocation:(NSInvocation *)invocation
{
	++InvocationForwardCount;
	[invocation invokeWithTarget:_backing];
}
@end

@interface InvocationFastProxy : NSObject
+ (instancetype)proxyWithBacking:(id)backing;
@end

@implementation InvocationFastProxy {
	NSObject *_backing;
}
+ (instancetype)proxyWithBacking:(id)backing
{
	InvocationFastProxy *proxy = [self new];

	proxy->_backing = backing;
	return proxy;
}
- (id)forwardingTargetForSelector:(SEL)aSelector
{
	return [_backing respondsToSelector:aSelector] ? _backing : nil;
}
@end

static int
InvocationResolverTriple(id self, SEL selector, int value)
{
	(void)self;
	(void)selector;
	return value * 3;
}

@interface InvocationResolver : NSObject
@end

@interface InvocationResolver (DynamicallyResolved)
- (int)resolvedTriple:(int)value;
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-strict"
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
#pragma clang diagnostic ignored "-Wselector"

@implementation InvocationResolver
+ (bool)resolveInstanceMethod:(SEL)selector
{
	if (selector == @selector(resolvedTriple:))
		return class_addMethod(self, selector, (IMP)InvocationResolverTriple, "i@:i");

	return [super resolveInstanceMethod:selector];
}
@end

static int
InvocationClassResolverQuad(id self, SEL selector, int value)
{
	(void)self;
	(void)selector;
	return value * 4;
}

@interface InvocationClassResolver : NSObject
@end

@interface InvocationClassResolver (DynamicallyResolved)
+ (int)resolvedQuad:(int)value;
@end

@implementation InvocationClassResolver
+ (bool)resolveClassMethod:(SEL)selector
{
	if (selector == @selector(resolvedQuad:))
		return class_addMethod(object_getClass(self), selector, (IMP)InvocationClassResolverQuad, "i@:i");

	return [super resolveClassMethod:selector];
}
@end

#pragma clang diagnostic pop

#endif
