# Returing — versões para celular e outras plataformas

O mesmo projeto roda em **Android, iPhone (pelo navegador ou app nativo), navegador, Windows, Linux e macOS**.
Presets prontos em `export_presets.cfg` (Projeto > Exportar).

| Plataforma | Preset | Como obter |
|---|---|---|
| Android | Android (APK) | exportar direto no Windows |
| **iPhone / iPad** | Web (iPhone, Android e navegador) | exportar direto no Windows; abre no Safari (veja abaixo) |
| iPhone (app nativo) | iOS (iPhone) | só em um **Mac com Xcode** (a Apple não permite gerar em Windows) |
| Windows / Linux / macOS | Windows (PC), Linux (PC), macOS (PC) | exportar direto no Windows |

## Testar no PC como se fosse celular
```
godot --path . -- --mobile
```
O mouse vira o dedo (botão esquerdo).

## iPhone pelo Safari (versão Web)
1. Hospede a pasta `web/` (ela precisa ser servida por um endereço http/https, não abre por duplo clique):
   * no PC: dê dois cliques em `servir_web.bat` e, no iPhone (mesma rede Wi-Fi), abra `http://IP-DO-PC:8080`;
   * ou envie a pasta para itch.io, GitHub Pages, Netlify etc. (HTTPS).
2. No Safari: Compartilhar > **Adicionar à Tela de Início**. Com HTTPS ele abre em tela cheia, como app.
3. Gire o aparelho para paisagem. O jogo detecta iPhone/iPad e liga os controles de toque sozinho.

A versão Web é compilada sem threads, então não exige cabeçalhos especiais do servidor.

## iPhone — app nativo (Xcode)
1. No Mac: Godot 4.7.2 + export templates, abrir este projeto.
2. Projeto > Exportar > **iOS (iPhone)**: preencher *App Store Team ID* e *Bundle Identifier* (`com.returing.game`), exportar.
3. Abrir o `.xcodeproj` no Xcode, escolher o iPhone e rodar (ou Archive para TestFlight).

## Android
Godot 4.7.2 + export templates, JDK 17 e Android SDK configurados em Editor > Configurações do Editor > Export > Android.
Exportar o preset **Android (APK)** (pacote `com.returing.game`, paisagem, arm64 + armeabi-v7a).

## Controles do celular
* Analógico esquerdo: mover. Analógico direito: **mirar e atacar** (espada e tiro).
* Espada: segure para mirar (aparece a área laranja do golpe) e **solte para golpear**. Tiro: segure para carregar (barra azul) e solte para atirar.
* Toque rápido no analógico direito: mira no inimigo mais próximo e ataca.
* Botões: trocar de arma, dash, E (interagir, perto do terminal) e pausa.

## Ajustes rápidos
* `autoload/platform.gd`: `MOBILE_SPRITE_SCALE` (1.5), `MOBILE_CAMERA_ZOOM` (2.0), `MOBILE_MIN_SHOT_CHARGE` (0.2).
* `autoload/mobile_controls.gd`: `MELEE_ON_RELEASE` (false = a espada golpeia sem parar enquanto o dedo está no analógico).
* Mira assistida do tiro: constantes `ASSIST_*` em `characters/turing/player_projectile.gd`.
