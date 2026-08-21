import type { Sample } from './spec.js';

export const samples: Sample[] = [
  {
    id: 'curl',
    label: 'curl',
    file: 'send.sh',
    code: `curl -X POST https://notifi.it/send \\
  -H "Authorization: Bearer $NOTIFI_KEY" \\
  -d "title=Backup complete" \\
  -d "message=4.2 GB in 3m 11s" \\
  -d "link=https://console.internal/backups"`,
  },
  {
    id: 'js',
    label: 'JavaScript',
    file: 'send.js',
    code: `await fetch("https://notifi.it/send", {
  method: "POST",
  headers: {
    "Authorization": \`Bearer \${process.env.NOTIFI_KEY}\`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    title: "Backup complete",
    message: "4.2 GB in 3m 11s",
  }),
});`,
  },
  {
    id: 'py',
    keywords: ['import'],
    label: 'Python',
    file: 'send.py',
    code: `import os, requests

requests.post(
    "https://notifi.it/send",
    headers={"Authorization": f"Bearer {os.environ['NOTIFI_KEY']}"},
    json={
        "title": "Backup complete",
        "message": "4.2 GB in 3m 11s",
    },
)`,
  },
  {
    id: 'go',
    keywords: ['package', 'import', 'func'],
    label: 'Go',
    file: 'send.go',
    code: `package main

import (
	"net/http"
	"net/url"
	"os"
	"strings"
)

func main() {
	form := url.Values{
		"title":   {"Backup complete"},
		"message": {"4.2 GB in 3m 11s"},
	}
	req, _ := http.NewRequest("POST", "https://notifi.it/send",
		strings.NewReader(form.Encode()))
	req.Header.Set("Authorization", "Bearer "+os.Getenv("NOTIFI_KEY"))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	http.DefaultClient.Do(req)
}`,
  },
  {
    id: 'swift',
    keywords: ['import', 'var', 'try await', 'try', 'for'],
    label: 'Swift',
    file: 'Send.swift',
    code: `import Foundation

var request = URLRequest(url: URL(string: "https://notifi.it/send")!)
request.httpMethod = "POST"
request.setValue("Bearer \\(key)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = try JSONEncoder().encode([
    "title": "Backup complete",
    "message": "4.2 GB in 3m 11s",
])

_ = try await URLSession.shared.data(for: request)`,
  },
  {
    id: 'ruby',
    keywords: ['require', 'true'],
    label: 'Ruby',
    file: 'send.rb',
    code: `require "net/http"

uri = URI("https://notifi.it/send")
req = Net::HTTP::Post.new(uri)
req["Authorization"] = "Bearer #{ENV['NOTIFI_KEY']}"
req.set_form_data(
  "title" => "Backup complete",
  "message" => "4.2 GB in 3m 11s"
)

Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }`,
  },
  {
    id: 'php',
    keywords: ['true'],
    label: 'PHP',
    file: 'send.php',
    code: `<?php
$ch = curl_init("https://notifi.it/send");
curl_setopt_array($ch, [
    CURLOPT_POST       => true,
    CURLOPT_HTTPHEADER => ["Authorization: Bearer " . getenv("NOTIFI_KEY")],
    CURLOPT_POSTFIELDS => [
        "title"   => "Backup complete",
        "message" => "4.2 GB in 3m 11s",
    ],
]);
curl_exec($ch);`,
  },
  {
    id: 'rust',
    keywords: ['let', 'await'],
    label: 'Rust',
    file: 'main.rs',
    code: `// reqwest = { version = "0.12", features = ["json"] }
let key = std::env::var("NOTIFI_KEY")?;

reqwest::Client::new()
    .post("https://notifi.it/send")
    .bearer_auth(key)
    .form(&[
        ("title", "Backup complete"),
        ("message", "4.2 GB in 3m 11s"),
    ])
    .send()
    .await?;`,
  },
  {
    id: 'hook',
    label: 'Claude Code',
    file: '.claude/settings.json',
    code: `// Fires when Claude stops.
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "curl -s https://notifi.it/send \\
                     -H \\"Authorization: Bearer $NOTIFI_KEY\\" \\
                     -d \\"title=Claude finished\\" \\
                     -d \\"message=$CLAUDE_PROJECT_DIR\\""
      }]
    }]
  }
}`,
  },
  {
    id: 'gha',
    label: 'GitHub Actions',
    file: '.github/workflows/ci.yml',
    code: `# Put NOTIFI_KEY in the repository's secrets.
- name: Tell me it broke
  if: failure()
  run: |
    curl -s https://notifi.it/send \\
      -H "Authorization: Bearer $NOTIFI_KEY" \\
      -d "title=$GITHUB_WORKFLOW failed" \\
      -d "message=$GITHUB_REF_NAME at $(git log -1 --format=%s)" \\
      -d "link=$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
  env:
    NOTIFI_KEY: \${{ secrets.NOTIFI_KEY }}`,
  },
  {
    id: 'shell',
    keywords: ['autoload', 'local', 'return'],
    label: 'Shell hook',
    file: '~/.zshrc',
    code: `# Notify for any command that took longer than a minute, and say
# whether it worked.
autoload -Uz add-zsh-hook

_notifi_start() { _NOTIFI_T=$SECONDS; _NOTIFI_CMD=$1 }
_notifi_end() {
  local code=$? secs=$(( SECONDS - \${_NOTIFI_T:-SECONDS} ))
  (( secs < 60 )) && return
  curl -s https://notifi.it/send \\
    -H "Authorization: Bearer $NOTIFI_KEY" \\
    -d "title=$([[ $code == 0 ]] && echo ok || echo failed) after \${secs}s" \\
    -d "message=$_NOTIFI_CMD" >/dev/null
}
add-zsh-hook preexec _notifi_start
add-zsh-hook precmd  _notifi_end`,
  },
  {
    id: 'systemd',
    keywords: ['Unit', 'Service'],
    label: 'systemd',
    file: 'notifi-failed@.service',
    code: `# Drop this in /etc/systemd/system/, then add one line to any unit:
#   OnFailure=notifi-failed@%n.service
# Every unit on the box can share it. %i is the unit that failed.
[Unit]
Description=Push a notification when %i fails

[Service]
Type=oneshot
EnvironmentFile=/etc/notifi.env
ExecStart=/usr/bin/curl -s https://notifi.it/send \\
  -H "Authorization: Bearer $NOTIFI_KEY" \\
  -d "title=%i failed on %H" \\
  --data-urlencode "message=$(systemctl status %i --lines=10 --no-pager)"`,
  },
  {
    id: 'kube',
    label: 'Kubernetes',
    file: 'backup.yaml',
    code: `# Put the key in a Secret, then curl at the end of any Job's command.
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
              curl -s https://notifi.it/send \\
                -H "Authorization: Bearer $NOTIFI_KEY" \\
                -d "title=Backup complete"
            env:
            - name: NOTIFI_KEY
              valueFrom: { secretKeyRef: { name: notifi, key: key } }`,
  },
];
