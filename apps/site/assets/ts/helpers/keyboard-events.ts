import { KeyboardEvent as ReactKeyboardEvent } from "react";

export const isEnter = (key: number | string): boolean =>
  key === "Enter" || key === 13;

export const isEscape = (key: number | string): boolean =>
  key === "Escape" || key === 27;

// for vanilla JS
export const handleNativeEnterKeyPress = (
  e: KeyboardEvent,
  cb: Function
): void => (isEnter(e.key || e.keyCode) ? cb(e) : () => {});

export const handleNativeEscapeKeyPress = (
  e: KeyboardEvent,
  cb: Function
): void => (isEscape(e.key || e.keyCode) ? cb(e) : () => {});

// for React
export const handleReactEnterKeyPress = (
  e: ReactKeyboardEvent,
  onClick: Function
): void => {
  if (e.key === "Enter") {
    onClick();
  }
};

export const handleReactExitKeyPress = (
  e: ReactKeyboardEvent,
  onClick: Function
): void => {
  if (e.key === "Escape") {
    onClick();
  }
};
