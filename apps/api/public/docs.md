# notifi API documentation

> One endpoint, seven parameters, no SDK. Everything on this page is generated from the same file that generates [`/openapi.json`](https://notifi.it/openapi.json) and the client collections, so the three cannot disagree.

_[Quickstart](https://notifi.it/docs#quickstart) [Authentication](https://notifi.it/docs#auth) [Request](https://notifi.it/docs#request) [Parameters](https://notifi.it/docs#parameters) [Response](https://notifi.it/docs#response) [Errors](https://notifi.it/docs#errors) [Rate limits](https://notifi.it/docs#limits) [Clients and import](https://notifi.it/docs#clients) [Machine-readable](https://notifi.it/docs#machine) [Recipes](https://notifi.it/docs#recipes)_

## Quickstart

Install notifi on [iPhone or iPad](https://apps.apple.com/app/id1563961135) or [on the Mac](https://notifi.it/download/mac), allow notifications, open the Keys tab and copy the `Default` key. It starts with `nk_`.

```bash
curl -X POST https://notifi.it/send \
  -H "Authorization: Bearer $NOTIFI_KEY" \
  -d "title=Hello from notifi" \
  -d "message=Your first notification." \
  -d "link=https://notifi.it/docs" \
  -d "image=https://notifi.it/anaglyph-bell.png"
```

## Authentication

Authenticate with a bearer token. A key parameter also works, but it is written to edge logs, shell history and any proxy in between: use it only for a quick test, and rotate the key afterwards.

| Method | Sent as | Notes |
| --- | --- | --- |
| Bearer token | `Authorization: Bearer nk_yourkey` | The send key from the app’s Keys tab, as Authorization: Bearer nk_yourkey. Preferred: a header is not written to edge logs or shell history. |
| Parameter | `key=nk_yourkey` | The send key as a parameter. It appears in edge logs, in shell history and in any proxy in between, which makes it the weaker option: use it only for a quick test, and rotate the key afterwards. |

## Request

`POST https://notifi.it/send`, JSON, form-encoded or multipart. `GET` takes the same parameters in the query string and is there for a quick test: a key sent that way lands in edge logs and shell history, so rotate it afterwards. Query parameters win over body fields when both are present.

```http
POST /send HTTP/1.1
Host: notifi.it
Authorization: Bearer nk_yourkey
Content-Type: application/json
Accept-Language: en-GB

{"title":"Hello from notifi","message":"Your first notification.","link":"https://notifi.it/docs","image":"https://notifi.it/anaglyph-bell.png"}
```

## Parameters

`key` is required unless the request carries a bearer token. An image is fetched server-side and must be `https`, PNG, JPEG or GIF, 5 MB at most.

| Name | Type | Required | Limit | Description |
| --- | --- | --- | --- | --- |
| `key` | string | conditional | `nk_…` | The send key, if it is not sent as a bearer token. Required unless sent as a bearer token. The key picks the device the notification lands on. |
| `title` | string | required | `1–200 chars` | The notification title. A longer title is delivered cropped, with a warning in the response. |
| `message` | string | optional | `≤ 16,000 chars` | The notification body, in Markdown. The push shows a short preview; the app renders the full text. A longer body is delivered cropped, with a warning. |
| `link` | string (uri) | optional | `≤ 2,048 chars` | URL opened when the notification is tapped. https always opens. Another scheme — shortcuts://run-shortcut?name=Deploy, an app’s own deep link — opens only when the key’s Open any link switch is on in the app; off, the link is hidden. |
| `image` | string (uri) | optional | `≤ 2,048 chars` | https URL of a PNG, JPEG or GIF up to 5 MB. One that cannot be fetched is dropped, with a warning, and the notification still arrives. |
| `occurred_at` | integer | optional | `unix ms` | When the event actually happened, as unix milliseconds. For a queued or retried send. Only changes the timestamp shown in the app; defaults to the time the server accepted the request. |
| `is_critical` | boolean | optional | — | Breaks through Focus. The key must also have critical alerts switched on in the app, or an ordinary notification is delivered and the response carries a warnings array. |

## Response

A send answers `202`. That means the server accepted it, not that it was delivered — delivery is best-effort, as the [terms](https://notifi.it/terms) describe. Every status the endpoint can answer with is here:

### 202

```
HTTP/1.1 202 Accepted
Content-Type: application/json; charset=utf-8

{"ok":true}
```

### 400

```
HTTP/1.1 400 Bad Request
Content-Type: application/json; charset=utf-8

{"error":{"code":"invalid_request","message":"title is required."}}
```

### 401

```
HTTP/1.1 401 Unauthorized
Content-Type: application/json; charset=utf-8

{"error":{"code":"unknown_key","message":"Unknown or revoked key."}}
```

### 422

```
HTTP/1.1 422 Unprocessable Content
Content-Type: application/json; charset=utf-8

{"error":{"code":"invalid_content","message":"Not sent. This device is set to refuse a notification it cannot deliver as written."}}
```

### 429

```
HTTP/1.1 429 Too Many Requests
Content-Type: application/json; charset=utf-8
Retry-After: 42

{"error":{"code":"rate_limited","message":"Too many notifications. Try again shortly."}}
```

A `warnings` array is present only when the notification was delivered differently from what was asked: a cropped title or body, a dropped image, or a critical alert delivered as an ordinary notification. The status is still `202` — the notification was sent, in the altered form each warning describes.

```http
HTTP/1.1 202 Accepted
Content-Type: application/json; charset=utf-8

{"ok":true,"warnings":["Sent with a shortened title: it was over 200 characters.","Sent as a normal notification: critical alerts are switched off for this key."]}
```

### Over-length text is cropped

A title over 200 characters or a body over 16000 is delivered cropped, with a warning. The device can refuse instead: **Reject invalid sends**, in the app's Settings, makes a send that would have been cropped or stripped answer `422 invalid_content` and store nothing. It is off by default, so cropping is what a send meets unless the person holding the device turned it on.

![The Settings screen, showing the Reject invalid sends switch turned off.](/shots/settings-reject-invalid-sends.png)

_Settings → Permissions → Reject invalid sends. Off, the default: sends are cropped, not refused._

### Critical alerts are granted per key

`is_critical=1` asks for an alert that breaks through Focus and silent mode. It is not enough on its own: the key it was sent with must have **Critical alerts** switched on, on that device, in that key's screen under the Keys tab. Without it the notification is delivered as an ordinary one and the response carries a warning saying so. A sender cannot turn this on — only the person holding the device can.

![A key's screen in the app, showing the Critical alerts switch turned on.](/shots/key-critical-alerts.png)

_Keys → a key → Settings → Critical alerts. Each key carries its own permission._

## Errors

Every error nests the code one level down. Read `error.code`, not `code`. The `message` is in the language negotiated from `Accept-Language` and is meant for a human, so match on the code.

| Status | `error.code` | Meaning |
| --- | --- | --- |
| `400` | `invalid_request` | A parameter is missing or malformed. |
| `401` | `unknown_key` | The key is unknown or has been revoked. |
| `422` | `invalid_content` | The device is set to refuse a notification it cannot deliver as written. |
| `429` | `rate_limited` | Over the hourly device limit or the per-minute IP limit. Carries a Retry-After header with the seconds until the window resets. |
| `404` | `not_found` | No such path. |
| `500` | `internal_error` | Something broke on our side. |

## Rate limits

- 60 notifications an hour per device, shared across every key on it.
- 5 active send keys per device, one of which is the app’s own default.
- 100 requests a minute per IP address, across every endpoint.
- Revoking a key in the app takes effect on the next send. Reinstalling the app, or moving to a new device, makes a new identity and every old key stops working; there is no migration.

A `429` carries `Retry-After` in seconds. The device limit is 60 an hour across all 5 keys; the address limit is 100 requests a minute and covers every endpoint.

## Clients and import

The collection and the OpenAPI document are generated from the same source as this page. Set `NOTIFI_KEY` and send.

### Postman

```
# Import → Link, then paste this. Postman keeps it in sync from there.
https://notifi.it/notifi.postman_collection.json
```

### Bruno

```
# Drop the .bru straight into a collection folder,
# or use Import → Postman Collection with the URL above.
curl -O https://notifi.it/notifi.bru
```

### Insomnia

```
# Import From → URL takes either the OpenAPI document
# or the Postman collection.
https://notifi.it/openapi.json
```

### HTTPie

```
# No import needed.
http -f POST https://notifi.it/send \
  "Authorization:Bearer $NOTIFI_KEY" \
  title="Hello from notifi" \
  message="Your first notification." \
  link="https://notifi.it/docs" \
  image="https://notifi.it/anaglyph-bell.png"
```

### Client generator

```
# Any generator that reads OpenAPI 3.1.
openapi-generator-cli generate \
  -i https://notifi.it/openapi.json \
  -g typescript-fetch \
  -o ./notifi
```

## Machine-readable

- [`/llms.txt`](https://notifi.it/llms.txt) — The full reference as plain text, written for coding agents.
- [`/openapi.json`](https://notifi.it/openapi.json) — OpenAPI 3.1 for /send.
- [`/notifi.postman_collection.json`](https://notifi.it/notifi.postman_collection.json) — Postman v2.1 collection. Bruno, Insomnia, Hoppscotch and Paw import it too.
- [`/notifi.bru`](https://notifi.it/notifi.bru) — A Bruno request file, for dropping straight into a collection folder.
- [`/sitemap.xml`](https://notifi.it/sitemap.xml) — Every page worth reading.
- [`/docs.md`](https://notifi.it/docs.md) — This page as Markdown.

Every page on this site is also served as Markdown: send `Accept: text/markdown` on the same URL, or append `.md`. [The source](https://github.com/notifi-it/notifi) covers the app, the API and the cryptography.

There is no MCP server, no webhook API and no OAuth. One endpoint and a bearer token is the whole integration surface, and anything claiming otherwise is not us.

## Recipes

The same request from everywhere it tends to get sent from — 15 of them, the same block the home page carries. Each one wants `NOTIFI_KEY` in the environment.

### curl

```
curl -X POST https://notifi.it/send \
  -H "Authorization: Bearer $NOTIFI_KEY" \
  -d "title=Hello from notifi" \
  -d "message=Your first notification." \
  -d "link=https://notifi.it/docs" \
  -d "image=https://notifi.it/anaglyph-bell.png"
```

### JavaScript

```
await fetch("https://notifi.it/send", {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${process.env.NOTIFI_KEY}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    title: "Hello from notifi",
    message: "Your first notification.",
    link: "https://notifi.it/docs",
    image: "https://notifi.it/anaglyph-bell.png",
  }),
});
```

### Python

```
import os, requests

requests.post(
    "https://notifi.it/send",
    headers={"Authorization": f"Bearer {os.environ['NOTIFI_KEY']}"},
    json={
        "title": "Hello from notifi",
        "message": "Your first notification.",
        "link": "https://notifi.it/docs",
        "image": "https://notifi.it/anaglyph-bell.png",
    },
)
```

### Go

```
package main

import (
	"net/http"
	"net/url"
	"os"
	"strings"
)

func main() {
	form := url.Values{
		"title":   {"Hello from notifi"},
		"message": {"Your first notification."},
		"link":    {"https://notifi.it/docs"},
		"image":   {"https://notifi.it/anaglyph-bell.png"},
	}
	req, _ := http.NewRequest("POST", "https://notifi.it/send",
		strings.NewReader(form.Encode()))
	req.Header.Set("Authorization", "Bearer "+os.Getenv("NOTIFI_KEY"))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	http.DefaultClient.Do(req)
}
```

### Swift

```
import Foundation

var request = URLRequest(url: URL(string: "https://notifi.it/send")!)
request.httpMethod = "POST"
request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = try JSONEncoder().encode([
    "title": "Hello from notifi",
    "message": "Your first notification.",
    "link": "https://notifi.it/docs",
    "image": "https://notifi.it/anaglyph-bell.png",
])

_ = try await URLSession.shared.data(for: request)
```

### Ruby

```
require "net/http"

uri = URI("https://notifi.it/send")
req = Net::HTTP::Post.new(uri)
req["Authorization"] = "Bearer #{ENV['NOTIFI_KEY']}"
req.set_form_data(
  "title" => "Hello from notifi",
  "message" => "Your first notification.",
  "link" => "https://notifi.it/docs",
  "image" => "https://notifi.it/anaglyph-bell.png"
)

Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
```

### PHP

```
<?php
$ch = curl_init("https://notifi.it/send");
curl_setopt_array($ch, [
    CURLOPT_POST       => true,
    CURLOPT_HTTPHEADER => ["Authorization: Bearer " . getenv("NOTIFI_KEY")],
    CURLOPT_POSTFIELDS => [
        "title"   => "Hello from notifi",
        "message" => "Your first notification.",
        "link"    => "https://notifi.it/docs",
        "image"   => "https://notifi.it/anaglyph-bell.png",
    ],
]);
curl_exec($ch);
```

### Rust

```
// reqwest = { version = "0.12", features = ["json"] }
let key = std::env::var("NOTIFI_KEY")?;

reqwest::Client::new()
    .post("https://notifi.it/send")
    .bearer_auth(key)
    .form(&[
        ("title", "Hello from notifi"),
        ("message", "Your first notification."),
        ("link", "https://notifi.it/docs"),
        ("image", "https://notifi.it/anaglyph-bell.png"),
    ])
    .send()
    .await?;
```

### Java

```
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.function.BiFunction;
import static java.nio.charset.StandardCharsets.UTF_8;

BiFunction<String, String, String> field = (k, v) -> k + "=" + URLEncoder.encode(v, UTF_8);

var body = String.join("&",
    field.apply("title", "Hello from notifi"),
    field.apply("message", "Your first notification."),
    field.apply("link", "https://notifi.it/docs"),
    field.apply("image", "https://notifi.it/anaglyph-bell.png"));

var request = HttpRequest.newBuilder(URI.create("https://notifi.it/send"))
    .header("Authorization", "Bearer " + System.getenv("NOTIFI_KEY"))
    .header("Content-Type", "application/x-www-form-urlencoded")
    .POST(HttpRequest.BodyPublishers.ofString(body))
    .build();

HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.discarding());
```

### Claude Code

```
// Fires when Claude stops.
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "curl -s https://notifi.it/send \
                     -H \"Authorization: Bearer $NOTIFI_KEY\" \
                     -d \"title=Claude finished\" \
                     -d \"message=$CLAUDE_PROJECT_DIR\""
      }]
    }]
  }
}
```

### GitHub Actions

```
# Put NOTIFI_KEY in the repository's secrets.
- name: Tell me it broke
  if: failure()
  run: |
    curl -s https://notifi.it/send \
      -H "Authorization: Bearer $NOTIFI_KEY" \
      -d "title=$GITHUB_WORKFLOW failed" \
      -d "message=$GITHUB_REF_NAME at $(git log -1 --format=%s)" \
      -d "link=$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
  env:
    NOTIFI_KEY: ${{ secrets.NOTIFI_KEY }}
```

### Shell hook

```
# Notify for any command that took longer than a minute, and say
# whether it worked.
autoload -Uz add-zsh-hook

_notifi_start() { _NOTIFI_T=$SECONDS; _NOTIFI_CMD=$1 }
_notifi_end() {
  local code=$? secs=$(( SECONDS - ${_NOTIFI_T:-SECONDS} ))
  (( secs < 60 )) && return
  curl -s https://notifi.it/send \
    -H "Authorization: Bearer $NOTIFI_KEY" \
    -d "title=$([[ $code == 0 ]] && echo ok || echo failed) after ${secs}s" \
    -d "message=$_NOTIFI_CMD" >/dev/null
}
add-zsh-hook preexec _notifi_start
add-zsh-hook precmd  _notifi_end
```

### cron

```
# crontab -e. A cron job gets no PATH, and its output goes nowhere you
# will read, so a job that quietly stopped working stays quiet for months.
# A literal % is a newline to cron: escape any you need as \%.
PATH=/usr/local/bin:/usr/bin:/bin
NOTIFI_KEY=...

0 3 * * * backup.sh >/tmp/backup.log 2>&1; curl -s https://notifi.it/send -H "Authorization: Bearer $NOTIFI_KEY" -d "title=backup $([ $? = 0 ] && echo ok || echo failed) on $(hostname)" --data-urlencode "message=$(tail -c 800 /tmp/backup.log)"
```

### systemd

```
# Drop this in /etc/systemd/system/, then add one line to any unit:
#   OnFailure=notifi-failed@%n.service
# Every unit on the box can share it. %i is the unit that failed.
[Unit]
Description=Push a notification when %i fails

[Service]
Type=oneshot
EnvironmentFile=/etc/notifi.env
ExecStart=/usr/bin/curl -s https://notifi.it/send \
  -H "Authorization: Bearer $NOTIFI_KEY" \
  -d "title=%i failed on %H" \
  --data-urlencode "message=$(systemctl status %i --lines=10 --no-pager)"
```

### Kubernetes

```
# Put the key in a Secret, then curl at the end of any Job's command.
apiVersion: batch/v1
kind: CronJob
metadata:
  name: nightly-backup
spec:
  schedule: "0 3 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: backup
            image: alpine/curl
            command: ["/bin/sh", "-c"]
            args:
            - |
              ./backup.sh &&
              curl -s https://notifi.it/send \
                -H "Authorization: Bearer $NOTIFI_KEY" \
                -d "title=Backup complete"
            env:
            - name: NOTIFI_KEY
              valueFrom: { secretKeyRef: { name: notifi, key: key } }
```

## Questions

The [FAQ](https://notifi.it/faq) covers cost, limits, what the server can read and what happens when you delete the app. Anything else goes to [hello@notifi.it](mailto:hello@notifi.it).

---

This page as HTML: https://notifi.it/docs

## More from notifi

- [Home](https://notifi.it/)
- [FAQ](https://notifi.it/faq)
- [Privacy](https://notifi.it/privacy)
- [Terms](https://notifi.it/terms)
- [llms.txt](https://notifi.it/llms.txt)
- [hello@notifi.it](mailto:hello@notifi.it)
- [GitHub](https://github.com/notifi-it/notifi)
- [X](https://x.com/notifiit)
- [Instagram](https://instagram.com/notifidotit)
- [Facebook](https://facebook.com/notifidotit)
