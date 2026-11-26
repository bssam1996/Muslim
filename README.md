# Muslim 🕌

**Your all-in-one Islamic companion.**

"Muslim" is a Flutter-based mobile application designed to be a comprehensive guide for Muslims everywhere. It provides essential tools for daily worship, including prayer times, Qibla direction, Quran reading, Azkar, Duas, Hadith collections, and more.

## ✨ Features

- 🕋 **Qibla Compass**: Accurate Qibla direction finder with visual compass.
- 📖 **Quran**: Digital Quran reading with custom fonts (Uthmanic script).
- 🤲 **Azkar & Duas**: Collection of morning/evening Azkar and various Duas.
- 📜 **Hadith**: Access to Hadith collections with search functionality.
- 📅 **Prayer Calendar**: Prayer times and Islamic calendar view.
- 📻 **Islamic Radio**: Listen to live Islamic radio stations.
- 🏠 **Umrah Guide**: Information and checklist for Umrah.
- ⏰ **Prayer Notifications**: Reminders for Salah times.
- 🌍 **Multi-language Support**: Available in English and Arabic (`en-US`, `ar-EG`).
- 🎨 **Custom UI**: Clean interface with custom fonts and theming.
- 🏠 **Home Widget**: Android widget for quick access to prayer info.
- 🔄 **Auto Updates**: Built-in app updater functionality.

## 📱 Supported Platforms

- Android
- Web (Limited)

## 🛠️ Tech Stack

- **Framework**: Flutter SDK
- **Language**: Dart
- **State Management**: Standard Flutter Widget Tree (with `shared_preferences` for storage)
- **Networking**: `http`, `seeip_client`
- **Local Storage**: `shared_preferences`
- **Localization**: `easy_localization`, `flutter_localization`
- **Background Tasks**: `workmanager`, `android_alarm_manager_plus`
- **Notifications**: `flutter_local_notifications`
- **Maps/Location**: `flutter_qiblah`
- **UI Components**: `syncfusion_flutter_datagrid`, `flutter_svg`, `smooth_page_indicator`

## 📂 Project Structure

## Container deployment

Both mobile and web use `https://api-muslim.bplusplus.uk/` by default. The web
container serves the compiled Flutter app with Nginx; the visitor's browser calls
the public API directly:

```text
Mobile  -> https://api-muslim.bplusplus.uk/v1/...
Browser -> https://api-muslim.bplusplus.uk/v1/...
```

The repository's `compose.yaml` includes the existing API image and deployment
settings alongside the web service, in the `muslim-api` Compose project. The mini
PC pulls `ghcr.io/bssam1996/muslim-web:latest`; no source checkout or Flutter SDK
is needed there.

The `Publish web image` GitHub Actions workflow builds the Docker image for
`linux/amd64` and `linux/arm64` and checks that the container serves the app before
publishing. Push the container files and workflow to `main`
(or merge a pull request into `main`) to publish `latest`. Pull requests build
the image without publishing it. The workflow also supports **Run workflow** in
GitHub Actions; runs from other branches publish a branch tag and a `sha-...`
tag, while only `main` updates `latest`. Authentication uses the workflow's
`GITHUB_TOKEN` with `packages: write`; no registry secret needs to be added.

After the first successful publish, set the `muslim-web` package's visibility
to **Public** in GitHub Packages to allow anonymous pulls, or run
`docker login ghcr.io` on the mini PC with a classic personal access token with `read:packages`
for a private package. Package visibility is separate from repository visibility.

The web container has no dependency on the API container or its internal address.
The existing `8003:8000` API port mapping is unchanged.

Copy `compose.yaml` to the mini PC, or add this service to its existing Compose
file alongside `api`:

```yaml
services:
  # Keep the existing API service and its configuration here.
  muslim-web:
    image: ghcr.io/bssam1996/muslim-web:latest
    restart: unless-stopped
    ports:
      - "127.0.0.1:8004:8080"
```

Then run from the directory containing that combined Compose file:

```sh
docker compose config
docker compose pull muslim-web
docker compose up -d muslim-web
curl -f http://127.0.0.1:8004/healthz
```

For `muslim.bplusplus.uk`, add a published application route in Cloudflare Tunnel
with service type **HTTP** and URL `127.0.0.1:8004` if `cloudflared` runs on the
mini PC host. If `cloudflared` runs in a container, join it to the web service's
Docker network and use URL `muslim-web:8080`. Cloudflare handles public HTTPS.
Keep `api-muslim.bplusplus.uk` routed to the API for mobile and browser clients.

To deploy a newly published image, run the same pull and up commands again.

`/healthz` checks the web server only, not API availability. The included Compose
file accepts `WEB_PORT` (default `8004`), `WEB_BIND_ADDRESS` (default
`127.0.0.1`), and `MUSLIM_WEB_IMAGE` to choose a branch or `sha-...` image tag.

For a local image build or a custom API URL, pass the `MUSLIM_API_URL` build
argument with a trailing slash:

```sh
docker build -t muslim-web:local --build-arg MUSLIM_API_URL=https://api-muslim.bplusplus.uk/ .
```

For Flutter builds outside Docker:

```sh
flutter build apk --release --dart-define=MUSLIM_API_URL=https://api-muslim.bplusplus.uk/
flutter build web --release --dart-define=MUSLIM_API_URL=https://api-muslim.bplusplus.uk/
```

The API must return CORS headers allowing the web app's origin. The public API
currently returns `Access-Control-Allow-Origin: *` for prayer-time requests;
keep the appropriate CORS policy enabled for all API endpoints the app uses.
CORS headers belong on API responses.

`MUSLIM_API_URL` is compiled into the app; changing a running container's
environment alone does not update it. The Dockerfile pins Flutter to `3.50.0`,
matching the development SDK; set the `FLUTTER_VERSION` build argument to change
it. The runtime image contains only Nginx and the compiled web files. Source PDFs
in `Books/`, platform signing
files, and local build outputs are excluded from the Docker build context.

