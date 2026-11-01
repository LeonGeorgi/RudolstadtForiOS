import {Config} from '@remotion/cli/config';

Config.setVideoImageFormat('png');
Config.setOverwriteOutput(true);
Config.setConcurrency(4);
Config.setBrowserExecutable('/Users/leon/Library/Caches/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-mac-arm64/chrome-headless-shell');
Config.setDisableSharedMemoryCapture(true);
Config.setChromiumOpenGlRenderer('angle');
Config.setDisallowParallelEncoding(true);
