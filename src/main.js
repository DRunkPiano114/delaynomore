import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { initPet, setMood, setAnimation, walkToCenter, walkBack, playHappy } from './pet.js';
import { showBubble, hideBubble, showEyeRest } from './bubble.js';
import { runOnboarding } from './onboarding.js';

async function main() {
  const config = await invoke('get_config');

  if (!config.onboarding_done) {
    await runOnboarding();
  } else {
    const pet = document.getElementById('pet-container');
    initPet(pet, config.pet_position);
  }

  // Create timer status bar
  createStatusBar();

  // Event listeners
  await listen('pet:state_update', (event) => {
    const { mood } = event.payload;
    setMood(mood);
  });

  await listen('pet:walk_to_center', () => {
    walkToCenter();
  });

  await listen('pet:show_bubble', (event) => {
    showBubble(event.payload);
  });

  await listen('pet:eye_rest', () => {
    showEyeRest();
  });

  await listen('pet:welcome_back', () => {
    setMood('Happy');
    playHappy();
  });

  await listen('pet:walk_back', () => {
    hideBubble();
    walkBack();
  });

  // Timer status updates
  await listen('timer:status', (event) => {
    updateStatusBar(event.payload);
  });
}

function createStatusBar() {
  const bar = document.createElement('div');
  bar.id = 'status-bar';
  bar.innerHTML = `
    <div class="status-progress"><div class="status-fill"></div></div>
    <div class="status-text">0:00</div>
    <div class="status-controls">
      <button class="status-btn" id="btn-debug" title="Debug menu">⚙</button>
    </div>
  `;
  document.body.appendChild(bar);

  // Debug menu on click
  document.getElementById('btn-debug').addEventListener('click', toggleDebugMenu);
}

function updateStatusBar({ workSec, intervalSec, isResting, flowProtection }) {
  const fill = document.querySelector('.status-fill');
  const text = document.querySelector('.status-text');
  if (!fill || !text) return;

  const pct = Math.min(100, (workSec / intervalSec) * 100);
  fill.style.width = pct + '%';

  if (isResting) {
    text.textContent = 'Resting...';
    fill.style.background = 'var(--color-happy)';
  } else if (flowProtection) {
    const min = Math.floor(workSec / 60);
    const sec = workSec % 60;
    text.textContent = `${min}:${String(sec).padStart(2, '0')} (flow protection)`;
    fill.style.background = 'var(--color-text-muted)';
  } else {
    const min = Math.floor(workSec / 60);
    const sec = workSec % 60;
    const target = Math.floor(intervalSec / 60);
    text.textContent = `${min}:${String(sec).padStart(2, '0')} / ${target}min`;
    fill.style.background = pct > 80 ? 'var(--color-sad)' : 'var(--color-primary)';
  }
}

let debugMenuOpen = false;
function toggleDebugMenu() {
  const existing = document.getElementById('debug-menu');
  if (existing) { existing.remove(); debugMenuOpen = false; return; }
  debugMenuOpen = true;

  const menu = document.createElement('div');
  menu.id = 'debug-menu';
  menu.innerHTML = `
    <button class="debug-item" id="dbg-trigger">Trigger reminder now</button>
    <button class="debug-item" id="dbg-1min">Set 1 min interval</button>
    <button class="debug-item" id="dbg-5min">Set 5 min interval</button>
    <button class="debug-item" id="dbg-reset">Reset default (45min)</button>
  `;
  document.body.appendChild(menu);

  document.getElementById('dbg-trigger').addEventListener('click', async () => {
    await invoke('trigger_reminder');
    menu.remove();
  });
  document.getElementById('dbg-1min').addEventListener('click', async () => {
    await invoke('set_intervals', { bigRestMin: 1, eyeRestMin: 1 });
    menu.remove();
  });
  document.getElementById('dbg-5min').addEventListener('click', async () => {
    await invoke('set_intervals', { bigRestMin: 5, eyeRestMin: 3 });
    menu.remove();
  });
  document.getElementById('dbg-reset').addEventListener('click', async () => {
    await invoke('set_intervals', { bigRestMin: 45, eyeRestMin: 20 });
    menu.remove();
  });

  // Close on outside click
  setTimeout(() => {
    document.addEventListener('click', function close(e) {
      if (!menu.contains(e.target) && e.target.id !== 'btn-debug') {
        menu.remove();
        document.removeEventListener('click', close);
      }
    });
  }, 0);
}

main();
