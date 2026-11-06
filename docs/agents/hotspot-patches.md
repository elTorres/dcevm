# HotSpot patch series

All VM changes live in `hotspot/.hg/patches/` as a patch series in Mercurial Queues (mq) layout: one `.patch` file per change plus a `series` file. The directory keeps its historical mq name, but Mercurial is no longer used: the Gradle build fetches the sources with Git and applies the series with GNU `patch`. `.gitignore` ignores everything under `hotspot/` except `.hg/patches/*.patch` and `.hg/patches/series`. Those two are the only VM artifacts committed to git. `.gitattributes` keeps them in LF on every platform.

## Patch naming

- `light-<hotspotTag>.patch` / `full-<hotspotTag>.patch`: the main DCEVM change for a HotSpot tag. `full` supports full redefinition, including removing supertypes, but exists only for JDK 7. `light` supports additions only and is the only flavor for JDK 8.
- `*-deopt-cp.patch`: implements `-XX:HotswapDeoptClassPath`.
- Feature or fix patches with a version suffix (`arguments-java8u40`, `gc-java8u40`, `dmh-field-accessors-java8u201`, `arguments-java8u212`, ...). The suffix is the first update where that variant is needed.
- `distro-name.patch` applies to every tag except the ones that exclude it with a negative guard (from 8u212 on, `distro-name-java8u212.patch` replaces it).

## Guards

`./gradlew patch` selects these guards (the same set `hg qselect` used to receive):

```groovy
<flavor>   jdk7|jdk8   <hotspotTag>   <flavor>-<hotspotTag>
```

Each line in `series` is a patch name followed by optional guards, with mq semantics:

- No guards: the patch always applies.
- `#+guard`: the patch applies only if at least one of its `#+` guards is selected. In practice almost every line is guarded by `#+<flavor>-<hotspotTag>` entries, such as `#+light-jdk8u212-b04`. A main patch is often reused for later tags: `light-jdk8u201-b09.patch` also carries `#+light-jdk8u202-b08` and `#+light-jdk8u212-b04`.
- `#-guard`: the patch is skipped if any of its `#-` guards is selected (`distro-name.patch #-light-jdk8u212-b04`).

Order in `series` is the application order. Each patch is applied with `patch -p1 --fuzz=2` after a successful `--dry-run`. If a patch does not apply, the task fails naming the patch and the files with rejected hunks, and the following patches are not applied.

## Local history in `hotspot/`

`./gradlew patch` wipes `hotspot/` (except `.hg/` and `build/`), copies the pristine sources of the tag and creates a local Git repository in `hotspot/` (ignored by the outer repository) with one commit `upstream <tag>` plus one commit per applied patch, whose message is the patch file name. Use it to inspect the series: `git -C hotspot log --oneline`, `git -C hotspot show <commit>`.

Any edit in `hotspot/` that is not saved into a patch with `refreshPatch` is lost on the next `./gradlew patch`.

## Editing an existing patch

1. Set `hotspotTag`/`flavor` in `gradle.properties`.
2. Run `./gradlew :hotspot:patch -PpatchUntil=<name.patch>` to stop the series right after the patch you want to change (replaces `hg qgoto`).
3. Edit the sources in `hotspot/`, then run `./gradlew :hotspot:refreshPatch` (replaces `hg qrefresh`). It rewrites the last applied patch with the diff of the sources against the previous commit, keeps the header of the file (everything before the first `diff`) and amends the local commit.
4. Run `./gradlew :hotspot:patch` to check that the whole series still applies from scratch, and commit the changed `.patch` file in git.

## Creating a new patch

1. Add its line to `series` with its guards and create the `.patch` file with just a one-line description (a patch without hunks applies as an empty change).
2. Run `./gradlew :hotspot:patch -PpatchUntil=<new.patch>`, make the changes in `hotspot/` and run `./gradlew :hotspot:refreshPatch`.

To port an older variant, apply it by hand on top of the empty patch (`patch -p1 -i .hg/patches/<old.patch>` inside `hotspot/`), fix the rejected hunks and then run `refreshPatch`. This is how `arguments-java8u212.patch` was made from `arguments-java8u40.patch`.

## Adding a new JDK update (history shows this pattern)

1. Set `hotspotTag` to the new tag in `gradle.properties`. Keep the commented list of older tags. Tags are those of `https://github.com/openjdk/jdk8u` (or `jdk7u`), for example `jdk8u212-b04`.
2. Add the new tag's `#+light-<tag>` guard to every shared patch line in `series` that still applies.
3. If the previous main patch or a feature patch no longer applies cleanly, create a new versioned variant (for example `light-<tag>.patch` or `dmh-field-accessors-java8u201.patch`) as described above. Guard it with the new tag and keep the new tag out of the old one (remove its `#+` guard or, for unguarded patches, add a `#-` guard).
4. Build and run the test suite against a JDK of exactly that update.
