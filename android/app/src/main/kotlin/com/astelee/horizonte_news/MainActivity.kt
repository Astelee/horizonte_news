package com.astelee.horizonte_news

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Habilita edge-to-edge explicitamente via API atual do AndroidX,
        // em vez de depender do comportamento padrão do sistema. Resolve
        // o aviso do Play Console sobre APIs descontinuadas de
        // ponta a ponta a partir do Android 15 (API 35).
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}