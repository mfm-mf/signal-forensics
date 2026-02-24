import { app, safeStorage } from 'electron';
import * as fs from 'fs';
import * as path from 'path';

// --- Argument parsing ---
// Usage: electron . [-o <output_path>] [--verbose]
function parseArgs(argv: string[]): { outputPath?: string; verbose: boolean } {
    // Strip the electron binary (and script path if not defaultApp)
    const args = argv.slice(process.defaultApp ? 2 : 1);
    let outputPath: string | undefined;
    let verbose = false;

    for (let i = 0; i < args.length; i++) {
        if ((args[i] === '-o' || args[i] === '--output') && args[i + 1]) {
            outputPath = args[++i];
        } else if (args[i] === '--verbose' || args[i] === '-v') {
            verbose = true;
        }
    }

    return { outputPath, verbose };
}

const { outputPath, verbose } = parseArgs(process.argv);

function log(...msgs: unknown[]) {
    if (verbose) console.log(...msgs);
}

// --- Main ---
app.whenReady().then(async () => {
    try {
        if (!safeStorage.isEncryptionAvailable()) {
            console.error("Error: Encryption is not available.");
            app.exit(1);
            return;
        }

        const appDataPath = process.env.APPDATA;
        if (!appDataPath) {
            console.error("Error: Could not determine AppData path.");
            app.exit(1);
            return;
        }

        const signalConfigPath = path.join(appDataPath, 'Signal', 'config.json');
        log("Looking for Signal config at:", signalConfigPath);

        if (!fs.existsSync(signalConfigPath)) {
            console.error("Error: Signal config file not found. Is Signal installed?");
            app.exit(1);
            return;
        }

        const configData = fs.readFileSync(signalConfigPath, 'utf8');
        let config: any;
        try {
            config = JSON.parse(configData);
        } catch {
            console.error("Error: Failed to parse Signal config.json.");
            app.exit(1);
            return;
        }

        if (!config.encryptedKey || typeof config.encryptedKey !== 'string') {
            console.error("Error: No valid encryptedKey found in Signal config.");
            app.exit(1);
            return;
        }

        if (!/^[0-9a-fA-F]+$/.test(config.encryptedKey)) {
            console.error("Error: encryptedKey is not a valid hex string.");
            app.exit(1);
            return;
        }

        const encryptedBuffer = Buffer.from(config.encryptedKey, 'hex');
        const decryptedKey = safeStorage.decryptString(encryptedBuffer);

        if (!decryptedKey) {
            console.error("Error: Decryption returned an empty result.");
            app.exit(1);
            return;
        }

        if (outputPath) {
            const resolvedPath = path.resolve(outputPath);
            const outputDir = path.dirname(resolvedPath);

            if (!fs.existsSync(outputDir)) {
                console.error(`Error: Output directory does not exist: ${outputDir}`);
                app.exit(1);
                return;
            }

            fs.writeFileSync(resolvedPath, decryptedKey, { encoding: 'utf8' });
            log("Decrypted key written to:", resolvedPath);
        } else {
            // Only write the key to stdout when no output file is specified
            process.stdout.write(decryptedKey + '\n');
        }

    } catch (error: any) {
        console.error("Unexpected error:", error?.message ?? error);
        app.exit(1);
        return;
    }

    app.quit();
});