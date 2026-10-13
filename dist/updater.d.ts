import type { Artifact, Platform, ChannelName, VerifyFailure } from './types';
import { type Storage } from './storage';
export type UpdaterOptions = {
    app: string;
    platform: Platform;
    arch: Artifact['arch'];
    channel?: ChannelName;
    baseUrl?: string;
    pinnedKeys?: Record<string, string>;
    storage?: Storage;
    fetch?: typeof fetch;
    timeoutMs?: number;
    now?: () => Date;
};
export type UpdateResult = {
    status: 'up-to-date';
} | {
    status: 'available' | 'required';
    version: string;
    notes: string[];
    artifact: Artifact;
    size: number;
} | {
    status: 'incompatible';
    version: string;
} | {
    status: 'unknown';
    reason: 'network' | 'http' | VerifyFailure;
};
export declare const DEFAULT_BASE_URL = "https://mystore-pied-sigma.vercel.app";
export declare const storeUrl: (app: string, baseUrl?: string) => string;
export declare const deepLink: (app: string) => string;
export declare function createUpdater(o: UpdaterOptions): {
    check: (currentVersion: string, locale?: 'fr' | 'en') => Promise<UpdateResult>;
    installId: () => Promise<string>;
};
