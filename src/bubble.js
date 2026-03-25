import { invoke } from '@tauri-apps/api/core';

let hideTimeout = null;

export function showBubble({ message, workDuration }) {
  const container = document.getElementById('bubble-container');
  container.innerHTML = `
    <div class="bubble">
      <div class="bubble-message">${escapeHtml(message)}</div>
      <div class="bubble-buttons">
        <button class="btn btn-primary" id="btn-rest" tabindex="0">Rest 5 min</button>
        <button class="btn btn-secondary" id="btn-snooze" tabindex="0">Not now</button>
      </div>
      <div class="bubble-info">Working for ${workDuration} min</div>
    </div>
  `;
  container.classList.remove('hiding');
  container.classList.add('visible');

  document.getElementById('btn-rest').addEventListener('click', () => {
    invoke('user_rest');
    hideBubble();
  });
  document.getElementById('btn-snooze').addEventListener('click', () => {
    invoke('user_snooze');
    hideBubble();
  });

  // 30s auto-dismiss
  clearTimeout(hideTimeout);
  hideTimeout = setTimeout(() => {
    hideBubble();
    invoke('user_snooze'); // timeout = snooze
  }, 30000);
}

export function hideBubble() {
  clearTimeout(hideTimeout);
  const container = document.getElementById('bubble-container');
  container.classList.remove('visible');
  container.classList.add('hiding');
  setTimeout(() => {
    container.classList.remove('hiding');
    container.innerHTML = '';
  }, 300);
}

export function showEyeRest() {
  const icon = document.getElementById('eye-rest-icon');
  icon.textContent = '\u{1f440}';
  icon.classList.add('visible');

  // Auto-hide after 3s
  const autoHide = setTimeout(() => {
    icon.classList.remove('visible');
    icon.textContent = '';
  }, 3000);

  // Click to expand mini bubble
  const handler = () => {
    clearTimeout(autoHide);
    icon.innerHTML = `
      <span>\u{1f440}</span>
      <div class="eye-mini-bubble">Look at something 20 feet away for 20 seconds~</div>
    `;
    setTimeout(() => {
      icon.classList.remove('visible');
      icon.innerHTML = '';
    }, 5000);
    icon.removeEventListener('click', handler);
  };
  icon.addEventListener('click', handler, { once: true });
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}
