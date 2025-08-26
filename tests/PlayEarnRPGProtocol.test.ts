/// <reference types="vitest" />

import { defineConfig } from "vite";
import {
  vitestSetupFilePath,
  getClarinetVitestsArgv,
} from "@hirosystems/clarinet-sdk/vitest";

/*
  Vitest is configured to work with Clarinet + Simnet.

  - `vitest-environment-clarinet` initializes Clarinet SDK 
    and exposes the `simnet` object globally.
  - `vitestSetupFilePath` will:
      • run before/after hooks to init simnet and collect coverage/costs
      • load custom Vitest matchers (toBeUint, etc.)
  - `getClarinetVitestsArgv()` parses CLI options like:
      • vitest run -- --manifest ./Clarinet.toml
      • vitest run -- --coverage --costs
*/

export default defineConfig({
  test: {
    // Use clarinet-powered test environment
    environment: "clarinet",

    // Run tests in a single isolated fork
    pool: "forks",
    poolOptions: {
      forks: { singleFork: true },
      threads: { singleThread: true },
    },

    // Setup files (Clarinet hooks + your custom setup if needed)
    setupFiles: [vitestSetupFilePath],

    // Pass clarinet-specific options
    environmentOptions: {
      clarinet: {
        ...getClarinetVitestsArgv(),
        // You can also override here, e.g.:
        // manifest: "./Clarinet.toml",
        // coverage: true,
        // costs: true,
      },
    },
  },
});
