import { createApp } from 'vue'
import App from './App.vue'
import { createStraifRouter } from './router'
import './styles/base.css'

createApp(App).use(createStraifRouter()).mount('#app')
