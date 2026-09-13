package com.astelee.horizonte_news

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Habilita edge-to-edge via WindowCompat (androidx.core), que
        // funciona com qualquer Activity — diferente de
        // ComponentActivity.enableEdgeToEdge(), que exigia um tipo de
        // Activity que o FlutterActivity dessa versão do engine não
        // resolve, quebrando a compilação. Resolve o aviso do Play
        // Console sobre APIs descontinuadas de ponta a ponta a partir
        // do Android 15 (API 35).
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
}