# AndroidX Room instantiates WorkDatabase_Impl reflectively during WorkManager startup.
# Keep the generated no-argument constructor in minified release builds.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
