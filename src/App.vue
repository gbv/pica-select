<script setup>
import { name, version } from '../package.json'

import PicaSelectClient from './components/PicaSelectClient.vue'
</script>

<template>
  <main class="container">
    <PicaSelectClient api="http://localhost:5000" />
  </main>
  <footer class="container">
    <p>
      Build with <a href="https://github.com/gbv/pica-select">{{name}}</a> {{version}}
    </p>
  </footer>
</template>

<style>
footer {
  padding-top: 2em;
  color: #666;
}
</style>
