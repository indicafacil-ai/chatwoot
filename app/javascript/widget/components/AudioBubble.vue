<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue';

defineProps({
  url: { type: String, required: true },
});

// A mensagem chega ao chat antes de o arquivo terminar de ser salvo, e o primeiro pedido pode voltar
// 404. O navegador nao tenta de novo sozinho: sem isto, o player fica em 0:00 ate recarregar a pagina.
const MAX_ATTEMPTS = 6;
const RETRY_DELAY_MS = 1000;

// O play e sempre o normal do navegador. O unico play barrado e o que o Chrome do celular dispara
// sozinho ao terminar um audio (volta ao primeiro da conversa e toca todos em sequencia): um audio que
// comeca logo depois de outro terminar, sem toque da pessoa neste player. O toque nem sempre chega ao
// elemento no celular (os controles nativos ficam na shadow DOM), por isso ele nao e exigido para tocar.
// Quando um comeca, os outros param.
const GESTURE_WINDOW_MS = 2000;
const CHAIN_WINDOW_MS = 1500;
const PLAY_EVENT = 'widget:audio-bubble-play';
const ENDED_KEY = 'widgetAudioEndedAt';

const audio = ref(null);
let attempts = 0;
let retryTimer = null;
let lastGestureAt = 0;

const onSourceError = () => {
  if (attempts >= MAX_ATTEMPTS) return;
  attempts += 1;
  clearTimeout(retryTimer);
  retryTimer = setTimeout(() => audio.value?.load(), attempts * RETRY_DELAY_MS);
};

const markGesture = () => {
  lastGestureAt = Date.now();
};

const onPlay = () => {
  const now = Date.now();
  const semToque = now - lastGestureAt > GESTURE_WINDOW_MS;
  const emCadeia = now - (window[ENDED_KEY] || 0) < CHAIN_WINDOW_MS;
  if (semToque && emCadeia) {
    audio.value?.pause();
    return;
  }
  window.dispatchEvent(new CustomEvent(PLAY_EVENT, { detail: audio.value }));
};

const onEnded = () => {
  window[ENDED_KEY] = Date.now();
};

const onOtherPlay = event => {
  if (event.detail !== audio.value) audio.value?.pause();
};

onMounted(() => window.addEventListener(PLAY_EVENT, onOtherPlay));

onBeforeUnmount(() => {
  clearTimeout(retryTimer);
  window.removeEventListener(PLAY_EVENT, onOtherPlay);
});
</script>

<template>
  <audio
    ref="audio"
    controls
    class="h-10 dark:invert"
    @pointerdown="markGesture"
    @touchstart.passive="markGesture"
    @keydown="markGesture"
    @play="onPlay"
    @ended="onEnded"
  >
    <source :src="url" @error="onSourceError" />
  </audio>
</template>
