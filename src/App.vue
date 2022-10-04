<script setup>
import { ref } from "vue"
import { name, version } from '../package.json'

import PicaSelectQuery from './components/PicaSelectQuery.vue'
import PicaSelectResult from './components/PicaSelectResult.vue'

const result = ref({})

const api = "http://localhost:5000"
</script>

<template>
  <main class="container">
    <PicaSelectQuery :api="api" v-model="result" class="pica-select-search"/>
  </main>
  <div class="container" v-if="result.url || result.error">
    <PicaSelectResult :result="result"/>
  </div>
  <footer class="container">
    <p>
      <a href="https://github.com/gbv/pica-select">{{name}}</a> {{version}}
      at <a :href="api">{{api}}</a>
    </p>
  </footer>
</template>

<style>
main.container {
  border: 1px solid #333;
  margin-bottom: 1rem;
  padding: 1rem;
}
footer {
  padding-top: 2em;
  color: #666;
}
</style>
