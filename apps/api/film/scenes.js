window.OM_SCENES = JSON.stringify([
  { name: 'Deploy', dur: 3.5, desc: 'curl types out in deploy.sh and a Deploy finished banner drops onto the iPhone' },
  { name: 'Grafana', dur: 3.5, desc: 'A Grafana webhook fires and a latency alert with its graph thumbnail lands on the iPad' },
  { name: 'CI', dur: 3.5, desc: 'A GitHub Action fails and a Build failed alert slides in on the Mac' },
  { name: 'Hold', dur: 0.5, desc: 'Quiet idle prompt before the loop restarts' },
]);
window.OM_PLAYBACK = JSON.stringify({ mode: 'loop' });
