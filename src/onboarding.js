import { invoke } from '@tauri-apps/api/core';
import { initPet, setAnimation, playHappy } from './pet.js';

export async function runOnboarding() {
  const pet = document.getElementById('pet-container');
  const ob = document.getElementById('onboarding-container');
  ob.classList.add('active');

  // Step 1: Pet enters from bottom
  pet.style.bottom = '-80px';
  pet.style.transition = 'bottom 0.6s ease-out';
  initPet(pet, null);
  await delay(100);
  pet.style.bottom = '20px';
  setAnimation('happy');
  await delay(800);

  // Step 2: Name input
  ob.innerHTML = `
    <div class="onboarding-bubble">
      <div class="onboarding-text">Hi! I'm your desktop buddy~ Give me a name!</div>
      <input class="onboarding-input" id="name-input" type="text" value="Kitty" maxlength="10" />
      <button class="btn btn-primary" id="name-confirm" style="width:100%">Confirm</button>
    </div>
  `;
  const nameInput = document.getElementById('name-input');
  nameInput.focus();
  nameInput.select();

  const name = await new Promise((resolve) => {
    const confirm = () => resolve(nameInput.value.trim() || 'Kitty');
    document.getElementById('name-confirm').addEventListener('click', confirm);
    nameInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') confirm();
    });
  });

  await invoke('set_pet_name', { name });
  playHappy();
  await delay(600);

  // Step 3: Greeting
  ob.innerHTML = `
    <div class="onboarding-bubble">
      <div class="onboarding-text">I'm ${escapeHtml(name)}! From now on I'll keep you company and remind you to rest \u{1f4aa}</div>
      <button class="btn btn-primary" id="start-btn" style="width:100%">Let's go!</button>
    </div>
  `;

  await new Promise((resolve) => {
    document.getElementById('start-btn').addEventListener('click', resolve);
  });

  // Step 4: Complete onboarding
  await invoke('complete_onboarding');
  ob.classList.remove('active');
  ob.innerHTML = '';
  setAnimation('idle');
}

function delay(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}
