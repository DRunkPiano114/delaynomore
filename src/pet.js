const EYES = {
  happy: `
    <path class="eye-l" d="M25,34 Q27,31 29,34" stroke="#1F2937" stroke-width="2" fill="none" stroke-linecap="round"/>
    <path class="eye-r" d="M35,34 Q37,31 39,34" stroke="#1F2937" stroke-width="2" fill="none" stroke-linecap="round"/>`,
  normal: `
    <circle class="eye-l" cx="27" cy="33" r="2.5" fill="#1F2937"/>
    <circle class="eye-r" cx="37" cy="33" r="2.5" fill="#1F2937"/>`,
  sad: `
    <path class="eye-l" d="M25,33 Q27,36 29,33" stroke="#1F2937" stroke-width="2" fill="none" stroke-linecap="round"/>
    <path class="eye-r" d="M35,33 Q37,36 39,33" stroke="#1F2937" stroke-width="2" fill="none" stroke-linecap="round"/>`,
  sleep: `
    <line class="eye-l" x1="25" y1="34" x2="29" y2="34" stroke="#1F2937" stroke-width="2" stroke-linecap="round"/>
    <line class="eye-r" x1="35" y1="34" x2="39" y2="34" stroke="#1F2937" stroke-width="2" stroke-linecap="round"/>`,
};

function buildSVG(eyeKey) {
  const eyes = EYES[eyeKey] || EYES.normal;
  return `<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <!-- Body -->
  <ellipse cx="32" cy="38" rx="20" ry="18" fill="#FBBF24"/>
  <!-- Left ear (smaller) -->
  <polygon points="16,24 22,10 28,24" fill="#FBBF24"/>
  <polygon points="18,22 22,13 26,22" fill="#F9A825"/>
  <!-- Right ear (larger — anti-AI-slop) -->
  <polygon points="36,24 44,6 50,24" fill="#FBBF24"/>
  <polygon points="38,22 44,10 48,22" fill="#F9A825"/>
  <!-- Tail -->
  <path d="M50,42 Q60,30 56,20 Q54,16 50,18" stroke="#F59E0B" stroke-width="3" fill="none" stroke-linecap="round"/>
  <!-- Eyes -->
  ${eyes}
  <!-- Nose -->
  <ellipse cx="32" cy="37" rx="2" ry="1.5" fill="#F59E0B"/>
  <!-- Mouth -->
  <path d="M30,39 Q32,41 34,39" stroke="#1F2937" stroke-width="1" fill="none"/>
</svg>`;
}

let currentAnim = 'idle';
let currentMood = 'Happy';
let isDragging = false;
let dragOffsetX = 0;
let dragOffsetY = 0;
let savedPosition = null;

export function initPet(container, position) {
  container.innerHTML = buildSVG('happy');
  setAnimation('idle');

  if (position && (position[0] !== 0 || position[1] !== 0)) {
    container.style.right = 'auto';
    container.style.left = position[0] + 'px';
    container.style.bottom = position[1] + 'px';
    savedPosition = { x: position[0], y: position[1] };
  }

  // Drag handling
  container.addEventListener('mousedown', (e) => {
    isDragging = true;
    dragOffsetX = e.clientX - container.getBoundingClientRect().left;
    dragOffsetY = e.clientY - container.getBoundingClientRect().top;
    container.style.transition = 'none';
    e.preventDefault();
  });

  document.addEventListener('mousemove', (e) => {
    if (!isDragging) return;
    let x = e.clientX - dragOffsetX;
    let y = e.clientY - dragOffsetY;
    // Constrain to window
    x = Math.max(0, Math.min(window.innerWidth - 64, x));
    y = Math.max(0, Math.min(window.innerHeight - 64, y));
    container.style.right = 'auto';
    container.style.bottom = 'auto';
    container.style.left = x + 'px';
    container.style.top = y + 'px';
  });

  document.addEventListener('mouseup', () => {
    if (!isDragging) return;
    isDragging = false;
    container.style.transition = '';
    const rect = container.getBoundingClientRect();
    savedPosition = { x: rect.left, y: window.innerHeight - rect.bottom };
    // Persist position
    import('@tauri-apps/api/core').then(({ invoke }) => {
      invoke('update_pet_position', { x: savedPosition.x, y: savedPosition.y });
    });
  });
}

export function setMood(mood) {
  currentMood = mood;
  const container = document.getElementById('pet-container');
  const eyeMap = { Happy: 'happy', Normal: 'normal', Sad: 'sad' };
  container.innerHTML = buildSVG(eyeMap[mood] || 'normal');
}

export function setAnimation(type) {
  const container = document.getElementById('pet-container');
  container.className = '';
  currentAnim = type;
  container.classList.add('anim-' + type);
}

export function walkToCenter() {
  const container = document.getElementById('pet-container');
  setAnimation('walk');
  container.style.transition = 'left 0.8s ease-in-out, right 0.8s ease-in-out, bottom 0.8s ease-in-out, top 0.8s ease-in-out';
  container.style.right = 'auto';
  container.style.top = 'auto';
  container.style.left = (window.innerWidth / 2 - 32) + 'px';
  container.style.bottom = '20px';
  setTimeout(() => setAnimation('remind'), 800);
}

export function walkBack() {
  const container = document.getElementById('pet-container');
  setAnimation('walk');
  container.style.transition = 'left 0.8s ease-in-out, right 0.8s ease-in-out, bottom 0.8s ease-in-out, top 0.8s ease-in-out';
  if (savedPosition) {
    container.style.right = 'auto';
    container.style.top = 'auto';
    container.style.left = savedPosition.x + 'px';
    container.style.bottom = savedPosition.y + 'px';
  } else {
    container.style.left = 'auto';
    container.style.top = 'auto';
    container.style.right = '20px';
    container.style.bottom = '20px';
  }
  setTimeout(() => setAnimation('idle'), 800);
}

export function playHappy() {
  setAnimation('happy');
  setTimeout(() => setAnimation('idle'), 1800);
}
