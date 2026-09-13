# ── Flutter ──────────────────────────────────────────────────────
# O próprio engine do Flutter já embute regras básicas, mas mantemos
# essas aqui de forma explícita para não depender só do padrão.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# ── Firebase / Firestore ────────────────────────────────────────
# Firestore serializa modelos via reflection; sem isso o R8 pode
# remover campos/construtores usados só implicitamente.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── OneSignal ────────────────────────────────────────────────────
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# ── Google Mobile Ads (AdMob) ───────────────────────────────────
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# ── video_player / ExoPlayer ─────────────────────────────────────
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# ── Gson / modelos serializados (se usados por dependências) ────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ── Kotlin coroutines / reflection ──────────────────────────────
-dontwarn kotlinx.coroutines.**
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}