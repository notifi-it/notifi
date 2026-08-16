const host = document.getElementById('film');
const still = window.matchMedia
  && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

if (host && window.NotifiLaunchGif && !still) {
  let mounted = false;

  const render = () => {
    if (mounted) return;
    mounted = true;
    window.removeEventListener('scroll', check);
    window.removeEventListener('resize', check);
    window.ReactDOM.render(
      window.React.createElement(window.NotifiLaunchGif),
      host
    );
  };

  const check = () => {
    const box = host.getBoundingClientRect();
    const view = window.innerHeight || document.documentElement.clientHeight;
    if (!view) return render();
    if (box.top < view + 300 && box.bottom > -300) render();
  };

  window.addEventListener('scroll', check, { passive: true });
  window.addEventListener('resize', check);
  check();
}
