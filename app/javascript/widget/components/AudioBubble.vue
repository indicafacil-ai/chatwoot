<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue';

defineProps({
  url: { type: String, required: true },
});

// A mensagem chega ao chat antes de o arquivo terminar de ser salvo, e o primeiro pedido pode voltar
// 404. O navegador nao tenta de novo sozinho: sem isto, o player fica em 0:00 ate recarregar a pagina.
const MAX_ATTEMPTS = 6;
const RETRY_DELAY_MS = 1000;

// O Chrome do celular, ao terminar um audio, pode voltar ao primeiro da conversa e tocar todos em
// sequencia sem ninguem tocar na tela. Aqui um audio so toca com o gesto da pessoa NESTE player, e
// quando um comeca os outros param.
const GESTURE_WINDOW_MS = 2000;
const PLAY_EVENT = 'widget:audio-bubble-play';

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
  if (Date.now() - lastGestureAt > GESTURE_WINDOW_MS) {
    audio.value?.pause();
    return;
  }
  window.dispatchEvent(new CustomEvent(PLAY_EVENT, { detail: audio.value }));
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
  >
    <source :src="url" @error="onSourceError" />
  </audio>
</template>
