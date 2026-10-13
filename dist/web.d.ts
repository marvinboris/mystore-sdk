import type { UpdateResult } from './updater';
type Required = Extract<UpdateResult, {
    status: 'available' | 'required';
}> & {
    status: 'required';
};
/** Blocking modal for verified required updates. DOM built with textContent only (Trusted Types / CSP safe). */
export declare function showRequiredUpdate(r: Required, o: {
    appName: string;
    onUpdate: () => void;
    locale?: 'fr' | 'en';
}): HTMLDialogElement;
export {};
