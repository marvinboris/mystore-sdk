# MyStore SDK

Asks MyStore whether your app has an update, and whether it is **required**, with an answer you can trust:
the manifest is signed (Ed25519, pinned key), fresh (14-day expiry) and never older than the last one seen.
Network or verification trouble returns `unknown`: your app keeps working. Only a verified `required` should block it.

- JavaScript / TypeScript: Expo & React Native, web & PWA, Electron, Tauri (≈ 10 KB gzip, no dependencies)
- Dart: Flutter and any Dart app (`dart/`)

## Install

```bash
npm i github:marvinboris/mystore-sdk#v0.1.0
```
```yaml
# pubspec.yaml
dependencies:
  mystore_sdk:
    git: { url: https://github.com/marvinboris/mystore-sdk, path: dart, ref: v0.1.0 }
```

## Results

| status | meaning | what to do |
|---|---|---|
| `up-to-date` | nothing newer for this device | nothing |
| `available` | newer version (with `version`, `notes`, `size`) | offer it, never force |
| `required` | this version is below the app's minimum (security fix) | block and send the user to the update |
| `incompatible` | no file for this device | nothing |
| `unknown` | offline, server or signature problem (`reason`) | keep working, retry later |

Versions are `X.Y.Z` or `X.Y.Z-beta.N` (`alpha.N`, `rc.N`). Passing anything else throws: it is a bug in your app.

## Expo / React Native

```ts
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Device from 'expo-device';
import * as Application from 'expo-application';
import { Linking } from 'react-native';
import { createUpdater, deepLink, storeUrl } from '@mystore/sdk';

const abi = Device.supportedCpuArchitectures?.[0];
const arch = abi === 'arm64-v8a' || abi === 'armeabi-v7a' || abi === 'x86_64' ? abi : 'universal';
const updater = createUpdater({ app: 'tontine', platform: 'android', arch,
  storage: { get: k => AsyncStorage.getItem(k), set: (k, v) => AsyncStorage.setItem(k, v) } });

const r = await updater.check(Application.nativeApplicationVersion!);
if (r.status === 'required') {
  // render a full-screen blocking view with r.notes[0], then:
  Linking.openURL(deepLink('tontine')).catch(() => Linking.openURL(storeUrl('tontine')));
}
```

## Web / PWA

```ts
import { createUpdater, showRequiredUpdate } from '@mystore/sdk';
const r = await createUpdater({ app: 'kalo', platform: 'web', arch: 'universal' }).check(APP_VERSION);
if (r.status === 'required') showRequiredUpdate(r, { appName: 'Kalo', onUpdate: () => location.reload() });
```
`showRequiredUpdate` opens a native modal `<dialog>` that re-opens if dismissed until the user updates, built without `innerHTML` (safe under strict CSP and Trusted Types).

## Electron / Tauri

Let the native updater install updates from MyStore feeds:
- Electron (electron-updater, generic provider): `https://mystore-pied-sigma.vercel.app/v1/<app>/electron/stable/`
- Tauri v2 updater endpoint: `https://mystore-pied-sigma.vercel.app/v1/<app>/tauri/stable.json`

Use the SDK only to enforce `required` (same code as Web, with `platform: 'windows' | 'macos' | 'linux'` and `arch: 'x64' | 'arm64' | 'universal'`).

## Flutter

```dart
import 'package:mystore_sdk/mystore_sdk.dart';
// arch from device_info_plus: (await DeviceInfoPlugin().androidInfo).supportedAbis.first
final updater = MyStoreUpdater(app: 'marche', platform: 'android', arch: 'arm64-v8a', storage: MyPrefsStorage());
switch (await updater.check(packageInfo.version)) {
  case Required(:final notes, :final size): showBlockingUpdate(notes.first, size); // open deepLink('marche') or storeUrl('marche')
  case Available(:final version): offerUpdate(version);
  case UpToDate() || Incompatible() || Unknown(): break;
}
```
`storage` is required: implement `UpdaterStorage` with `shared_preferences` so the device id (staged rollout) and the anti-replay serial survive restarts. `Required` and `Available` are distinct types: handle `Required` explicitly.

## Options

`baseUrl` (default `https://mystore-pied-sigma.vercel.app`), `channel` (`stable` | `beta`), `timeoutMs` / `timeout` (10 s), `pinnedKeys` (defaults to MyStore's production key), `storage` (JS: localStorage by default, pass AsyncStorage on React Native; Dart: required).

MIT licensed.
