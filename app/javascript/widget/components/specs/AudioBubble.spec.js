import { mount } from '@vue/test-utils';
import AudioBubble from '../AudioBubble.vue';

describe('AudioBubble', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  const montar = () => {
    const wrapper = mount(AudioBubble, {
      props: { url: 'https://x/reply.ogg' },
    });
    const load = vi.fn();
    wrapper.find('audio').element.load = load;
    return { wrapper, load };
  };

  it('usa o endereco recebido', () => {
    const { wrapper } = montar();
    expect(wrapper.find('source').attributes('src')).toBe(
      'https://x/reply.ogg'
    );
  });

  it('tenta carregar de novo quando o arquivo ainda nao esta pronto', async () => {
    const { wrapper, load } = montar();
    await wrapper.find('source').trigger('error');
    expect(load).not.toHaveBeenCalled();
    vi.advanceTimersByTime(1000);
    expect(load).toHaveBeenCalledTimes(1);
  });

  it('desiste depois do limite de tentativas', async () => {
    const { wrapper, load } = montar();
    for (let i = 0; i < 10; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await wrapper.find('source').trigger('error');
      vi.advanceTimersByTime(10000);
    }
    expect(load).toHaveBeenCalledTimes(6);
  });

  it('nao tenta de novo depois de sair da tela', async () => {
    const { wrapper, load } = montar();
    await wrapper.find('source').trigger('error');
    wrapper.unmount();
    vi.advanceTimersByTime(10000);
    expect(load).not.toHaveBeenCalled();
  });

  describe('quando toca', () => {
    const comPause = wrapper => {
      const pause = vi.fn();
      wrapper.find('audio').element.pause = pause;
      return pause;
    };

    afterEach(() => {
      delete window.widgetAudioEndedAt;
    });

    it('toca normalmente com o play, mesmo sem o toque chegar ao elemento', async () => {
      const { wrapper } = montar();
      const pause = comPause(wrapper);
      await wrapper.find('audio').trigger('play');
      expect(pause).not.toHaveBeenCalled();
    });

    it('para o audio que comeca sozinho logo depois de outro terminar', async () => {
      const primeiro = montar().wrapper;
      const segundo = montar().wrapper;
      const pauseSegundo = comPause(segundo);
      await primeiro.find('audio').trigger('ended');
      await segundo.find('audio').trigger('play');
      expect(pauseSegundo).toHaveBeenCalledTimes(1);
      primeiro.unmount();
      segundo.unmount();
    });

    it('deixa tocar o proximo quando a pessoa toca nele depois de outro terminar', async () => {
      const primeiro = montar().wrapper;
      const segundo = montar().wrapper;
      const pauseSegundo = comPause(segundo);
      await primeiro.find('audio').trigger('ended');
      await segundo.find('audio').trigger('pointerdown');
      await segundo.find('audio').trigger('play');
      expect(pauseSegundo).not.toHaveBeenCalled();
      primeiro.unmount();
      segundo.unmount();
    });

    it('deixa tocar depois do toque da pessoa no player', async () => {
      const { wrapper } = montar();
      const pause = comPause(wrapper);
      await wrapper.find('audio').trigger('pointerdown');
      await wrapper.find('audio').trigger('play');
      expect(pause).not.toHaveBeenCalled();
    });

    it('para os outros audios quando um comeca', async () => {
      const primeiro = montar().wrapper;
      const segundo = montar().wrapper;
      const pausePrimeiro = comPause(primeiro);
      await segundo.find('audio').trigger('pointerdown');
      await segundo.find('audio').trigger('play');
      expect(pausePrimeiro).toHaveBeenCalledTimes(1);
      primeiro.unmount();
      segundo.unmount();
    });
  });
});
