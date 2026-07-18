import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import TrailerHero from './TrailerHero.vue';

describe('TrailerHero', () => {
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
