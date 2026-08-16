const host = document.getElementById('film');
const still = window.matchMedia
  && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

if (host && window.NotifiLaunchGif && !still) {
  const render = () => {
    window.ReactDOM.render(
      window.React.createElement(window.NotifiLaunchGif),
      host
    );
  };

  if (window.IntersectionObserver) {
    const io = new IntersectionObserver((entries) => {
      if (!entries.some((e) => e.isIntersecting)) return;
      io.disconnect();
      render();
    }, { rootMargin: '200px' });
    io.observe(host);
  } else {
    render();
  }
}
