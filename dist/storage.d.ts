export type Storage = {
    get(key: string): Promise<string | null>;
    set(key: string, value: string): Promise<void>;
};
export declare function memoryStorage(): Storage;
/** localStorage when usable (Safari private mode and some WebViews throw), memory otherwise. */
export declare function webStorage(): Storage;
/** Wraps any storage so a failing get/set never breaks an update check. */
export declare function safeStorage(s: Storage): Storage;
