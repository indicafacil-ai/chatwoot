<script setup>
import { onBeforeUnmount, ref } from 'vue';

defineProps({
  url: { type: String, required: true },
});

// A mensagem chega ao chat antes de o arquivo terminar de ser salvo, e o primeiro pedido pode voltar
// 404. O navegador nao tenta de novo sozinho: sem isto, o player fica em 0:00 ate recarregar a pagina.
const MAX_ATTEMPTS = 6;
const RETRY_DELAY_MS = 1000;

const audio = ref(null);
let attempts = 0;
let retryTimer = null;

const onSourceError = () => {
  if (attempts >= MAX_ATTEMPTS) return;
  attempts += 1;
  clearTimeout(retryTimer);
  retryTimer = setTimeout(() => audio.value?.load(), attempts * RETRY_DELAY_MS);
};

onBeforeUnmount(() => clearTimeout(retryTimer));
</script>

<template>
  <audio ref="audio" controls class="h-10 dark:invert">
    <source :src="url" @error="onSourceError" />
  </audio>
</template>
