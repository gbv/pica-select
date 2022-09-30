<script setup>
import { name, version } from '../package.json'

import PicaSelectClient from './components/PicaSelectClient.vue'

const api = "http://localhost:5000"
</script>

<template>
  <main class="container">
    <PicaSelectClient :api="api" />
  </main>
  <footer class="container">
    <p>
      <a href="https://github.com/gbv/pica-select">{{name}}</a> {{version}}
      at <a :href="api">{{api}}</a>
    </p>
  </footer>
</template>

<style>
main {
  border: 1px solid #333;
  padding: 1rem;
}
footer {
  padding-top: 2em;
  color: #666;
}
</style>
