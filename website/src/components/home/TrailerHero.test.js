import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import TrailerHero from './TrailerHero.vue';

describe('TrailerHero', () => {
  it('links to Steam without the retired Watch film copy', () => {
    const wrapper = mount(TrailerHero);
    const steamLink = wrapper.get('a');

    expect(steamLink.text()).toBe('Get Straif on Steam');
    expect(steamLink.attributes()).toMatchObject({
      href: 'https://store.steampowered.com/app/3850480/Straif/',
      target: '_blank',
      rel: 'noopener noreferrer',
    });
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
