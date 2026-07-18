import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import TrailerHero from './TrailerHero.vue';

describe('TrailerHero', () => {
  it('does not render promotional copy or a Steam link over the trailer', () => {
    const wrapper = mount(TrailerHero);

    expect(wrapper.find('a').exists()).toBe(false);
    expect(wrapper.text()).not.toMatch(/watch film/i);
  });

  it('uses an inline SVG for the play icon', () => {
    const wrapper = mount(TrailerHero);
    const playButton = wrapper.get(
      'button[aria-label="Play the Straif trailer"]'
    );

    expect(playButton.get('svg').attributes('aria-hidden')).toBe('true');
    expect(playButton.element.children).toHaveLength(1);
  });

  it('loads the privacy-enhanced embed only after activation', async () => {
    const wrapper = mount(TrailerHero);
    expect(wrapper.find('iframe').exists()).toBe(false);
    await wrapper
      .get('button[aria-label="Play the Straif trailer"]')
      .trigger('click');
    const iframe = wrapper.get('iframe');
    expect(iframe.attributes('src')).toContain(
      'https://www.youtube-nocookie.com/embed/CfzotZZ3Sd0'
    );
    expect(iframe.attributes('title')).toBe('Straif official trailer');
  });
});
