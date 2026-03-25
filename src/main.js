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

  // Right-click context menu on pet
  setupContextMenu();

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
}

function setupContextMenu() {
  const pet = document.getElementById('pet-container');
  pet.addEventListener('contextmenu', (e) => {
    e.preventDefault();
    showContextMenu();
  });
}

function showContextMenu() {
  const existing = document.getElementById('context-menu');
  if (existing) { existing.remove(); return; }

  const menu = document.createElement('div');
  menu.id = 'context-menu';
  menu.innerHTML = `
    <button class="context-item" id="ctx-trigger">Trigger reminder now</button>
    <div class="context-separator"></div>
    <button class="context-item" id="ctx-1min">Set 1 min interval</button>
    <button class="context-item" id="ctx-5min">Set 5 min interval</button>
    <button class="context-item" id="ctx-reset">Reset default (45min)</button>
  `;
  document.body.appendChild(menu);

  // Position above the pet
  const pet = document.getElementById('pet-container');
  const petRect = pet.getBoundingClientRect();
  const menuRect = menu.getBoundingClientRect();
  let left = petRect.left + petRect.width / 2 - menuRect.width / 2;
  let top = petRect.top - menuRect.height - 8;

  // Keep within window bounds
  left = Math.max(4, Math.min(left, window.innerWidth - menuRect.width - 4));
  if (top < 4) top = petRect.bottom + 8; // flip below if no space above
  menu.style.left = left + 'px';
  menu.style.top = top + 'px';

  document.getElementById('ctx-trigger').addEventListener('click', async () => {
    await invoke('trigger_reminder');
    menu.remove();
  });
  document.getElementById('ctx-1min').addEventListener('click', async () => {
    await invoke('set_intervals', { bigRestMin: 1, eyeRestMin: 1 });
    menu.remove();
  });
  document.getElementById('ctx-5min').addEventListener('click', async () => {
    await invoke('set_intervals', { bigRestMin: 5, eyeRestMin: 3 });
    menu.remove();
  });
  document.getElementById('ctx-reset').addEventListener('click', async () => {
    await invoke('set_intervals', { bigRestMin: 45, eyeRestMin: 20 });
    menu.remove();
  });

  // Close on outside click
  setTimeout(() => {
    document.addEventListener('click', function close(e) {
      if (!menu.contains(e.target)) {
        menu.remove();
        document.removeEventListener('click', close);
      }
    });
  }, 0);
}

main();
