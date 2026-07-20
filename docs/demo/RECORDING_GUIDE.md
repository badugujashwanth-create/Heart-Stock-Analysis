# Recording guide

1. Install backend, Flutter, Node, Chromium, and FFmpeg dependencies.
2. Start only the local rules-mode stack with prediction persistence enabled for the isolated synthetic database.
3. Run `scripts/record-demo.ps1 -UseExistingServices` or let the script start its own services.
4. Confirm the WebM exceeds three minutes, is 1280×720, contains VP9 video and Opus narration, and matches `demo.sha256`.
5. Open all milestone frames together and reject any capture with secrets, personal data, broken layout, loading failures, or misleading claims.

The final video is a release/portfolio asset, not a dedicated in-product navigation section.
