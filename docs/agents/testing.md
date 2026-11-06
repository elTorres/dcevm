# Tests (`dcevm/`)

## How tests run

`:dcevm:test` uses `<targetJre>/bin/java` (default `targetJre=build/jre`) with these settings:

- `-XXaltjvm=<jvmName>` so the freshly installed DCEVM is used
- `-javaagent:../agent/build/libs/agent.jar` (exposes `Instrumentation`, used by `InstrumentationRedefiner`)
- `-Djava.library.path=../native/build` (for `SimpleNativeTest`)
- `-XX:TraceRedefineClasses=<traceRedefinition>`, compressed oops on or off per `oops`, and `-XX:LogFile=build/hotspot.log` for `fastdebug`
- `-Ddcevm.test.light=<flavor == light>` (read as `TestUtil.LIGHT`)

`ignoreFailures = true`, and the task is never up to date. Check `dcevm/build/reports/tests/index.html` for results.

Source sets: `src/test/java7` is always compiled. `src/test/java8` (lambdas and similar) is added only when Gradle itself runs on Java 8+.

Run a single class or method: `./gradlew :dcevm:test --tests com.github.dcevm.test.fields.AccessDeletedFieldTest` (wildcards work: `--tests '*.lambdas.*'`).

### From an IDE

1. `./gradlew agent:build`
2. JVM args: `-javaagent:agent/build/libs/agent.jar`, plus `-XXaltjvm=dcevm` if DCEVM is installed side by side.

## Versioned inner-class convention

Each test is an outer class whose static nested classes represent successive versions of the same class:

```java
public static class A      { ... }   // version 0
public static class A___1  { ... }   // version 1, becomes A once redefined
public static class A___2  { ... }

@Before public void setUp() { __toVersion__(0); }
... __toVersion__(1); ...             // redefine to version 1
```

- `HotSwapTestHelper.__toVersion__(n, extra...)` finds the caller's outermost class. `HotSwapTool.toVersion` then redefines every nested class named `*___n` in place of its unversioned counterpart. Classes without an `___n` variant stay unchanged. `__version__()` returns the current version.
- `TestClassAdapter` (ASM 5 remapper) rewrites the class bytes: it strips `___<n>` from type names and truncates **method** names at `___`. `ClassRedefinitionPolicy(alias = X.class)` maps a class to a different target name.
- `HotSwapTool` reads `.class` files straight from the package directory on disk. Tests must run from exploded class directories, not jars.
- Always reset to version 0 in `@Before`. Version state is static and shared across tests in the JVM.

## Flavor-specific expectations

- `@Category(Full.class)` tests are excluded for `flavor=light`, and `@Category(Light.class)` tests are excluded for `flavor=full` (`com.github.dcevm.test.category`).
- For behaviour that only fails on light, prefer `TestUtil.assertUnsupportedWithLight(...)` / `assertUnsupportedToVersionWithLight(...)` (expects `UnsupportedOperationException` on light).

## Native test

The JNI symbol names in `native/natives.c` are tied to `com.github.dcevm.test.natives.SimpleNativeTest$A` (`..._00024A_value`). Renaming that class or its methods requires updating `natives.c`.

## Reference result: jdk8u212-b04 on Windows x64

With `flavor=light`, `kind=fastdebug` and Oracle JDK 1.8.0_212 as `jre` (VS2017 build), `./gradlew test` runs 96 tests with no failures or errors and 11 skipped. The skipped ones carry `@Ignore` in the test sources: `SimpleObjectStressTest`, `EnumTest.testEnumFields`, the 4 tests of `HierarchySwapTest`, `RedefineClassClassTest`, `RedefineObjectClassTest` and `TypeNarrowingMethodTest`/`2`/`3`. Compare new results against this baseline.
