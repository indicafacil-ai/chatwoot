<script>
import { defineAsyncComponent } from 'vue';
import { mapGetters } from 'vuex';

import ChatAttachmentButton from 'widget/components/ChatAttachment.vue';
import ChatAudioRecorder from 'widget/components/ChatAudioRecorder.vue';
import ChatSendButton from 'widget/components/ChatSendButton.vue';
import { useAttachments } from '../composables/useAttachments';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import ResizableTextArea from 'shared/components/ResizableTextArea.vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';

const EmojiPicker = defineAsyncComponent(
  () => import('shared/components/emoji/EmojiPicker.vue')
);

export default {
  name: 'ChatInputWrap',
  components: {
    ChatAttachmentButton,
    ChatAudioRecorder,
    ChatSendButton,
    EmojiPicker,
    FluentIcon,
    ResizableTextArea,
  },
  props: {
    onSendMessage: {
      type: Function,
      default: () => {},
    },
    onSendAttachment: {
      type: Function,
      default: () => {},
    },
  },
  setup() {
    const {
      canHandleAttachments,
      shouldShowEmojiPicker,
      hasEmojiPickerEnabled,
    } = useAttachments();
    return {
      canHandleAttachments,
      shouldShowEmojiPicker,
      hasEmojiPickerEnabled,
    };
  },
  data() {
    return {
      userInput: '',
      showEmojiPicker: false,
      isFocused: false,
      isRecording: false,
    };
  },

  computed: {
    ...mapGetters({
      widgetColor: 'appConfig/getWidgetColor',
      isWidgetOpen: 'appConfig/getIsWidgetOpen',
      shouldShowEmojiPicker: 'appConfig/getShouldShowEmojiPicker',
    }),
    showAttachment() {
      return this.canHandleAttachments && this.userInput.length === 0;
    },
    // Gravar voz e uma forma de anexar: onde o anexo esta desligado, o microfone tambem nao
    // aparece. Uma regra so, em vez de dois interruptores que um dia divergem.
    showMicrophone() {
      return this.showAttachment && !this.isRecording;
    },
    showSendButton() {
      return this.userInput.length > 0;
    },
  },
  watch: {
    isWidgetOpen(isWidgetOpen) {
      if (isWidgetOpen) {
        this.focusInput();
      }
    },
  },
  unmounted() {
    document.removeEventListener('keypress', this.handleEnterKeyPress);
  },
  mounted() {
    document.addEventListener('keypress', this.handleEnterKeyPress);
    if (this.isWidgetOpen) {
      this.focusInput();
    }
  },

  methods: {
    onBlur() {
      this.isFocused = false;
    },
    onFocus() {
      this.isFocused = true;
    },
    handleButtonClick() {
      if (this.userInput && this.userInput.trim()) {
        this.onSendMessage(this.userInput);
      }
      this.userInput = '';
      this.focusInput();
    },
    handleEnterKeyPress(e) {
      if (e.keyCode === 13 && !e.shiftKey) {
        e.preventDefault();
        this.handleButtonClick();
      }
    },
    toggleEmojiPicker() {
      this.showEmojiPicker = !this.showEmojiPicker;
    },
    hideEmojiPicker(e) {
      if (this.showEmojiPicker) {
        e.stopPropagation();
        this.toggleEmojiPicker();
      }
    },
    emojiOnClick(emoji) {
      this.userInput = `${this.userInput}${emoji} `;
    },
    onSelectEmoji({ value }) {
      this.emojiOnClick(value);
    },
    onTypingOff() {
      this.toggleTyping('off');
    },
    onTypingOn() {
      this.toggleTyping('on');
    },
    toggleTyping(typingStatus) {
      this.$store.dispatch('conversation/toggleUserTyping', { typingStatus });
    },
    focusInput() {
      this.$refs.chatInput.focus();
    },
    startRecording() {
      this.isRecording = true;
    },
    // O audio sobe pelo MESMO caminho do anexo — limite de tamanho, upload direto e aviso de erro
    // sao um so. Por isso o botao de anexo continua montado durante a gravacao, apenas escondido:
    // e dele que sai o envio.
    async onFinishRecording(file) {
      this.isRecording = false;
      await this.$refs.attachment?.uploadRawFile(file);
      this.focusInput();
    },
    onCancelRecording() {
      this.isRecording = false;
      this.focusInput();
    },
    // Chave escrita por extenso, e nao montada: chave dinamica escapa da varredura de traducao e
    // so aparece como texto faltando na tela de quem ja esta com problema.
    onRecordingError(motivo) {
      this.isRecording = false;
      const aviso =
        motivo === 'PERMISSION_DENIED'
          ? this.$t('VOICE_MESSAGE.PERMISSION_DENIED')
          : this.$t('VOICE_MESSAGE.NOT_SUPPORTED');
      emitter.emit(BUS_EVENTS.SHOW_ALERT, { message: aviso });
    },
  },
};
</script>

<template>
  <div
    class="items-center flex ltr:pl-3 rtl:pr-3 ltr:pr-2 rtl:pl-2 rounded-[7px] transition-all duration-200 bg-n-background !shadow-[0_0_0_1px,0_0_2px_3px]"
    :class="{
      '!shadow-[var(--widget-color,#2781f6)]': isFocused,
      '!shadow-n-strong dark:!shadow-n-strong': !isFocused,
    }"
    @keydown.esc="hideEmojiPicker"
  >
    <ChatAudioRecorder
      v-if="isRecording"
      @finish="onFinishRecording"
      @cancel="onCancelRecording"
      @error="onRecordingError"
    />
    <ResizableTextArea
      v-show="!isRecording"
      id="chat-input"
      ref="chatInput"
      v-model="userInput"
      :rows="1"
      :aria-label="$t('CHAT_PLACEHOLDER')"
      :placeholder="$t('CHAT_PLACEHOLDER')"
      class="user-message-input reset-base"
      @typing-off="onTypingOff"
      @typing-on="onTypingOn"
      @focus="onFocus"
      @blur="onBlur"
    />
    <div
      v-show="!isRecording"
      class="relative flex items-center ltr:pl-2 rtl:pr-2"
    >
      <ChatAttachmentButton
        v-if="canHandleAttachments"
        v-show="showAttachment"
        ref="attachment"
        class="text-n-slate-12"
        :on-attach="onSendAttachment"
      />
      <button
        v-if="showMicrophone"
        class="flex items-center justify-center min-h-8 min-w-8 text-n-slate-12"
        :aria-label="$t('VOICE_MESSAGE.RECORD')"
        @click="startRecording"
      >
        <FluentIcon icon="microphone" />
      </button>
      <button
        v-if="shouldShowEmojiPicker && hasEmojiPickerEnabled"
        class="flex items-center justify-center min-h-8 min-w-8"
        :aria-label="$t('EMOJI.ARIA_LABEL')"
        @click="toggleEmojiPicker"
      >
        <FluentIcon
          icon="emoji"
          class="transition-all duration-150"
          :class="{
            'text-n-slate-12': !showEmojiPicker,
            'text-n-brand': showEmojiPicker,
          }"
        />
      </button>
      <EmojiPicker
        v-if="shouldShowEmojiPicker && showEmojiPicker"
        v-on-clickaway="hideEmojiPicker"
        class="!bottom-full end-0 mb-2 max-w-[calc(100vw-3rem)]"
        @select="onSelectEmoji"
        @keydown.esc="hideEmojiPicker"
      />
      <ChatSendButton
        v-if="showSendButton"
        :color="widgetColor"
        @click="handleButtonClick"
      />
    </div>
  </div>
</template>

<style scoped lang="scss">
.user-message-input {
  @apply border-none outline-none w-full placeholder:text-n-slate-10 resize-none h-8 min-h-8 max-h-60 py-1 px-0 my-2 bg-n-background text-n-slate-12 transition-all duration-200;
}
</style>
