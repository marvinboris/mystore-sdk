export type Platform = 'android' | 'windows' | 'macos' | 'linux' | 'web';
export type Arch = 'arm64-v8a' | 'armeabi-v7a' | 'x86_64' | 'x64' | 'arm64' | 'universal';
export type ChannelName = 'stable' | 'beta';
export type VerifyFailure = 'malformed' | 'unknown-key' | 'bad-signature' | 'expired' | 'rollback' | 'wrong-app';
export type Artifact = {
    platform: Platform;
    arch: Arch;
    kind: 'apk' | 'exe' | 'msi' | 'dmg' | 'zip' | 'appimage' | 'deb' | 'pwa';
    url: string;
    size: number;
    sha256: string;
    sha512?: string;
    minOs?: string;
    tauriSig?: string;
};
