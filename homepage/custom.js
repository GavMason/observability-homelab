// Animated starfield background
(function() {
  // Create canvas
  const canvas = document.createElement('canvas');
  canvas.id = 'starfield';
  canvas.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;z-index:0;pointer-events:none;';
  document.body.prepend(canvas);

  const ctx = canvas.getContext('2d');
  let stars = [];
  const STAR_COUNT = 200;

  function resize() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
  }

  function createStars() {
    stars = [];
    for (let i = 0; i < STAR_COUNT; i++) {
      stars.push({
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height,
        size: Math.random() * 1.8 + 0.3,
        twinkleSpeed: Math.random() * 0.02 + 0.005,
        twinkleOffset: Math.random() * Math.PI * 2,
        baseAlpha: Math.random() * 0.5 + 0.3,
        // Slight blue/white tint
        hue: Math.random() > 0.7 ? 220 : 0,
        sat: Math.random() > 0.7 ? 30 : 0
      });
    }
  }

  let time = 0;
  function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    time += 1;

    for (const s of stars) {
      const alpha = s.baseAlpha + Math.sin(time * s.twinkleSpeed + s.twinkleOffset) * 0.3;
      if (s.hue) {
        ctx.fillStyle = 'hsla(' + s.hue + ',' + s.sat + '%,85%,' + Math.max(0.05, alpha) + ')';
      } else {
        ctx.fillStyle = 'rgba(255,255,255,' + Math.max(0.05, alpha) + ')';
      }
      ctx.beginPath();
      ctx.arc(s.x, s.y, s.size, 0, Math.PI * 2);
      ctx.fill();
    }

    requestAnimationFrame(draw);
  }

  resize();
  createStars();
  draw();

  window.addEventListener('resize', function() {
    resize();
    createStars();
  });
})();
