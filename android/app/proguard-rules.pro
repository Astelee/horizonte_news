# ── Flutter ──────────────────────────────────────────────────────
# O engine do Flutter já embute suas próprias regras via
# flutter-embedding; não precisamos manter tudo sem ofuscar.
-keep class io.flutter.embedding.engine.FlutterJNI { *; }
-keep class io.flutter.plugin.editing.** { *; }
-dontwarn io.flutter.embedding.**

# io.flutter.app.FlutterPlayStoreSplitApplication referencia classes da
# Play Core (com.google.android.play.core.splitcompat.*) usadas só para
# apps que fazem split install por feature — não é o caso deste app, e
# a dependência da Play Core nem está no projeto. Sem esse -dontwarn o
# R8 falha com "Missing class" ao tentar manter essa classe.
-dontwarn com.google.android.play.core.**

# ── Firebase / Firestore ────────────────────────────────────────
# Firestore serializa modelos via reflection; mantemos só os
# construtores/campos anotados, não o pacote inteiro.
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.PropertyName <methods>;
}
-keep class com.google.firebase.firestore.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── OneSignal ────────────────────────────────────────────────────
-keep class com.onesignal.OneSignal { *; }
-keep class com.onesignal.NotificationExtenderService { *; }
-dontwarn com.onesignal.**

# ── Google Mobile Ads (AdMob) ───────────────────────────────────
-keep class com.google.android.gms.ads.internal.util.WorkManagerUtil { *; }
-keep public class com.google.android.gms.ads.** {
    public *;
}
-dontwarn com.google.android.gms.ads.**

# ── video_player / ExoPlayer ─────────────────────────────────────
-keep class com.google.android.exoplayer2.database.** { *; }
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